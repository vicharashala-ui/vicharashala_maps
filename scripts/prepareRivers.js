// scripts/prepareRivers.js — spec §4.7 step ⑦, final rivers assembly.
//
// Input:  research/rivers-index-reconciled.json (106 entries, metadata)
//         build/rivers-govt-matched.geojson       (govt shapefile geometry, Step 5c)
//         build/rivers-overpass-merged.geojson,
//         build/rivers-overpass-merge-report.json (Overpass geometry + QA, Step 11)
//         build/hydrorivers-india-clip.geojson     (cached HydroRIVERS clip, Step 6/17b —
//         only read to backfill stream_order for the Overpass-only rivers; govt-matched
//         rivers already carry it from joinHydroRivers.js)
//
// Output: public/data/rivers-index.json  (validated, geometry-backed rivers only)
//         public/data/rivers-id-map.json ({ id: [featureId] } — one id per river since our
//         merge steps already coalesce each river to a single feature, unlike spec's raw-way
//         assumption)
//         build/rivers-by-id/{id}.geojson (one file per river, feeds spatialIntersect.js)
//         build/rivers-prepared.geojson   (tippecanoe input, step ⑧)
//
// V1 SCOPE: only rivers with real, non-contaminated geometry ship. Rivers still flagged after
// inspectFlaggedRivers.js, or never matched in OSM at all, are excluded outright — no
// null-bounds placeholder entries, per RiverIndexEntry.bounds being non-nullable (§4.1).
// Logged as a deviation in PROGRESS.md, deferred to manual digitizing / Phase 2.

import fs from 'node:fs';
import * as turf from '@turf/turf';
import { RiverIndexEntry } from './schemas.js';

const RECONCILED_INDEX = 'research/rivers-index-reconciled.json';
const GOVT_MATCHED = 'build/rivers-govt-matched.geojson';
const OVERPASS_MERGED = 'build/rivers-overpass-merged.geojson';
const OVERPASS_MERGE_REPORT = 'build/rivers-overpass-merge-report.json';
const HYDRORIVERS_CLIP = 'build/hydrorivers-india-clip.geojson';

const OUT_INDEX = 'public/data/rivers-index.json';
const OUT_ID_MAP = 'public/data/rivers-id-map.json';
const OUT_BY_ID_DIR = 'build/rivers-by-id';
const OUT_PREPARED = 'build/rivers-prepared.geojson';

// Same shapefile-name -> reconciled-name mapping as reconcileGovtMetadata.js — govt geometry
// features keep the shapefile's canonical name, not the alias used in rivers-index-reconciled.json.
const GOVT_NAME_TO_RECONCILED_NAME = {
  Ghaghra: 'Ghaghra (Karnali)',
  Kali: 'Kali (Karnataka)',
  Ghaggar: 'Ghaggar-Hakra',
};

// Same false positive as reconcileGovtMetadata.js: the shapefile's "Purna" is the
// Godavari-tributary river, not the Tapi-tributary one spec §4.9 lists — geometry, not just
// metadata, must be excluded or the wrong river's shape ships under the right river's id.
const GOVT_FALSE_POSITIVES = new Set(['Purna']);

// HydroRIVERS grid-match constants, mirrored from joinHydroRivers.js for consistency.
const MATCH_TOLERANCE_KM = 1;
const SAMPLE_INTERVAL_KM = 0.5;
const GRID_CELL_DEG = 0.02;

function reachMidpoint(feature) {
  const coords =
    feature.geometry.type === 'MultiLineString'
      ? feature.geometry.coordinates[0]
      : feature.geometry.coordinates;
  const line = turf.lineString(coords);
  const length = turf.length(line, { units: 'kilometers' });
  return turf.along(line, length / 2, { units: 'kilometers' }).geometry.coordinates;
}

function gridKey(lng, lat) {
  return `${Math.floor(lng / GRID_CELL_DEG)}_${Math.floor(lat / GRID_CELL_DEG)}`;
}

function buildGridIndex(reaches) {
  const grid = new Map();
  for (const reach of reaches) {
    const [lng, lat] = reach.midpoint;
    const key = gridKey(lng, lat);
    if (!grid.has(key)) grid.set(key, []);
    grid.get(key).push(reach);
  }
  return grid;
}

function nearbyReaches(grid, lng, lat) {
  const cellX = Math.floor(lng / GRID_CELL_DEG);
  const cellY = Math.floor(lat / GRID_CELL_DEG);
  const results = [];
  for (let dx = -1; dx <= 1; dx++) {
    for (let dy = -1; dy <= 1; dy++) {
      const bucket = grid.get(`${cellX + dx}_${cellY + dy}`);
      if (bucket) results.push(...bucket);
    }
  }
  return results;
}

function samplePoints(feature) {
  const coordsList =
    feature.geometry.type === 'MultiLineString'
      ? feature.geometry.coordinates
      : [feature.geometry.coordinates];

  const points = [];
  for (const coords of coordsList) {
    if (coords.length < 2) continue;
    const line = turf.lineString(coords);
    const length = turf.length(line, { units: 'kilometers' });
    for (let d = 0; d <= length; d += SAMPLE_INTERVAL_KM) {
      points.push(turf.along(line, d, { units: 'kilometers' }).geometry.coordinates);
    }
    points.push(coords[coords.length - 1]);
  }
  return points;
}

// Backfills stream_order for rivers whose only geometry source is Overpass (govt-matched
// rivers already have it via joinHydroRivers.js). Mutates each entry's `river.stream_order`.
function backfillStreamOrder(entries) {
  console.log(`==> Backfilling stream_order for ${entries.length} Overpass-only rivers via HydroRIVERS`);
  const hydroData = JSON.parse(fs.readFileSync(HYDRORIVERS_CLIP, 'utf-8'));
  const reaches = hydroData.features.map((f, i) => ({
    id: i,
    midpoint: reachMidpoint(f),
    ordStra: f.properties.ORD_STRA,
  }));
  const grid = buildGridIndex(reaches);

  for (const { river, geometry } of entries) {
    const points = samplePoints({ geometry });
    const matchedIds = new Set();
    for (const [lng, lat] of points) {
      for (const candidate of nearbyReaches(grid, lng, lat)) {
        if (matchedIds.has(candidate.id)) continue;
        if (turf.distance([lng, lat], candidate.midpoint, { units: 'kilometers' }) <= MATCH_TOLERANCE_KM) {
          matchedIds.add(candidate.id);
        }
      }
    }
    const matched = reaches.filter((r) => matchedIds.has(r.id));
    river.stream_order = matched.length ? Math.max(...matched.map((r) => r.ordStra)) : null;
    console.log(`  ${river.name}: ${matched.length} reaches${river.stream_order ? `, order ${river.stream_order}` : ' — no match'}`);
  }
}

function run() {
  const index = JSON.parse(fs.readFileSync(RECONCILED_INDEX, 'utf-8'));
  const govt = JSON.parse(fs.readFileSync(GOVT_MATCHED, 'utf-8'));
  const overpassMerged = JSON.parse(fs.readFileSync(OVERPASS_MERGED, 'utf-8'));
  const mergeReport = JSON.parse(fs.readFileSync(OVERPASS_MERGE_REPORT, 'utf-8'));

  const govtByName = new Map(
    govt.features
      .filter((f) => !GOVT_FALSE_POSITIVES.has(f.properties.name))
      .map((f) => [GOVT_NAME_TO_RECONCILED_NAME[f.properties.name] ?? f.properties.name, f])
  );
  const overpassByName = new Map(overpassMerged.features.map((f) => [f.properties.name, f]));
  const cleanNames = new Set(mergeReport.clean.map((r) => r.name));

  const withGeometry = [];
  const excluded = [];

  for (const river of index) {
    const govtFeature = govtByName.get(river.name);
    const overpassFeature = cleanNames.has(river.name) ? overpassByName.get(river.name) : null;
    const source = govtFeature ? 'govt' : overpassFeature ? 'overpass' : null;
    const geometry = govtFeature?.geometry ?? overpassFeature?.geometry ?? null;

    if (!geometry) {
      excluded.push(river.name);
      continue;
    }
    withGeometry.push({ river, geometry, source });
  }

  console.log(`${withGeometry.length} rivers have geometry, ${excluded.length} deferred (post-V1, see PROGRESS.md):`);
  console.log(`  ${excluded.join(', ')}`);

  const needsStreamOrder = withGeometry.filter((w) => w.source === 'overpass' && !w.river.stream_order);
  if (needsStreamOrder.length) backfillStreamOrder(needsStreamOrder);

  const stillMissingStreamOrder = withGeometry.filter((w) => !w.river.stream_order);
  const final = withGeometry.filter((w) => w.river.stream_order);

  if (stillMissingStreamOrder.length) {
    console.log(`\nWARNING: no HydroRIVERS reach found nearby — excluded from V1 (post-V1, see PROGRESS.md):`);
    console.log(`  ${stillMissingStreamOrder.map((w) => w.river.name).join(', ')}`);
  }

  fs.mkdirSync(OUT_BY_ID_DIR, { recursive: true });

  const idMap = {};
  const preparedFeatures = [];
  const indexOut = [];
  const failures = [];
  let nextFeatureId = 1;

  for (const { river, geometry } of final) {
    const featureId = nextFeatureId++;
    const feature = {
      type: 'Feature',
      id: featureId,
      properties: { id: river.id, stream_order: river.stream_order },
      geometry,
    };
    const bounds = turf.bbox(feature);
    const { _source, _needs_verification, ...rest } = river;

    try {
      indexOut.push(RiverIndexEntry.parse({ ...rest, bounds }));
    } catch (err) {
      failures.push({ name: river.name, error: err.errors ?? err.message });
      continue;
    }

    preparedFeatures.push(feature);
    idMap[river.id] = [featureId];
    fs.writeFileSync(
      `${OUT_BY_ID_DIR}/${river.id}.geojson`,
      JSON.stringify({ type: 'FeatureCollection', features: [feature] })
    );
  }

  if (failures.length) {
    console.error(`\n${failures.length} rivers failed RiverIndexEntry schema validation:`);
    failures.forEach((f) => console.error(`  ${f.name}:`, JSON.stringify(f.error)));
    process.exit(1);
  }

  fs.writeFileSync(OUT_INDEX, JSON.stringify(indexOut, null, 2));
  fs.writeFileSync(OUT_ID_MAP, JSON.stringify(idMap, null, 2));
  fs.writeFileSync(OUT_PREPARED, JSON.stringify({ type: 'FeatureCollection', features: preparedFeatures }));

  console.log(`\nWrote ${indexOut.length} rivers to ${OUT_INDEX}`);
}

run();
