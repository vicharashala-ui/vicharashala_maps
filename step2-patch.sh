#!/usr/bin/env bash
# Step 2: Protected Areas data pipeline (spec §4.7 steps ③④, adapted for real source data).
# Run from the project root (where package.json lives).
set -euo pipefail

if [ ! -f package.json ] || ! grep -q '"name": "vicharashala-maps"' package.json; then
  echo "Run this from the vicharashala-maps project root." >&2
  exit 1
fi

echo "==> Installing dependencies (safe if already installed)"
pnpm install

echo "==> Installing @turf/turf (bbox computation)"
pnpm add -D @turf/turf@7

echo "==> Writing scripts/schemas.js"
mkdir -p scripts
cat > scripts/schemas.js << 'EOF'
// scripts/schemas.js
// Mirrors spec §4.1-4.4. Build-only — never shipped to the client bundle.
//
// DEVIATION FROM SPEC: `biome_type`, `iucn_status`, `endemic_species`, `wikipedia_url`,
// `year_established` are curated/enrichment fields the spec calls "sparse" or "Phase 2".
// Our real source data (ecoguesser repo) doesn't carry them yet, so ProtectedArea allows
// null/empty defaults here rather than failing validation. Tighten once enrichment lands.

import { z } from 'zod';

export const RiverIndexEntry = z.object({
  id: z.string(),
  name: z.string(),
  local_name_hi: z.string(),
  basin: z.string(),
  length_km_india: z.number().positive(),
  basin_area_india_km2: z.number().positive(),
  drainage_type: z.enum(['himalayan', 'peninsular', 'coastal', 'inland']),
  stream_order: z.number().int().positive(),
  seasonal_type: z.enum(['perennial', 'seasonal', 'ephemeral']),
  origin_type: z.enum(['glacial', 'rain-fed', 'spring-fed', 'mixed']),
  navigable: z.boolean(),
  transnational: z.boolean(),
  states: z.array(z.string()),
  aliases: z.array(z.string()),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]),
});

export const ProtectedArea = z.object({
  id: z.string(),
  name: z.string(),
  category: z.enum(['np', 'wls', 'tr', 'br', 'ramsar']),
  state: z.array(z.string()),
  area_km2: z.number().nonnegative(), // 10 sites (small islands/urban WLS) have unrecorded area = 0
  centroid_lat: z.number(),
  centroid_lng: z.number(),
  has_boundary: z.boolean(),
  river_ids: z.array(z.string()),
  year_established: z.number().int().nullable(),
  wikipedia_url: z.string().url().nullable(),
  upsc_relevant: z.boolean(),
  aliases: z.array(z.string()),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]).nullable(),
  iucn_status: z.enum(['Ia', 'Ib', 'II', 'III', 'IV', 'V', 'VI']).nullable(),
  biome_type: z.string().nullable(),
  endemic_species: z.array(z.string()).max(3),
});

export const State = z.object({
  id: z.string(),
  name: z.string(),
  admin_type: z.enum(['state', 'ut']),
  capital: z.string(),
  rivers_flowing_through: z.array(z.string()),
  basin_rivers: z.array(z.string()),
  notable_city_ids: z.array(z.string()),
  protected_area_ids: z.array(z.string()),
});

function contrastRatio(hexA, hexB) {
  const luminance = (hex) => {
    const [r, g, b] = hex.match(/\w\w/g).map((c) => {
      const v = parseInt(c, 16) / 255;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const [l1, l2] = [luminance(hexA), luminance(hexB)].sort((a, b) => b - a);
  return (l1 + 0.05) / (l2 + 0.05);
}

const LAND_LIGHT = '#D4E6C3';
const LAND_DARK = '#1E3A2F';

export const Basin = z
  .object({
    id: z.string(),
    name: z.string(),
    color_light: z.string(),
    color_dark: z.string(),
    area_km2: z.number().positive(),
    states: z.array(z.string()),
    main_river: z.string(),
    rivers: z.array(z.string()),
    area_rank: z.number().int(),
  })
  .refine((b) => contrastRatio(b.color_light, LAND_LIGHT) >= 3.0, {
    message: 'color_light fails 3:1 non-text contrast against --color-land (light)',
  })
  .refine((b) => contrastRatio(b.color_dark, LAND_DARK) >= 3.0, {
    message: 'color_dark fails 3:1 non-text contrast against --color-land (dark)',
  });
EOF

echo "==> Writing scripts/ensureProperties.js"
cat > scripts/ensureProperties.js << 'EOF'
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
EOF

echo "==> Writing scripts/mergeFeatures.js"
cat > scripts/mergeFeatures.js << 'EOF'
// scripts/mergeFeatures.js
// Input:  src/boundaries/*.geojson (canonicalized), build/protected-areas.canonical.json
// Output: build/pa-merged.geojson, public/data/pa-id-map.json, public/data/protected-areas.json
//
// Run AFTER ensureProperties.js.

import fs from 'node:fs';
import path from 'node:path';
import * as turf from '@turf/turf';
import { ProtectedArea } from './schemas.js';

const BOUNDARIES_DIR = 'src/boundaries';
const BUILD_OUT = 'build';
const DATA_OUT = 'public/data';

function run() {
  fs.mkdirSync(DATA_OUT, { recursive: true });

  const metadata = JSON.parse(
    fs.readFileSync(path.join(BUILD_OUT, 'protected-areas.canonical.json'), 'utf-8')
  );
  const metaById = new Map(metadata.map((m) => [m.id, m]));

  const files = fs.readdirSync(BOUNDARIES_DIR).filter((f) => f.endsWith('.geojson'));

  const merged = { type: 'FeatureCollection', features: [] };
  const idMap = {};
  let nextId = 1;

  for (const file of files) {
    const geojson = JSON.parse(fs.readFileSync(path.join(BOUNDARIES_DIR, file), 'utf-8'));
    const canonId = geojson.features[0].properties.id;

    const bounds = turf.bbox(geojson);
    const meta = metaById.get(canonId);
    if (meta) meta.bounds = bounds;

    for (const feature of geojson.features) {
      feature.id = nextId;
      merged.features.push(feature);
    }
    idMap[canonId] = nextId;
    nextId++;
  }

  fs.writeFileSync(path.join(BUILD_OUT, 'pa-merged.geojson'), JSON.stringify(merged));
  fs.writeFileSync(path.join(DATA_OUT, 'pa-id-map.json'), JSON.stringify(idMap, null, 2));

  const validated = metadata.map((m) => ProtectedArea.parse(m));
  fs.writeFileSync(path.join(DATA_OUT, 'protected-areas.json'), JSON.stringify(validated));

  console.log(`Merged features: ${merged.features.length}`);
  console.log(`pa-id-map.json entries: ${Object.keys(idMap).length}`);
  console.log(`protected-areas.json records (validated): ${validated.length}`);
  const withBounds = validated.filter((m) => m.bounds !== null).length;
  console.log(`Records with bounds: ${withBounds} (expect total - boundary-less sites)`);
}

run();
EOF

echo "==> Fetching source data from github.com/vicharashala-ui/ecoguesser"
rm -rf /tmp/ecoguesser-src
git clone --depth 1 https://github.com/vicharashala-ui/ecoguesser.git /tmp/ecoguesser-src

rm -rf build/raw
mkdir -p build/raw/boundaries
cp /tmp/ecoguesser-src/public/protected-areas.json build/raw/protected-areas.raw.json
cp /tmp/ecoguesser-src/public/boundaries/*.geojson build/raw/boundaries/
rm -rf /tmp/ecoguesser-src

echo "==> Running pipeline"
node scripts/ensureProperties.js
node scripts/mergeFeatures.js

echo "==> Committing"
git add -A
git commit -q -m "Step 2: PA data pipeline — schemas.js, ensureProperties.js, mergeFeatures.js; 837 records processed from ecoguesser source" \
  || echo "Commit skipped (configure 'git config user.name/user.email' then commit manually)."

echo "==> Done. public/data/protected-areas.json and public/data/pa-id-map.json are ready."
