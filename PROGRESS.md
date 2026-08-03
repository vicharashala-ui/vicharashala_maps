# Vicharashala Maps — Progress

Spec: `VICHARASHALA_MAPS_SPEC.md` (upload alongside this file if starting a new session).
Package manager: **pnpm**. Environment: **native Windows** (Git Bash, no WSL).

## How to resume in a new session
1. Upload this `PROGRESS.md`.
2. **Also re-upload `VICHARASHALA_MAPS_SPEC.md`** if you have it — my sandbox's copy became inaccessible partway through Step 4 (cache expiry, not a data-loss issue on your end), so some Step 4 decisions (see below) were made from memory/inference rather than re-checking exact spec prose. Worth a quick cross-check once the spec is back in context.
3. `pnpm install` — `pnpm-lock.yaml` is committed, restores exact versions, not "latest."
4. `pnpm build` to confirm things still build before adding new code.
5. Continue at "Next step" below.

## Workflow
- Code/config changes ship as a `stepN-patch.sh` script — run from the project root in Git Bash. Each is tested end-to-end against a clean checkout before being handed over, not just "should work." Idempotent, includes `pnpm install`.
- Generated **binary artifacts** (e.g. `.pmtiles`) ship as plain files to drop into place — they're build output, not source, so a patch script doesn't make sense for them.
- Linux-only native tools (tippecanoe) aren't available on native Windows. Sandbox builds them and hands over the finished artifact instead.
- Source data comes from `https://github.com/vicharashala-ui/ecoguesser.git`, a sibling project with already-processed PA data matching this spec almost field-for-field.

## Current status: Step 24 delivered — all 21 Ganga-system `rivers/{id}.json` authored, schema-validated, and cross-checked against `rivers-index.json` for transcription errors. `rivers/{id}.json` coverage now 28/85 (Indus + Ganga systems complete). Ravi's length reverted to 725/725 per Ashwin's decision to keep `rivers-index.json` unpatched.

Found and fixed a real bug while building: `Ravi`'s merged geometry had one over-nested `MultiLineString` segment — one of its 11 raw Overpass ways came back typed `MultiLineString` (not `LineString`) from `osmtogeojson`, and Step 11's `mergeOverpassRivers.js` assumed every raw way was a `LineString`, double-wrapping that one segment. tippecanoe rejected it outright (`malformed point`). Scanned all 85 features segment-by-segment — only this one segment was affected. Fixed the delivered `rivers-prepared.geojson` in place, and patched `mergeOverpassRivers.js` (`feats.flatMap` instead of `feats.map`) so this can't recur if the deferred/flagged rivers are ever re-merged.

`--attribution` corrected from the spec's literal `"OpenStreetMap contributors"` (written when the plan was OSM-primary) to `"Government of India (data.gov.in), OpenStreetMap contributors, HydroSHEDS/USGS"`, reflecting that 63/85 rivers are actually govt-shapefile-sourced.

### rivers-index.json research + reconciliation: done
Built via web research (batched by river system per spec §4.9), then reconciled against Step 5c/6's govt shapefile + HydroRIVERS data in Step 8. `research/rivers-index-reconciled.json` (106 entries) is the current working file — supersedes `rivers-index-draft.json`, which is kept only as a historical record of the pre-reconciliation research.

**Count correction**: spec §4.9's river lists actually total 107 named rivers (9 Indus + 26 Ganga + 15 Brahmaputra + 29 Peninsular-East + 14 Peninsular-West + 12 Coastal + 2 Inland Drainage), not the ~105 figure used throughout this project so far. Every named entry in §4.9 has a draft record now.

- **Indus** (9/9), **Ganga** (26/26), **Brahmaputra** (15/15), **Peninsular-East** (29/29), **Peninsular-West** (14/14) — all done in prior updates
- **Coastal** (12/12 done): Ulhas, Vaitarna, Savitri, Vashisthi, Kali (Karnataka), Netravati, Gurupur, Aghanashini, Damanganga, Swarnamukhi, Manimuktha, Vaippar
- **Inland Drainage** (2/2 done): Luni, Ghaggar-Hakra
- Every entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)

### Remaining open items
1. ~~Reconcile against Step 5c's govt data~~ — done, Step 8.
2. ~~Backfill `stream_order` for all 85 geometry-backed rivers~~ — done, Step 17 (govt-matched via re-run join, Overpass-only via the same grid-match reused inside `prepareRivers.js`).
3. **8 flagged + unmatched rivers (~20, see this session's console output for the exact list)** — genuine gap, deferred to manual digitizing / Phase 2. Not shipped in V1's `rivers-index.json`.
4. **Length discrepancies >20%** between web research and govt data, worth a manual sanity check: Chenab (700→431km), Barak (524→100km), Subarnarekha (395→480km), Vaigai (258→312km), Bharathapuzha (209→100km), Kali/Karnataka (265→179km), Vaippar (130→87km). Govt value is what shipped.
5. **Vellar** (Peninsular-East) — Tamil Nadu has two rivers by this name; draft used the Southern one, still unverified against govt/OSM either way.

### Not started yet
- `rivers.pmtiles` (step ⑧ — tippecanoe over `build/rivers-prepared.geojson`)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- River layers + detail panel wired into the frontend
- Everything in spec §5 onward

## Next step
1. Run `step24-patch.sh`.
2. `protected_area_ids` for all 21 new Ganga-system rivers are still `[]` placeholders — same pattern as the Indus batch. Re-run `node scripts/spatialIntersect.js` (it's safe to re-run any time; idempotent) and paste the new rivers' entries from `build/river-protected-area-ids.json` so they can be merged in, same as Step 23.
3. Continue `rivers/{id}.json` in batches — 57/85 rivers remain. Natural next batches by system: Brahmaputra (barak, brahmaputra, kameng, kopili, lohit, manas, subansiri...), then Peninsular (godavari, krishna, kaveri, narmada, tapi and their tributaries), then coastal/minor rivers.
4. `deriveStateCrossRefs.js` (step ⑫) — 28/85 rivers and 14 cities now exist. Getting closer, but still worth deciding whether to wait for full coverage or run it now for partial/best-effort `states.json` and re-run later as more batches land.
5. `buildSearchIndex.js` (step ⑬) — after ⑪/⑫.
6. Real research to backfill `basin_area_india_km2` for the rivers currently shipping `null` (many of Step 24's Ganga tributaries — Banas, Parbati, Son, Gomti, Ghaghra's exact figure, Sarda, Gandak, Mahananda — don't have a confidently-sourced total; check `rivers-index.json`'s `_needs_verification` flags from Step 7 research if any exist for these).
7. Not yet built: search, browse lists, filters, compare mode, state panel, header/footer, SEO pages, `basins.json` + basin badges/colors, `search-index-pa.json`.

### Step 24 — Ganga-system `rivers/{id}.json` batch (delivered as `step24-patch.sh`)
- All 21 geometry-backed Ganga-basin rivers authored: ganga, bhagirathi, alaknanda, yamuna, chambal, banas, kali-sindh, parbati, betwa, ken, son, gomti, ghaghra, sarda, gandak, kosi, mahananda, damodar, hooghly, barakar, ajay. (5 spec rivers not shipped/no geometry — burhi-gandak, mechi, kamla, bagmati, rupnarayan — skipped, same as Indus's jhelum/spiti.)
- Also reverts `rivers/ravi.json`'s `length_km_india`/`length_km_total` from the Step 21 correction (320/725) back to 725/725, to match Ashwin's decision to leave `rivers-index.json` as-is — the two files were disagreeing after Step 21 and before this fix.
- **Confidence note, same caveat as Step 21**: source/sink coordinates and altitudes for the lesser-known Malwa Plateau tributaries (Banas, Kali Sindh, Parbati) and the high-Himalaya transnational sources (Ghaghra/Karnali, Sarda/Mahakali, Gandak/Narayani, Kosi) are standard-reference-level facts, not individually search-verified — a few coordinates are reasonable estimates rather than pinpoint-precise. All numeric fields that exist in `rivers-index.json` (length, stream_order, states, transnational, navigable) were transcribed from there directly and cross-checked programmatically, so those are exact, not estimated.
- **`protected_area_ids` left as `[]`** in all 21 files — same as Indus batch pre-Step-23, needs a `spatialIntersect.js` re-run + merge (see Next step item 2).
- **`basin_area_total_km2`/`basin_area_india_km2`**: used the shipped index value where present; left `null` where the index also has `null` (Banas, Parbati, Son, Gomti, Ghaghra's total, Sarda, Gandak, Mahananda's total) rather than guessing.
- **Interesting cross-reference**: Hooghly's `tributaries.right` includes both `damodar` and `ajay` — worth double-checking this reads correctly in the frontend once built, since Hooghly is itself a `distributary` (of the Ganga) that also *receives* tributaries, a slightly unusual combination the UI may not have been designed around yet.
- **Verified**: all 28 `rivers/{id}.json` files (7 Indus + 21 Ganga) pass `RiverDetail.parse()`; every `river`/`notable_city_ids`/`tributaries`/`distributaries` cross-reference resolves to a real id; every numeric/boolean field that exists in both `rivers-index.json` and the new detail files matches exactly (scripted diff, zero mismatches); `step24-patch.sh` tested end-to-end on a clean clone.

### Step 23 — Real `protected_area_ids` merged into the Indus batch (delivered as `step23-patch.sh`)
- Pulled the real per-river PA lists from your `build/river-protected-area-ids.json` (Step 20/22's actual output) into `rivers/{indus,ravi,beas,sutlej,zanskar,shyok}.json`. `chenab.json` unchanged — its list is genuinely `[]`, no PA intersects the Chenab in the current data.
- Notable results: Beas and Sutlej each pick up several Ramsar/WLS sites around Harike and Pong Dam (expected — those are well-known wetland PAs on these rivers); Zanskar → Hemis NP (correct, Hemis extends into the Zanskar valley); Ravi → Kathlaur-Kushlian WLS (a real, if less well-known, Punjab sanctuary on the Ravi).
- **Verified**: all 7 files re-validated against `RiverDetail`; `step23-patch.sh` tested end-to-end on a clean clone.

### Step 22 — Fix Ravi's malformed geometry (delivered as `step22-patch.sh`)
- **Bug**: Step 20's real `spatialIntersect.js` run crashed on `turf.booleanIntersects` (`coord must be GeoJSON Point or an Array of numbers`). Traced to one raw Overpass way in Ravi's geometry: typed `LineString`, but with a ~30-position sub-array embedded where one single `[lng,lat]` position should be — nesting corruption *within* one way's own coordinates, not *across* separate ways (Step 18 already fixed the across-ways case; this is a different bug in the same family).
- `scripts/mergeOverpassRivers.js`: replaced the type-trusting flatten with `wayToLineStrings()` — a `MultiLineString`-typed way's top-level segments stay separate (they can be genuinely disjoint, per Step 18), but any nesting found *within* a segment (or within a plain `LineString` way) is now deep-flattened in place via `deepFlattenPositions()`, regardless of what `geometry.type` claims. Fixes this bug class for any future full-pipeline re-run.
- `fix-ravi-geometry.mjs`: standalone one-off repair for the already-corrupted `build/rivers-by-id/ravi.geojson` on disk — same logic, doesn't need the raw Step 10 Overpass data. Validates the repaired geometry (every position finite `[lng,lat]`, segment count unchanged from before) before writing; throws instead of silently shipping a bad fix if either check fails.
- **Caught my own bug while testing**: first attempt at the fix (`extractLineStrings`, checked only the first array element to decide nesting depth) missed exactly this failure mode — a segment with a mix of valid positions and one corrupted embedded sub-array doesn't get caught by a first-element check. Found this with a fixture built directly from Ashwin's actual bad-coordinate output before shipping; rewrote as the current segment-preserving `deepFlattenPositions`/`wayToLineStrings` approach and re-verified.
- **Verified**: fixture built from Ashwin's real diagnostic output (2-segment `MultiLineString`, one segment with the exact corruption pattern found) — repair produces a valid geometry, correct segment count (2, unchanged), all positions pass `turf.coordAll` + `booleanIntersects` without throwing. `step22-patch.sh` tested end-to-end on a clean clone.
- **Not yet done**: hasn't run against your actual `build/rivers-by-id/ravi.geojson` — that's the next step, on your machine.



## Completed steps log (continued above Step 19)

### Step 21 — `cities.json` + `rivers/{id}.json` batch 1 (delivered as `step21-patch.sh`)
- `scripts/schemas.js`: added `RiverDetail` (spec §4.1) and `City` (spec §4.5) zod schemas
- `public/data/cities.json`: 14 major river cities (Leh, Haridwar, Rishikesh, Varanasi, Prayagraj, Patna, Kolkata, Delhi, Agra, Guwahati, Ahmedabad, Nashik, Hyderabad, Ludhiana), each referencing a real shipped river id, with ghats for the religiously-significant ones
- `public/data/rivers/{indus,chenab,ravi,beas,sutlej,zanskar,shyok}.json`: full detail records for all 7 geometry-backed Indus-system rivers (2 of the spec's 9 — jhelum, spiti — aren't shipped in V1, no geometry, so skipped)
- **Confidence note**: unlike the numeric index data (Step 7's rigorously multi-sourced, `_source`/`_needs_verification`-tracked research), this batch's source/sink coordinates and altitudes are standard, well-established geography facts (Wikipedia-infobox-level) rather than individually search-verified to the same standard — a few (Bara Bhangal, Rimo Glacier, Padum coordinates) are reasonable estimates, not pinpoint-precise. Fine for map/info-panel display; flag if exam-grade precision is needed later.
- **`protected_area_ids` left as `[]`** in all 7 files — real values need `build/river-protected-area-ids.json` (Step 20's output), which requires running on your machine (see item 2 above).
- **Ravi length correction** — see item 3 above, needs your decision.
- **Verified**: all 7 river files + 14 cities pass `RiverDetail.parse()`/`City.parse()`; cross-checked every `river` (cities→rivers), `notable_city_ids` (rivers→cities), and `tributaries`/`distributaries` (rivers→rivers) reference resolves to a real shipped id; `step21-patch.sh` tested end-to-end against two independent clean clones.

### Step 20 — spatialIntersect.js (delivered as `step20-patch.sh`)
- `scripts/spatialIntersect.js` — Turf.js `booleanIntersects`, PA-bbox pre-filtered before the real check (837 PAs × 85 rivers would otherwise be needlessly expensive)
- Updates `public/data/protected-areas.json`'s `river_ids` in place
- **Deviation**: spec's step ⑪ says this writes `protected_area_ids` into `rivers/{id}.json`. Those detail files weren't authored yet at the time (Step 20 ran before Step 21), so writing into them would have meant inventing placeholder records. Writes `build/river-protected-area-ids.json` instead (`{ river_id: [pa_id, ...] }`) as an intermediate — now that Step 21 has authored 7 real `rivers/{id}.json` files, this can be merged in (see Next step item 2).
- **v2 fix (real run on your machine crashed)**: `turf.booleanIntersects` threw `coord must be GeoJSON Point or an Array of numbers` deep inside `@turf/invariant`, on a real PA in `build/pa-merged.geojson` with a malformed coordinate — some ring point isn't a valid `[x,y]` pair. v2 adds a pre-flight `isGeometryValid()` check (via `turf.coordAll`) that names and skips any malformed PA/river feature instead of crashing the whole 837×85 run; a skipped PA's existing `river_ids` is left untouched (not wiped), and the console prints exactly which PA/river id(s) were skipped so the root cause (almost certainly in `mergeFeatures.js`'s source boundary file, or a river's Overpass geometry) can be tracked down separately. Caught a real bug in my own fix while testing it: the first version of this skip-logic still zeroed out the skipped PA's `river_ids` — fixed and re-verified before shipping v2.
- **Verified**: synthetic 3-PA/1-river fixture including one deliberately malformed PA (a ring point with only 1 coordinate) — malformed PA correctly named, skipped, and its `river_ids` left untouched; the other 2 PAs processed correctly; run completes instead of crashing. Not run against your real `build/pa-merged.geojson`/`build/rivers-by-id/` — gitignored, not in the sandbox.
- **Action needed from you**: once v2 runs cleanly, check its stderr for `SKIPPED N PA(s)` — if any print, note the id(s) so the malformed-geometry root cause can be found in `mergeFeatures.js`/the source boundary GeoJSON later.

## Completed steps log

### Step 19 — Core map frontend, built from scratch (delivered as `step19-patch.sh`)
- **Found the gap**: `src/components/{Map,Panels,...}` only had `.gitkeep` files; `MapView.tsx`/`ProtectedAreasLayer.tsx`/`PAInfoPanel.tsx`/`LayerControl.tsx`/`MapControls.tsx` referenced from earlier sessions were never actually committed. Built all of them plus the river-layer work fresh, in one pass.
- **Fixed a pre-existing bug**: `package.json`'s `devEngines.packageManager.version` was `"^11.17.0"` — pnpm 11.17's corepack shim rejects a version range there and refuses to run *any* command. Pinned to exact `"11.17.0"`.
- New: `src/utils/{types,geoUtils,dataStore,mapStore,urlState}.ts`, `src/scripts/themeInit.raw.ts`, `src/components/Map/{MapView,RiversLayer,ProtectedAreasLayer,LayerControl,MapControls}.tsx`, `src/components/Panels/{RiverDetailPanel,PAInfoPanel}.tsx`
- Rewrote: `src/styles/global.css` (full §5.6/§6.1 token set), `src/pages/index.astro` (inlines `rivers-index.json`+`states.json` per §5.3, mounts everything), `tsconfig.json` (added `jsxImportSource: "preact"` — required for `astro check` to resolve Preact JSX types at all; build itself worked without it since esbuild doesn't type-check)
- `RiversLayer.tsx`: vector layer from `rivers.pmtiles`, click/hover, feature-state selected/highlighted (no `setFilter`), fly-to on select, cross-highlights associated PA polygons via `river_ids` (only if PA data already loaded — doesn't force-load it)
- `ProtectedAreasLayer.tsx`: 5 categories × fill+outline layer (np/wls/tr/br/ramsar), NP>TR>BR>Ramsar>WLS click priority, DOM markers with dashed-circle CSS for the 2 boundary-less TRs, category toggles wired to `LayerControl` via nanostores
- `RiverDetailPanel.tsx` / `PAInfoPanel.tsx`: cross-link each other via `river_ids`; river panel only shows fields that actually exist in `rivers-index.json` (no source/sink/tributaries/basin badge — needs `basins.json` + `rivers/{id}.json`, neither built yet)
- **Bug caught by `astro check`, not by `pnpm build`**: assumed `pa-id-map.json` was `Record<string, number[]>` (mirroring `rivers-id-map.json`'s multi-segment shape); it's actually `Record<string, number>` — one PA is always one polygon feature, unlike rivers which can be split into segments. Fixed in both `ProtectedAreasLayer.tsx` and `RiversLayer.tsx`'s PA cross-highlight code.
- Added `@astrojs/check` + `typescript@5.7.3` as devDependencies — `astro check` needs TS <7 for now (TS 7's native compiler doesn't expose the API the checker relies on yet); `pnpm build` itself is unaffected by TS version since Vite/esbuild only strips types
- Verified against a clean checkout: `pnpm install` → `astro check` (0 errors) → `pnpm build` (succeeds) — not just the dev sandbox
- **Not verified**: no browser/visual QA (sandbox has no display). Test `pnpm dev` and click through both panels, marker highlighting, and layer toggles before trusting this beyond "compiles and builds."

### Step 18 — rivers.pmtiles (delivered as a binary file + scripts/mergeOverpassRivers.js fix, not a patch script)
- Installed tippecanoe 2.49.0 in sandbox (same version as Step 3, unavailable on native Windows), built from source (felt/tippecanoe fork)
- Ran spec §4.7 step ⑧'s command against the uploaded `build/rivers-prepared.geojson`, with `--attribution` corrected to name all three actual data sources (govt shapefile, OpenStreetMap, HydroSHEDS/USGS) instead of the spec's OSM-only default
- **Bug found and fixed**: tippecanoe rejected the file outright (`malformed point`) — `Ravi`'s merged `MultiLineString` had one segment double-nested, because one of its 11 raw Overpass ways came back as `MultiLineString` (not `LineString`) from `osmtogeojson`, and `mergeOverpassRivers.js`'s merge logic assumed every raw way was a `LineString`. Verified via a full segment-by-segment structural scan that this was the *only* malformed segment across all 85 features — not a systemic issue. Fixed the delivered geojson in place; separately patched `mergeOverpassRivers.js` (`feats.flatMap` instead of `feats.map`, unit-tested against both the normal and bug-triggering shapes) so a future re-merge (e.g. resolving deferred rivers) can't reproduce it
- Verified via the `pmtiles` JS library: minZoom 4 / maxZoom 14, source-layer `rivers`, `id`+`stream_order` fields present (all 85 river ids, stream_order range 4–8), bounds match India's extent, **8.1 MB** (well under Cloudflare's 25 MiB limit)
- **Action needed**: place the delivered file at `public/tiles/rivers.pmtiles`, and apply the `mergeOverpassRivers.js` diff (delivered inline) if you plan to re-run Step 11 later


- Step 17's actual run (85 real rivers, not synthetic fixtures) surfaced 33 `RiverIndexEntry` validation failures — all the same field, `basin_area_india_km2: null`, a Step 7 web-research gap orthogonal to the geometry/stream_order pipeline
- Considered deriving it from HydroRIVERS' `UPLAND_SKM` (upstream drainage area at the matched reach) — rejected: it's global upstream area, not India-scoped, so it would overstate the figure for every transnational river (Ganga, Indus, Brahmaputra, etc.) — the same class of issue `length_km_india` already has documented caveats for
- `scripts/schemas.js`: `basin_area_india_km2` relaxed `z.number().positive()` → `.nullable()`, deviation documented inline (same pattern as `ProtectedArea.area_km2`)
- Re-ran `prepareRivers.js` with no other changes — confirmed 85/85 pass validation, final `public/data/rivers-index.json` count matches the 85 predicted after Step 17's geometry-matching output
- Backfilling real values for the 33 is a follow-up research task, not blocking V1

### Step 17 — prepareRivers.js: final rivers assembly (delivered as `step17-patch.sh`)
- `scripts/prepareRivers.js` — merges govt-shapefile geometry (Step 9/17b, 63 rivers) + clean Overpass geometry (Step 16, 22 rivers) into `build/rivers-prepared.geojson`, computes `bounds` via `turf.bbox()`, validates every entry against `RiverIndexEntry`, writes `public/data/rivers-index.json` + `public/data/rivers-id-map.json` + one file per river under `build/rivers-by-id/`
- Reuses the same shapefile-name→reconciled-name alias map and `Purna` false-positive exclusion as `reconcileGovtMetadata.js` — applies to geometry attachment too, not just metadata (a river's wrong-basin same-name govt feature would otherwise ship the wrong shape under the right id)
- Backfills `stream_order` for the 22 Overpass-only rivers via the same HydroRIVERS grid-match approach as `joinHydroRivers.js` (duplicated, not imported — consistent with this project's existing self-contained-script convention)
- Fails loudly: any `RiverIndexEntry` validation failure is collected (not stopped at the first one) and reported with the exact Zod field/message before exiting non-zero; no partial `public/data/` output on failure
- Tested against synthetic fixtures covering all 4 real code paths: govt geometry via direct name, govt geometry via the alias map (Kali→Kali (Karnataka)), Overpass geometry needing stream_order backfill (found + not-found cases), and 3 exclusion cases (govt false-positive, Overpass-flagged despite having geometry, fully unmatched) — real `build/` data isn't available in the sandbox, same constraint as every step since Step 9

**Also this step:** re-ran `joinHydroRivers.js` + `reconcileGovtMetadata.js` after discovering `stream_order` was `null` for all 106 entries in `research/rivers-index-reconciled.json`, despite Step 6's log reporting 61/61 real matches — the join's output apparently never reached the version `reconcileGovtMetadata.js` read at the time. Re-running both fixed it (64/64 matched this time, 63 real + Purna's excluded false-positive). Also ran `inspectFlaggedRivers.js` for real: 0/8 auto-resolved, confirming the 8 flagged rivers need manual geometry work, not more automated passes.

### Step 16 — actually researched the 9 flagged rivers instead of building more tooling (delivered as `step16-patch.sh`)
Two fixes grounded in evidence, not more automation:

**Ravi's expected length was wrong.** `rivers-index-reconciled.json`'s `length_km_india: 725` for Ravi was the river's TOTAL length (India+Pakistan) — Britannica, Wikipedia, and Mershon Center (OSU) all independently give ~320km as the India-only portion (720-725km total, ~80km of that forming the border before entering Pakistan). Catchment area (14,442 km²) was already correctly India-scoped and matched Wikipedia exactly, suggesting the total-length figure got transcribed into the wrong field. Corrected to 320 — Ravi's actual 171km matched is 0.53x against the corrected figure, clean.

**Aliases were researched but never wired into the fetch config.** `rivers-index-reconciled.json` has had an `aliases` field per river since Step 7 — documented alternate/local/historical names — but `fetchRivers.js`'s `BATCHES` config was hand-authored separately and never pulled from it, so Overpass only ever got queried for each river's primary name. Systematically cross-checked every flagged/unmatched river's `aliases` against its current `BATCHES` variant list and found 10 with usable aliases sitting completely unused: Jhelum (Vyeth, Vitasta, Hydaspes), Ravi (Iravati, Purushni), Burhi Gandak (Sikrahna), Dibang (Talon), Manas (Drangme Chhu), Sankosh (Puna Tsang Chu), Tamiraparani (Tambraparni, Porunai), Chaliyar (Beypore River), Kamla (Balan), Rupnarayan (Dwarakeswar, Shilabati — split from the compound alias since OSM wouldn't tag the literal joined string). Independently confirmed Jhelum/Vyeth and Dibang/Talon via web search before trusting the aliases field blindly. Wired all 10 into `BATCHES` — strictly additive (OR-matched regex), so it can only surface more candidates, never fewer; for the already-over-matched rivers (Burhi Gandak, Rupnarayan) it won't fix their flag but doesn't make it worse either.

**This exposed a real gap in Step 13's resume logic**: a region was only re-fetched if its rivers lacked a matched/unmatched verdict — it never checked whether the *query config itself* had changed, so these new aliases would have been silently ignored for any region the old data already "completes". Fixed: `fetchRivers.js` now persists a signature (`JSON.stringify(batch.rivers)`) per region and forces a re-fetch whenever it no longer matches. One-time cost: this run re-fetches all 8 batches (signature tracking is new, so nothing matches yet); after that, only regions with a genuine future config change get re-queried, not all 8.

**Verified**: full regression suite (dedup, degenerate-geometry handling, idempotency) re-run against the updated `BATCHES` — all pass. New signature-invalidation logic tested with a fixture proving only intentionally-stale regions get re-queried while unchanged ones stay skipped. `research/rivers-index-reconciled.json`'s JSON validity re-checked after the edit (caught and fixed a trailing-comma break from the edit itself). Ran the actual `step16-patch.sh` end-to-end in a clean checkout (with Step 15's state simulated first, matching your real machine) — full pipeline (fetch → merge → inspect) runs clean through to completion even in the all-batches-fail edge case. Caught and fixed a heredoc-generation bug during this: `research/rivers-index-reconciled.json` has no trailing newline, which ran its closing `]` into the heredoc delimiter on the same line and would have corrupted the patch — general lesson, now inserting an explicit blank `echo` after every embedded file in patch scripts.

**Not resolved**: Burhi Gandak, Dhansiri, Rushikulya, Purna, Girna, Vaitarna — spent real effort (Dibang's search alone surfaced a length-definition ambiguity, upstream tributaries carry different names before the river is called "Dibang") but didn't reach an equally solid conclusion for these in the time spent. Flagging honestly rather than padding out speculative fixes.

### Step 15 — fixed a real crash in inspectFlaggedRivers.js (delivered as `step15-patch.sh`)
Root cause: `sampleStates()` picked sample indices as `[0, Math.floor((coords.length-1)/2), coords.length-1]` and indexed straight in. For a degenerate segment (0 or 1 coordinates), that math produces negative indices, `coords[-1]` is `undefined`, and `turf.point(undefined)` throws `"coordinates must contain numbers"` — exactly the error hit. `mergeOverpassRivers.js`'s own length loop never surfaced this because a `for` loop over an empty/single-element array just silently contributes 0 — same underlying data quirk, no crash, just no signal either.

Fix: coordinates are filtered to valid `[lon,lat]` pairs before any indexing (`isValidCoord`), a missing `geometry` is treated as no coordinates rather than crashing on `.coordinates` of `null`, and a segment left with nothing usable reports `UNRESOLVED` (same bucket as a genuine open-ocean/border segment) instead of stopping the run. Applied the same coordinate filter in the length calculation for consistency, though that path wasn't actually crashing.

**Verified**: reproduced the exact crash with a fixture mixing empty-coords, single-point, and null-geometry segments alongside a legit one — old code crashed identically, new code ran clean and correctly reported the bad segments as UNRESOLVED. Re-ran the full Step 14 fixture suite (contamination-drop, insufficient-coverage-stays-flagged, ocean-stays-unresolved) — all three verdicts unchanged, confirming the fix didn't regress the actual detection logic. Also ran the real `step15-patch.sh` in a clean checkout against a fixture mixing degenerate segments into two of the real flagged river names (Jhelum, Purna) — clean run.

### Step 14 — automated first pass on flagged rivers (delivered as `step14-patch.sh`, superseded by `step15-patch.sh`)
Adds `scripts/inspectFlaggedRivers.js`. A flagged river (length way outside 0.4x-1.6x expected) is usually a same-named-but-unrelated OSM way pulled in alongside the real one (already confirmed for Purna) — checkable without eyeballing coordinates, since every river has an expected `states` list in `rivers-index-reconciled.json`. Samples each segment's start/mid/end (not just one point, so a segment legitimately straddling a state border isn't misjudged) against `india-states.geojson`; a segment with no state match anywhere in the river's expected list is marked a drop-suspect, recomputes the ratio without it, and reports AUTO_RESOLVED if that brings it into range. Segments with no state match at all (open ocean, or a genuine cross-border stretch for transnational rivers like Jhelum/Ravi) are left UNRESOLVED rather than auto-dropped — can't confirm those are wrong.

This is a heuristic that narrows the manual work, not a replacement for it — a KEEP verdict isn't a correctness guarantee (two rivers can share a state), so AUTO_RESOLVED rivers still deserve a spot-check.

**Verified before shipping**: built synthetic fixtures covering all three verdict paths — real contamination (segment in an unrelated state) correctly dropped with the ratio corrected into range; a river still under-covered after dropping suspects correctly stays flagged; an open-ocean segment correctly left UNRESOLVED instead of being silently dropped. Also ran the actual `step14-patch.sh` in a clean checkout against a fixture built from the real 9 flagged river names + their real `states` metadata from the repo's own `rivers-index-reconciled.json`, to confirm no schema surprises against real data. Not run against the actual `build/rivers-overpass.geojson` on your machine — that's real segment geometry I don't have.

Also researched whether the 13 unmatched rivers might just be under a different OSM name/spelling (checked Spiti via web search) — found no alternate name in use for it at all, so didn't burn further searches chasing the same low-probability lead for the other 12. Recommend treating the 13 as a genuine OSM coverage gap (manual digitizing / Phase 2), not a query problem.

### Step 13 — fixed a real duplication bug in fetchRivers.js's resume logic (delivered as `step13-patch.sh`)
Diagnosed from your actual Step 12 console output, not a hypothesis: Step 12's `completedBatches` array was tracked separately from the `matched`/`unmatched`/`multiCandidate` data arrays. A region whose Overpass query succeeded but whose run ended before `completedBatches.push(region)` got persisted (interrupted run, or a run of an older pre-Step-11 script version) wasn't recognized as "done" on the next run — it got re-queried, and its matched features got pushed into the same flat `allFeatures` array a second time. Cross-checked your pasted unmatched/multi-candidate lists against the `BATCHES` config: every duplicated name (Spiti, Manas, Sankosh, Chaliyar, Jhelum, Ravi, Zanskar, Shyok, Dhansiri, Rangeet, Pamba) belonged to a region that got re-queried that run, and all 8 regions' 43 rivers were *already fully accounted for* in the existing `build/` files — the retries were pure waste, not genuinely-needed re-fetches. The doubling explains the previously-flagged Zanskar (2.01x), Pamba (1.89x), and Burhi Gandak (1.87x) — all ≈2x, not real OSM contamination.

**Fix**: `fetchRivers.js` no longer trusts a separately-tracked flag. `loadAndMigrate()` reconstructs, per region, whether every configured river already has a matched-or-unmatched verdict directly from the existing `build/rivers-overpass.geojson` + `-report.json`, deduping any doubled features by `osm_id` along the way. A region only counts as complete if *every* one of its rivers is accounted for; anything less gets re-fetched, nothing else does. `deriveReport()` is now always computed fresh from the feature data rather than accumulated — it can't drift out of sync the way the old flat push-arrays did. Output is written unconditionally at the end of every run (not just inside the fetch loop) so a fully-salvaged run still persists the deduped file to disk, not just the printed report.

**Verified end-to-end**, not just unit-level: built a fixture reproducing your exact reported bug pattern (4 regions with doubled features, matching your duplicate-name lists exactly), ran the actual `step13-patch.sh` against a clean checkout — result matched the prediction: "8/8 batches already complete on disk", zero Overpass calls, feature count 328→243 after dedup, Zanskar/Pamba/Burhi Gandak flipped from ~2x-flagged to clean (0.6–0.8x on the fixture's dummy geometry — real numbers will differ once run against your actual data, but the *mechanism* is confirmed fixed). Second run of the same patch script is a byte-identical no-op (idempotent). `osmtogeojson` import also made lazy (only loaded if a batch actually needs a live fetch) so the salvage-only path has no dependency on it being installed.

**Not independently verified against live Overpass** — my sandbox has no route to `overpass-api.de`/`overpass.kumi.systems` (`403 host_not_allowed`, confirmed via the egress proxy's deny header), same constraint noted in prior sessions. `queryOverpass`/`buildQuery`/`BATCHES` are untouched from the already-battle-tested Step 12 code; only the state-management layer around them changed, and that's what was tested above.

### Step 11-12 — merge script + made fetchRivers.js resumable (delivered as `step11-patch.sh`, superseded by `step12-patch.sh`)
- **`scripts/mergeOverpassRivers.js`**: real runs showed most "multi-candidate" rivers (Ravi: 11 candidates, Ken: 16, Sarda: 37, etc.) are normal — OSM maps long rivers as many separate way segments, not one line, so many matches per name is expected, not a name collision. Rather than manually eyeball coordinates for ~23 rivers, this merges same-name segments into one feature and sums their length, comparing the total against the web-researched `length_km_india` already in `rivers-index-reconciled.json`. A total far off from the researched figure is the real contamination signal (confirmed against the known Purna case — two unrelated rivers share that name, per Step 9 — synthetic segments summing to 2x the researched length correctly flagged; a normal 3-segment river at 1.0x correctly passed). Thresholds: <0.4x or >1.6x expected flags for manual review.
- **`fetchRivers.js` made resumable**: real runs showed a rotating subset of the 8 batches failing on rate-limits/timeouts on every single run so far — different batches each time, never all 8 in one pass. The script used to overwrite its entire output from scratch every run, so a batch that succeeded once could get lost if a later run of the whole script failed elsewhere before writing. Fixed to load its own previous `build/rivers-overpass.geojson`/`-report.json` on startup and skip any batch already in `completedBatches`, only retrying what previously failed. Verified: a second run against an already-completed batch makes zero network calls for it, and results accumulate correctly across runs (5 matched in run 1 + 3 more in run 2 = 8 total, not overwritten).
- Net effect: this is no longer "run once and report the result" — it's "keep re-running until `BATCHES THAT FAILED` is empty," and each re-run only costs whatever didn't succeed yet.

### Step 10 (in progress) — fetchRivers.js debugged against real Overpass, 2 real bugs found and fixed
Overpass reachability confirmed from your machine: `curl` to `overpass-api.de` returned `200`. Rewrote `scripts/fetchRivers.js`: bbox instead of `area["ISO3166-1"="IN"]` (the country-wide area lookup makes Overpass compute the whole India polygon before it can filter anything — almost certainly the real cause of the original v1 504, not the name regex), batched into 8 regions (indus_himalaya / ganga_upper / ganga_bihar_plains / brahmaputra_ne / kaveri_south_tn / kerala_west / konkan_goa_tapi / karnataka_andhra_coastal — `ganga_plains` was split into two after its first real run 504'd, being the largest bbox over the densest-mapped river network in the set), `waterway~"river|stream"` not just `river`, known name variants baked into each batch's query, multi-candidate rivers (Vellar, etc.) flagged rather than silently resolved.

First real runs against live Overpass surfaced two genuine bugs mocked testing hadn't caught:
1. **No client-side timeout on the HTTP request.** `[timeout:60]` in the query only bounds Overpass's own processing time, not the connection itself — when the mirror endpoint stalled without ever responding, `fetch()` hung forever. Fixed with an `AbortController` (query timeout + 20s) and `querying <endpoint>...` progress logging so a slow response is distinguishable from a dead one. Verified by mocking a `fetch` that truly never resolves — confirmed both endpoints now abort cleanly instead of hanging.
2. **`osmtogeojson@2.2.12` (the version actually pinned in this project) nests tags under `properties.tags.{key}`, not flattened onto `properties` directly.** The matcher read `properties.name` — always `undefined` — so real runs matched 0/43 despite Overpass correctly returning 127 real ways across 5 successful batches (server-side name filtering worked fine; purely a client-side property-path bug). My own earlier "passing" mocked tests used a different, newer `osmtogeojson` version (3.0.0-beta.5, pulled by a bare `npm install osmtogeojson` in my own test sandbox) that happens to flatten tags by default — that version mismatch is exactly why the bug wasn't caught before a real run. Fixed to read `properties.tags.name`, verified directly against a real sample response you sent (5/5 Purna features matched) and against a full mock run redone using the *correctly pinned* 2.2.12.

**Lesson logged**: when mocking a library's output shape for testing, pin the exact version from the project's lockfile, not whatever a fresh install resolves — different versions can have different default behavior and the mock will validate against the wrong one, giving false confidence.

Rate-limiting (429) and transient timeouts on various batches across runs so far look like normal Overpass flakiness, not script bugs — per-batch error isolation makes re-running cheap (small batches, no incremental skip-if-already-matched logic, but that's fine at this scale).

### Step 9 — 3 more rivers recovered + a duplicate-rivname data bug fixed (delivered as `step9-patch.sh`)
You uploaded `rivers-govt-raw.geojson` (the converted, pre-matching intermediate — 110 features). Checked all 43-at-the-time unmatched river names against it with exact/substring/Levenshtein(≤2) fuzzy matching:
- **Recovered 3**: Banas and Parbati (Chambal tributaries — never actually attempted before, `processRiversShapefile.js`'s `RIVER_NAMES` list didn't include them as separate entries at all, only Kali Sindh was in that gap and it's genuinely absent from the shapefile), and Manjira (shapefile spells it "Manjra" — added as a `VARIANT_MAP` entry).
- **Everything else genuinely absent** — this shapefile only has 110 named-river features nationally (a "major rivers" dataset), not partial coverage of the full ~106-river target list. No more recoverable via better matching.
- **Real bug found and fixed**: the shapefile has 3 duplicate `rivname`s (Banas, Wainganga, Sharavati — each has 2 unrelated/mismatched features under the same name). The old matcher's `Map.set()` silently kept whichever came last in iteration order. Wainganga happened to land on the correct feature by luck; **Sharavati did not** — it had already shipped in Step 8's output as 38.2km (a misclassified fragment under Netravati's sub-basin) instead of the real ~134km river, which is exactly why it showed up in Step 8's discrepancy list. Fixed by grouping candidates per name and picking explicitly via a `DISAMBIGUATE` config (keyed on `ba_name`/`sub_basin`); an unhandled duplicate now throws instead of guessing.
- `processRiversShapefile.js` also now skips the mapshaper conversion if `build/rivers-govt-raw.geojson` already exists, so re-running it doesn't require the original `.shp` files to still be present.
- Re-ran `reconcileGovtMetadata.js` with the corrected data: 60 → 63 govt-matched rivers, 46 → 43 still needing geometry, Sharavati's discrepancy resolved.
- Tested end-to-end on a clean checkout (with your uploaded raw geojson dropped into `build/`), twice for idempotency, output validated (106 unique IDs, correct Sharavati/Wainganga/Banas values).

### Step 8 — Govt/HydroRIVERS metadata reconciled into rivers-index research (delivered as `step8-patch.sh`)
- `scripts/reconcileGovtMetadata.js` — merges `build/rivers-govt-metadata.json` (Step 5c/6, 61 entries) into `research/rivers-index-draft.json` (107 entries), overriding `length_km_india` (only when not a multi-part/braided-channel sum, `needs_verification:false`) and `stream_order` (always, when present) — both are govt/HydroRIVERS-authoritative per §4.8. `basin`/`sub_basin`/`origin_description` from the govt file aren't applied — they don't map onto `RiverIndexEntry` schema fields, only onto the manually-authored `rivers/{id}.json` detail files (Phase 2, out of scope here).
- Output: `research/rivers-index-reconciled.json` (106 entries). `rivers-index-draft.json` untouched, kept as historical record.
- **Findings, all applied automatically by the script (see comments in `reconcileGovtMetadata.js` for the reasoning)**:
  - 3 of the govt shapefile's 61 matches used a different name spelling than the draft (`Ghaghra`→`Ghaghra (Karnali)`, `Kali`→`Kali (Karnataka)` — confirmed via govt `basin` field, `Ghaggar`→`Ghaggar-Hakra`) — the original exact-string matcher in `processRiversShapefile.js` doesn't alias these, so these 3 rivers' govt data was sitting unused until this step.
  - **Purna false positive**: the govt shapefile's only "Purna" feature is the Godavari-tributary one, not the Tapi-tributary one the spec's grouping implies. Excluded — see updated open items above.
  - **Kopili/Kapili**: resolved as duplicate, `kapili` dropped. 107 → 106 total rivers.
  - 60 of 106 entries got `stream_order` and/or `length_km_india` overridden with govt data; 8 of those have a >20% length discrepancy vs. web research (govt value used, listed above).
- Tested end-to-end on a clean checkout — idempotent (`git status --short` after 2 runs matches after 1), output validated (106 unique IDs, draft file untouched).

### Step 6 v2 — HydroRIVERS join, performance bug fixed
**v1 bug**: matched HydroRIVERS reaches onto named rivers via a linear per-candidate `pointToLineDistance` check with only a bbox pre-filter. Worked fine on a 90-reach synthetic test. At the real scale of India's bbox — **503,929 reaches**, an order of magnitude more than I'd estimated — this hung for 5+ hours with no progress output and no crash. My synthetic test never exercised anything close to real scale, which is exactly the gap that let this ship broken.

**Fix**: rewrote the matching as (1) a grid spatial index over reach midpoints (~2.2km cells, built once), (2) each named river's geometry resampled into regularly-spaced points (every 0.5km, independent of source vertex density) rather than checking against raw geometry, (3) for each sample point, only the 3×3 nearby grid cells are checked (a handful of candidates) instead of the full bbox-filtered set, with a real haversine distance for the final decision. Also added per-river progress logging with timing, so a genuine hang would be visible immediately instead of silent.

**Verified before shipping**: generated a 503,929-reach synthetic fixture matching HydroRIVERS' real density (uniform random scatter across the India bbox — if anything harder on the grid index than real river-clustered data), ran the actual patch script against it end-to-end on a clean checkout — 28-32 seconds, all 61 rivers matched, correctness re-confirmed against the smaller Chenab-based fixture from v1 (same results: order 13, ~103 reaches matched).

**Confirmed on real HydroRIVERS data**: 24.5s total, 61/61 rivers matched, no zero-match rivers — the stress test predicted real performance accurately.

### Step 5c — Government rivers shapefile processed (delivered as `step5c-patch.sh`)
*(Steps 5a/5b were an Overpass-first attempt — 406 then 504 errors, see git history in this file's earlier revisions if needed. Superseded once you found the data.gov.in shapefile; not worth carrying forward as separate log entries.)*
- Source: `data.gov.in` "Rivers" shapefile (you uploaded it directly — `Rivers.shp/.dbf/.shx/.prj/.cpg/.sbn/.sbx`)
- `scripts/processRiversShapefile.js` — converts via Mapshaper (WGS84 reprojection), matches the shapefile's 110 features against spec's 105-river list (handling spelling variants: Satluj→Sutlej, Gomati→Gomti, Ghaghara→Ghaghra, Sone→Son, Pranhitha→Pranhita, Cauvery→Kaveri, Kalinadi→Kali, Ghagghar→Ghaggar, etc.)
- **61/105 matched** with real geometry + government-sourced `basin`/`sub_basin`/`origin` text; **44 unmatched** (mostly smaller Western Ghats and Northeast tributaries not in this dataset — still need Overpass)
- **Length caveat**: 38 of 110 source features are `MultiLineString` (delta/braided channels digitized as separate parts, e.g. Ganga, Brahmaputra, Godavari, Yamuna, Krishna). The shapefile's `shape_Leng` field sums every part, inflating the figure well past commonly-cited lengths (this file's Ganga = 3096 km vs. the ~2525 km usually cited). `length_km_india` is only auto-filled for single-part rivers (29 of the 61 matched); the other 32 are left `null` with `needs_verification: true` rather than shipping an inflated number as fact.
- Outputs: `build/rivers-govt-matched.geojson` (61 features, canonical names), `build/rivers-govt-metadata.json` (partial rivers-index.json seed), `build/rivers-govt-report.json` (full matched/unmatched/needs-verification breakdown)
- **Gotcha hit and fixed**: `pnpm add -D mapshaper` exits with code 1 on first install (pnpm 11's supply-chain policy blocks native builds for `better-sqlite3`/`msgpackr-extract` by default) — same class of issue as Step 1's esbuild/sharp. Patch script now runs `pnpm approve-builds` right after, non-interactively.
- Verified end-to-end on a clean checkout of your actual repo (via GitHub), not just the dev sandbox
- Not started: full mainstem-length correction for the 32 flagged rivers (would need real longest-path extraction from the multi-part geometry, or a second source)

---

## Completed steps log

### Step 4 — State/UT metadata enrichment (delivered as `step4-patch.sh`)
- `scripts/enrichStates.js` — enriches all 36 features (28 states + 8 UTs) with `id`, `name`, `admin_type`, `capital`; validates each via the `State` zod schema
- Outputs `public/geojson/india-states.geojson` (geometry + minimal properties) and `public/data/states.json` (metadata only — mirrors the PA data's geometry/metadata split)
- Verified on a clean checkout with Steps 1-3 already applied — same 28/8 split both times, `pnpm build` still succeeds

**Source data finding:** `scripts/source-data/india-states.geojson` in ecoguesser is **already simplified** (Visvalingam, 200m interval, keep-shapes, 0.0001° precision — same method/tolerance as the PA boundaries). No Mapshaper invocation was needed for this step at all — it's pure JS, so Windows/Git Bash has zero friction here.

**Deviation from spec**: `rivers_flowing_through`, `basin_rivers`, `notable_city_ids`, `protected_area_ids` are left as empty arrays — these depend on the rivers pipeline and `spatialIntersect.js`/`deriveStateCrossRefs.js` (steps ⑥-⑧, ⑪, ⑫), none of which exist yet. Validated as empty arrays against the `State` schema (which allows this), not skipped.

**Capital list**: used the commonly-accepted single capital per state/UT (e.g. Jammu & Kashmir → Srinagar, its summer/main seat; Uttarakhand → Dehradun, the de facto seat over the designated-but-unused Gairsain). Worth a manual sanity check if precision on any specific one matters for your use case — this table isn't sourced from the ecoguesser repo, it's a static reference table I wrote.

**Note:** ecoguesser also has a documented topojson conversion for this same file (`convertStatesTopo.js`) that roughly halves gzip size (~216KB vs 333KB gzip) by deduplicating shared state borders — with well-documented reasoning for why they explicitly avoid mapshaper's auto-quantization (it silently produced an invalid/self-intersecting Andaman & Nicobar polygon). Not adopted here — spec's folder layout (`public/geojson/`) reads as plain GeoJSON, and adding topojson would mean a new client-side decode dependency not yet confirmed against the actual spec text. Worth revisiting as a size optimization later if needed — the exact reasoning/command is preserved in ecoguesser's script if we do.

### Step 1 — Project scaffold
- Astro v6.4.8 (pinned — spec targets v6, registry default is now v7) initialized manually with `pnpm init`, not `create-astro`, for exact version control
- Runtime deps: preact, @astrojs/preact@**5.1.5** (not 6.0.1 — see Decisions), maplibre-gl, pmtiles, nanostores, @nanostores/preact, fuse.js, virtua, @fontsource/sora, @fontsource/inter, tailwindcss@4 + @tailwindcss/vite@4
- Dev deps: zod@3 (build-time validation)
- `astro.config.mjs` (static output, Preact integration, Tailwind v4 Vite plugin), `tsconfig.json` (strict)
- Full folder skeleton per spec §5.2
- `pnpm build` and `pnpm dev` both verified working
- Git repo initialized

**Decisions/gotchas:**
- `@astrojs/preact@6.0.1` pulls in Vite 8 (rolldown, experimental) via `@preact/preset-vite`, which breaks `@tailwindcss/vite@4.3.3` (`Missing field tsconfigPaths` build error). Downgraded to `@astrojs/preact@5.1.5`, which targets Vite 7 — matches Astro 6's own `vite: ^7.3.2` requirement.
- Also had to add `vite@^7.3.2` as an **explicit devDependency** — without it, pnpm's peer resolution let a second Vite 8 sneak in via `@tailwindcss/vite`'s peer range (`^5||^6||^7||^8`), causing "Found 2 versions of vite." Pinning collapses everything onto one Vite 7 instance.
- zod v3, not v4 — spec's `.refine()` patterns are written against v3.

**Pinned versions:** astro 6.4.8 · @astrojs/preact 5.1.5 · preact 10.29.7 · vite 7.3.6 · maplibre-gl 5.24.0 · pmtiles 4.4.1 · tailwindcss/@tailwindcss/vite 4.3.3 · nanostores 1.4.1 · @nanostores/preact 1.1.0 · fuse.js 7.5.0 · virtua 0.44.3 · zod 3.25.76

### Step 2 — Protected Areas data pipeline (delivered as `step2-patch.sh`)
- `scripts/schemas.js` — Zod schemas per spec §4.1-4.4
- `scripts/ensureProperties.js` — canonicalizes all 837 raw ecoguesser IDs, injects `{name, category, area_km2}` into boundary file properties
- `scripts/mergeFeatures.js` — merges 835 boundary files, assigns sequential numeric Feature IDs, computes `bounds` via Turf `bbox()`, validates, writes `public/data/protected-areas.json` (837 records) + `public/data/pa-id-map.json`
- Verified on a clean checkout, not just the dev sandbox

**Data source findings:**
- ecoguesser's PA data is already at spec step ②'s output stage: 837 metadata records + 835 boundary GeoJSONs (2 fewer — boundary-less TRs, matches spec exactly). Filenames match metadata IDs 1:1, no fuzzy matching needed.
- **Deviation**: canonical IDs keep a `-{category}` suffix (`nameri-np` / `nameri-tr`) instead of spec's bare slug — 3 real sites hold two designations each (Keoladeo Ghana = NP+Ramsar, Nameri = NP+TR, Pilibhit = WLS+TR) and bare slugs collide. Verified unique across all 837.
- **Deviation**: `area_km2` relaxed to `.nonnegative()` — 10 real records (small island/urban sanctuaries) have unrecorded area = 0.
- Fields absent from source, defaulted (spec calls most Phase 2/curated anyway): `year_established`, `iucn_status`, `biome_type` → `null`; `endemic_species`, `aliases` → `[]`; `upsc_relevant` → `false`. `wikipedia_url` auto-derived from name.
- ecoguesser also has `india-boundary.geojson`, `scripts/source-data/india-states.geojson`, working `simplifyBoundaries.js`/`convertStatesTopo.js` — reusable for Step 4 (state boundaries).
- ecoguesser has **no river data** at all.

**Pinned versions:** @turf/turf 7.3.5 (devDependency)

### Step 3 — protected-areas.pmtiles (delivered as a binary file, not a patch script)
- Installed tippecanoe 2.49.0 in sandbox (unavailable on native Windows)
- Built `public/tiles/protected-areas.pmtiles` from `build/pa-merged.geojson` using spec §4.7 step ⑤'s command verbatim
- Verified via the `pmtiles` JS library: minZoom 4 / maxZoom 14, source-layer `protected-areas`, `id`+`category` fields present, bounds match India's extent, **8.68 MB** (well under Cloudflare's 25 MiB limit — no R2 offload needed)
- **Action needed**: place the delivered file at `public/tiles/protected-areas.pmtiles` in your project (overwrites the empty placeholder from Step 1)

