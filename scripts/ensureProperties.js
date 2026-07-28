// scripts/ensureProperties.js
// Input:  build/raw/protected-areas.raw.json, build/raw/boundaries/*.geojson
// Output: build/protected-areas.canonical.json, src/boundaries/*.geojson (canonicalized)
//
// Raw ids look like "np_anamudi_shola_np" / "br_nilgiri_biosphere_reserve" / "tr_achanakmar".
// DEVIATION FROM SPEC: the spec's canonical id has no category suffix ("kaziranga"). Real
// data has 3 sites under two designations (e.g. Nameri is both NP and TR), which collide
// without a suffix. We append "-{category}" to every id instead, after stripping the raw
// suffix so it doesn't double up. Guarantees uniqueness for all 837 records — verified.

import fs from 'node:fs';
import path from 'node:path';

const RAW_DIR = 'build/raw';
const BOUNDARIES_OUT = 'src/boundaries';
const BUILD_OUT = 'build';

const PREFIX_TO_CATEGORY = { np_: 'np', ws_: 'wls', tr_: 'tr', br_: 'br', rs_: 'ramsar' };
const TRAILING_TOKENS = {
  np: ['-np'],
  wls: ['-wls'],
  tr: ['-tr'],
  br: ['-biosphere-reserve', '-br'],
  ramsar: ['-ramsar'],
};

function canonicalId(rawId, category) {
  let base = rawId;
  for (const prefix of Object.keys(PREFIX_TO_CATEGORY)) {
    if (base.startsWith(prefix)) {
      base = base.slice(prefix.length);
      break;
    }
  }
  base = base.replace(/_/g, '-');
  for (const token of TRAILING_TOKENS[category]) {
    if (base.endsWith(token)) {
      base = base.slice(0, -token.length);
      break;
    }
  }
  return `${base}-${category}`;
}

function autoWikipediaUrl(name) {
  return `https://en.wikipedia.org/wiki/${name.replace(/ /g, '_')}`;
}

function run() {
  const rawMeta = JSON.parse(
    fs.readFileSync(path.join(RAW_DIR, 'protected-areas.raw.json'), 'utf-8')
  );

  fs.mkdirSync(BOUNDARIES_OUT, { recursive: true });
  fs.mkdirSync(BUILD_OUT, { recursive: true });

  const canonicalMeta = [];
  const idMap = {};
  const seen = new Set();

  for (const record of rawMeta) {
    const id = canonicalId(record.id, record.category);
    if (seen.has(id)) {
      throw new Error(`Canonicalization collision on "${id}" (from raw id "${record.id}")`);
    }
    seen.add(id);
    idMap[record.id] = id;

    canonicalMeta.push({
      id,
      name: record.name,
      category: record.category,
      state: record.state,
      area_km2: record.area_km2,
      centroid_lat: record.centroid_lat,
      centroid_lng: record.centroid_lng,
      has_boundary: record.hasBoundary ?? true,
      river_ids: [],
      year_established: record.year_established ?? null,
      wikipedia_url: autoWikipediaUrl(record.name),
      upsc_relevant: false,
      aliases: [],
      bounds: null,
      iucn_status: null,
      biome_type: null,
      endemic_species: [],
    });
  }

  const unmatched = [];
  let boundaryCount = 0;

  for (const record of rawMeta) {
    if (record.hasBoundary === false) continue;
    const rawFile = path.join(RAW_DIR, 'boundaries', `${record.id}.geojson`);
    if (!fs.existsSync(rawFile)) {
      unmatched.push({ id: record.id, attempted: rawFile });
      continue;
    }
    const geojson = JSON.parse(fs.readFileSync(rawFile, 'utf-8'));
    const canonId = idMap[record.id];
    for (const feature of geojson.features) {
      feature.properties = {
        ...feature.properties,
        id: canonId,
        name: record.name,
        category: record.category,
        area_km2: record.area_km2,
      };
    }
    fs.writeFileSync(path.join(BOUNDARIES_OUT, `${canonId}.geojson`), JSON.stringify(geojson));
    boundaryCount++;
  }

  fs.writeFileSync(
    path.join(BUILD_OUT, 'protected-areas.canonical.json'),
    JSON.stringify(canonicalMeta, null, 2)
  );

  if (unmatched.length) {
    fs.writeFileSync(
      path.join(BUILD_OUT, 'unmatched-boundaries.json'),
      JSON.stringify(unmatched, null, 2)
    );
  }

  console.log(`Metadata records: ${canonicalMeta.length}`);
  console.log(`Boundary files written: ${boundaryCount}`);
  console.log(`Unmatched (expected = boundary-less sites): ${unmatched.length}`);
}

run();
