#!/usr/bin/env bash
set -euo pipefail

# Step 11 — re-run fetchRivers.js to pick up the 2 rate-limited batches (idempotent,
# re-fetches all batches but that is cheap at this scale), then merge same-name OSM
# way segments into one feature per river with a length-based sanity check against
# the researched length_km_india — flags contamination (like the known Purna name
# collision) instead of blindly merging every multi-candidate river.

cat > scripts/mergeOverpassRivers.js << 'MERGE_EOF'
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

    merged.push({
      type: 'Feature',
      properties: { name, segment_count: feats.length, total_length_km: Math.round(totalLength * 10) / 10 },
      geometry: feats.length === 1 ? feats[0].geometry : { type: 'MultiLineString', coordinates: feats.map((f) => f.geometry.coordinates) },
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
MERGE_EOF

node scripts/fetchRivers.js
node scripts/mergeOverpassRivers.js

echo
echo "build/rivers-overpass-merged.geojson ready. Check build/rivers-overpass-merge-report.json for anything flagged."
