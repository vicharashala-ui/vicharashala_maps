// fix-ravi-geometry.mjs — one-off repair for build/rivers-by-id/ravi.geojson.
//
// Root cause: one of Ravi's raw Overpass ways has spurious extra nesting within its own
// coordinates (an array of ~30 positions sitting where a single [lng,lat] position should be,
// inside one linestring segment). mergeOverpassRivers.js's original fix only handled nesting
// *across* separate ways (Step 18); it didn't catch corruption *within* one way's own
// coordinates (this bug, Step 22). scripts/mergeOverpassRivers.js has been patched to handle
// both on future runs — this script repairs the artifact already on disk, since the fix is
// purely structural and doesn't need the raw Step 10 Overpass data to re-derive.
//
// Preserves the existing MultiLineString's segment count (each segment may be genuinely
// disjoint from the others — don't merge them into one line) while flattening any spurious
// nesting found within any single segment.
//
// Run: node fix-ravi-geometry.mjs

import fs from 'node:fs';

const RAVI_PATH = 'build/rivers-by-id/ravi.geojson';

function isPosition(x) {
  return Array.isArray(x) && typeof x[0] === 'number' && typeof x[1] === 'number';
}

function deepFlattenPositions(x, out = []) {
  if (isPosition(x)) {
    out.push(x);
    return out;
  }
  if (Array.isArray(x)) for (const item of x) deepFlattenPositions(item, out);
  return out;
}

function isGeometryValid(feature) {
  const segments = feature.geometry.type === 'MultiLineString'
    ? feature.geometry.coordinates
    : [feature.geometry.coordinates];
  return segments.every((seg) => seg.length > 0 && seg.every((c) => isPosition(c) && c.every(Number.isFinite)));
}

const fc = JSON.parse(fs.readFileSync(RAVI_PATH, 'utf-8'));
const feature = fc.features[0];
const originalType = feature.geometry.type;
const originalSegmentCount = originalType === 'MultiLineString' ? feature.geometry.coordinates.length : 1;

const segments = originalType === 'MultiLineString'
  ? feature.geometry.coordinates.map((segment) => deepFlattenPositions(segment))
  : [deepFlattenPositions(feature.geometry.coordinates)];

feature.geometry = segments.length === 1
  ? { type: 'LineString', coordinates: segments[0] }
  : { type: 'MultiLineString', coordinates: segments };

if (!isGeometryValid(feature)) {
  throw new Error('Repair failed — geometry still has an invalid coordinate after flattening. Needs a manual look.');
}
if (segments.length !== originalSegmentCount) {
  throw new Error(`Segment count changed (${originalSegmentCount} -> ${segments.length}) — expected it to stay the same. Needs a manual look, not shipping this.`);
}

fs.writeFileSync(RAVI_PATH, JSON.stringify(fc));
console.log(`Repaired ${RAVI_PATH}`);
console.log(`Geometry type: ${feature.geometry.type}, ${segments.length} segment(s) (unchanged from before), ${segments.flat().length} total positions`);
console.log("Now run: node scripts/spatialIntersect.js to recompute Ravi's protected_area_ids");
