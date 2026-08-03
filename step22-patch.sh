#!/usr/bin/env bash
# step22-patch.sh — fixes Ravi's malformed geometry (SKIPPED by Step 20's spatialIntersect.js)
#
# Root cause: one of Ravi's raw Overpass ways has spurious nesting WITHIN its own coordinates
# (not across ways, which Step 18 already fixed). Patches scripts/mergeOverpassRivers.js for
# future full-pipeline re-runs, AND ships a standalone one-off repair for the artifact already
# on disk (build/rivers-by-id/ravi.geojson) so a full Overpass re-fetch isn't needed.
#
# Run from project root in Git Bash. Idempotent (overwrites scripts/mergeOverpassRivers.js;
# fix-ravi-geometry.mjs is safe to re-run, it validates its own output before writing).
set -euo pipefail

mkdir -p scripts

cat > scripts/mergeOverpassRivers.js << 'PATCH_EOF'
// scripts/mergeOverpassRivers.js
// Input:  build/rivers-overpass.geojson (raw matched way segments, Step 10)
//         research/rivers-index-reconciled.json (web-researched length_km_india, for QA)
// Output: build/rivers-overpass-merged.geojson (one feature per river)
//         build/rivers-overpass-merge-report.json (length comparison + flags)
//
// Overpass returning many segments for one river name is NORMAL — OSM maps long rivers as
// many separate ways, not one LineString. Merging them all and eyeballing coordinates for 23
// rivers isn't worth it. Instead: sum each candidate's length, compare the total against the
// web-researched length_km_india already in rivers-index-reconciled.json. A total wildly off
// from the expected figure (not just "has many segments") is the real signal of contamination
// — e.g. Purna, where Step 9 already confirmed the govt shapefile match was a same-named but
// unrelated river; the same collision risk applies here. In range -> auto-merge as one feature.
// Out of range -> flagged, needs a manual look at build/rivers-overpass.geojson before merging.

import fs from 'node:fs';

const LENGTH_RATIO_LOW = 0.4;  // merged length < 40% of researched length -> missing segments or wrong candidate
const LENGTH_RATIO_HIGH = 1.6; // merged length > 160% of researched length -> likely contaminated by an unrelated same-named feature

function haversineKm([lon1, lat1], [lon2, lat2]) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function isPosition(x) {
  return Array.isArray(x) && typeof x[0] === 'number' && typeof x[1] === 'number';
}

// Recursively strips any spurious extra nesting within one linestring segment down to a flat
// array of [lng,lat] positions. A single segment is by definition one continuous path — any
// nested sub-array found inside it is corruption (osmtogeojson quirk), not a meaningfully
// separate line, so it gets spliced back in as more points at that position, not split out.
function deepFlattenPositions(x, out = []) {
  if (isPosition(x)) {
    out.push(x);
    return out;
  }
  if (Array.isArray(x)) for (const item of x) deepFlattenPositions(item, out);
  return out;
}

// One raw Overpass way -> one or more linestrings. A 'MultiLineString'-typed way's top-level
// segments are genuinely disjoint (Ravi, Step 17c/18 — OSM sometimes maps one way as several
// separate pieces) and must stay separate. Anything nested WITHIN one of those segments, or
// within a plain 'LineString' way's own coordinates, is spurious extra depth from osmtogeojson
// (Ravi, Step 22 — a different bug in the same family) and gets fully flattened in place.
function wayToLineStrings(feature) {
  const { type, coordinates } = feature.geometry;
  if (type === 'MultiLineString') return coordinates.map((segment) => deepFlattenPositions(segment));
  return [deepFlattenPositions(coordinates)];
}

function lineLengthKm(coords) {
  let total = 0;
  for (let i = 1; i < coords.length; i++) total += haversineKm(coords[i - 1], coords[i]);
  return total;
}

function run() {
  const raw = JSON.parse(fs.readFileSync('build/rivers-overpass.geojson', 'utf-8'));
  const index = JSON.parse(fs.readFileSync('research/rivers-index-reconciled.json', 'utf-8'));
  const expectedLength = new Map(index.map((r) => [r.name, r.length_km_india]));

  const byName = new Map();
  for (const f of raw.features) {
    const name = f.properties.name;
    if (!byName.has(name)) byName.set(name, []);
    byName.get(name).push(f);
  }

  const merged = [];
  const report = { clean: [], flagged: [], noExpectedLength: [] };

  for (const [name, feats] of byName) {
    const totalLength = feats.reduce((sum, f) => sum + lineLengthKm(f.geometry.coordinates), 0);
    const expected = expectedLength.get(name);

    const lineStrings = feats.flatMap(wayToLineStrings);

    merged.push({
      type: 'Feature',
      properties: { name, segment_count: feats.length, total_length_km: Math.round(totalLength * 10) / 10 },
      geometry:
        lineStrings.length === 1
          ? { type: 'LineString', coordinates: lineStrings[0] }
          : { type: 'MultiLineString', coordinates: lineStrings },
    });

    if (expected == null) {
      report.noExpectedLength.push(name);
      continue;
    }
    const ratio = Math.round((totalLength / expected) * 100) / 100;
    const entry = { name, segments: feats.length, mergedLengthKm: Math.round(totalLength), expectedLengthKm: expected, ratio };
    (ratio < LENGTH_RATIO_LOW || ratio > LENGTH_RATIO_HIGH ? report.flagged : report.clean).push(entry);
  }

  fs.writeFileSync('build/rivers-overpass-merged.geojson', JSON.stringify({ type: 'FeatureCollection', features: merged }));
  fs.writeFileSync('build/rivers-overpass-merge-report.json', JSON.stringify(report, null, 2));

  console.log(`Merged ${byName.size} rivers.`);
  console.log(`Clean (length within ${LENGTH_RATIO_LOW}x-${LENGTH_RATIO_HIGH}x expected): ${report.clean.length}`);
  console.log(`Flagged (needs a manual look before merging): ${report.flagged.length}`);
  report.flagged.forEach((f) => console.log(`  ${f.name}: ${f.segments} segments, ${f.mergedLengthKm}km merged vs ${f.expectedLengthKm}km expected (${f.ratio}x)`));
  if (report.noExpectedLength.length) console.log(`No expected length to compare, skipped QA: ${report.noExpectedLength.join(', ')}`);
}

run();
PATCH_EOF
echo

cat > fix-ravi-geometry.mjs << 'PATCH_EOF'
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
PATCH_EOF
echo

echo "Patch applied: scripts/mergeOverpassRivers.js (structural fix), fix-ravi-geometry.mjs (repair script)"
echo ""
echo "Next: node fix-ravi-geometry.mjs"
echo "Then: node scripts/spatialIntersect.js   (recomputes Ravi's protected_area_ids)"
