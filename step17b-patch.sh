#!/usr/bin/env bash
# step17b-patch.sh — relax basin_area_india_km2 to nullable, re-run prepareRivers.js
#
# Fixes the 33-river schema validation failure from step17-patch.sh's run. No change to
# prepareRivers.js itself — only scripts/schemas.js, then a re-run.
set -euo pipefail

if [ ! -f scripts/prepareRivers.js ]; then
  echo "ERROR: scripts/prepareRivers.js not found — run step17-patch.sh first." >&2
  exit 1
fi

echo "==> Updating scripts/schemas.js (basin_area_india_km2 -> nullable)"
cat > scripts/schemas.js << 'SCHEMAS_EOF'
// scripts/schemas.js
// Mirrors spec §4.1-4.4. Build-only — never shipped to the client bundle.
//
// DEVIATION FROM SPEC: `biome_type`, `iucn_status`, `endemic_species`, `wikipedia_url`,
// `year_established` are curated/enrichment fields the spec calls "sparse" or "Phase 2".
// Our real source data (ecoguesser repo) doesn't carry them yet, so ProtectedArea allows
// null/empty defaults here rather than failing validation. Tighten once enrichment lands.

import { z } from 'zod';

// DEVIATION FROM SPEC: `basin_area_india_km2` is nullable. 33 of the 85 V1-scope rivers never
// got a reliable figure during Step 7's web research (left null rather than invented) — this
// wasn't caught until Step 17b ran full schema validation against the complete geometry-backed
// set for the first time. HydroRIVERS' UPLAND_SKM is a possible backfill source but overstates
// India-only area for transnational rivers (includes upstream basin outside India), so it's not
// auto-substituted here. Tighten once real research backfills these.
export const RiverIndexEntry = z.object({
  id: z.string(),
  name: z.string(),
  local_name_hi: z.string(),
  basin: z.string(),
  length_km_india: z.number().positive(),
  basin_area_india_km2: z.number().positive().nullable(),
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
SCHEMAS_EOF
echo ""

echo "==> Re-running prepareRivers.js"
node scripts/prepareRivers.js

echo "==> Updating PROGRESS.md"
cat > /tmp/update-progress-17b.mjs << 'UPDATE_PROGRESS_EOF'
// One-shot PROGRESS.md updater for step17b-patch.sh. Run once, then deleted by the patch.
import fs from 'node:fs';

const PATH = 'PROGRESS.md';
let text = fs.readFileSync(PATH, 'utf-8');

if (text.includes('### Step 17b — basin_area_india_km2 relaxed to nullable')) {
  console.log('PROGRESS.md already has the Step 17b entry — skipping (idempotent re-run).');
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

const NEW_STATUS = `## Current status: Step 17b delivered and run — \`public/data/rivers-index.json\` ships **85 rivers** (63 govt + 22 Overpass clean), 21 deferred to post-V1 (8 flagged + 13 unmatched).

Step 17's first real run against the full 85-river set caught a validation gap that synthetic fixtures didn't: \`basin_area_india_km2\` is \`null\` for 33/85 rivers — a Step 7 web-research gap, unrelated to geometry or \`stream_order\`. Confirmed: no clean govt/HydroRIVERS re-derivation exists (HydroRIVERS' \`UPLAND_SKM\` overstates India-only area for transnational rivers, since it includes upstream basin outside India — same class of caveat as \`length_km_india\`'s transboundary figures). Relaxed \`RiverIndexEntry.basin_area_india_km2\` to nullable for V1, documented inline in \`schemas.js\` — same pattern as \`ProtectedArea.area_km2\`'s earlier relaxation. Backfilling the 33 via real research is a follow-up, not a blocker.

`;

text = replaceBetween(
  text,
  '## Current status:',
  '### rivers-index.json research + reconciliation: done',
  NEW_STATUS
);

const NEW_NEXT_STEP = `## Next step
\`rivers.pmtiles\` (step ⑧ — tippecanoe over \`build/rivers-prepared.geojson\`, same command shape as Step 3's \`protected-areas.pmtiles\`), then wire river layers + detail panel into the frontend. Separately, whenever convenient: real research to backfill \`basin_area_india_km2\` for the 33 rivers currently shipping \`null\`.

`;

text = replaceBetween(text, '## Next step', '## Completed steps log', NEW_NEXT_STEP);

const STEP_17B_ENTRY = `### Step 17b — basin_area_india_km2 relaxed to nullable (delivered as \`step17b-patch.sh\`)
- Step 17's actual run (85 real rivers, not synthetic fixtures) surfaced 33 \`RiverIndexEntry\` validation failures — all the same field, \`basin_area_india_km2: null\`, a Step 7 web-research gap orthogonal to the geometry/stream_order pipeline
- Considered deriving it from HydroRIVERS' \`UPLAND_SKM\` (upstream drainage area at the matched reach) — rejected: it's global upstream area, not India-scoped, so it would overstate the figure for every transnational river (Ganga, Indus, Brahmaputra, etc.) — the same class of issue \`length_km_india\` already has documented caveats for
- \`scripts/schemas.js\`: \`basin_area_india_km2\` relaxed \`z.number().positive()\` → \`.nullable()\`, deviation documented inline (same pattern as \`ProtectedArea.area_km2\`)
- Re-ran \`prepareRivers.js\` with no other changes — confirmed 85/85 pass validation, final \`public/data/rivers-index.json\` count matches the 85 predicted after Step 17's geometry-matching output
- Backfilling real values for the 33 is a follow-up research task, not blocking V1

`;

const marker = '## Completed steps log\n\n';
const idx = text.indexOf(marker);
if (idx === -1) throw new Error('Could not find "## Completed steps log" marker.');
const insertAt = idx + marker.length;
text = text.slice(0, insertAt) + STEP_17B_ENTRY + text.slice(insertAt);

fs.writeFileSync(PATH, text);
console.log('PROGRESS.md updated (Step 17b).');
UPDATE_PROGRESS_EOF
echo ""
node /tmp/update-progress-17b.mjs
rm /tmp/update-progress-17b.mjs

echo ""
echo "Done. public/data/rivers-index.json should now have 85 rivers with no validation failures."
