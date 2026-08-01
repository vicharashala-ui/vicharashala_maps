// scripts/inspectFlaggedRivers.js
// Input:  build/rivers-overpass.geojson, build/rivers-overpass-merge-report.json (Step 12/13)
//         research/rivers-index-reconciled.json (expected `states` per river)
//         public/geojson/india-states.geojson (state polygons, Step 4)
// Output: build/flagged-rivers-review.json
//
// A flagged river (length way outside 0.4x-1.6x expected) is usually a same-named-but-
// unrelated OSM way pulled in alongside the real one (see Purna, already known). This is
// checkable without eyeballing coordinates: every river has an expected state (or states) in
// rivers-index-reconciled.json. A segment whose midpoint falls in a state the river was never
// researched to touch is very likely the wrong feature, not a legitimate part of it.
//
// This is a heuristic, not a verdict — it recommends which segments to drop and reports the
// resulting ratio if you do, but a state match doesn't guarantee correctness (two rivers can
// share a state) and a state MISS doesn't always mean wrong (border rivers legitimately
// leave India; those come back as UNRESOLVED, not auto-dropped). Treat AUTO_RESOLVED as a
// strong lead to spot-check, not a substitute for the manual look on anything still flagged.

import fs from 'node:fs';
import * as turf from '@turf/turf';

const LENGTH_RATIO_LOW = 0.4;
const LENGTH_RATIO_HIGH = 1.6;

function haversineKm([lon1, lat1], [lon2, lat2]) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function lineLengthKm(coords) {
  const valid = coords.filter(isValidCoord);
  let total = 0;
  for (let i = 1; i < valid.length; i++) total += haversineKm(valid[i - 1], valid[i]);
  return total;
}

function isValidCoord(c) {
  return Array.isArray(c) && Number.isFinite(c[0]) && Number.isFinite(c[1]);
}

// Samples start/mid/end rather than just the midpoint — a single point can land on the wrong
// side of a state border for a segment that legitimately straddles one. Some OSM ways come
// back with degenerate geometry (0 or 1 coordinates — e.g. a way whose other nodes weren't
// resolved by Overpass) or the odd malformed coordinate pair; those are filtered out before
// sampling rather than indexed into directly, and a segment left with nothing usable is
// reported UNRESOLVED rather than crashing the whole run.
function sampleStates(coords, statePolys) {
  const valid = coords.filter(isValidCoord);
  if (valid.length === 0) return [null, null, null];
  const idxs = [0, Math.floor((valid.length - 1) / 2), valid.length - 1];
  const states = [];
  for (const i of idxs) {
    const pt = turf.point(valid[i]);
    const hit = statePolys.find((s) => turf.booleanPointInPolygon(pt, s));
    states.push(hit ? hit.properties.id : null);
  }
  return states;
}

function run() {
  const raw = JSON.parse(fs.readFileSync('build/rivers-overpass.geojson', 'utf-8'));
  const mergeReport = JSON.parse(fs.readFileSync('build/rivers-overpass-merge-report.json', 'utf-8'));
  const index = JSON.parse(fs.readFileSync('research/rivers-index-reconciled.json', 'utf-8'));
  const statesGeo = JSON.parse(fs.readFileSync('public/geojson/india-states.geojson', 'utf-8'));

  const expectedStates = new Map(index.map((r) => [r.name, new Set(r.states ?? [])]));
  const byName = new Map();
  for (const f of raw.features) {
    if (!byName.has(f.properties.name)) byName.set(f.properties.name, []);
    byName.get(f.properties.name).push(f);
  }

  const review = [];
  for (const flaggedEntry of mergeReport.flagged) {
    const { name, expectedLengthKm } = flaggedEntry;
    const expected = expectedStates.get(name) ?? new Set();
    const segments = byName.get(name) ?? [];

    const segmentReview = segments.map((f) => {
      const coords = f.geometry?.coordinates ?? [];
      const states = sampleStates(coords, statesGeo.features);
      const matchedExpected = states.some((s) => s && expected.has(s));
      const allUnresolved = states.every((s) => s === null);
      const verdict = matchedExpected ? 'KEEP' : allUnresolved ? 'UNRESOLVED' : 'DROP_SUSPECT';
      return { osm_id: f.properties.osm_id, lengthKm: Math.round(lineLengthKm(coords) * 10) / 10, statesSampled: states, verdict };
    });

    const kept = segmentReview.filter((s) => s.verdict !== 'DROP_SUSPECT');
    const keptLengthKm = Math.round(kept.reduce((sum, s) => sum + s.lengthKm, 0));
    const newRatio = expectedLengthKm ? Math.round((keptLengthKm / expectedLengthKm) * 100) / 100 : null;
    const resolved = newRatio !== null && newRatio >= LENGTH_RATIO_LOW && newRatio <= LENGTH_RATIO_HIGH;

    review.push({
      name,
      expectedStates: [...expected],
      originalRatio: flaggedEntry.ratio,
      segments: segmentReview,
      droppedCount: segmentReview.length - kept.length,
      lengthAfterDroppingSuspectKm: keptLengthKm,
      ratioAfterDroppingSuspect: newRatio,
      status: resolved ? 'AUTO_RESOLVED' : 'STILL_FLAGGED',
    });
  }

  fs.writeFileSync('build/flagged-rivers-review.json', JSON.stringify(review, null, 2));

  const resolved = review.filter((r) => r.status === 'AUTO_RESOLVED');
  const stillFlagged = review.filter((r) => r.status === 'STILL_FLAGGED');
  console.log(`Inspected ${review.length} flagged rivers.`);
  console.log(`\nAUTO_RESOLVED (dropping out-of-state segments brings ratio into range — spot-check, don't just trust):`);
  resolved.forEach((r) => console.log(`  ${r.name}: ${r.originalRatio}x -> ${r.ratioAfterDroppingSuspect}x, dropped ${r.droppedCount} segment(s)`));
  console.log(`\nSTILL_FLAGGED (state check didn't explain it — genuinely needs a manual look):`);
  stillFlagged.forEach((r) => console.log(`  ${r.name}: ${r.originalRatio}x -> ${r.ratioAfterDroppingSuspect ?? 'n/a'}x after dropping ${r.droppedCount} suspect segment(s)`));
}

run();
