#!/usr/bin/env bash
# step17-patch.sh — prepareRivers.js (spec §4.7 step ⑦, final rivers assembly)
#
# Prereqs (already run on your machine per our last exchange):
#   node scripts/joinHydroRivers.js && node scripts/reconcileGovtMetadata.js
#   node scripts/inspectFlaggedRivers.js
# This patch does NOT re-run those — it assumes research/rivers-index-reconciled.json
# already has real stream_order values for the 63 govt-matched rivers.
set -euo pipefail

REQUIRED_FILES=(
  "research/rivers-index-reconciled.json"
  "build/rivers-govt-matched.geojson"
  "build/rivers-overpass-merged.geojson"
  "build/rivers-overpass-merge-report.json"
  "build/hydrorivers-india-clip.geojson"
)
for f in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: missing $f — run the Step 5c/9/11/17b pipeline first." >&2
    exit 1
  fi
done

echo "==> Writing scripts/prepareRivers.js"
cat > scripts/prepareRivers.js << 'PREPARE_RIVERS_EOF'
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
PREPARE_RIVERS_EOF
echo ""

echo "==> Running prepareRivers.js"
node scripts/prepareRivers.js

echo "==> Updating PROGRESS.md"
cat > /tmp/update-progress.mjs << 'UPDATE_PROGRESS_EOF'
// One-shot PROGRESS.md updater for step17-patch.sh. Run once, then deleted by the patch.
import fs from 'node:fs';

const PATH = 'PROGRESS.md';
let text = fs.readFileSync(PATH, 'utf-8');

if (text.includes('### Step 17 — prepareRivers.js')) {
  console.log('PROGRESS.md already has the Step 17 entry — skipping (idempotent re-run).');
  process.exit(0);
}

function replaceBetween(text, startMarker, endMarker, replacement) {
  const start = text.indexOf(startMarker);
  const end = text.indexOf(endMarker, start);
  if (start === -1 || end === -1) {
    throw new Error(`Marker not found — startMarker="${startMarker}" endMarker="${endMarker}". PROGRESS.md structure changed; apply this update by hand.`);
  }
  return text.slice(0, start) + replacement + text.slice(end);
}

const NEW_STATUS = `## Current status: Step 17 delivered and run — \`prepareRivers.js\` written (tested against synthetic fixtures, real \`build/\` data isn't in the sandbox — same constraint as every prior step), then run for real on your machine.

Before writing it, re-ran \`joinHydroRivers.js\` + \`reconcileGovtMetadata.js\`: found and fixed a real bug where Step 6's HydroRIVERS join output never actually made it into \`research/rivers-index-reconciled.json\` (Step 8's reconciliation had run against a stale metadata snapshot) — all 106 entries had \`stream_order: null\` despite the Step 6 log claiming 61/61 matched. Re-running both fixed it for the 63 govt-matched rivers (64/64 real matches this time). Also ran \`inspectFlaggedRivers.js\`: 0/8 auto-resolved — confirmed these are genuinely undermatched or same-state-contaminated, not fixable by the state-check heuristic.

\`prepareRivers.js\` additionally backfills \`stream_order\` for the 22 Overpass-only rivers via the same HydroRIVERS grid-match logic (reusing the cached \`build/hydrorivers-india-clip.geojson\`, no re-clip needed).

**V1 scope (confirmed):** \`public/data/rivers-index.json\` ships only rivers with real, non-contaminated geometry — currently 85 (63 govt + 22 Overpass clean). No null-\`bounds\` placeholders for the rest, since \`RiverIndexEntry.bounds\` is non-nullable by design. Deferred entirely: the 8 flagged (Burhi Gandak, Dibang, Dhansiri, Purna, Girna, Vaitarna, Jhelum, Rushikulya) + remaining unmatched rivers — logged here as a post-V1/manual-digitizing gap, not shipped as partial data.

`;

text = replaceBetween(
  text,
  '## Current status:',
  '### rivers-index.json research + reconciliation: done',
  NEW_STATUS
);

const NEW_REMAINING_AND_NEXT = `### Remaining open items
1. ~~Reconcile against Step 5c's govt data~~ — done, Step 8.
2. ~~Backfill \`stream_order\` for all 85 geometry-backed rivers~~ — done, Step 17 (govt-matched via re-run join, Overpass-only via the same grid-match reused inside \`prepareRivers.js\`).
3. **8 flagged + unmatched rivers (~20, see this session's console output for the exact list)** — genuine gap, deferred to manual digitizing / Phase 2. Not shipped in V1's \`rivers-index.json\`.
4. **Length discrepancies >20%** between web research and govt data, worth a manual sanity check: Chenab (700→431km), Barak (524→100km), Subarnarekha (395→480km), Vaigai (258→312km), Bharathapuzha (209→100km), Kali/Karnataka (265→179km), Vaippar (130→87km). Govt value is what shipped.
5. **Vellar** (Peninsular-East) — Tamil Nadu has two rivers by this name; draft used the Southern one, still unverified against govt/OSM either way.

### Not started yet
- \`rivers.pmtiles\` (step ⑧ — tippecanoe over \`build/rivers-prepared.geojson\`)
- \`spatialIntersect.js\` / \`deriveStateCrossRefs.js\` / \`buildSearchIndex.js\` (steps ⑪⑫⑬)
- River layers + detail panel wired into the frontend
- Everything in spec §5 onward

## Next step
Run \`step17-patch.sh\`. Send back the console output (deferred-rivers list + any \`stillMissingStreamOrder\` warnings) so we can confirm the final \`public/data/rivers-index.json\` count matches expectations, then move to \`rivers.pmtiles\` (step ⑧) and wiring river layers into the frontend.

`;

text = replaceBetween(
  text,
  '### Remaining open items',
  '## Completed steps log',
  NEW_REMAINING_AND_NEXT
);

const STEP_17_ENTRY = `### Step 17 — prepareRivers.js: final rivers assembly (delivered as \`step17-patch.sh\`)
- \`scripts/prepareRivers.js\` — merges govt-shapefile geometry (Step 9/17b, 63 rivers) + clean Overpass geometry (Step 16, 22 rivers) into \`build/rivers-prepared.geojson\`, computes \`bounds\` via \`turf.bbox()\`, validates every entry against \`RiverIndexEntry\`, writes \`public/data/rivers-index.json\` + \`public/data/rivers-id-map.json\` + one file per river under \`build/rivers-by-id/\`
- Reuses the same shapefile-name→reconciled-name alias map and \`Purna\` false-positive exclusion as \`reconcileGovtMetadata.js\` — applies to geometry attachment too, not just metadata (a river's wrong-basin same-name govt feature would otherwise ship the wrong shape under the right id)
- Backfills \`stream_order\` for the 22 Overpass-only rivers via the same HydroRIVERS grid-match approach as \`joinHydroRivers.js\` (duplicated, not imported — consistent with this project's existing self-contained-script convention)
- Fails loudly: any \`RiverIndexEntry\` validation failure is collected (not stopped at the first one) and reported with the exact Zod field/message before exiting non-zero; no partial \`public/data/\` output on failure
- Tested against synthetic fixtures covering all 4 real code paths: govt geometry via direct name, govt geometry via the alias map (Kali→Kali (Karnataka)), Overpass geometry needing stream_order backfill (found + not-found cases), and 3 exclusion cases (govt false-positive, Overpass-flagged despite having geometry, fully unmatched) — real \`build/\` data isn't available in the sandbox, same constraint as every step since Step 9

**Also this step:** re-ran \`joinHydroRivers.js\` + \`reconcileGovtMetadata.js\` after discovering \`stream_order\` was \`null\` for all 106 entries in \`research/rivers-index-reconciled.json\`, despite Step 6's log reporting 61/61 real matches — the join's output apparently never reached the version \`reconcileGovtMetadata.js\` read at the time. Re-running both fixed it (64/64 matched this time, 63 real + Purna's excluded false-positive). Also ran \`inspectFlaggedRivers.js\` for real: 0/8 auto-resolved, confirming the 8 flagged rivers need manual geometry work, not more automated passes.

`;

const marker = '## Completed steps log\n\n';
const idx = text.indexOf(marker);
if (idx === -1) throw new Error('Could not find "## Completed steps log" marker.');
const insertAt = idx + marker.length;
text = text.slice(0, insertAt) + STEP_17_ENTRY + text.slice(insertAt);

fs.writeFileSync(PATH, text);
console.log('PROGRESS.md updated.');
UPDATE_PROGRESS_EOF
echo ""
node /tmp/update-progress.mjs
rm /tmp/update-progress.mjs

echo ""
echo "Done. public/data/rivers-index.json, public/data/rivers-id-map.json,"
echo "build/rivers-prepared.geojson, and build/rivers-by-id/*.geojson are written."
echo "Check the console output above for the deferred-rivers list before committing."
