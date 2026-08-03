// scripts/spatialIntersect.js — spec §4.7 step ⑪ (Turf.js booleanIntersects).
//
// Input:  build/pa-merged.geojson          (PA boundaries, Step 4's mergeFeatures.js output;
//                                            feature.properties.id = canonical PA id)
//         build/rivers-by-id/{id}.geojson  (one file per river, prepareRivers.js step ⑦ output)
//         public/data/protected-areas.json (validated PA records, updated in place)
//
// Output: public/data/protected-areas.json (river_ids populated, in place)
//         build/river-protected-area-ids.json ({ river_id: [pa_id, ...] })
//
// DEVIATION (log in PROGRESS.md): spec says this writes protected_area_ids directly into
// rivers/{id}.json. Those detail files are manually authored (§4.1) and don't exist yet —
// Phase 2 work, not started. Writing into them here would mean inventing placeholder detail
// records. Instead this writes the derived river -> PA id list to a build/ intermediate, to be
// merged into rivers/{id}.json once that manual-authoring pass exists.
//
// ~85 geometry-backed rivers x 837 PAs: each PA's bbox pre-filters candidates before the real
// booleanIntersects check, so most pairs never reach the expensive polygon/line test.

import fs from 'node:fs';
import * as turf from '@turf/turf';

const PA_MERGED = 'build/pa-merged.geojson';
const RIVERS_BY_ID_DIR = 'build/rivers-by-id';
const PA_JSON = 'public/data/protected-areas.json';
const OUT_RIVER_PA_IDS = 'build/river-protected-area-ids.json';

function bboxesOverlap(a, b) {
  return a[0] <= b[2] && a[2] >= b[0] && a[1] <= b[3] && a[3] >= b[1];
}

// turf.booleanIntersects throws deep inside turf/invariant on a malformed coordinate
// (e.g. a ring point that isn't a 2/3-length numeric array) instead of returning false.
// One bad upstream feature would otherwise crash the whole 837x85 run. Check every
// coordinate up front so we can name-and-skip the bad feature instead of losing the batch.
function isGeometryValid(feature) {
  try {
    for (const coord of turf.coordAll(feature)) {
      if (!Array.isArray(coord) || coord.length < 2 || coord.length > 3) return false;
      if (coord.some((n) => typeof n !== 'number' || !Number.isFinite(n))) return false;
    }
    return true;
  } catch {
    return false;
  }
}

function run() {
  const paMerged = JSON.parse(fs.readFileSync(PA_MERGED, 'utf-8'));
  const paRecords = JSON.parse(fs.readFileSync(PA_JSON, 'utf-8'));

  const skippedPAs = [];
  const paFeatures = [];
  for (const f of paMerged.features) {
    if (!isGeometryValid(f)) {
      skippedPAs.push(f.properties.id);
      continue;
    }
    paFeatures.push({ id: f.properties.id, bbox: turf.bbox(f), feature: f });
  }

  const riverFiles = fs.readdirSync(RIVERS_BY_ID_DIR).filter((f) => f.endsWith('.geojson'));
  if (!riverFiles.length) throw new Error(`No river files found in ${RIVERS_BY_ID_DIR}`);

  const riverToPAs = {};
  const paToRivers = new Map(); // pa.id -> Set<river.id>
  const skippedRivers = [];

  for (const file of riverFiles) {
    const riverId = file.replace(/\.geojson$/, '');
    const riverFeature = JSON.parse(fs.readFileSync(`${RIVERS_BY_ID_DIR}/${file}`, 'utf-8')).features[0];

    if (!isGeometryValid(riverFeature)) {
      skippedRivers.push(riverId);
      riverToPAs[riverId] = [];
      continue;
    }

    const riverBbox = turf.bbox(riverFeature);
    const matched = [];
    for (const pa of paFeatures) {
      if (!bboxesOverlap(riverBbox, pa.bbox)) continue;
      if (!turf.booleanIntersects(riverFeature, pa.feature)) continue;
      matched.push(pa.id);
      if (!paToRivers.has(pa.id)) paToRivers.set(pa.id, new Set());
      paToRivers.get(pa.id).add(riverId);
    }
    riverToPAs[riverId] = matched.sort();
  }

  let changed = 0;
  const skippedPASet = new Set(skippedPAs);
  for (const pa of paRecords) {
    if (skippedPASet.has(pa.id)) continue; // leave river_ids as-is, geometry couldn't be checked
    const rivers = paToRivers.has(pa.id) ? [...paToRivers.get(pa.id)].sort() : [];
    if (JSON.stringify(pa.river_ids) !== JSON.stringify(rivers)) changed++;
    pa.river_ids = rivers;
  }

  fs.writeFileSync(PA_JSON, JSON.stringify(paRecords));
  fs.writeFileSync(OUT_RIVER_PA_IDS, JSON.stringify(riverToPAs, null, 2));

  const riversWithPAs = Object.values(riverToPAs).filter((v) => v.length).length;
  console.log(`Checked ${riverFiles.length} rivers x ${paFeatures.length} PAs`);
  console.log(`${riversWithPAs}/${riverFiles.length} rivers intersect at least one PA`);
  console.log(`${paRecords.length} PA records processed, ${changed} river_ids changed`);
  if (skippedPAs.length) {
    console.warn(`SKIPPED ${skippedPAs.length} PA(s) with malformed geometry (excluded from all checks): ${skippedPAs.join(', ')}`);
    console.warn('These need a fix in build/pa-merged.geojson (root cause likely in mergeFeatures.js or its source boundary file) — river_ids for these PAs was NOT overwritten.');
  }
  if (skippedRivers.length) {
    console.warn(`SKIPPED ${skippedRivers.length} river(s) with malformed geometry (written with empty PA list): ${skippedRivers.join(', ')}`);
    console.warn('Root cause likely in prepareRivers.js / build/rivers-prepared.geojson for these ids.');
  }
  console.log(`Wrote ${PA_JSON} (in place) and ${OUT_RIVER_PA_IDS}`);
}

run();
