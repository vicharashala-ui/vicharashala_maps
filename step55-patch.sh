#!/usr/bin/env bash
# Step 55 patch — adds bagmati, tamiraparani, vaitarna rivers (91 total).
# Idempotent: safe to re-run. Run from repo root. Also copies rivers.pmtiles
# from this script's own directory (must be colocated) into public/tiles/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat > 'PROGRESS.md' << 'VMAPS_PATCH_EOF'
# Vicharashala Maps — Progress

Free static interactive atlas of India's rivers + protected areas. Deploys to Cloudflare Pages (`vicharashalamaps.pages.dev`). Spec: `Spec_file.md` (numbered §, e.g. §3.6, §4.1, §11.2 — cite these when referencing requirements). Repo: `https://github.com/vicharashala-ui/vicharashala_maps.git`. Reference repo (PA/state source data): `https://github.com/vicharashala-ui/ecoguesser.git`.

**Lakes and Dams are fully out of scope** (not deferred). AdSense is Phase 4 (post-V1).

## Resume checklist
1. Clone repo fresh. Read this file's "Status" + "Next step" below (skip the step log unless you need historical reasoning for a specific decision).
2. `pnpm install` (lockfile pins exact versions — restores exact, not latest).
3. `pnpm build` to confirm clean baseline before changing anything.
4. Implement the next step against actual repo state, not just this file's note of it.
5. Verify: `pnpm exec astro check` (must be 0 errors) **and** `pnpm build` (must be clean) — `astro check` catches type bugs `build` misses; `build` catches runtime/SSR bugs `check` misses (e.g. `location` used outside `useEffect`). Run both, every time.
6. Ship as `stepN-patch.sh`: idempotent, tested against a **fresh** `git clone` (not just the working sandbox), byte-identical output on a second run (md5 diff), includes `pnpm install`+`pnpm build` as its own verification.
7. Append a short entry to the step log below (2-6 lines: what shipped, any real bug found + fix, what's deliberately deferred). Don't narrate routine verification — only log genuine findings, deviations, or judgment calls.
8. Copy the patch script + this updated file to `/mnt/user-data/outputs/`.

## Environment
Native Windows, Git Bash (no WSL, no Python — `python3` resolves to a broken MS Store alias). pnpm. Ashwin reviews/applies patches; doesn't author code directly. Communicates tersely ("next", "continue") — track state yourself from this file + the repo, flag dead-ends honestly, execute autonomously.

## Stack & pinned versions
Astro 6.4.8 · @astrojs/preact 5.1.5 (NOT 6.0.1 — pulls Vite 8/rolldown, breaks Tailwind v4 plugin) · preact 10.29.7 · vite 7.3.6 (explicit devDependency, or a second Vite 8 sneaks in via peer resolution) · maplibre-gl 5.24.0 · pmtiles 4.4.1 · tailwindcss/@tailwindcss/vite 4.3.3 · nanostores 1.4.1 · fuse.js 7.5.0 · zod 3.25.76 (v3, not v4 — schemas use `.refine()`) · @turf/turf 7.3.5 (devDep) · @astrojs/sitemap 3.7.3 · rehype-external-links 3.0.0. `virtua` sits unused in package.json (see gotchas).

## Status: V1 functionally complete through Step 49 — spec build-out is done. Steps 50-53 are post-V1 map polish (Ashwin-requested); Steps 54-55 extend river coverage beyond V1's 85.
- **Data pipeline**: 91/~105 `rivers/{id}.json` authored + validated (85 original + 6 via `hydrorivers-tracer`: spiti, burhi-gandak, jhelum, bagmati, tamiraparani, vaitarna). `basins.json` (37), `states.json` (36), `cities.json` (14), `protected-areas.json` (837) all complete. Cross-refs (`protected_area_ids`, `rivers_flowing_through`, etc.) derived and merged. Search indexes built (127 primary docs). `rivers.pmtiles` (13.5MB, 91 features) + `protected-areas.pmtiles` (8.68MB) built.
- **Frontend**: full interactive map (§3.1-3.13 — layers, selection panels for river/PA/state, filters, browse/list mode, global search, comparison mode, River of the Day, URL state) all built. Header/Footer, About/Privacy/Terms/404, blog (5 seed posts), static `/river/[id]` ×85, `/state/[id]` ×36, `/basin/[id]` ×35 pages — **168 total static routes**. Full SEO (§8): sitemap, robots.txt, favicon, canonical/OG/Twitter meta + JSON-LD on every page, `og-image.png`. `public/_headers` (§11.2: CSP + caching) shipped Step 48. Font preload + Cloudflare preconnect (§11.3) shipped Step 49.
- **Everything buildable by Claude is done.** Only 2 items remain, both requiring Ashwin's own action (see Next step) — nothing left to code.
- **Deliberately out of scope for V1** (Phase 2/4 per spec, not gaps): River filter Origin/Seasonality/Length-range/Navigability; PA filter Area/Year-range; PA comparison in Compare mode; AdSense; `wikipedia_url`/image enrichment.

## Architecture — key facts
- **Zero-fetch core data**: `rivers-index.json`, `states.json`, `basins.json`, `cities.json` are inlined into `index.astro` as `<script type="application/json">` (§5.3) — read via `dataStore.ts` lookups, no network round-trip on first paint.
- **Lazy-fetched**: `protected-areas.json` + `pa-id-map.json` + `search-index-pa.json` all load together via `loadPAData()` (promise-memoized) on first PA layer activation / Browse-PA-tab / `?pa=` deep link. Per-river `rivers/{id}.json` detail loads via `loadRiverDetail()` (same promise-memo pattern, keyed per river) — used by Compare mode and `RiverDetailPanel`.
- **NanoStores** (`mapStore.ts`): `selectedRiverId`/`selectedPAId`/`selectedStateId`/`activePanel`/`browseOpen`/`browseTab`. `filterStore.ts`: `riverFilters`/`paFilters` + a computed `matchingRiverIds` (recomputes only when filters change, since `riversIndex` is static).
- **Selection vs. filtering are deliberately separate map mechanisms** (spec warns against conflating them): selection highlighting = MapLibre `feature-state`; filter panels = `setFilter`. Don't merge these.
- **URL state** (`urlState.ts`, §3.13): 3 independent concerns, each with its own debounce timer, never sharing logic — selection (`river`/`pa`/`state`, mutually exclusive, `debouncedUpdateUrl`), filters (`debouncedUpdateFilterUrl`), compare (`r1`/`r2`/`r3`, no debounce — discrete clicks not fast input). Always `history.replaceState`, never `pushState`.
- **Virtualization**: hand-rolled `useWindowedList.ts` (~35 lines: scroll pos + ResizeObserver → visible range + translateY spacer). `virtua` doesn't work here — see gotchas.
- **A11y**: `useFocusOnOpen.ts` — every slide-in panel (River/PA/State/Browse) moves focus in on open, restores on close.
- **Theming**: `themeInit.raw.ts` — the site's *only* first-party inline executable script (FOUC-prevention, reads `localStorage`, sets `data-theme` before paint). Its trimmed-content SHA-256 hash is baked into `public/_headers`' CSP `script-src`; if this file's content ever changes, recompute the hash (command is in `_headers`' step-48 patch script) or the CSP silently breaks the site. Rendered everywhere via `set:html={themeInit.trim()}` — the `.trim()` must match exactly what was hashed.
- **Each page duplicates its own minimal `<head>` boilerplate** rather than a shared layout (established Step 43) — so any `<head>`-level change (meta, preload links) touches every page file individually, not one place.

## Key learnings / gotchas (still relevant)
- **`virtua` is incompatible with this toolchain, confirmed not assumed.** Tailwind v4's Vite plugin does a raw Node ESM resolution of `virtua`'s bare `react` import during static prerender, bypassing Vite's `preact/compat` alias entirely (this project has no `react`/`react-dom` installed). Left in `package.json` in case a future tooling bump fixes it, but nothing imports it — use `useWindowedList.ts` instead.
- **`astro check` and `pnpm build` catch different bugs — always run both.** Real examples: wrong `Record` type shape and missing `jsxImportSource` (caught only by `check`); a `location`-in-initializer crash on `/compare`'s prerender, and a missing-newline in a generated file (caught only by `build`/byte-diff, not `check`).
- **SSR/prerender guard**: any browser API (`location`, etc.) used in a component's initial render must be deferred to `useEffect` behind a `hydrated` flag, or static prerender crashes.
- **Windows path safety**: always `node:path` (`path.join`/`dirname`), never manual string-slicing on separators.
- **Pin exact lockfile versions when mocking a library's output shape.** `osmtogeojson@2.2.12` (this project's pinned version) nests tags under `properties.tags.name`; a fresh `npm install` resolves a newer version that flattens them — caused a real false-passing-test bug during the data pipeline.
- **Scale-test before handoff.** A HydroRIVERS join script worked at 90 synthetic records, hung 5+ hours at the real 503,929-reach scale (linear per-candidate distance check). Fixed with a grid spatial index. Lesson: synthetic tests must match real order-of-magnitude, not just "some" data.
- **Patch scripts must be idempotent and clone-tested.** Every shipped `stepN-patch.sh` was run twice on a fresh clone; second run must be a byte-identical no-op.
- **`feature-state` for selection highlighting, `setFilter` for visibility filtering** — spec explicitly warns against conflating these (see Architecture above).

## Known data caveats (flagged during authoring, not silently resolved)
- **~13 rivers from spec §4.9's list remain unmatched/flagged and NOT shipped**: Dhansiri, Rushikulya, Purna, Girna, plus others from Step 16's flagged list — genuine OSM/govt-shapefile coverage gap. Burhi Gandak and Vaitarna, both originally on this list, shipped via `hydrorivers-tracer` (Steps 54/55); Dhansiri was attempted the same way twice and rejected (see Step 55) — still needs manual digitizing.
- **Length discrepancies >20%** between web research and the govt-shapefile value that actually shipped: Chenab (700→431km), Barak (524→100km, India-only digitized segment — `length_km_total` field has the fuller 900km figure), Subarnarekha (395→480km), Vaigai (258→312km), Bharathapuzha (209→100km), Kali/Karnataka (265→179km), Vaippar (130→87km).
- **Basin-area index/detail-file mismatches** (index ships `null` for `basin_area_india_km2` but a solid total exists, so only `basin_area_total_km2` is filled in the detail file): Indravati, Musi, Hemavathi. Candidates for a future `rivers-index.json` correction.
- **Sharavati basin area is a judgment call**, sources disagree 2,771–3,600 km²; shipped 3,042 km² (IISc) as closest to consensus.
- **Still `null` on both basin-area fields** (no reliable single-river figure found, sources disagree by up to 2x, often conflating shared-estuary catchments): kallada, sharavati (india field only), zuari, mandovi, kali-karnataka, aghanashini, ponnaiyar; also several Ganga/Brahmaputra tributaries (Banas, Parbati, Son, Gomti, Sarda, Gandak, Mahananda, Lohit, Subansiri, Manas, Teesta, Rangeet, Torsa, Jaldhaka) and Pranhita/Wainganga/Wardha.
- **Naming coincidences, verified real not bugs** — flagged in each river's `did_you_know` so they aren't "corrected" later: Zuari's alias "Aghanashini" (a real historical Goa name, coincidentally identical to the unrelated Karnataka river Aghanashini in the same dataset); Vellar's index label "(Southern)" vs. Wikipedia's "(Northern Tamil Nadu)" for what's verified to be the same river.
- **`sink.type` schema only allows `sea|river|lake`** — doesn't fit endorheic terminations. Luni (Rann of Kutch salt flats) and Ghaggar-Hakra (dissipates in Cholistan desert, Pakistan) both use `"lake"` as the closest available value; `sink.name`/`sink.location` describe the real terminus accurately. Worth adding an `endorheic` enum value if more inland-draining rivers are ever added.
- **Barak ships under `basin: "brahmaputra-basin"`** (matches spec §4.9's grouping) despite never physically joining the Brahmaputra — it exits via Bangladesh as the Surma/Kushiyara toward the Meghna. `type: "main"` reflects this; don't let the frontend imply a direct confluence.
- **`protected-areas.json`'s `state` field is Title Case with `&`** (`"Jammu & Kashmir"`), unlike every other dataset's slug format — normalized (`&`→`and`) only inside `deriveStateCrossRefs.js`. `PAInfoPanel`'s state text is still **not** a clickable chip back to `StatePanel` (would need the same name→id resolution) — flagged, not blocking.
- **4 states/UTs have no `rivers_flowing_through`** (Andaman & Nicobar, Chandigarh, Lakshadweep, Tripura) — genuinely outside the 85-river scope, not a bug.

## Workflow / conventions
- Marker-string guards for surgical Node-scripted edits to existing files; full heredoc overwrites for new files (naturally idempotent).
- Patch scripts are programmatically generated to avoid quoting errors.
- "Verified" in a step log entry means: schema validation, cross-reference resolution against real shipped IDs, and a byte-identical fresh-clone + second-run test — not just "should work."
- Flag genuine dead-ends / judgment calls / data conflicts explicitly rather than silently picking one option or padding out speculative fixes.

## Next step
**Extending river coverage beyond the original 85** (spec §4.9 lists ~105; 22 were missing). Of those 22: **spiti, burhi-gandak, jhelum** (Step 54), **bagmati, tamiraparani, vaitarna** (Step 55) shipped — 91/~105 total. **13 remain** — mechi, kamla, dibang, sankosh, kapili, rushikulya, chaliyar, purna, girna, savitri, vashisthi, gurupur, swarnamukhi, manimuktha (not yet researched/traced), plus **rupnarayan** and **dhansiri** (both traced but rejected — see Step 54/55's HydroRIVERS caveats below, need manual/OSM sourcing instead). Continue with `scripts/hydrorivers-tracer/` following the same batch pattern (research waypoint+mouth coords → trace → sanity-check length/order against a literature reference → author `rivers/{id}.json` → re-extract+rebuild `rivers.pmtiles` at full maxzoom fidelity via `scripts/rebuildRiversPmtiles.mjs`, not `extractRiversFromPmtiles.mjs`'s lossy z11 probe). Note `scripts/rebuildRiversPmtiles.mjs` currently hardcodes the 3 Step-55 river ids to append — generalize this before the next batch (parameterize the new-ids list, or diff `rivers-index.json` against `rivers-id-map.json`'s keys).

Separately, two Ashwin-side items are still open from V1 completion (not blocking the above): Search Console verification file; enabling Cloudflare Web Analytics in the dashboard. And a browser/visual QA pass is still owed once there's a natural pause (sandbox has no display).

---

## Step log (condensed — full narrative detail for older steps is in git history / prior PROGRESS.md revisions if ever needed)

- **55** — 3 more rivers via `hydrorivers-tracer`: **bagmati, tamiraparani, vaitarna** (91 total). **Bagmati** is transnational (source at Bāghdwār spring, Shivapuri Hills, Nepal) — traced full source-to-mouth through the network (which spans Nepal too, since the clip bbox is a rectangle not a country boundary), then clipped to the India-only portion by walking the traced line backward from the mouth and cutting at the first point outside `india-outline.geojson` (new helper logic, not yet promoted to a shared script — see gotcha below). 201.5km India-portion, in line with typical cited ranges. **Tamiraparani** (135.1km vs ~128km cited) and **Vaitarna** (149.2km vs ~154km cited) were both single-country traces, no clipping needed. Two new basin entries added to `basins.json` (`tamiraparani-basin`, `vaitarna-basin`, neither river fit an existing basin) — `area_km2` sourced from a govt-affiliated study for Tamiraparani (sources disagreed 4,367–5,869 km², used the middle/govt figure 5,717) and a peer-reviewed hydrology paper for Vaitarna (3,795 km², single consistent source). All 37 basins' `area_rank` recomputed by re-sorting on `area_km2`; existing basins' colors left untouched (schema only requires per-basin contrast ≥3:1, not rank-ordered hue), new basins given contrast-verified colors reused from the existing palette family. `deriveStateCrossRefs.js` re-run clean (Bihar/Tamil Nadu/Maharashtra all picked up their new river). **`dhansiri` traced twice and rejected** — both attempts (waypoint at Golaghat, then at Dimapur) came in 26-35% short of the ~352km cited length and passed 14-32km from Dimapur, a city the river should run directly through; strong signal the upstream max-catchment climb is branching onto the Doyang tributary (reportedly larger-catchment) at their confluence instead of continuing up Dhansiri's own channel — same class of tributary/confluence ambiguity as Rupnarayan (Step 54), needs manual/OSM sourcing. `rivers.pmtiles` rebuilt via new `scripts/rebuildRiversPmtiles.mjs` (formalizes Step 54's ad-hoc per-river bbox-scoped z14 re-extraction into a real script): re-extracts each of the 88 pre-existing rivers by scanning only its own bbox (from `rivers-index.json`) at full maxzoom, rather than a whole-India z14 grid (~1.4M tiles — intractable; per-river bboxing keeps each scan small); verified all 88 numeric feature ids (`rivers-id-map.json`) came out byte-identical via a direct old-vs-new key comparison (not just spot-checked), new rivers appended as ids 89/90/91. 13.5MB, still under Cloudflare's 25MiB limit. **Gotcha for next batch**: `rebuildRiversPmtiles.mjs` currently hardcodes the Step-55 new-river-id list and reads each new river's shipped geometry from a `/tmp/{id}.json` trace-output file (this session's scratch location, not committed) — needs generalizing (parameterize ids, and have the tracer write its output straight to a stable `build/` path) before reuse. Verified via `astro check` (0 errors) + `pnpm build` (176 pages) + zod-validated every touched file (`RiverDetail`×3, `RiverIndexEntry`×91, `Basin`×37, `State`×36) + cross-checked `rivers-index.json`'s numeric/boolean fields against each new `rivers/{id}.json` (0 mismatches) + fresh-clone byte-identical idempotent second-run. **13 rivers from the original gap list remain** — see "Next step."
- **54** — First 3 rivers added beyond the original 85 (spec §4.9's ~105-river list has 22 gaps; this closes 3 of them): **spiti, burhi-gandak, jhelum**. New **`scripts/hydrorivers-tracer/`** pipeline: since OSM/govt-shapefile sourcing (the original 85's method) had no name-matched geometry for these, traces a named river through HydroRIVERS' 503,929-reach network directly. HydroRIVERS carries no river names, so isolating one river's course needs anchoring on a real-world reference point — but neither the obvious choice works cleanly: a literal source coordinate is ambiguous near a headwater divide (two valleys can share a mountain pass — Spiti's Kunzum Pass source snapped onto the neighbouring Chandra/Chenab-bound valley on the first attempt, tracing 1700km down the wrong system entirely), and a literal confluence point is ambiguous for a tributary (the larger river being joined always has more upstream catchment area, so naive max-catchment branch selection at a fork follows the big river, not the tributary — caught on Burhi Gandak's first attempt). Fix: anchor on an unambiguous **mid-river waypoint** (a town clearly on the channel, away from both problem spots), walk downstream to the mouth and upstream via max-catchment-area branch selection to the headwater — no ambiguous branch decision needed at either end. Two more real bugs found+fixed en route: a `Map` keyed by numeric `NEXT_DOWN` values queried with string reach ids (silently returned "no upstream" for every climb — Burhi Gandak's first successful-looking trace was actually missing its entire upper course); and the downstream walk overshooting a confluence by exactly one reach onto the joined river's own channel before the distance-tolerance check caught it (Burhi Gandak's `next` reach at Khagaria was already on the Ganga, upland 812,416 km² vs. its own ~13,000 km² — inflated length and Strahler order until fixed with a catchment-jump detector: >3x and >500 km² single-step jump = confluence, stop before crossing). All three shipped rivers sanity-checked against literature (spiti 182km vs ~200km cited; burhi-gandak 441km vs 320-400km cited, sources vary; jhelum 228km India-portion, Verinag→LoC near Uri) and against their own bbox (no stray jumps to an unrelated basin). **`rupnarayan` traced but rejected** — its confluence sits in the Hooghly/Damodar tidal delta where multiple major rivers physically commingle; even the largest nearby reach dead-ends (`next=0`) with an implausible 37,785 km² catchment (its real basin is ~10,000 km², so that reach is actually merged tidal-creek data, not Rupnarayan's own channel) — a genuine HydroRIVERS limitation in this terrain type (matches the existing "flat/deltaic terrain" gotcha for the original 85), not a bug to chase further; flagged for manual/OSM sourcing like the original project's own deferred-rivers precedent. `rivers.pmtiles` rebuilt via a **lossless per-river bbox-scoped re-extraction at full maxzoom (z14)** — not `extractRiversFromPmtiles.mjs`'s existing whole-India z11 brute-force probe, which would have visibly downgraded the existing 85 rivers' line fidelity; verified all 85 pre-existing numeric feature ids (`rivers-id-map.json`) came out byte-identical, only the 3 new rivers got fresh ids. 12.6MB, still well under Cloudflare's 25MiB limit. `length_km_india` set to each river's **measured traced-geometry length** (not a quoted reference figure) — confirmed this matches the established convention for the original 85 (their lengths are OSM-way-sum measurements too, not Wikipedia citations), so a river's displayed stat and its rendered map line always agree. Verified via `astro check` (0 errors) + `pnpm build` (171 pages) + fresh-clone byte-identical idempotent second-run (md5, both the 3 new river files and the regenerated `rivers-id-map.json`/`rivers-index.json`). **19 rivers from the original 22-gap list remain** — see "Next step."
- **53** — Two Ashwin-requested fixes. **State Borders toggle:** new `stateBordersVisible` atom (`mapStore.ts`, default `false`, same off-by-default precedent as `paLayerVisible`) + new sibling component `StateBordersLayer.tsx` (matches the `RiversLayer`/`ProtectedAreasLayer`/`StateHighlightLayer` pattern — subscribes, sets `visibility` layout on the existing `state-borders` line layer, unsubscribes on cleanup) + a checkbox row in `LayerControl.tsx`. The `state-borders` layer itself now gets `layout: { visibility: 'none' }` at creation (not just left to the subscription) to avoid a one-frame flash of visible-then-hidden borders on load. `india-border` (national outline) and `land-fill` (invisible state click/hit-test target) are untouched — toggle only governs the internal state-boundary lines, not the country outline or state-click-to-select, which both stay functional/visible regardless. **Dark-mode popup contrast:** the river-hover tooltip (`RiversLayer.tsx`'s `maplibregl.Popup`) was unreadable in dark mode — MapLibre's default `.maplibregl-popup-content` CSS hardcodes a white background but sets no text color of its own, so it inherited `body`'s `color`, which is the light dark-mode text color, landing near-white-on-white. Fixed by pinning both `background` and `color` (plus the popup-tip arrow's border-color per anchor side) to the theme's `--color-surface`/`--color-text` vars in `global.css`, so it's legible in both themes and repaints correctly if the vars change. No other `Popup` instances exist in the codebase (checked) so this is a single, complete fix. Verified via `astro check` (0 errors) + `pnpm build` (168 pages) + fresh-clone byte-identical + idempotent second-run diff — no visual check possible in this sandbox, confirm the toggle's on/off states and popup legibility in both themes in a real browser.
- **52** — Two Ashwin-requested map changes, from ecoguesser's `config.js` (uploaded, not in this repo). **Basemap swapped to OFM Liberty:** `BASEMAP_STYLE` is now the single `https://tiles.openfreemap.org/styles/liberty` URL, replacing the Positron/Dark pair from Step 50/51 — explicit request, reverses Step 50's evaluate-and-reject decision on Liberty. Liberty has no dark counterpart on OpenFreeMap (only Positron/Bright/Liberty/Dark/Fiord exist, confirmed against the live style list), so the theme toggle no longer affects basemap tiles, only site UI chrome — `isDarkTheme()` import/call removed from `MapView.tsx` (still used elsewhere, e.g. `RiverDetailPanel.tsx`'s basin color pick, so the export itself wasn't touched). Verified Step 51's `removeTransportLayers()` still works unchanged: fetched Liberty's live style JSON and confirmed it uses the same OpenMapTiles `source-layer` names (`transportation`/`transportation_name`/`aeroway`/`aerodrome_label`) as Positron/Dark, since source-layer (not layer id) is what that function matches on. Liberty's extra detail vs. Positron (3D buildings, general POI icons) was left alone — out of scope, only asked to swap the basemap and match bounds, not further declutter. **Bounds matched to ecoguesser:** `INDIA_BOUNDS`'s north edge corrected `37.6` → `37.1` to exactly match ecoguesser's `MAP_CONFIG.INDIA_BOUNDS` — this repo had it duplicated in both `MapView.tsx` (initial `bounds`) and `MapControls.tsx` (reset-button `fitBounds`, ecoguesser's `RecenterButton.jsx` equivalent), both updated to stay in sync (no shared constant introduced — surgical fix, not a refactor). Also added a `maxBounds` pan limit to the `Map` constructor matching ecoguesser's `MAP_CONFIG.MAX_BOUNDS` (`[[45,-18],[112,52]]`), which this repo didn't have at all before — same subcontinent-scale pan constraint both apps now share. Verified via `astro check` (0 errors) + `pnpm build` (168 pages) + fresh-clone byte-identical + idempotent second-run diff — no visual check possible in this sandbox, confirm Liberty's look and the tightened north bound (Kashmir/Ladakh framing) in a real browser.
- **51** — Two Ashwin-requested map changes, both in existing files (`MapView.tsx`/`ProtectedAreasLayer.tsx`). **Basemap decluttering:** `removeTransportLayers()` strips every basemap layer whose `source-layer` is `transportation`/`transportation_name`/`aeroway`/`aerodrome_label` (roads, railways, paths, oneway arrows, highway shields, runways/taxiways, airport labels) right after `load`. Matched by `source-layer`, not layer id — verified positron (`openmaptiles/positron-gl-style`) and dark (`dark-matter-gl-style`) are different upstream forks with different layer ids for the same content (e.g. positron's `railway_service` vs dark's `railway_minor`, dark has no `airport`/`aerodrome_label` layer at all), but both stay on the OpenMapTiles schema, so the source-layer names are stable across either — same pattern as `raiseSettlementLabelZoom` (Step 50). Water/waterway, place labels, boundaries, buildings, landcover left untouched — orientation context, not transportation. **PA selection isolation:** selecting a PA (click or info panel) now hides every other PA site instead of just highlighting the chosen one among all visible sites — `isolatedId` (set in `applySelection`) makes `applyFilters` filter every category layer down to `['==', ['get','id'], isolatedId]` and makes `setLayerVisibility` hide all boundary-less markers but the selected one; deselecting (`isolatedId = null`) re-derives the normal category/search-filter/visibility state from scratch, so no separate restore path to keep in sync. Verified via `astro check` (0 errors) + `pnpm build` (168 pages) + fresh-clone byte-identical + idempotent second-run diff — no visual/browser check possible in this sandbox, confirm the isolation and decluttered basemap look right in a real browser.
- **50** — Map polish pass (3 real fixes, 1 evaluated-and-rejected proposal, all in `RiversLayer.tsx`/`MapView.tsx`). **Found+fixed:** the `rivers-context-line` layer (a transnational river's course outside India, `extendTransnationalRivers.js`) had never been wired to any click/hover handler — MapView's original comment explicitly called it "decorative-only," so clicking a river's Pakistan/Bangladesh/Nepal/China/Myanmar reach did nothing. `RiversLayer.tsx`'s handlers are now factored into `makeMouseMoveHandler`/`makeClickHandler(propKey)` and bound to both `rivers-line` (`id` property, pmtiles) and `rivers-context-line` (`river_id` property, geojson) — same selection/popup/URL-state flow either way. **Found+fixed:** OpenFreeMap's `dark` style ships every settlement-label layer (`place_city`/`place_town`/`place_village`/`place_state`) with no `minzoom` at all, i.e. visible from zoom 0 — much more clutter than `positron`, which already gates these 5–9. Added `raiseSettlementLabelZoom()` in `MapView.tsx`: matches on `source-layer: 'place'` + a small id-pattern table (city→6, town→7, village/suburb/hamlet→8, state→5), applied at runtime via `setLayerZoomRange` so it works uniformly across both styles without forking/self-hosting either one; country labels untouched (low density, useful for orienting transnational rivers). **Evaluated: switch light basemap from Positron to OSM Liberty (OpenFreeMap's `liberty`).** Rejected — Liberty is the actively-maintained full-detail style (roads, POIs, buildings); Positron is a deliberately stripped-down fork (POIs removed, labels pushed to higher zooms) that's already the "quiet basemap for overlaying your own data" style this atlas needs, and Liberty's extra detail would compete with the rivers/PA layers rather than recede behind them. Rationale logged as a comment on `BASEMAP_STYLE` rather than switched. **Also:** `rivers-line`'s width/opacity raised at the low-zoom end (width 0.6→1.2 @ zoom 4, opacity 0.6→0.75 default / 0.7→0.85 highlighted) so rivers read clearly at the default India-wide view instead of needing to zoom in first. Verified via `astro check` (0 errors) + `pnpm build` (168 pages, clean) — no visual/browser check possible in this sandbox, so confirm the label-zoom tuning and context-river click actually look right in a real browser before calling this done.
- **49** — Font preload (`sora-latin-600`, `inter-latin-400`) + Cloudflare Analytics preconnect on all 11 page templates (§11.3). Imported the woff2 files via Vite's `?url` suffix (`@fontsource/sora/files/...woff2?url`) rather than hardcoding the fingerprinted `dist/_astro/` filename — same pattern as the existing `themeInit.raw.ts?raw` import — so the preload href always matches the actual build output with nothing to manually keep in sync (unlike the CSP hash in `_headers`, which does need manual recomputation). Verified the resolved `dist/**/index.html` hrefs point at real, existing files. New `scripts/addFontPreload.mjs`, marker-guarded per file (idempotent).
- **48** — `public/_headers` (§11.2): CSP with live-computed script hash for `themeInit.raw.ts` + caching rules for `/tiles`,`/geojson`,`/data`,`/_astro`. Patch script re-verifies the hash against the live file and aborts if stale.
- **47** — `public/og-image.png` (1200×630, built from spec's own color tokens, not stock) wired as `og:image`/`summary_large_image` on all 8 OG-carrying pages.
- **46** — Blog scaffolding: Content Layer API (`src/content.config.ts`, Zod from `astro/zod` not `astro:content`'s deprecated re-export), 5 real seed articles cross-linked to real river/blog routes, `/blog` + `/blog/[slug]`, `rehype-external-links` wired for future posts.
- **45** — `/state/[id]` (36) + `/basin/[id]` (35) static pages; cross-linked river↔state↔basin everywhere (153 internal links, 0 broken — verified via a one-off link-checker).
- **44** — SEO foundations: sitemap, robots.txt, favicon, canonical/OG/Twitter on the 6 pre-existing pages, JSON-LD `Dataset` on `/`; `/river/[id]` ×85 (the substantial piece — quick-facts, source/sink, tributaries, PAs, cities, JSON-LD `Place`).
- **43** — Header/Footer + About/Privacy/Terms/404. Theme toggle (self-hosted SVG sun/moon, no emoji). Search deliberately NOT relocated into header (stays floating over the map) — flagged as a scoped-down deviation from §6.3's full layout, not silently skipped.
- **42** — Comparison Mode `/compare`: 2-3 river picker, 9-row table, `r1/r2/r3` URL state. Found+fixed an SSR crash (`location` read in a `useState` initializer).
- **41** — Filter Panels: River (State/Basin/DrainageType/Transnational) + PA (Category/State) filters, deep-linkable, wired via `setFilter` kept separate from selection highlighting.
- **40** — State Panel: click a state polygon or a state chip anywhere → `StatePanel` (capital, rivers, cities, PAs). `cities.json` inlined. Found+fixed: state-polygon clicks previously did nothing at all (no handler existed).
- **39** — Re-ran `spatialIntersect.js` full pipeline to check a stale "Next step" claim — result: 0 changes needed, 85/85 already correct. Logged as a step anyway (verified-correct is a real outcome, not silence).
- **38** — Browse/List mode. `virtua` failure discovered + hand-rolled virtualizer written (see gotchas). Focus management retrofitted onto all panels.
- **37** — `basins.json` (35, programmatically derived from the 85 river files, not hand-typed) + contrast-verified badge colors + `validateBasins.js` prebuild hook (fails the build on bad basin data — verified by deliberately breaking one and confirming build stops).
- **36** — Global search (Fuse.js, §3.8) + state-selection map highlight (not yet the full State Panel — that's Step 40).
- **35** — `buildSearchIndex.js`: trimmed (not full-record) Fuse indexes for rivers+states and PAs; version-drift guard tested.
- **34** — `deriveStateCrossRefs.js`: derives all 4 relational arrays on `states.json` from already-authoritative sources; found+handled a `&`-vs-`and` state-name format mismatch (only in PA data).
- **33** — Real `protected_area_ids` merged into all 85 rivers. The original build-intermediate pipeline (`build/pa-merged.geojson`, `build/rivers-by-id/`) was gitignored and unrecoverable — rebuilt both from committed source instead (`src/boundaries/*.geojson` + decoding the shipped `rivers.pmtiles` itself), verified equivalent against the 7 already-correct Indus-batch rivers.
- **29–32** — Remaining 4 `rivers/{id}.json` batches (Peninsular-East, Peninsular-West, Western Ghats/west-coast, Tamil Nadu east-coast + inland drainage) → **85/85 river detail files complete.** See "Known data caveats" above for the real findings from these batches (naming coincidences, sink.type gap, basin-area gaps).
- **24–28** — Ganga (21), Brahmaputra (11), Godavari (6), Krishna (4), Kaveri (7) system batches. Real finds folded into "Known data caveats" above (Barak's basin grouping, Indravati/Musi's basin-area gap, confluence-not-spring sources for Pranhita/Tungabhadra/Brahmani).
- **22–23** — Fixed a real geometry-corruption bug in Ravi (nested coordinate arrays inside a single Overpass way, a different bug class from Step 18's across-ways issue) + merged real PA references into the Indus batch.
- **17–21** — `stream_order` backfilled for all 85 geometry-backed rivers; Indus-system batch (7 rivers) authored as the first `rivers/{id}.json` batch, establishing the batch pattern (schema validation + cross-reference check + fresh-clone idempotent patch) every later batch followed.
- **13–16** — Fixed a real duplicate-fetch bug in `fetchRivers.js`'s resume logic (~2x-inflated river lengths from doubled Overpass features); built `mergeOverpassRivers.js` + `inspectFlaggedRivers.js` heuristics for the flagged-river problem; manually researched/fixed Ravi's length + wired 10 previously-unused name aliases into Overpass queries.
- **9–12** — Recovered 3 more rivers via fuzzy-matching against the govt shapefile; fixed a silent duplicate-`rivname` data bug (Sharavati shipped wrong for one step); built `mergeOverpassRivers.js` (multi-segment length summing) and made `fetchRivers.js` resumable.
- **10** — Rewrote `fetchRivers.js` against live Overpass: fixed a hanging client-side timeout (`AbortController`) and the `osmtogeojson` version-mismatch bug (see gotchas).
- **8** — `reconcileGovtMetadata.js`: merged govt/HydroRIVERS metadata into the river research index (106 entries); found 3 unaliased name-spelling mismatches and one false-positive "Purna" match.
- **6** — HydroRIVERS spatial join: v1 hung 5+ hours at real scale (see gotchas); v2's grid-index rewrite ran the real 503,929-reach dataset in 24.5s, 61/61 matched.
- **5c** — Government rivers shapefile processed: 61/105 matched with real geometry; multi-part (braided-channel) `shape_Leng` sums flagged rather than shipped as fact.
- **4** — State/UT metadata (`states.json`, `india-states.geojson`) — reused ecoguesser's already-simplified source geometry, no Mapshaper needed.
- **3** — `protected-areas.pmtiles` built via tippecanoe (sandbox-only, Windows has no native build) — 8.68MB, under Cloudflare's 25MiB limit.
- **2** — Protected Areas pipeline: 837 records + 835 boundaries merged from ecoguesser's already-processed data (2 fewer than metadata count — boundary-less TRs, matches spec).
- **1** — Project scaffold: Astro 6.4.8 manually pinned (see Stack above for the full version-conflict story with `@astrojs/preact`/Vite).
VMAPS_PATCH_EOF

mkdir -p "public/data"
cat > 'public/data/basins.json' << 'VMAPS_PATCH_EOF'
[
  {
    "id": "ganga-basin",
    "name": "Ganga Basin",
    "color_light": "#9d4325",
    "color_dark": "#dd7f5f",
    "area_km2": 861452,
    "states": [
      "bihar",
      "jharkhand",
      "west-bengal",
      "uttarakhand",
      "rajasthan",
      "madhya-pradesh",
      "uttar-pradesh",
      "chhattisgarh",
      "himachal-pradesh",
      "haryana",
      "delhi"
    ],
    "main_river": "ganga",
    "rivers": [
      "ajay",
      "alaknanda",
      "banas",
      "barakar",
      "betwa",
      "bhagirathi",
      "chambal",
      "damodar",
      "gandak",
      "ganga",
      "ghaghra",
      "gomti",
      "hooghly",
      "kali-sindh",
      "ken",
      "kosi",
      "mahananda",
      "parbati",
      "sarda",
      "son",
      "yamuna"
    ],
    "area_rank": 1
  },
  {
    "id": "indus-basin",
    "name": "Indus Basin",
    "color_light": "#9d5725",
    "color_dark": "#dd945f",
    "area_km2": 321289,
    "states": [
      "himachal-pradesh",
      "punjab",
      "jammu-and-kashmir",
      "ladakh"
    ],
    "main_river": "indus",
    "rivers": [
      "beas",
      "chenab",
      "indus",
      "ravi",
      "shyok",
      "sutlej",
      "zanskar"
    ],
    "area_rank": 2
  },
  {
    "id": "godavari-basin",
    "name": "Godavari Basin",
    "color_light": "#9d6d25",
    "color_dark": "#ddab5f",
    "area_km2": 312812,
    "states": [
      "maharashtra",
      "telangana",
      "andhra-pradesh",
      "chhattisgarh",
      "odisha",
      "madhya-pradesh",
      "karnataka"
    ],
    "main_river": "godavari",
    "rivers": [
      "godavari",
      "indravati",
      "manjira",
      "pranhita",
      "wainganga",
      "wardha"
    ],
    "area_rank": 3
  },
  {
    "id": "krishna-basin",
    "name": "Krishna Basin",
    "color_light": "#957a23",
    "color_dark": "#ddc05f",
    "area_km2": 258948,
    "states": [
      "maharashtra",
      "karnataka",
      "telangana",
      "andhra-pradesh"
    ],
    "main_river": "krishna",
    "rivers": [
      "bhima",
      "krishna",
      "musi",
      "tungabhadra"
    ],
    "area_rank": 4
  },
  {
    "id": "brahmaputra-basin",
    "name": "Brahmaputra Basin",
    "color_light": "#847d1f",
    "color_dark": "#ddd55f",
    "area_km2": 194413,
    "states": [
      "manipur",
      "nagaland",
      "mizoram",
      "assam",
      "meghalaya",
      "tripura",
      "arunachal-pradesh",
      "sikkim",
      "west-bengal"
    ],
    "main_river": "brahmaputra",
    "rivers": [
      "barak",
      "brahmaputra",
      "jaldhaka",
      "kameng",
      "kopili",
      "lohit",
      "manas",
      "rangeet",
      "subansiri",
      "teesta",
      "torsa"
    ],
    "area_rank": 5
  },
  {
    "id": "mahanadi-basin",
    "name": "Mahanadi Basin",
    "color_light": "#7a841f",
    "color_dark": "#d0dd5f",
    "area_km2": 141600,
    "states": [
      "chhattisgarh",
      "odisha"
    ],
    "main_river": "mahanadi",
    "rivers": [
      "mahanadi"
    ],
    "area_rank": 6
  },
  {
    "id": "narmada-basin",
    "name": "Narmada Basin",
    "color_light": "#68841f",
    "color_dark": "#b9dd5f",
    "area_km2": 98796,
    "states": [
      "madhya-pradesh",
      "gujarat",
      "maharashtra",
      "chhattisgarh"
    ],
    "main_river": "narmada",
    "rivers": [
      "narmada"
    ],
    "area_rank": 7
  },
  {
    "id": "kaveri-basin",
    "name": "Kaveri Basin",
    "color_light": "#5c8c21",
    "color_dark": "#a4dd5f",
    "area_km2": 81155,
    "states": [
      "kerala",
      "tamil-nadu",
      "karnataka",
      "puducherry"
    ],
    "main_river": "kaveri",
    "rivers": [
      "amaravathi",
      "arkavathi",
      "bhavani",
      "hemavathi",
      "kabini",
      "kaveri",
      "shimsha"
    ],
    "area_rank": 8
  },
  {
    "id": "tapi-basin",
    "name": "Tapi Basin",
    "color_light": "#4a8c21",
    "color_dark": "#8fdd5f",
    "area_km2": 65145,
    "states": [
      "madhya-pradesh",
      "maharashtra",
      "gujarat"
    ],
    "main_river": "tapi",
    "rivers": [
      "tapi"
    ],
    "area_rank": 9
  },
  {
    "id": "ghaggar-basin",
    "name": "Ghaggar-Hakra Basin",
    "color_light": "#368c21",
    "color_dark": "#78dd5f",
    "area_km2": 42200,
    "states": [
      "himachal-pradesh",
      "punjab",
      "haryana",
      "rajasthan"
    ],
    "main_river": "ghaggar-hakra",
    "rivers": [
      "ghaggar-hakra"
    ],
    "area_rank": 10
  },
  {
    "id": "brahmani-basin",
    "name": "Brahmani Basin",
    "color_light": "#258c21",
    "color_dark": "#63dd5f",
    "area_km2": 39033,
    "states": [
      "jharkhand",
      "odisha"
    ],
    "main_river": "brahmani",
    "rivers": [
      "brahmani"
    ],
    "area_rank": 11
  },
  {
    "id": "luni-basin",
    "name": "Luni Basin",
    "color_light": "#218c2f",
    "color_dark": "#5fdd70",
    "area_km2": 37363,
    "states": [
      "rajasthan",
      "gujarat"
    ],
    "main_river": "luni",
    "rivers": [
      "luni"
    ],
    "area_rank": 12
  },
  {
    "id": "mahi-basin",
    "name": "Mahi Basin",
    "color_light": "#218c41",
    "color_dark": "#5fdd85",
    "area_km2": 34842,
    "states": [
      "madhya-pradesh",
      "rajasthan",
      "gujarat"
    ],
    "main_river": "mahi",
    "rivers": [
      "mahi"
    ],
    "area_rank": 13
  },
  {
    "id": "sabarmati-basin",
    "name": "Sabarmati Basin",
    "color_light": "#218c55",
    "color_dark": "#5fdd9c",
    "area_km2": 21674,
    "states": [
      "rajasthan",
      "gujarat"
    ],
    "main_river": "sabarmati",
    "rivers": [
      "sabarmati"
    ],
    "area_rank": 14
  },
  {
    "id": "subarnarekha-basin",
    "name": "Subarnarekha Basin",
    "color_light": "#218c67",
    "color_dark": "#5fddb1",
    "area_km2": 18951,
    "states": [
      "jharkhand",
      "west-bengal",
      "odisha"
    ],
    "main_river": "subarnarekha",
    "rivers": [
      "subarnarekha"
    ],
    "area_rank": 15
  },
  {
    "id": "ponnaiyar-basin",
    "name": "Ponnaiyar Basin",
    "color_light": "#218c79",
    "color_dark": "#5fddc6",
    "area_km2": 16019,
    "states": [
      "karnataka",
      "tamil-nadu"
    ],
    "main_river": "ponnaiyar",
    "rivers": [
      "ponnaiyar"
    ],
    "area_rank": 16
  },
  {
    "id": "baitarani-basin",
    "name": "Baitarani Basin",
    "color_light": "#218c8c",
    "color_dark": "#5fdddd",
    "area_km2": 10982,
    "states": [
      "jharkhand",
      "odisha"
    ],
    "main_river": "baitarani",
    "rivers": [
      "baitarani"
    ],
    "area_rank": 17
  },
  {
    "id": "vamsadhara-basin",
    "name": "Vamsadhara Basin",
    "color_light": "#25899d",
    "color_dark": "#5fc8dd",
    "area_km2": 10830,
    "states": [
      "odisha",
      "andhra-pradesh"
    ],
    "main_river": "vamsadhara",
    "rivers": [
      "vamsadhara"
    ],
    "area_rank": 18
  },
  {
    "id": "nagavali-basin",
    "name": "Nagavali Basin",
    "color_light": "#25759d",
    "color_dark": "#5fb3dd",
    "area_km2": 9510,
    "states": [
      "odisha",
      "andhra-pradesh"
    ],
    "main_river": "nagavali",
    "rivers": [
      "nagavali"
    ],
    "area_rank": 19
  },
  {
    "id": "vaigai-basin",
    "name": "Vaigai Basin",
    "color_light": "#25619d",
    "color_dark": "#5f9edd",
    "area_km2": 7230,
    "states": [
      "tamil-nadu"
    ],
    "main_river": "vaigai",
    "rivers": [
      "vaigai"
    ],
    "area_rank": 20
  },
  {
    "id": "bharathapuzha-basin",
    "name": "Bharathapuzha Basin",
    "color_light": "#254b9d",
    "color_dark": "#5f87dd",
    "area_km2": 6810,
    "states": [
      "kerala",
      "tamil-nadu"
    ],
    "main_river": "bharathapuzha",
    "rivers": [
      "bharathapuzha"
    ],
    "area_rank": 21
  },
  {
    "id": "tamiraparani-basin",
    "name": "Tamiraparani Basin",
    "color_light": "#51259d",
    "color_dark": "#9368df",
    "area_km2": 5717,
    "states": [
      "tamil-nadu"
    ],
    "main_river": "tamiraparani",
    "rivers": [
      "tamiraparani"
    ],
    "area_rank": 22
  },
  {
    "id": "periyar-basin",
    "name": "Periyar Basin",
    "color_light": "#25379d",
    "color_dark": "#6879df",
    "area_km2": 5398,
    "states": [
      "kerala",
      "tamil-nadu"
    ],
    "main_river": "periyar",
    "rivers": [
      "periyar"
    ],
    "area_rank": 23
  },
  {
    "id": "vaippar-basin",
    "name": "Vaippar Basin",
    "color_light": "#27259d",
    "color_dark": "#7270e1",
    "area_km2": 5288,
    "states": [
      "tamil-nadu"
    ],
    "main_river": "vaippar",
    "rivers": [
      "vaippar"
    ],
    "area_rank": 24
  },
  {
    "id": "kali-karnataka-basin",
    "name": "Kali Basin",
    "color_light": "#3d259d",
    "color_dark": "#8670e1",
    "area_km2": 5104,
    "states": [
      "karnataka"
    ],
    "main_river": "kali-karnataka",
    "rivers": [
      "kali-karnataka"
    ],
    "area_rank": 25
  },
  {
    "id": "palar-basin",
    "name": "Palar Basin",
    "color_light": "#51259d",
    "color_dark": "#9368df",
    "area_km2": 5044,
    "states": [
      "karnataka",
      "andhra-pradesh",
      "tamil-nadu"
    ],
    "main_river": "palar",
    "rivers": [
      "palar"
    ],
    "area_rank": 26
  },
  {
    "id": "ulhas-basin",
    "name": "Ulhas Basin",
    "color_light": "#65259d",
    "color_dark": "#a25fdd",
    "area_km2": 4637,
    "states": [
      "maharashtra"
    ],
    "main_river": "ulhas",
    "rivers": [
      "ulhas"
    ],
    "area_rank": 27
  },
  {
    "id": "vaitarna-basin",
    "name": "Vaitarna Basin",
    "color_light": "#7c259d",
    "color_dark": "#c25fdd",
    "area_km2": 3795,
    "states": [
      "maharashtra"
    ],
    "main_river": "vaitarna",
    "rivers": [
      "vaitarna"
    ],
    "area_rank": 28
  },
  {
    "id": "netravati-basin",
    "name": "Netravati Basin",
    "color_light": "#79259d",
    "color_dark": "#b75fdd",
    "area_km2": 3502,
    "states": [
      "karnataka"
    ],
    "main_river": "netravati",
    "rivers": [
      "netravati"
    ],
    "area_rank": 29
  },
  {
    "id": "sharavati-basin",
    "name": "Sharavati Basin",
    "color_light": "#8f259d",
    "color_dark": "#ce5fdd",
    "area_km2": 3042,
    "states": [
      "karnataka"
    ],
    "main_river": "sharavati",
    "rivers": [
      "sharavati"
    ],
    "area_rank": 30
  },
  {
    "id": "damanganga-basin",
    "name": "Damanganga Basin",
    "color_light": "#9d2597",
    "color_dark": "#dd5fd7",
    "area_km2": 2318,
    "states": [
      "maharashtra",
      "gujarat",
      "dadra-and-nagar-haveli-and-daman-and-diu"
    ],
    "main_river": "damanganga",
    "rivers": [
      "damanganga"
    ],
    "area_rank": 31
  },
  {
    "id": "pamba-basin",
    "name": "Pamba Basin",
    "color_light": "#9d2583",
    "color_dark": "#dd5fc2",
    "area_km2": 2235,
    "states": [
      "kerala"
    ],
    "main_river": "pamba",
    "rivers": [
      "pamba"
    ],
    "area_rank": 32
  },
  {
    "id": "vellar-basin",
    "name": "Vellar Basin",
    "color_light": "#9d256d",
    "color_dark": "#dd5fab",
    "area_km2": 2034,
    "states": [
      "tamil-nadu"
    ],
    "main_river": "vellar",
    "rivers": [
      "vellar"
    ],
    "area_rank": 33
  },
  {
    "id": "mandovi-basin",
    "name": "Mandovi Basin",
    "color_light": "#9d2559",
    "color_dark": "#dd5f96",
    "area_km2": 2032,
    "states": [
      "karnataka",
      "goa",
      "maharashtra"
    ],
    "main_river": "mandovi",
    "rivers": [
      "mandovi"
    ],
    "area_rank": 34
  },
  {
    "id": "kallada-basin",
    "name": "Kallada Basin",
    "color_light": "#9d2545",
    "color_dark": "#dd5f81",
    "area_km2": 1699,
    "states": [
      "kerala"
    ],
    "main_river": "kallada",
    "rivers": [
      "kallada"
    ],
    "area_rank": 35
  },
  {
    "id": "aghanashini-basin",
    "name": "Aghanashini Basin",
    "color_light": "#9d2531",
    "color_dark": "#dd5f6c",
    "area_km2": 1350,
    "states": [
      "karnataka"
    ],
    "main_river": "aghanashini",
    "rivers": [
      "aghanashini"
    ],
    "area_rank": 36
  },
  {
    "id": "zuari-basin",
    "name": "Zuari Basin",
    "color_light": "#9d2f25",
    "color_dark": "#dd6a5f",
    "area_km2": 975,
    "states": [
      "goa"
    ],
    "main_river": "zuari",
    "rivers": [
      "zuari"
    ],
    "area_rank": 37
  }
]
VMAPS_PATCH_EOF

mkdir -p "public/data"
cat > 'public/data/rivers-id-map.json' << 'VMAPS_PATCH_EOF'
{
  "indus": [
    1
  ],
  "chenab": [
    2
  ],
  "ravi": [
    3
  ],
  "beas": [
    4
  ],
  "sutlej": [
    5
  ],
  "zanskar": [
    6
  ],
  "shyok": [
    7
  ],
  "ganga": [
    8
  ],
  "bhagirathi": [
    9
  ],
  "alaknanda": [
    10
  ],
  "yamuna": [
    11
  ],
  "chambal": [
    12
  ],
  "banas": [
    13
  ],
  "kali-sindh": [
    14
  ],
  "parbati": [
    15
  ],
  "betwa": [
    16
  ],
  "ken": [
    17
  ],
  "son": [
    18
  ],
  "gomti": [
    19
  ],
  "ghaghra": [
    20
  ],
  "sarda": [
    21
  ],
  "gandak": [
    22
  ],
  "kosi": [
    23
  ],
  "mahananda": [
    24
  ],
  "damodar": [
    25
  ],
  "hooghly": [
    26
  ],
  "barakar": [
    27
  ],
  "ajay": [
    28
  ],
  "brahmaputra": [
    29
  ],
  "lohit": [
    30
  ],
  "subansiri": [
    31
  ],
  "kameng": [
    32
  ],
  "manas": [
    33
  ],
  "teesta": [
    34
  ],
  "rangeet": [
    35
  ],
  "torsa": [
    36
  ],
  "jaldhaka": [
    37
  ],
  "barak": [
    38
  ],
  "kopili": [
    39
  ],
  "mahanadi": [
    40
  ],
  "brahmani": [
    41
  ],
  "baitarani": [
    42
  ],
  "subarnarekha": [
    43
  ],
  "vamsadhara": [
    44
  ],
  "nagavali": [
    45
  ],
  "godavari": [
    46
  ],
  "krishna": [
    47
  ],
  "tungabhadra": [
    48
  ],
  "bhima": [
    49
  ],
  "musi": [
    50
  ],
  "manjira": [
    51
  ],
  "indravati": [
    52
  ],
  "pranhita": [
    53
  ],
  "wainganga": [
    54
  ],
  "wardha": [
    55
  ],
  "kaveri": [
    56
  ],
  "amaravathi": [
    57
  ],
  "kabini": [
    58
  ],
  "hemavathi": [
    59
  ],
  "shimsha": [
    60
  ],
  "arkavathi": [
    61
  ],
  "bhavani": [
    62
  ],
  "palar": [
    63
  ],
  "ponnaiyar": [
    64
  ],
  "vellar": [
    65
  ],
  "vaigai": [
    66
  ],
  "narmada": [
    67
  ],
  "tapi": [
    68
  ],
  "mahi": [
    69
  ],
  "sabarmati": [
    70
  ],
  "periyar": [
    71
  ],
  "bharathapuzha": [
    72
  ],
  "pamba": [
    73
  ],
  "kallada": [
    74
  ],
  "sharavati": [
    75
  ],
  "zuari": [
    76
  ],
  "mandovi": [
    77
  ],
  "ulhas": [
    78
  ],
  "kali-karnataka": [
    79
  ],
  "netravati": [
    80
  ],
  "aghanashini": [
    81
  ],
  "damanganga": [
    82
  ],
  "vaippar": [
    83
  ],
  "luni": [
    84
  ],
  "ghaggar-hakra": [
    85
  ],
  "spiti": [
    86
  ],
  "burhi-gandak": [
    87
  ],
  "jhelum": [
    88
  ],
  "bagmati": [
    89
  ],
  "tamiraparani": [
    90
  ],
  "vaitarna": [
    91
  ]
}
VMAPS_PATCH_EOF

mkdir -p "public/data"
cat > 'public/data/rivers-index.json' << 'VMAPS_PATCH_EOF'
[
  {
    "id": "indus",
    "name": "Indus",
    "local_name_hi": "सिन्धु",
    "basin": "indus-basin",
    "length_km_india": 709,
    "basin_area_india_km2": 321289,
    "drainage_type": "himalayan",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "ladakh"
    ],
    "aliases": [
      "Sindhu",
      "Singi Khamban"
    ],
    "bounds": [
      73.77077043034254,
      32.636536070492134,
      79.53821972591814,
      35.85081830154183
    ]
  },
  {
    "id": "chenab",
    "name": "Chenab",
    "local_name_hi": "चिनाब",
    "basin": "indus-basin",
    "length_km_india": 431.4,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "himachal-pradesh",
      "jammu-and-kashmir"
    ],
    "aliases": [
      "Chandrabhaga",
      "Asikni"
    ],
    "bounds": [
      74.52253131117732,
      32.5505695933755,
      76.97652394875051,
      33.388611960437444
    ]
  },
  {
    "id": "ravi",
    "name": "Ravi",
    "local_name_hi": "रावी",
    "basin": "indus-basin",
    "length_km_india": 725,
    "basin_area_india_km2": 14442,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "himachal-pradesh",
      "punjab"
    ],
    "aliases": [
      "Iravati",
      "Purushni"
    ],
    "bounds": [
      74.7822782,
      31.932843,
      76.4495015,
      32.6207819
    ]
  },
  {
    "id": "beas",
    "name": "Beas",
    "local_name_hi": "ब्यास",
    "basin": "indus-basin",
    "length_km_india": 470,
    "basin_area_india_km2": 20303,
    "drainage_type": "himalayan",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": false,
    "states": [
      "himachal-pradesh",
      "punjab"
    ],
    "aliases": [
      "Vipasha",
      "Vipas",
      "Hyphasis"
    ],
    "bounds": [
      74.95016487168179,
      31.147332683277615,
      77.24799993759588,
      32.37295160552816
    ]
  },
  {
    "id": "sutlej",
    "name": "Sutlej",
    "local_name_hi": "सतलुज",
    "basin": "indus-basin",
    "length_km_india": 1050,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "himachal-pradesh",
      "punjab"
    ],
    "aliases": [
      "Satluj",
      "Satadru",
      "Zungbal"
    ],
    "bounds": [
      74.54535312496029,
      30.956794887033652,
      78.73961608289386,
      31.843136593880626
    ]
  },
  {
    "id": "zanskar",
    "name": "Zanskar",
    "local_name_hi": "जांस्कर",
    "basin": "indus-basin",
    "length_km_india": 134,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": false,
    "states": [
      "ladakh"
    ],
    "aliases": [],
    "bounds": [
      76.8414333,
      33.5168359,
      77.3319365,
      34.1654572
    ]
  },
  {
    "id": "shyok",
    "name": "Shyok",
    "local_name_hi": "श्योक",
    "basin": "indus-basin",
    "length_km_india": 400,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "ladakh"
    ],
    "aliases": [
      "Shayok"
    ],
    "bounds": [
      77.6176722,
      34.1264559,
      78.334461,
      35.3526829
    ]
  },
  {
    "id": "ganga",
    "name": "Ganga",
    "local_name_hi": "गंगा",
    "basin": "ganga-basin",
    "length_km_india": 2525,
    "basin_area_india_km2": 861452,
    "drainage_type": "himalayan",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": true,
    "transnational": true,
    "states": [
      "uttarakhand",
      "uttar-pradesh",
      "bihar",
      "jharkhand",
      "west-bengal"
    ],
    "aliases": [
      "Ganges",
      "Ganga Mata"
    ],
    "bounds": [
      78.03045935028754,
      24.556482584180397,
      88.16130121003667,
      30.145455810237248
    ]
  },
  {
    "id": "bhagirathi",
    "name": "Bhagirathi",
    "local_name_hi": "भागीरथी",
    "basin": "ganga-basin",
    "length_km_india": 229.1,
    "basin_area_india_km2": 6921,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": false,
    "states": [
      "uttarakhand"
    ],
    "aliases": [],
    "bounds": [
      78.31467435063402,
      30.145455810237248,
      79.25203598850842,
      31.047409290960296
    ]
  },
  {
    "id": "alaknanda",
    "name": "Alaknanda",
    "local_name_hi": "अलकनंदा",
    "basin": "ganga-basin",
    "length_km_india": 206.4,
    "basin_area_india_km2": 10882,
    "drainage_type": "himalayan",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": false,
    "states": [
      "uttarakhand"
    ],
    "aliases": [],
    "bounds": [
      78.59742698346808,
      30.143258397438387,
      79.57664852602751,
      30.8196478547323
    ]
  },
  {
    "id": "yamuna",
    "name": "Yamuna",
    "local_name_hi": "यमुना",
    "basin": "ganga-basin",
    "length_km_india": 1376,
    "basin_area_india_km2": 366223,
    "drainage_type": "himalayan",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": false,
    "states": [
      "uttarakhand",
      "himachal-pradesh",
      "haryana",
      "delhi",
      "uttar-pradesh"
    ],
    "aliases": [
      "Jamuna",
      "Jumna"
    ],
    "bounds": [
      77.09580825397633,
      25.25677421362755,
      81.89069052499315,
      31.02644107364941
    ]
  },
  {
    "id": "chambal",
    "name": "Chambal",
    "local_name_hi": "चंबल",
    "basin": "ganga-basin",
    "length_km_india": 988.5,
    "basin_area_india_km2": 144591,
    "drainage_type": "peninsular",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "rajasthan",
      "uttar-pradesh"
    ],
    "aliases": [
      "Charmanyavati"
    ],
    "bounds": [
      75.2656294186882,
      22.48168138455151,
      79.24829977444949,
      26.870061913024653
    ]
  },
  {
    "id": "banas",
    "name": "Banas",
    "local_name_hi": "बनास",
    "basin": "ganga-basin",
    "length_km_india": 550,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 7,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "rajasthan"
    ],
    "aliases": [],
    "bounds": [
      73.47760748160958,
      24.859022964804577,
      76.73951453746561,
      26.216460917308975
    ]
  },
  {
    "id": "kali-sindh",
    "name": "Kali Sindh",
    "local_name_hi": "काली सिंध",
    "basin": "ganga-basin",
    "length_km_india": 550,
    "basin_area_india_km2": 48492,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "rajasthan"
    ],
    "aliases": [
      "Kali Sindhu"
    ],
    "bounds": [
      76.1608336,
      22.6683423,
      76.4700077,
      25.5351348
    ]
  },
  {
    "id": "parbati",
    "name": "Parbati",
    "local_name_hi": "पार्वती",
    "basin": "ganga-basin",
    "length_km_india": 444.2,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "rajasthan"
    ],
    "aliases": [],
    "bounds": [
      76.47283808297156,
      22.790213396145333,
      77.2254316842215,
      25.85304314552687
    ]
  },
  {
    "id": "betwa",
    "name": "Betwa",
    "local_name_hi": "बेतवा",
    "basin": "ganga-basin",
    "length_km_india": 590,
    "basin_area_india_km2": 46580,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "uttar-pradesh"
    ],
    "aliases": [
      "Vetravati"
    ],
    "bounds": [
      77.35069594057963,
      23.037520739152747,
      80.21453290940721,
      25.954284857284005
    ]
  },
  {
    "id": "ken",
    "name": "Ken",
    "local_name_hi": "केन",
    "basin": "ganga-basin",
    "length_km_india": 427,
    "basin_area_india_km2": 28058,
    "drainage_type": "peninsular",
    "stream_order": 8,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "uttar-pradesh"
    ],
    "aliases": [
      "Karnavati"
    ],
    "bounds": [
      79.825495,
      23.8982047,
      80.5268025,
      25.7776994
    ]
  },
  {
    "id": "son",
    "name": "Son",
    "local_name_hi": "सोन",
    "basin": "ganga-basin",
    "length_km_india": 784,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "chhattisgarh",
      "uttar-pradesh",
      "jharkhand",
      "bihar"
    ],
    "aliases": [
      "Sone",
      "Sonbhadra"
    ],
    "bounds": [
      81.00285471291238,
      22.691992859576125,
      84.87313927242172,
      25.705411884759577
    ]
  },
  {
    "id": "gomti",
    "name": "Gomti",
    "local_name_hi": "गोमती",
    "basin": "ganga-basin",
    "length_km_india": 960,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "uttar-pradesh"
    ],
    "aliases": [
      "Gumti",
      "Gomati"
    ],
    "bounds": [
      80.06758185476069,
      25.491925717643827,
      83.17183763955266,
      28.620575271236824
    ]
  },
  {
    "id": "ghaghra",
    "name": "Ghaghra (Karnali)",
    "local_name_hi": "घाघरा",
    "basin": "ganga-basin",
    "length_km_india": 503,
    "basin_area_india_km2": 57578,
    "drainage_type": "himalayan",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "uttar-pradesh",
      "bihar"
    ],
    "aliases": [
      "Karnali",
      "Manchu"
    ],
    "bounds": [
      81.01595322248862,
      25.73826536008539,
      84.79178997303465,
      28.420637560557953
    ]
  },
  {
    "id": "sarda",
    "name": "Sarda (Sharda)",
    "local_name_hi": "शारदा",
    "basin": "ganga-basin",
    "length_km_india": 350,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "uttarakhand",
      "uttar-pradesh"
    ],
    "aliases": [
      "Kali",
      "Mahakali"
    ],
    "bounds": [
      80.0942087,
      27.6393885,
      81.285975,
      30.1262914
    ]
  },
  {
    "id": "gandak",
    "name": "Gandak",
    "local_name_hi": "गंडक",
    "basin": "ganga-basin",
    "length_km_india": 260,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "uttar-pradesh",
      "bihar"
    ],
    "aliases": [
      "Gandaki",
      "Narayani",
      "Sapt Gandaki"
    ],
    "bounds": [
      83.96470543454804,
      25.64481649473058,
      85.28242514895892,
      27.182874766559497
    ]
  },
  {
    "id": "kosi",
    "name": "Kosi",
    "local_name_hi": "कोसी",
    "basin": "ganga-basin",
    "length_km_india": 260,
    "basin_area_india_km2": 11410,
    "drainage_type": "himalayan",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "bihar"
    ],
    "aliases": [
      "Koshi",
      "Saptakoshi",
      "Sorrow of Bihar"
    ],
    "bounds": [
      86.438713,
      25.4055708,
      87.2586201,
      26.9102464
    ]
  },
  {
    "id": "mahananda",
    "name": "Mahananda",
    "local_name_hi": "महानंदा",
    "basin": "ganga-basin",
    "length_km_india": 324,
    "basin_area_india_km2": 11530,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": true,
    "states": [
      "west-bengal",
      "bihar"
    ],
    "aliases": [],
    "bounds": [
      87.9849467,
      24.4906245,
      88.3062718,
      25.3421337
    ]
  },
  {
    "id": "damodar",
    "name": "Damodar",
    "local_name_hi": "दामोदर",
    "basin": "ganga-basin",
    "length_km_india": 592,
    "basin_area_india_km2": 25820,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "jharkhand",
      "west-bengal"
    ],
    "aliases": [
      "River of Sorrows",
      "Damuda"
    ],
    "bounds": [
      84.66737282933904,
      22.280578271576072,
      88.09519596136906,
      23.77133833119507
    ]
  },
  {
    "id": "hooghly",
    "name": "Hooghly",
    "local_name_hi": "हुगली",
    "basin": "ganga-basin",
    "length_km_india": 260,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "mixed",
    "navigable": true,
    "transnational": false,
    "states": [
      "west-bengal"
    ],
    "aliases": [
      "Bhagirathi-Hooghly"
    ],
    "bounds": [
      87.90662507114797,
      21.617535606166282,
      88.51388332406779,
      23.410745391892515
    ]
  },
  {
    "id": "barakar",
    "name": "Barakar",
    "local_name_hi": "बराकर",
    "basin": "ganga-basin",
    "length_km_india": 291.3,
    "basin_area_india_km2": 6159,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "jharkhand",
      "west-bengal"
    ],
    "aliases": [],
    "bounds": [
      85.29610443065005,
      23.690933445416203,
      86.82527126446439,
      24.35441547426065
    ]
  },
  {
    "id": "ajay",
    "name": "Ajay",
    "local_name_hi": "अजय",
    "basin": "ganga-basin",
    "length_km_india": 308.4,
    "basin_area_india_km2": 6000,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "bihar",
      "jharkhand",
      "west-bengal"
    ],
    "aliases": [],
    "bounds": [
      86.29661914512434,
      23.54173521349504,
      88.13406588557294,
      24.525749584633708
    ]
  },
  {
    "id": "brahmaputra",
    "name": "Brahmaputra",
    "local_name_hi": "ब्रह्मपुत्र",
    "basin": "brahmaputra-basin",
    "length_km_india": 916,
    "basin_area_india_km2": 194413,
    "drainage_type": "himalayan",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": true,
    "transnational": true,
    "states": [
      "arunachal-pradesh",
      "assam"
    ],
    "aliases": [
      "Tsangpo",
      "Yarlung Tsangpo",
      "Siang",
      "Dihang"
    ],
    "bounds": [
      89.84631240391785,
      25.714658761413023,
      95.05865167255253,
      27.586808342973157
    ]
  },
  {
    "id": "lohit",
    "name": "Lohit",
    "local_name_hi": "लोहित",
    "basin": "brahmaputra-basin",
    "length_km_india": 200,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "arunachal-pradesh",
      "assam"
    ],
    "aliases": [
      "Zayul Chu"
    ],
    "bounds": [
      95.06251093844085,
      27.53922008551963,
      97.03797597084552,
      28.35242468020038
    ]
  },
  {
    "id": "subansiri",
    "name": "Subansiri",
    "local_name_hi": "सुबानसिरी",
    "basin": "brahmaputra-basin",
    "length_km_india": 382,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "arunachal-pradesh",
      "assam"
    ],
    "aliases": [
      "Gold River"
    ],
    "bounds": [
      93.18749359005344,
      26.847467804923042,
      94.35592249887554,
      28.44254399798272
    ]
  },
  {
    "id": "kameng",
    "name": "Kameng",
    "local_name_hi": "कामेंग",
    "basin": "brahmaputra-basin",
    "length_km_india": 150,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "arunachal-pradesh",
      "assam"
    ],
    "aliases": [
      "Jia Bharali",
      "Bhareli"
    ],
    "bounds": [
      92.58898950849525,
      26.612829446352467,
      93.1431407450182,
      27.728913865438823
    ]
  },
  {
    "id": "manas",
    "name": "Manas",
    "local_name_hi": "मानस",
    "basin": "brahmaputra-basin",
    "length_km_india": 104,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "assam"
    ],
    "aliases": [
      "Drangme Chhu"
    ],
    "bounds": [
      90.9491855,
      26.8370816,
      91.6856817,
      27.5000553
    ]
  },
  {
    "id": "teesta",
    "name": "Teesta",
    "local_name_hi": "तीस्ता",
    "basin": "brahmaputra-basin",
    "length_km_india": 414,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "sikkim",
      "west-bengal"
    ],
    "aliases": [
      "Tista"
    ],
    "bounds": [
      88.42554450935079,
      26.240831281588882,
      88.97819994179304,
      28.041509088722666
    ]
  },
  {
    "id": "rangeet",
    "name": "Rangeet",
    "local_name_hi": "रंगीत",
    "basin": "brahmaputra-basin",
    "length_km_india": 65,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": false,
    "states": [
      "sikkim"
    ],
    "aliases": [
      "Rangit",
      "Ranjit"
    ],
    "bounds": [
      88.275168,
      27.0795165,
      88.433163,
      27.4916648
    ]
  },
  {
    "id": "torsa",
    "name": "Torsa",
    "local_name_hi": "तोर्षा",
    "basin": "brahmaputra-basin",
    "length_km_india": 100,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": true,
    "states": [
      "west-bengal"
    ],
    "aliases": [
      "Amo Chhu",
      "Machu"
    ],
    "bounds": [
      89.30958793096254,
      26.221253203857756,
      89.64199169755942,
      26.865660527402373
    ]
  },
  {
    "id": "jaldhaka",
    "name": "Jaldhaka",
    "local_name_hi": "जलढाका",
    "basin": "brahmaputra-basin",
    "length_km_india": 193,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "spring-fed",
    "navigable": false,
    "transnational": true,
    "states": [
      "sikkim",
      "west-bengal"
    ],
    "aliases": [
      "Dichu"
    ],
    "bounds": [
      88.85502592570062,
      26.001349514871922,
      89.46718126923705,
      27.108923876128564
    ]
  },
  {
    "id": "barak",
    "name": "Barak",
    "local_name_hi": "बराक",
    "basin": "brahmaputra-basin",
    "length_km_india": 100.3,
    "basin_area_india_km2": 41723,
    "drainage_type": "himalayan",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": true,
    "transnational": true,
    "states": [
      "manipur",
      "mizoram",
      "assam"
    ],
    "aliases": [],
    "bounds": [
      92.48857005191893,
      24.750038367013122,
      92.9100994670463,
      24.915926193600225
    ]
  },
  {
    "id": "kopili",
    "name": "Kopili",
    "local_name_hi": "कोपिली",
    "basin": "brahmaputra-basin",
    "length_km_india": 333,
    "basin_area_india_km2": 16420,
    "drainage_type": "himalayan",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "meghalaya",
      "assam"
    ],
    "aliases": [
      "Kapili"
    ],
    "bounds": [
      91.95332680305376,
      25.210483981642756,
      92.93263207993498,
      26.252027844153837
    ]
  },
  {
    "id": "mahanadi",
    "name": "Mahanadi",
    "local_name_hi": "महानदी",
    "basin": "mahanadi-basin",
    "length_km_india": 851,
    "basin_area_india_km2": 141600,
    "drainage_type": "peninsular",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "chhattisgarh",
      "odisha"
    ],
    "aliases": [],
    "bounds": [
      81.37026912475861,
      20.224242676325407,
      86.72521978529936,
      21.74527042081266
    ]
  },
  {
    "id": "brahmani",
    "name": "Brahmani",
    "local_name_hi": "ब्राह्मणी",
    "basin": "brahmani-basin",
    "length_km_india": 799,
    "basin_area_india_km2": 39033,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "jharkhand",
      "odisha"
    ],
    "aliases": [
      "South Koel"
    ],
    "bounds": [
      84.79748455335147,
      20.5665438064675,
      86.97685988395413,
      22.238434311322
    ]
  },
  {
    "id": "baitarani",
    "name": "Baitarani",
    "local_name_hi": "बैतरणी",
    "basin": "baitarani-basin",
    "length_km_india": 414.3,
    "basin_area_india_km2": 10982,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "jharkhand",
      "odisha"
    ],
    "aliases": [],
    "bounds": [
      85.36456107267172,
      20.733154229330484,
      86.8221903868247,
      22.09559971863791
    ]
  },
  {
    "id": "subarnarekha",
    "name": "Subarnarekha",
    "local_name_hi": "स्वर्णरेखा",
    "basin": "subarnarekha-basin",
    "length_km_india": 479.5,
    "basin_area_india_km2": 18951,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "jharkhand",
      "west-bengal",
      "odisha"
    ],
    "aliases": [],
    "bounds": [
      85.20311029155947,
      21.577435352953728,
      87.34538278997891,
      23.463012545710736
    ]
  },
  {
    "id": "vamsadhara",
    "name": "Vamsadhara",
    "local_name_hi": "वंशधारा",
    "basin": "vamsadhara-basin",
    "length_km_india": 287,
    "basin_area_india_km2": 10830,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "odisha",
      "andhra-pradesh"
    ],
    "aliases": [],
    "bounds": [
      83.35435699737342,
      18.33094484777648,
      84.1315547126176,
      19.80212716889233
    ]
  },
  {
    "id": "nagavali",
    "name": "Nagavali",
    "local_name_hi": "नागावली",
    "basin": "nagavali-basin",
    "length_km_india": 250.4,
    "basin_area_india_km2": 9510,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "odisha",
      "andhra-pradesh"
    ],
    "aliases": [
      "Langulya"
    ],
    "bounds": [
      83.24411017864725,
      18.217088974909256,
      83.93261732268701,
      19.710748294225
    ]
  },
  {
    "id": "godavari",
    "name": "Godavari",
    "local_name_hi": "गोदावरी",
    "basin": "godavari-basin",
    "length_km_india": 1465,
    "basin_area_india_km2": 312812,
    "drainage_type": "peninsular",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "maharashtra",
      "telangana",
      "andhra-pradesh",
      "chhattisgarh",
      "odisha"
    ],
    "aliases": [
      "Dakshin Ganga"
    ],
    "bounds": [
      73.52414487929967,
      16.304956335835044,
      82.3217789933934,
      20.051462112193537
    ]
  },
  {
    "id": "krishna",
    "name": "Krishna",
    "local_name_hi": "कृष्णा",
    "basin": "krishna-basin",
    "length_km_india": 1400,
    "basin_area_india_km2": 258948,
    "drainage_type": "peninsular",
    "stream_order": 8,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "maharashtra",
      "karnataka",
      "telangana",
      "andhra-pradesh"
    ],
    "aliases": [
      "Krishnaveni"
    ],
    "bounds": [
      73.63156421474659,
      15.711093967707615,
      81.12554369747741,
      17.989307007295437
    ]
  },
  {
    "id": "tungabhadra",
    "name": "Tungabhadra",
    "local_name_hi": "तुंगभद्रा",
    "basin": "krishna-basin",
    "length_km_india": 552.5,
    "basin_area_india_km2": 71417,
    "drainage_type": "peninsular",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka",
      "andhra-pradesh"
    ],
    "aliases": [
      "Pampa"
    ],
    "bounds": [
      75.6226768367887,
      14.014661079550713,
      78.24851314935961,
      15.963924308325865
    ]
  },
  {
    "id": "bhima",
    "name": "Bhima",
    "local_name_hi": "भीमा",
    "basin": "krishna-basin",
    "length_km_india": 864.5,
    "basin_area_india_km2": 70614,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "maharashtra",
      "karnataka",
      "telangana"
    ],
    "aliases": [
      "Chandrabhaga"
    ],
    "bounds": [
      73.53580196101383,
      16.408230853798717,
      77.28305999974481,
      19.073752593447306
    ]
  },
  {
    "id": "musi",
    "name": "Musi",
    "local_name_hi": "मूसी",
    "basin": "krishna-basin",
    "length_km_india": 296.2,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "telangana"
    ],
    "aliases": [
      "Muchukunda",
      "Musunuru"
    ],
    "bounds": [
      77.9131630238338,
      16.69204461116172,
      79.67580559565174,
      17.446958461717667
    ]
  },
  {
    "id": "manjira",
    "name": "Manjira",
    "local_name_hi": "मंजिरा",
    "basin": "godavari-basin",
    "length_km_india": 724,
    "basin_area_india_km2": 30844,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "maharashtra",
      "karnataka",
      "telangana"
    ],
    "aliases": [
      "Manjra",
      "Manjara"
    ],
    "bounds": [
      75.38526227335987,
      17.64757056487456,
      78.21336298638079,
      18.89667704112967
    ]
  },
  {
    "id": "indravati",
    "name": "Indravati",
    "local_name_hi": "इंद्रावती",
    "basin": "godavari-basin",
    "length_km_india": 489,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "odisha",
      "chhattisgarh",
      "maharashtra",
      "telangana"
    ],
    "aliases": [],
    "bounds": [
      80.24474344121495,
      18.72386714506009,
      83.06480967767898,
      19.596209107234742
    ]
  },
  {
    "id": "pranhita",
    "name": "Pranhita",
    "local_name_hi": "प्राणहिता",
    "basin": "godavari-basin",
    "length_km_india": 115.5,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 7,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "maharashtra",
      "telangana"
    ],
    "aliases": [],
    "bounds": [
      79.78981842531098,
      18.82680265365891,
      79.97518129505508,
      19.596556934666257
    ]
  },
  {
    "id": "wainganga",
    "name": "Wainganga",
    "local_name_hi": "वैनगंगा",
    "basin": "godavari-basin",
    "length_km_india": 629.8,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "maharashtra"
    ],
    "aliases": [],
    "bounds": [
      79.45461689257111,
      19.611196258917847,
      80.1950004517294,
      22.458455329505835
    ]
  },
  {
    "id": "wardha",
    "name": "Wardha",
    "local_name_hi": "वर्धा",
    "basin": "godavari-basin",
    "length_km_india": 533.6,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "maharashtra",
      "telangana"
    ],
    "aliases": [],
    "bounds": [
      78.05215641796468,
      19.50692035042399,
      79.78981842531098,
      21.820233691261485
    ]
  },
  {
    "id": "kaveri",
    "name": "Kaveri",
    "local_name_hi": "कावेरी",
    "basin": "kaveri-basin",
    "length_km_india": 800,
    "basin_area_india_km2": 81155,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka",
      "tamil-nadu",
      "kerala",
      "puducherry"
    ],
    "aliases": [
      "Cauvery",
      "Ponni"
    ],
    "bounds": [
      75.4923320125614,
      10.828756696805454,
      79.8568636459128,
      12.623643824642304
    ]
  },
  {
    "id": "amaravathi",
    "name": "Amaravathi",
    "local_name_hi": "अमरावती",
    "basin": "kaveri-basin",
    "length_km_india": 256,
    "basin_area_india_km2": 8280,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "kerala",
      "tamil-nadu"
    ],
    "aliases": [
      "Pournami"
    ],
    "bounds": [
      77.2513476,
      10.3514674,
      78.1940615,
      10.9717029
    ]
  },
  {
    "id": "kabini",
    "name": "Kabini",
    "local_name_hi": "काबिनी",
    "basin": "kaveri-basin",
    "length_km_india": 240,
    "basin_area_india_km2": 7040,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "kerala",
      "karnataka"
    ],
    "aliases": [
      "Kabani",
      "Kapila"
    ],
    "bounds": [
      76.0750989,
      11.79938,
      76.913867,
      12.234668
    ]
  },
  {
    "id": "hemavathi",
    "name": "Hemavathi",
    "local_name_hi": "हेमावती",
    "basin": "kaveri-basin",
    "length_km_india": 245,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka"
    ],
    "aliases": [],
    "bounds": [
      75.8527873,
      12.4967118,
      76.4606541,
      12.8564788
    ]
  },
  {
    "id": "shimsha",
    "name": "Shimsha",
    "local_name_hi": "शिम्शा",
    "basin": "kaveri-basin",
    "length_km_india": 221,
    "basin_area_india_km2": 8469,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka"
    ],
    "aliases": [],
    "bounds": [
      76.8084075,
      12.3101556,
      77.2385484,
      13.3930222
    ]
  },
  {
    "id": "arkavathi",
    "name": "Arkavathi",
    "local_name_hi": "अर्कावती",
    "basin": "kaveri-basin",
    "length_km_india": 190,
    "basin_area_india_km2": 4351,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka"
    ],
    "aliases": [],
    "bounds": [
      77.2767544,
      12.2865068,
      77.4915969,
      13.1430248
    ]
  },
  {
    "id": "bhavani",
    "name": "Bhavani",
    "local_name_hi": "भवानी",
    "basin": "kaveri-basin",
    "length_km_india": 234,
    "basin_area_india_km2": 1410,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "kerala",
      "tamil-nadu"
    ],
    "aliases": [],
    "bounds": [
      76.4591454,
      11.0654582,
      77.6864399,
      11.5252056
    ]
  },
  {
    "id": "palar",
    "name": "Palar",
    "local_name_hi": "पालार",
    "basin": "palar-basin",
    "length_km_india": 348,
    "basin_area_india_km2": 5044,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka",
      "andhra-pradesh",
      "tamil-nadu"
    ],
    "aliases": [],
    "bounds": [
      77.89213850920602,
      12.468106945856002,
      80.14949522641106,
      13.434405259164654
    ]
  },
  {
    "id": "ponnaiyar",
    "name": "Ponnaiyar",
    "local_name_hi": "पोन्नैयार",
    "basin": "ponnaiyar-basin",
    "length_km_india": 497,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka",
      "tamil-nadu"
    ],
    "aliases": [],
    "bounds": [
      77.73517966669773,
      11.76783781349111,
      79.80706571120056,
      13.402827339243675
    ]
  },
  {
    "id": "vellar",
    "name": "Vellar (Southern)",
    "local_name_hi": "वेल्लार",
    "basin": "vellar-basin",
    "length_km_india": 137,
    "basin_area_india_km2": 2034,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "tamil-nadu"
    ],
    "aliases": [],
    "bounds": [
      78.4356204,
      10.0639014,
      79.7789705,
      11.7087141
    ]
  },
  {
    "id": "vaigai",
    "name": "Vaigai",
    "local_name_hi": "वैगई",
    "basin": "vaigai-basin",
    "length_km_india": 312.2,
    "basin_area_india_km2": 7230,
    "drainage_type": "peninsular",
    "stream_order": 4,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "tamil-nadu"
    ],
    "aliases": [],
    "bounds": [
      77.37606151383869,
      9.327817167429753,
      79.00198625812632,
      10.1153130845768
    ]
  },
  {
    "id": "narmada",
    "name": "Narmada",
    "local_name_hi": "नर्मदा",
    "basin": "narmada-basin",
    "length_km_india": 1312,
    "basin_area_india_km2": 98796,
    "drainage_type": "peninsular",
    "stream_order": 7,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "gujarat",
      "maharashtra",
      "chhattisgarh"
    ],
    "aliases": [
      "Rewa"
    ],
    "bounds": [
      72.59426228347786,
      21.634945576327375,
      81.75927463840323,
      23.14365952594254
    ]
  },
  {
    "id": "tapi",
    "name": "Tapi",
    "local_name_hi": "तापी",
    "basin": "tapi-basin",
    "length_km_india": 779,
    "basin_area_india_km2": 65145,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "maharashtra",
      "gujarat"
    ],
    "aliases": [
      "Tapti"
    ],
    "bounds": [
      72.7206974034038,
      21.058948936764878,
      78.26246195535794,
      21.821313685286373
    ]
  },
  {
    "id": "mahi",
    "name": "Mahi",
    "local_name_hi": "माही",
    "basin": "mahi-basin",
    "length_km_india": 553.5,
    "basin_area_india_km2": 34842,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "madhya-pradesh",
      "rajasthan",
      "gujarat"
    ],
    "aliases": [],
    "bounds": [
      72.82211814143649,
      22.233342058648603,
      75.0429379767034,
      23.925792721788696
    ]
  },
  {
    "id": "sabarmati",
    "name": "Sabarmati",
    "local_name_hi": "साबरमती",
    "basin": "sabarmati-basin",
    "length_km_india": 371,
    "basin_area_india_km2": 21674,
    "drainage_type": "peninsular",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "rajasthan",
      "gujarat"
    ],
    "aliases": [
      "Wakal"
    ],
    "bounds": [
      72.35918320936958,
      22.215140000422707,
      73.23045557263175,
      24.620094861896106
    ]
  },
  {
    "id": "periyar",
    "name": "Periyar",
    "local_name_hi": "पेरियार",
    "basin": "periyar-basin",
    "length_km_india": 244,
    "basin_area_india_km2": 5398,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "kerala",
      "tamil-nadu"
    ],
    "aliases": [],
    "bounds": [
      76.1688642624959,
      9.286881629988537,
      77.31615423793907,
      10.19586537136468
    ]
  },
  {
    "id": "bharathapuzha",
    "name": "Bharathapuzha",
    "local_name_hi": "भरतपुझा",
    "basin": "bharathapuzha-basin",
    "length_km_india": 99.9,
    "basin_area_india_km2": 6810,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "kerala",
      "tamil-nadu"
    ],
    "aliases": [
      "Nila",
      "Ponnani River"
    ],
    "bounds": [
      75.91200389085114,
      10.742969630404579,
      76.55660459992816,
      10.866102454916739
    ]
  },
  {
    "id": "pamba",
    "name": "Pamba",
    "local_name_hi": "पम्बा",
    "basin": "pamba-basin",
    "length_km_india": 176,
    "basin_area_india_km2": 2235,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "kerala"
    ],
    "aliases": [
      "Baris",
      "Dakshina Bhageerathi"
    ],
    "bounds": [
      76.3623512,
      9.3237648,
      77.2122366,
      9.5178624
    ]
  },
  {
    "id": "kallada",
    "name": "Kallada",
    "local_name_hi": "कल्लदा",
    "basin": "kallada-basin",
    "length_km_india": 126.1,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 4,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "kerala"
    ],
    "aliases": [],
    "bounds": [
      76.54054188446342,
      8.813178087716423,
      77.23582543594257,
      9.090340469116933
    ]
  },
  {
    "id": "sharavati",
    "name": "Sharavati",
    "local_name_hi": "शरावती",
    "basin": "sharavati-basin",
    "length_km_india": 134.2,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka"
    ],
    "aliases": [],
    "bounds": [
      74.42135681122524,
      13.719693247016119,
      75.14486967969829,
      14.300502576413363
    ]
  },
  {
    "id": "zuari",
    "name": "Zuari",
    "local_name_hi": "जुआरी",
    "basin": "zuari-basin",
    "length_km_india": 92,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 4,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": true,
    "transnational": false,
    "states": [
      "goa"
    ],
    "aliases": [
      "Aghanashini"
    ],
    "bounds": [
      74.0739335,
      15.1873344,
      74.3163965,
      15.2778084
    ]
  },
  {
    "id": "mandovi",
    "name": "Mandovi",
    "local_name_hi": "मांडवी",
    "basin": "mandovi-basin",
    "length_km_india": 81,
    "basin_area_india_km2": null,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": true,
    "transnational": false,
    "states": [
      "karnataka",
      "goa",
      "maharashtra"
    ],
    "aliases": [
      "Mahadayi",
      "Rio de Goa"
    ],
    "bounds": [
      73.8065575,
      15.4514362,
      74.0415752,
      15.5499651
    ]
  },
  {
    "id": "ulhas",
    "name": "Ulhas",
    "local_name_hi": "उल्हास",
    "basin": "ulhas-basin",
    "length_km_india": 146,
    "basin_area_india_km2": 4637,
    "drainage_type": "coastal",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "maharashtra"
    ],
    "aliases": [],
    "bounds": [
      72.79720430676036,
      18.76206758217679,
      73.41147093906629,
      19.324021291777004
    ]
  },
  {
    "id": "kali-karnataka",
    "name": "Kali (Karnataka)",
    "local_name_hi": "काली नदी",
    "basin": "kali-karnataka-basin",
    "length_km_india": 178.7,
    "basin_area_india_km2": null,
    "drainage_type": "coastal",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka"
    ],
    "aliases": [
      "Kali Nadi",
      "Kalinadi"
    ],
    "bounds": [
      74.12087474160343,
      14.841564548681095,
      74.73253759863496,
      15.279046625790937
    ]
  },
  {
    "id": "netravati",
    "name": "Netravati",
    "local_name_hi": "नेत्रावती",
    "basin": "netravati-basin",
    "length_km_india": 115.7,
    "basin_area_india_km2": 3502,
    "drainage_type": "coastal",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka"
    ],
    "aliases": [],
    "bounds": [
      74.82491257105623,
      12.836685584590517,
      75.37187787177068,
      13.17006197923674
    ]
  },
  {
    "id": "aghanashini",
    "name": "Aghanashini",
    "local_name_hi": "अघनाशिनी",
    "basin": "aghanashini-basin",
    "length_km_india": 117,
    "basin_area_india_km2": null,
    "drainage_type": "coastal",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "karnataka"
    ],
    "aliases": [
      "Tadadi Hole"
    ],
    "bounds": [
      74.3577935,
      14.3918558,
      74.8256987,
      14.5616469
    ]
  },
  {
    "id": "damanganga",
    "name": "Damanganga",
    "local_name_hi": "दमणगंगा",
    "basin": "damanganga-basin",
    "length_km_india": 131,
    "basin_area_india_km2": null,
    "drainage_type": "coastal",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "maharashtra",
      "gujarat",
      "dadra-and-nagar-haveli-and-daman-and-diu"
    ],
    "aliases": [
      "Dawan River"
    ],
    "bounds": [
      72.8298759,
      20.1430635,
      73.5713949,
      20.4118883
    ]
  },
  {
    "id": "vaippar",
    "name": "Vaippar",
    "local_name_hi": "वैप्पार",
    "basin": "vaippar-basin",
    "length_km_india": 86.5,
    "basin_area_india_km2": 5288,
    "drainage_type": "coastal",
    "stream_order": 5,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "tamil-nadu"
    ],
    "aliases": [],
    "bounds": [
      77.6954633557735,
      9.031645774732576,
      78.2320575066458,
      9.35347633453861
    ]
  },
  {
    "id": "luni",
    "name": "Luni",
    "local_name_hi": "लूनी",
    "basin": "luni-basin",
    "length_km_india": 495,
    "basin_area_india_km2": 37363,
    "drainage_type": "inland",
    "stream_order": 6,
    "seasonal_type": "seasonal",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "rajasthan",
      "gujarat"
    ],
    "aliases": [
      "Sagarmati"
    ],
    "bounds": [
      71.19828923224328,
      24.58746141897201,
      74.37350225120252,
      26.530231569575857
    ]
  },
  {
    "id": "ghaggar-hakra",
    "name": "Ghaggar-Hakra",
    "local_name_hi": "घग्गर-हकरा",
    "basin": "ghaggar-basin",
    "length_km_india": 320,
    "basin_area_india_km2": 42200,
    "drainage_type": "inland",
    "stream_order": 5,
    "seasonal_type": "ephemeral",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": true,
    "states": [
      "himachal-pradesh",
      "punjab",
      "haryana",
      "rajasthan"
    ],
    "aliases": [
      "Hakra",
      "Sarasvati"
    ],
    "bounds": [
      74.644285962054,
      29.47186992186666,
      77.09554217917423,
      30.80717061657729
    ]
  },
  {
    "id": "spiti",
    "name": "Spiti",
    "local_name_hi": "स्पीति",
    "basin": "indus-basin",
    "length_km_india": 182,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "glacial",
    "navigable": false,
    "transnational": false,
    "states": [
      "himachal-pradesh"
    ],
    "aliases": [],
    "bounds": [
      77.6625,
      31.80625,
      78.64375,
      32.61458
    ]
  },
  {
    "id": "burhi-gandak",
    "name": "Burhi Gandak",
    "local_name_hi": "बूढ़ी गंडक",
    "basin": "ganga-basin",
    "length_km_india": 441,
    "basin_area_india_km2": 10150,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "bihar"
    ],
    "aliases": [
      "Sikrahna",
      "Sikrana"
    ],
    "bounds": [
      84.39792,
      25.47708,
      86.57292,
      27.35
    ]
  },
  {
    "id": "jhelum",
    "name": "Jhelum",
    "local_name_hi": "झेलम",
    "basin": "indus-basin",
    "length_km_india": 228,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "spring-fed",
    "navigable": true,
    "transnational": true,
    "states": [
      "jammu-and-kashmir"
    ],
    "aliases": [
      "Vitasta",
      "Vyeth"
    ],
    "bounds": [
      74.04792,
      33.56875,
      75.50417,
      34.37708
    ]
  },
  {
    "id": "bagmati",
    "name": "Bagmati",
    "local_name_hi": "बागमती",
    "basin": "ganga-basin",
    "length_km_india": 201.5,
    "basin_area_india_km2": null,
    "drainage_type": "himalayan",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "spring-fed",
    "navigable": false,
    "transnational": true,
    "states": [
      "bihar"
    ],
    "aliases": [],
    "bounds": [
      85.26042,
      25.71042,
      86.31042,
      26.74375
    ]
  },
  {
    "id": "tamiraparani",
    "name": "Tamiraparani",
    "local_name_hi": "ताम्रपर्णी",
    "basin": "tamiraparani-basin",
    "length_km_india": 135.1,
    "basin_area_india_km2": 5717,
    "drainage_type": "peninsular",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "tamil-nadu"
    ],
    "aliases": [
      "Thamirabarani",
      "Porunai",
      "Tamraparni"
    ],
    "bounds": [
      77.24167,
      8.60625,
      78.10625,
      8.78125
    ]
  },
  {
    "id": "vaitarna",
    "name": "Vaitarna",
    "local_name_hi": "वैतरणा",
    "basin": "vaitarna-basin",
    "length_km_india": 149.2,
    "basin_area_india_km2": 3795,
    "drainage_type": "coastal",
    "stream_order": 5,
    "seasonal_type": "perennial",
    "origin_type": "rain-fed",
    "navigable": false,
    "transnational": false,
    "states": [
      "maharashtra"
    ],
    "aliases": [],
    "bounds": [
      72.78125,
      19.50625,
      73.54792,
      19.90833
    ]
  }
]
VMAPS_PATCH_EOF

mkdir -p "public/data"
cat > 'public/data/search-index-primary.json' << 'VMAPS_PATCH_EOF'
{"fuseVersion":"7.5.0","keys":[{"name":"name","weight":2},{"name":"aliases","weight":1}],"docs":[{"type":"river","id":"indus","name":"Indus","aliases":["Sindhu","Singi Khamban"],"length_km_india":709,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"chenab","name":"Chenab","aliases":["Chandrabhaga","Asikni"],"length_km_india":431.4,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"ravi","name":"Ravi","aliases":["Iravati","Purushni"],"length_km_india":725,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"beas","name":"Beas","aliases":["Vipasha","Vipas","Hyphasis"],"length_km_india":470,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"sutlej","name":"Sutlej","aliases":["Satluj","Satadru","Zungbal"],"length_km_india":1050,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"zanskar","name":"Zanskar","aliases":[],"length_km_india":134,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"shyok","name":"Shyok","aliases":["Shayok"],"length_km_india":400,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"ganga","name":"Ganga","aliases":["Ganges","Ganga Mata"],"length_km_india":2525,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"bhagirathi","name":"Bhagirathi","aliases":[],"length_km_india":229.1,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"alaknanda","name":"Alaknanda","aliases":[],"length_km_india":206.4,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"yamuna","name":"Yamuna","aliases":["Jamuna","Jumna"],"length_km_india":1376,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"chambal","name":"Chambal","aliases":["Charmanyavati"],"length_km_india":988.5,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"banas","name":"Banas","aliases":[],"length_km_india":550,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"kali-sindh","name":"Kali Sindh","aliases":["Kali Sindhu"],"length_km_india":550,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"parbati","name":"Parbati","aliases":[],"length_km_india":444.2,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"betwa","name":"Betwa","aliases":["Vetravati"],"length_km_india":590,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"ken","name":"Ken","aliases":["Karnavati"],"length_km_india":427,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"son","name":"Son","aliases":["Sone","Sonbhadra"],"length_km_india":784,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"gomti","name":"Gomti","aliases":["Gumti","Gomati"],"length_km_india":960,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"ghaghra","name":"Ghaghra (Karnali)","aliases":["Karnali","Manchu"],"length_km_india":503,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"sarda","name":"Sarda (Sharda)","aliases":["Kali","Mahakali"],"length_km_india":350,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"gandak","name":"Gandak","aliases":["Gandaki","Narayani","Sapt Gandaki"],"length_km_india":260,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"kosi","name":"Kosi","aliases":["Koshi","Saptakoshi","Sorrow of Bihar"],"length_km_india":260,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"mahananda","name":"Mahananda","aliases":[],"length_km_india":324,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"damodar","name":"Damodar","aliases":["River of Sorrows","Damuda"],"length_km_india":592,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"hooghly","name":"Hooghly","aliases":["Bhagirathi-Hooghly"],"length_km_india":260,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"barakar","name":"Barakar","aliases":[],"length_km_india":291.3,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"ajay","name":"Ajay","aliases":[],"length_km_india":308.4,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"brahmaputra","name":"Brahmaputra","aliases":["Tsangpo","Yarlung Tsangpo","Siang","Dihang"],"length_km_india":916,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"lohit","name":"Lohit","aliases":["Zayul Chu"],"length_km_india":200,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"subansiri","name":"Subansiri","aliases":["Gold River"],"length_km_india":382,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"kameng","name":"Kameng","aliases":["Jia Bharali","Bhareli"],"length_km_india":150,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"manas","name":"Manas","aliases":["Drangme Chhu"],"length_km_india":104,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"teesta","name":"Teesta","aliases":["Tista"],"length_km_india":414,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"rangeet","name":"Rangeet","aliases":["Rangit","Ranjit"],"length_km_india":65,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"torsa","name":"Torsa","aliases":["Amo Chhu","Machu"],"length_km_india":100,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"jaldhaka","name":"Jaldhaka","aliases":["Dichu"],"length_km_india":193,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"barak","name":"Barak","aliases":[],"length_km_india":100.3,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"kopili","name":"Kopili","aliases":["Kapili"],"length_km_india":333,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"mahanadi","name":"Mahanadi","aliases":[],"length_km_india":851,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"brahmani","name":"Brahmani","aliases":["South Koel"],"length_km_india":799,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"baitarani","name":"Baitarani","aliases":[],"length_km_india":414.3,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"subarnarekha","name":"Subarnarekha","aliases":[],"length_km_india":479.5,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"vamsadhara","name":"Vamsadhara","aliases":[],"length_km_india":287,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"nagavali","name":"Nagavali","aliases":["Langulya"],"length_km_india":250.4,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"godavari","name":"Godavari","aliases":["Dakshin Ganga"],"length_km_india":1465,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"krishna","name":"Krishna","aliases":["Krishnaveni"],"length_km_india":1400,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"tungabhadra","name":"Tungabhadra","aliases":["Pampa"],"length_km_india":552.5,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"bhima","name":"Bhima","aliases":["Chandrabhaga"],"length_km_india":864.5,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"musi","name":"Musi","aliases":["Muchukunda","Musunuru"],"length_km_india":296.2,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"manjira","name":"Manjira","aliases":["Manjra","Manjara"],"length_km_india":724,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"indravati","name":"Indravati","aliases":[],"length_km_india":489,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"pranhita","name":"Pranhita","aliases":[],"length_km_india":115.5,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"wainganga","name":"Wainganga","aliases":[],"length_km_india":629.8,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"wardha","name":"Wardha","aliases":[],"length_km_india":533.6,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"kaveri","name":"Kaveri","aliases":["Cauvery","Ponni"],"length_km_india":800,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"amaravathi","name":"Amaravathi","aliases":["Pournami"],"length_km_india":256,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"kabini","name":"Kabini","aliases":["Kabani","Kapila"],"length_km_india":240,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"hemavathi","name":"Hemavathi","aliases":[],"length_km_india":245,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"shimsha","name":"Shimsha","aliases":[],"length_km_india":221,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"arkavathi","name":"Arkavathi","aliases":[],"length_km_india":190,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"bhavani","name":"Bhavani","aliases":[],"length_km_india":234,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"palar","name":"Palar","aliases":[],"length_km_india":348,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"ponnaiyar","name":"Ponnaiyar","aliases":[],"length_km_india":497,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"vellar","name":"Vellar (Southern)","aliases":[],"length_km_india":137,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"vaigai","name":"Vaigai","aliases":[],"length_km_india":312.2,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"narmada","name":"Narmada","aliases":["Rewa"],"length_km_india":1312,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"tapi","name":"Tapi","aliases":["Tapti"],"length_km_india":779,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"mahi","name":"Mahi","aliases":[],"length_km_india":553.5,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"sabarmati","name":"Sabarmati","aliases":["Wakal"],"length_km_india":371,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"periyar","name":"Periyar","aliases":[],"length_km_india":244,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"bharathapuzha","name":"Bharathapuzha","aliases":["Nila","Ponnani River"],"length_km_india":99.9,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"pamba","name":"Pamba","aliases":["Baris","Dakshina Bhageerathi"],"length_km_india":176,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"kallada","name":"Kallada","aliases":[],"length_km_india":126.1,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"sharavati","name":"Sharavati","aliases":[],"length_km_india":134.2,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"zuari","name":"Zuari","aliases":["Aghanashini"],"length_km_india":92,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"mandovi","name":"Mandovi","aliases":["Mahadayi","Rio de Goa"],"length_km_india":81,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"ulhas","name":"Ulhas","aliases":[],"length_km_india":146,"drainage_type":"coastal","transnational":false},{"type":"river","id":"kali-karnataka","name":"Kali (Karnataka)","aliases":["Kali Nadi","Kalinadi"],"length_km_india":178.7,"drainage_type":"coastal","transnational":false},{"type":"river","id":"netravati","name":"Netravati","aliases":[],"length_km_india":115.7,"drainage_type":"coastal","transnational":false},{"type":"river","id":"aghanashini","name":"Aghanashini","aliases":["Tadadi Hole"],"length_km_india":117,"drainage_type":"coastal","transnational":false},{"type":"river","id":"damanganga","name":"Damanganga","aliases":["Dawan River"],"length_km_india":131,"drainage_type":"coastal","transnational":false},{"type":"river","id":"vaippar","name":"Vaippar","aliases":[],"length_km_india":86.5,"drainage_type":"coastal","transnational":false},{"type":"river","id":"luni","name":"Luni","aliases":["Sagarmati"],"length_km_india":495,"drainage_type":"inland","transnational":false},{"type":"river","id":"ghaggar-hakra","name":"Ghaggar-Hakra","aliases":["Hakra","Sarasvati"],"length_km_india":320,"drainage_type":"inland","transnational":true},{"type":"river","id":"spiti","name":"Spiti","aliases":[],"length_km_india":182,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"burhi-gandak","name":"Burhi Gandak","aliases":["Sikrahna","Sikrana"],"length_km_india":441,"drainage_type":"himalayan","transnational":false},{"type":"river","id":"jhelum","name":"Jhelum","aliases":["Vitasta","Vyeth"],"length_km_india":228,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"bagmati","name":"Bagmati","aliases":[],"length_km_india":201.5,"drainage_type":"himalayan","transnational":true},{"type":"river","id":"tamiraparani","name":"Tamiraparani","aliases":["Thamirabarani","Porunai","Tamraparni"],"length_km_india":135.1,"drainage_type":"peninsular","transnational":false},{"type":"river","id":"vaitarna","name":"Vaitarna","aliases":[],"length_km_india":149.2,"drainage_type":"coastal","transnational":false},{"type":"state","id":"andaman-and-nicobar-islands","name":"Andaman and Nicobar Islands","capital":"Port Blair","admin_type":"ut"},{"type":"state","id":"andhra-pradesh","name":"Andhra Pradesh","capital":"Amaravati","admin_type":"state"},{"type":"state","id":"arunachal-pradesh","name":"Arunachal Pradesh","capital":"Itanagar","admin_type":"state"},{"type":"state","id":"assam","name":"Assam","capital":"Dispur","admin_type":"state"},{"type":"state","id":"bihar","name":"Bihar","capital":"Patna","admin_type":"state"},{"type":"state","id":"chandigarh","name":"Chandigarh","capital":"Chandigarh","admin_type":"ut"},{"type":"state","id":"chhattisgarh","name":"Chhattisgarh","capital":"Raipur","admin_type":"state"},{"type":"state","id":"dadra-and-nagar-haveli-and-daman-and-diu","name":"Dadra and Nagar Haveli and Daman and Diu","capital":"Daman","admin_type":"ut"},{"type":"state","id":"delhi","name":"Delhi","capital":"New Delhi","admin_type":"ut"},{"type":"state","id":"goa","name":"Goa","capital":"Panaji","admin_type":"state"},{"type":"state","id":"gujarat","name":"Gujarat","capital":"Gandhinagar","admin_type":"state"},{"type":"state","id":"haryana","name":"Haryana","capital":"Chandigarh","admin_type":"state"},{"type":"state","id":"himachal-pradesh","name":"Himachal Pradesh","capital":"Shimla","admin_type":"state"},{"type":"state","id":"jammu-and-kashmir","name":"Jammu and Kashmir","capital":"Srinagar","admin_type":"ut"},{"type":"state","id":"jharkhand","name":"Jharkhand","capital":"Ranchi","admin_type":"state"},{"type":"state","id":"karnataka","name":"Karnataka","capital":"Bengaluru","admin_type":"state"},{"type":"state","id":"kerala","name":"Kerala","capital":"Thiruvananthapuram","admin_type":"state"},{"type":"state","id":"ladakh","name":"Ladakh","capital":"Leh","admin_type":"ut"},{"type":"state","id":"lakshadweep","name":"Lakshadweep","capital":"Kavaratti","admin_type":"ut"},{"type":"state","id":"madhya-pradesh","name":"Madhya Pradesh","capital":"Bhopal","admin_type":"state"},{"type":"state","id":"maharashtra","name":"Maharashtra","capital":"Mumbai","admin_type":"state"},{"type":"state","id":"manipur","name":"Manipur","capital":"Imphal","admin_type":"state"},{"type":"state","id":"meghalaya","name":"Meghalaya","capital":"Shillong","admin_type":"state"},{"type":"state","id":"mizoram","name":"Mizoram","capital":"Aizawl","admin_type":"state"},{"type":"state","id":"nagaland","name":"Nagaland","capital":"Kohima","admin_type":"state"},{"type":"state","id":"odisha","name":"Odisha","capital":"Bhubaneswar","admin_type":"state"},{"type":"state","id":"puducherry","name":"Puducherry","capital":"Puducherry","admin_type":"ut"},{"type":"state","id":"punjab","name":"Punjab","capital":"Chandigarh","admin_type":"state"},{"type":"state","id":"rajasthan","name":"Rajasthan","capital":"Jaipur","admin_type":"state"},{"type":"state","id":"sikkim","name":"Sikkim","capital":"Gangtok","admin_type":"state"},{"type":"state","id":"tamil-nadu","name":"Tamil Nadu","capital":"Chennai","admin_type":"state"},{"type":"state","id":"telangana","name":"Telangana","capital":"Hyderabad","admin_type":"state"},{"type":"state","id":"tripura","name":"Tripura","capital":"Agartala","admin_type":"state"},{"type":"state","id":"uttar-pradesh","name":"Uttar Pradesh","capital":"Lucknow","admin_type":"state"},{"type":"state","id":"uttarakhand","name":"Uttarakhand","capital":"Dehradun","admin_type":"state"},{"type":"state","id":"west-bengal","name":"West Bengal","capital":"Kolkata","admin_type":"state"}],"index":{"keys":[{"path":["name"],"id":"name","weight":2,"src":"name"},{"path":["aliases"],"id":"aliases","weight":1,"src":"aliases"}],"records":[{"i":0,"$":{"0":{"v":"Indus","n":1},"1":[{"v":"Sindhu","i":0,"n":1},{"v":"Singi Khamban","i":1,"n":0.707}]}},{"i":1,"$":{"0":{"v":"Chenab","n":1},"1":[{"v":"Chandrabhaga","i":0,"n":1},{"v":"Asikni","i":1,"n":1}]}},{"i":2,"$":{"0":{"v":"Ravi","n":1},"1":[{"v":"Iravati","i":0,"n":1},{"v":"Purushni","i":1,"n":1}]}},{"i":3,"$":{"0":{"v":"Beas","n":1},"1":[{"v":"Vipasha","i":0,"n":1},{"v":"Vipas","i":1,"n":1},{"v":"Hyphasis","i":2,"n":1}]}},{"i":4,"$":{"0":{"v":"Sutlej","n":1},"1":[{"v":"Satluj","i":0,"n":1},{"v":"Satadru","i":1,"n":1},{"v":"Zungbal","i":2,"n":1}]}},{"i":5,"$":{"0":{"v":"Zanskar","n":1},"1":[]}},{"i":6,"$":{"0":{"v":"Shyok","n":1},"1":[{"v":"Shayok","i":0,"n":1}]}},{"i":7,"$":{"0":{"v":"Ganga","n":1},"1":[{"v":"Ganges","i":0,"n":1},{"v":"Ganga Mata","i":1,"n":0.707}]}},{"i":8,"$":{"0":{"v":"Bhagirathi","n":1},"1":[]}},{"i":9,"$":{"0":{"v":"Alaknanda","n":1},"1":[]}},{"i":10,"$":{"0":{"v":"Yamuna","n":1},"1":[{"v":"Jamuna","i":0,"n":1},{"v":"Jumna","i":1,"n":1}]}},{"i":11,"$":{"0":{"v":"Chambal","n":1},"1":[{"v":"Charmanyavati","i":0,"n":1}]}},{"i":12,"$":{"0":{"v":"Banas","n":1},"1":[]}},{"i":13,"$":{"0":{"v":"Kali Sindh","n":0.707},"1":[{"v":"Kali Sindhu","i":0,"n":0.707}]}},{"i":14,"$":{"0":{"v":"Parbati","n":1},"1":[]}},{"i":15,"$":{"0":{"v":"Betwa","n":1},"1":[{"v":"Vetravati","i":0,"n":1}]}},{"i":16,"$":{"0":{"v":"Ken","n":1},"1":[{"v":"Karnavati","i":0,"n":1}]}},{"i":17,"$":{"0":{"v":"Son","n":1},"1":[{"v":"Sone","i":0,"n":1},{"v":"Sonbhadra","i":1,"n":1}]}},{"i":18,"$":{"0":{"v":"Gomti","n":1},"1":[{"v":"Gumti","i":0,"n":1},{"v":"Gomati","i":1,"n":1}]}},{"i":19,"$":{"0":{"v":"Ghaghra (Karnali)","n":0.707},"1":[{"v":"Karnali","i":0,"n":1},{"v":"Manchu","i":1,"n":1}]}},{"i":20,"$":{"0":{"v":"Sarda (Sharda)","n":0.707},"1":[{"v":"Kali","i":0,"n":1},{"v":"Mahakali","i":1,"n":1}]}},{"i":21,"$":{"0":{"v":"Gandak","n":1},"1":[{"v":"Gandaki","i":0,"n":1},{"v":"Narayani","i":1,"n":1},{"v":"Sapt Gandaki","i":2,"n":0.707}]}},{"i":22,"$":{"0":{"v":"Kosi","n":1},"1":[{"v":"Koshi","i":0,"n":1},{"v":"Saptakoshi","i":1,"n":1},{"v":"Sorrow of Bihar","i":2,"n":0.577}]}},{"i":23,"$":{"0":{"v":"Mahananda","n":1},"1":[]}},{"i":24,"$":{"0":{"v":"Damodar","n":1},"1":[{"v":"River of Sorrows","i":0,"n":0.577},{"v":"Damuda","i":1,"n":1}]}},{"i":25,"$":{"0":{"v":"Hooghly","n":1},"1":[{"v":"Bhagirathi-Hooghly","i":0,"n":1}]}},{"i":26,"$":{"0":{"v":"Barakar","n":1},"1":[]}},{"i":27,"$":{"0":{"v":"Ajay","n":1},"1":[]}},{"i":28,"$":{"0":{"v":"Brahmaputra","n":1},"1":[{"v":"Tsangpo","i":0,"n":1},{"v":"Yarlung Tsangpo","i":1,"n":0.707},{"v":"Siang","i":2,"n":1},{"v":"Dihang","i":3,"n":1}]}},{"i":29,"$":{"0":{"v":"Lohit","n":1},"1":[{"v":"Zayul Chu","i":0,"n":0.707}]}},{"i":30,"$":{"0":{"v":"Subansiri","n":1},"1":[{"v":"Gold River","i":0,"n":0.707}]}},{"i":31,"$":{"0":{"v":"Kameng","n":1},"1":[{"v":"Jia Bharali","i":0,"n":0.707},{"v":"Bhareli","i":1,"n":1}]}},{"i":32,"$":{"0":{"v":"Manas","n":1},"1":[{"v":"Drangme Chhu","i":0,"n":0.707}]}},{"i":33,"$":{"0":{"v":"Teesta","n":1},"1":[{"v":"Tista","i":0,"n":1}]}},{"i":34,"$":{"0":{"v":"Rangeet","n":1},"1":[{"v":"Rangit","i":0,"n":1},{"v":"Ranjit","i":1,"n":1}]}},{"i":35,"$":{"0":{"v":"Torsa","n":1},"1":[{"v":"Amo Chhu","i":0,"n":0.707},{"v":"Machu","i":1,"n":1}]}},{"i":36,"$":{"0":{"v":"Jaldhaka","n":1},"1":[{"v":"Dichu","i":0,"n":1}]}},{"i":37,"$":{"0":{"v":"Barak","n":1},"1":[]}},{"i":38,"$":{"0":{"v":"Kopili","n":1},"1":[{"v":"Kapili","i":0,"n":1}]}},{"i":39,"$":{"0":{"v":"Mahanadi","n":1},"1":[]}},{"i":40,"$":{"0":{"v":"Brahmani","n":1},"1":[{"v":"South Koel","i":0,"n":0.707}]}},{"i":41,"$":{"0":{"v":"Baitarani","n":1},"1":[]}},{"i":42,"$":{"0":{"v":"Subarnarekha","n":1},"1":[]}},{"i":43,"$":{"0":{"v":"Vamsadhara","n":1},"1":[]}},{"i":44,"$":{"0":{"v":"Nagavali","n":1},"1":[{"v":"Langulya","i":0,"n":1}]}},{"i":45,"$":{"0":{"v":"Godavari","n":1},"1":[{"v":"Dakshin Ganga","i":0,"n":0.707}]}},{"i":46,"$":{"0":{"v":"Krishna","n":1},"1":[{"v":"Krishnaveni","i":0,"n":1}]}},{"i":47,"$":{"0":{"v":"Tungabhadra","n":1},"1":[{"v":"Pampa","i":0,"n":1}]}},{"i":48,"$":{"0":{"v":"Bhima","n":1},"1":[{"v":"Chandrabhaga","i":0,"n":1}]}},{"i":49,"$":{"0":{"v":"Musi","n":1},"1":[{"v":"Muchukunda","i":0,"n":1},{"v":"Musunuru","i":1,"n":1}]}},{"i":50,"$":{"0":{"v":"Manjira","n":1},"1":[{"v":"Manjra","i":0,"n":1},{"v":"Manjara","i":1,"n":1}]}},{"i":51,"$":{"0":{"v":"Indravati","n":1},"1":[]}},{"i":52,"$":{"0":{"v":"Pranhita","n":1},"1":[]}},{"i":53,"$":{"0":{"v":"Wainganga","n":1},"1":[]}},{"i":54,"$":{"0":{"v":"Wardha","n":1},"1":[]}},{"i":55,"$":{"0":{"v":"Kaveri","n":1},"1":[{"v":"Cauvery","i":0,"n":1},{"v":"Ponni","i":1,"n":1}]}},{"i":56,"$":{"0":{"v":"Amaravathi","n":1},"1":[{"v":"Pournami","i":0,"n":1}]}},{"i":57,"$":{"0":{"v":"Kabini","n":1},"1":[{"v":"Kabani","i":0,"n":1},{"v":"Kapila","i":1,"n":1}]}},{"i":58,"$":{"0":{"v":"Hemavathi","n":1},"1":[]}},{"i":59,"$":{"0":{"v":"Shimsha","n":1},"1":[]}},{"i":60,"$":{"0":{"v":"Arkavathi","n":1},"1":[]}},{"i":61,"$":{"0":{"v":"Bhavani","n":1},"1":[]}},{"i":62,"$":{"0":{"v":"Palar","n":1},"1":[]}},{"i":63,"$":{"0":{"v":"Ponnaiyar","n":1},"1":[]}},{"i":64,"$":{"0":{"v":"Vellar (Southern)","n":0.707},"1":[]}},{"i":65,"$":{"0":{"v":"Vaigai","n":1},"1":[]}},{"i":66,"$":{"0":{"v":"Narmada","n":1},"1":[{"v":"Rewa","i":0,"n":1}]}},{"i":67,"$":{"0":{"v":"Tapi","n":1},"1":[{"v":"Tapti","i":0,"n":1}]}},{"i":68,"$":{"0":{"v":"Mahi","n":1},"1":[]}},{"i":69,"$":{"0":{"v":"Sabarmati","n":1},"1":[{"v":"Wakal","i":0,"n":1}]}},{"i":70,"$":{"0":{"v":"Periyar","n":1},"1":[]}},{"i":71,"$":{"0":{"v":"Bharathapuzha","n":1},"1":[{"v":"Nila","i":0,"n":1},{"v":"Ponnani River","i":1,"n":0.707}]}},{"i":72,"$":{"0":{"v":"Pamba","n":1},"1":[{"v":"Baris","i":0,"n":1},{"v":"Dakshina Bhageerathi","i":1,"n":0.707}]}},{"i":73,"$":{"0":{"v":"Kallada","n":1},"1":[]}},{"i":74,"$":{"0":{"v":"Sharavati","n":1},"1":[]}},{"i":75,"$":{"0":{"v":"Zuari","n":1},"1":[{"v":"Aghanashini","i":0,"n":1}]}},{"i":76,"$":{"0":{"v":"Mandovi","n":1},"1":[{"v":"Mahadayi","i":0,"n":1},{"v":"Rio de Goa","i":1,"n":0.577}]}},{"i":77,"$":{"0":{"v":"Ulhas","n":1},"1":[]}},{"i":78,"$":{"0":{"v":"Kali (Karnataka)","n":0.707},"1":[{"v":"Kali Nadi","i":0,"n":0.707},{"v":"Kalinadi","i":1,"n":1}]}},{"i":79,"$":{"0":{"v":"Netravati","n":1},"1":[]}},{"i":80,"$":{"0":{"v":"Aghanashini","n":1},"1":[{"v":"Tadadi Hole","i":0,"n":0.707}]}},{"i":81,"$":{"0":{"v":"Damanganga","n":1},"1":[{"v":"Dawan River","i":0,"n":0.707}]}},{"i":82,"$":{"0":{"v":"Vaippar","n":1},"1":[]}},{"i":83,"$":{"0":{"v":"Luni","n":1},"1":[{"v":"Sagarmati","i":0,"n":1}]}},{"i":84,"$":{"0":{"v":"Ghaggar-Hakra","n":1},"1":[{"v":"Hakra","i":0,"n":1},{"v":"Sarasvati","i":1,"n":1}]}},{"i":85,"$":{"0":{"v":"Spiti","n":1},"1":[]}},{"i":86,"$":{"0":{"v":"Burhi Gandak","n":0.707},"1":[{"v":"Sikrahna","i":0,"n":1},{"v":"Sikrana","i":1,"n":1}]}},{"i":87,"$":{"0":{"v":"Jhelum","n":1},"1":[{"v":"Vitasta","i":0,"n":1},{"v":"Vyeth","i":1,"n":1}]}},{"i":88,"$":{"0":{"v":"Bagmati","n":1},"1":[]}},{"i":89,"$":{"0":{"v":"Tamiraparani","n":1},"1":[{"v":"Thamirabarani","i":0,"n":1},{"v":"Porunai","i":1,"n":1},{"v":"Tamraparni","i":2,"n":1}]}},{"i":90,"$":{"0":{"v":"Vaitarna","n":1},"1":[]}},{"i":91,"$":{"0":{"v":"Andaman and Nicobar Islands","n":0.5}}},{"i":92,"$":{"0":{"v":"Andhra Pradesh","n":0.707}}},{"i":93,"$":{"0":{"v":"Arunachal Pradesh","n":0.707}}},{"i":94,"$":{"0":{"v":"Assam","n":1}}},{"i":95,"$":{"0":{"v":"Bihar","n":1}}},{"i":96,"$":{"0":{"v":"Chandigarh","n":1}}},{"i":97,"$":{"0":{"v":"Chhattisgarh","n":1}}},{"i":98,"$":{"0":{"v":"Dadra and Nagar Haveli and Daman and Diu","n":0.354}}},{"i":99,"$":{"0":{"v":"Delhi","n":1}}},{"i":100,"$":{"0":{"v":"Goa","n":1}}},{"i":101,"$":{"0":{"v":"Gujarat","n":1}}},{"i":102,"$":{"0":{"v":"Haryana","n":1}}},{"i":103,"$":{"0":{"v":"Himachal Pradesh","n":0.707}}},{"i":104,"$":{"0":{"v":"Jammu and Kashmir","n":0.577}}},{"i":105,"$":{"0":{"v":"Jharkhand","n":1}}},{"i":106,"$":{"0":{"v":"Karnataka","n":1}}},{"i":107,"$":{"0":{"v":"Kerala","n":1}}},{"i":108,"$":{"0":{"v":"Ladakh","n":1}}},{"i":109,"$":{"0":{"v":"Lakshadweep","n":1}}},{"i":110,"$":{"0":{"v":"Madhya Pradesh","n":0.707}}},{"i":111,"$":{"0":{"v":"Maharashtra","n":1}}},{"i":112,"$":{"0":{"v":"Manipur","n":1}}},{"i":113,"$":{"0":{"v":"Meghalaya","n":1}}},{"i":114,"$":{"0":{"v":"Mizoram","n":1}}},{"i":115,"$":{"0":{"v":"Nagaland","n":1}}},{"i":116,"$":{"0":{"v":"Odisha","n":1}}},{"i":117,"$":{"0":{"v":"Puducherry","n":1}}},{"i":118,"$":{"0":{"v":"Punjab","n":1}}},{"i":119,"$":{"0":{"v":"Rajasthan","n":1}}},{"i":120,"$":{"0":{"v":"Sikkim","n":1}}},{"i":121,"$":{"0":{"v":"Tamil Nadu","n":0.707}}},{"i":122,"$":{"0":{"v":"Telangana","n":1}}},{"i":123,"$":{"0":{"v":"Tripura","n":1}}},{"i":124,"$":{"0":{"v":"Uttar Pradesh","n":0.707}}},{"i":125,"$":{"0":{"v":"Uttarakhand","n":1}}},{"i":126,"$":{"0":{"v":"West Bengal","n":0.707}}}]}}
VMAPS_PATCH_EOF

mkdir -p "public/data"
cat > 'public/data/states.json' << 'VMAPS_PATCH_EOF'
[
  {
    "id": "andaman-and-nicobar-islands",
    "name": "Andaman and Nicobar Islands",
    "admin_type": "ut",
    "capital": "Port Blair",
    "rivers_flowing_through": [],
    "basin_rivers": [],
    "notable_city_ids": [],
    "protected_area_ids": [
      "arial-island-wls",
      "bamboo-island-wls",
      "barren-island-wls",
      "battimalv-island-wls",
      "belle-island-wls",
      "benett-island-wls",
      "bingham-island-wls",
      "blister-island-wls",
      "bluff-island-wls",
      "bondoville-island-wls",
      "brush-island-wls",
      "buchanan-island-wls",
      "campbell-bay-np",
      "chanel-island-wls",
      "cinque-island-wls",
      "clyde-island-wls",
      "cone-island-wls",
      "curlew-b-p-island-wls",
      "curlew-island-wls",
      "cuthbert-bay-wls",
      "defence-island-wls",
      "dot-island-wls",
      "dottrell-island-wls",
      "duncan-island-wls",
      "east-island-wls",
      "east-of-inglis-island-wls",
      "egg-island-wls",
      "elat-island-wls",
      "entrance-island-wls",
      "galathea-bay-wls",
      "galathea-np",
      "gander-island-wls",
      "girjan-island-wls",
      "goose-island-wls",
      "great-nicobar-br",
      "hump-island-wls",
      "interview-island-wls",
      "james-island-wls",
      "jungle-island-wls",
      "kwangtung-island-wls",
      "kyd-island-wls",
      "landfall-island-wls",
      "latouche-island-wls",
      "lohabarrack-saltwater-crocodile-wls",
      "mahatma-gandhi-marine-wandoor-np",
      "mangrove-island-wls",
      "mask-island-wls",
      "mayo-island-wls",
      "megapode-island-wls",
      "montogemery-island-wls",
      "mount-harriett-np",
      "narcondam-island-wls",
      "north-brother-island-wls",
      "north-island-wls",
      "north-reef-island-wls",
      "oliver-island-wls",
      "orchid-island-wls",
      "ox-island-wls",
      "oyster-island-i-wls",
      "oyster-island-ii-wls",
      "paget-island-wls",
      "parkinson-island-wls",
      "passage-island-wls",
      "patric-island-wls",
      "peacock-island-wls",
      "pitman-island-wls",
      "point-island-wls",
      "potanma-islands-wls",
      "ranger-island-wls",
      "rani-jhansi-marine-np",
      "reef-island-wls",
      "roper-island-wls",
      "ross-island-wls",
      "rowe-island-wls",
      "saddle-peak-np",
      "sandy-island-wls",
      "sea-serpent-island-wls",
      "shark-island-wls",
      "shearme-island-wls",
      "sir-hugh-rose-island-wls",
      "sister-island-wls",
      "snake-island-i-wls",
      "snake-island-ii-wls",
      "south-brother-island-wls",
      "south-reef-island-wls",
      "south-sentinel-island-wls",
      "spike-island-i-wls",
      "spike-island-ii-wls",
      "stoat-island-wls",
      "surat-island-wls",
      "swamp-island-wls",
      "table-delgarno-island-wls",
      "table-excelsior-island-wls",
      "talabaicha-island-wls",
      "temple-island-wls",
      "tilongchang-island-wls",
      "tree-island-wls",
      "trilby-island-wls",
      "tuft-island-wls",
      "turtle-islands-wls",
      "west-island-wls",
      "wharf-island-wls",
      "white-cliff-island-wls"
    ]
  },
  {
    "id": "andhra-pradesh",
    "name": "Andhra Pradesh",
    "admin_type": "state",
    "capital": "Amaravati",
    "rivers_flowing_through": [
      "godavari",
      "krishna",
      "nagavali",
      "palar",
      "tungabhadra",
      "vamsadhara"
    ],
    "basin_rivers": [
      "godavari",
      "krishna",
      "nagavali",
      "palar",
      "tungabhadra",
      "vamsadhara"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "coringa-wls",
      "gundla-brahmeswaram-wls",
      "kambalkonda-wls",
      "kaundinya-wls",
      "kolleru-lake-ramsar",
      "kolleru-wls",
      "krishna-wls",
      "nagarjunasagar-srisailam-tr",
      "nagarjunasagar-srisailam-wls",
      "nellapattu-wls",
      "papikonda-np",
      "rajiv-gandhi-rameswaram-np",
      "rollapadu-wls",
      "seshachalam-hills-br",
      "sri-lankamalleswaram-wls",
      "sri-penusila-narasimha-wls",
      "sri-venkateswara-np",
      "sri-venkateswara-wls"
    ]
  },
  {
    "id": "arunachal-pradesh",
    "name": "Arunachal Pradesh",
    "admin_type": "state",
    "capital": "Itanagar",
    "rivers_flowing_through": [
      "brahmaputra",
      "kameng",
      "lohit",
      "subansiri"
    ],
    "basin_rivers": [
      "brahmaputra",
      "kameng",
      "lohit",
      "subansiri"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "d-ering-memorial-lali-wls",
      "dibang-wls",
      "dihang-dibang-br",
      "eagle-nest-wls",
      "itanagar-wls",
      "kamlang-tr",
      "kamlang-wls",
      "kane-wls",
      "mehao-wls",
      "mouling-np",
      "namdapha-np",
      "namdapha-tr",
      "pakhui-wls",
      "pakke-tr",
      "sessa-orchid-wls",
      "tale-valley-wls",
      "yordi-rabe-supse-wls"
    ]
  },
  {
    "id": "assam",
    "name": "Assam",
    "admin_type": "state",
    "capital": "Dispur",
    "rivers_flowing_through": [
      "barak",
      "brahmaputra",
      "kameng",
      "kopili",
      "lohit",
      "manas",
      "subansiri"
    ],
    "basin_rivers": [
      "barak",
      "brahmaputra",
      "kameng",
      "kopili",
      "lohit",
      "manas",
      "subansiri"
    ],
    "notable_city_ids": [
      "guwahati"
    ],
    "protected_area_ids": [
      "amchang-wls",
      "barail-wls",
      "barnadi-wls",
      "bherjan-borajan-podumoni-wls",
      "burachapori-wls",
      "chakrashila-wls",
      "deepar-beel-wls",
      "deepor-beel-ramsar",
      "dehing-patkai-np",
      "dibru-saikhowa-br",
      "dibru-saikhowa-np",
      "dihing-patkai-wls",
      "east-karbi-anglong-wls",
      "garampani-wls",
      "hallongapara-gibbon-wls",
      "kaziranga-np",
      "kaziranga-tr",
      "lawkhowa-wls",
      "manas-br",
      "manas-np",
      "manas-tr",
      "marat-longri-wls",
      "nambor-doigrung-wls",
      "nambor-wls",
      "nameri-np",
      "nameri-tr",
      "orang-np",
      "orang-tr",
      "pabitora-wls",
      "pani-dihing-wls",
      "raimona-np",
      "sikhna-jwhwlao-np",
      "sonai-rupai-wls"
    ]
  },
  {
    "id": "bihar",
    "name": "Bihar",
    "admin_type": "state",
    "capital": "Patna",
    "rivers_flowing_through": [
      "ajay",
      "bagmati",
      "burhi-gandak",
      "gandak",
      "ganga",
      "ghaghra",
      "kosi",
      "mahananda",
      "son"
    ],
    "basin_rivers": [
      "ajay",
      "bagmati",
      "burhi-gandak",
      "gandak",
      "ganga",
      "ghaghra",
      "kosi",
      "mahananda",
      "son"
    ],
    "notable_city_ids": [
      "patna"
    ],
    "protected_area_ids": [
      "barela-s-a-z-s-wls",
      "bhimbandh-wls",
      "gogabil-lake-ramsar",
      "gokul-jalashay-ramsar",
      "kabartal-wetland-ramsar",
      "kanwarjheel-wls",
      "kusheshwar-sthan-wls",
      "nagi-dam-wls",
      "nagi-ramsar",
      "nakti-dam-wls",
      "nakti-ramsar",
      "pant-rajgir-wls",
      "udaipur-jheel-ramsar",
      "udaypur-wls",
      "valmiki-np",
      "valmiki-tr",
      "valmiki-wls",
      "vikramshila-gangetic-dolphin-wls"
    ]
  },
  {
    "id": "chandigarh",
    "name": "Chandigarh",
    "admin_type": "ut",
    "capital": "Chandigarh",
    "rivers_flowing_through": [],
    "basin_rivers": [],
    "notable_city_ids": [],
    "protected_area_ids": [
      "city-bird-wildlife-sanctuary-wls",
      "sukna-lake-wildlife-sanctuary-wls"
    ]
  },
  {
    "id": "chhattisgarh",
    "name": "Chhattisgarh",
    "admin_type": "state",
    "capital": "Raipur",
    "rivers_flowing_through": [
      "godavari",
      "indravati",
      "mahanadi",
      "narmada",
      "son"
    ],
    "basin_rivers": [
      "godavari",
      "indravati",
      "mahanadi",
      "narmada",
      "son"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "achanakmar-amarkantak-br",
      "achanakmar-tr",
      "achanakmar-wls",
      "badalkhol-wls",
      "barnawapara-wls",
      "bhairamgarh-wls",
      "bhoramdev-wls",
      "gomardha-wls",
      "guru-ghasidas-sanjay-np",
      "guru-ghasidas-tamor-pingla-tr",
      "indravati-np",
      "indravati-tr",
      "kanger-ghati-np",
      "kopra-jalashay-ramsar",
      "pamed-wls",
      "semarsot-wls",
      "sitanadi-wls",
      "tamorpingla-wls",
      "udanti-sitanadi-tr",
      "udanti-wild-buffalo-wls"
    ]
  },
  {
    "id": "dadra-and-nagar-haveli-and-daman-and-diu",
    "name": "Dadra and Nagar Haveli and Daman and Diu",
    "admin_type": "ut",
    "capital": "Daman",
    "rivers_flowing_through": [
      "damanganga"
    ],
    "basin_rivers": [
      "damanganga"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "dadra-nagar-haveli-wls",
      "fudam-wls"
    ]
  },
  {
    "id": "delhi",
    "name": "Delhi",
    "admin_type": "ut",
    "capital": "New Delhi",
    "rivers_flowing_through": [
      "yamuna"
    ],
    "basin_rivers": [
      "yamuna"
    ],
    "notable_city_ids": [
      "delhi"
    ],
    "protected_area_ids": [
      "asola-bhati-indira-priyadarshini-wls"
    ]
  },
  {
    "id": "goa",
    "name": "Goa",
    "admin_type": "state",
    "capital": "Panaji",
    "rivers_flowing_through": [
      "mandovi",
      "zuari"
    ],
    "basin_rivers": [
      "mandovi",
      "zuari"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "bhagwan-mahavir-np",
      "bhagwan-mahavir-wls",
      "bondla-wls",
      "chorao-island-dr-salim-ali-wls",
      "cotigaon-wls",
      "madei-wls",
      "nanda-lake-ramsar",
      "netravali-wls"
    ]
  },
  {
    "id": "gujarat",
    "name": "Gujarat",
    "admin_type": "state",
    "capital": "Gandhinagar",
    "rivers_flowing_through": [
      "damanganga",
      "luni",
      "mahi",
      "narmada",
      "sabarmati",
      "tapi"
    ],
    "basin_rivers": [
      "damanganga",
      "luni",
      "mahi",
      "narmada",
      "sabarmati",
      "tapi"
    ],
    "notable_city_ids": [
      "ahmedabad"
    ],
    "protected_area_ids": [
      "balaram-ambaji-wls",
      "barda-wls",
      "blackbuck-np",
      "chhari-dhand-wetland-conservation-reserve-ramsar",
      "gaga-great-indian-bustard-wls",
      "gir-np",
      "gir-wls",
      "girnar-wls",
      "great-rann-of-kutch-br",
      "hingolgarh-nature-reserve-wls",
      "jambugodha-wls",
      "jessore-wls",
      "kachchh-desert-wls",
      "khijadia-wildlife-sanctuary-ramsar",
      "khijadiya-wls",
      "lala-great-indian-bustard-wls",
      "marine-gulf-of-kachchh-np",
      "marine-gulf-of-kachchh-wls",
      "mitiyala-wls",
      "nal-sarovar-wls",
      "nalsarovar-bird-sanctuary-ramsar",
      "narayan-sarovar-wls",
      "paniya-wls",
      "porbandar-lake-wls",
      "purna-wls",
      "rampura-vidi-wls",
      "ratanmahal-sloth-bear-wls",
      "shoolpaneswar-dhumkhal-wls",
      "thol-lake-wildlife-sanctuary-ramsar",
      "thol-lake-wls",
      "vansda-np",
      "wadhvana-wetland-ramsar",
      "wild-ass-wls"
    ]
  },
  {
    "id": "haryana",
    "name": "Haryana",
    "admin_type": "state",
    "capital": "Chandigarh",
    "rivers_flowing_through": [
      "ghaggar-hakra",
      "yamuna"
    ],
    "basin_rivers": [
      "ghaggar-hakra",
      "yamuna"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "abubshehar-wls",
      "bhindawas-wildlife-sanctuary-ramsar",
      "bhindawas-wls",
      "bir-shikargarh-wls",
      "chhilchila-wls",
      "kalesar-np",
      "kalesar-wls",
      "khaparwas-wls",
      "morni-hills-khol-hi-raitan-wls",
      "nahar-wls",
      "sultanpur-national-park-ramsar",
      "sultanpur-np"
    ]
  },
  {
    "id": "himachal-pradesh",
    "name": "Himachal Pradesh",
    "admin_type": "state",
    "capital": "Shimla",
    "rivers_flowing_through": [
      "beas",
      "chenab",
      "ghaggar-hakra",
      "ravi",
      "spiti",
      "sutlej",
      "yamuna"
    ],
    "basin_rivers": [
      "beas",
      "chenab",
      "ghaggar-hakra",
      "ravi",
      "spiti",
      "sutlej",
      "yamuna"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "bandli-wls",
      "chail-wls",
      "chandartal-wls",
      "chandertal-wetland-ramsar",
      "churdhar-wls",
      "cold-desert-br",
      "daranghati-wls",
      "darlaghat-wls",
      "dhauladhar-wls",
      "gamgul-siahbehi-wls",
      "govind-sagar-wls",
      "great-himalayan-national-park-np",
      "inderkilla-national-park-np",
      "kais-wls",
      "kalatop-khajjiar-wls",
      "kanawar-wls",
      "khirganga-national-park-np",
      "khokhan-wls",
      "kibber-wls",
      "kugti-wls",
      "lippa-asrang-wls",
      "majathal-wls",
      "manali-wls",
      "nargu-wls",
      "pin-valley-national-park-np",
      "pong-dam-lake-ramsar",
      "pong-dam-lake-wls",
      "rakchham-chitkul-sangla-valley-wls",
      "renuka-wetland-ramsar",
      "renukaji-wls",
      "rupi-bhaba-wls",
      "sainj-wls",
      "sechu-tuan-nala-wls",
      "shikari-devi-wls",
      "shilli-wls",
      "shimla-water-catchment-wls",
      "shri-naina-devi-wls",
      "sim-balbara-national-park-np",
      "talra-wls",
      "tirthan-wls",
      "tundah-wls"
    ]
  },
  {
    "id": "jammu-and-kashmir",
    "name": "Jammu and Kashmir",
    "admin_type": "ut",
    "capital": "Srinagar",
    "rivers_flowing_through": [
      "chenab",
      "jhelum"
    ],
    "basin_rivers": [
      "chenab",
      "jhelum"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "baltas-thajwas-wls",
      "city-forest-np",
      "dachigam-np",
      "gulmarg-wls",
      "hirpora-wls",
      "hokarsar-lake-wls",
      "hokera-wetland-ramsar",
      "hygam-wetland-conservation-reserve-ramsar",
      "jasrota-wls",
      "kazinag-np",
      "kishtwar-np",
      "lacchipora-wls",
      "limber-wls",
      "nandni-wls",
      "overa-aru-wls",
      "rajparian-daksum-wls",
      "ramnagar-rakha-wls",
      "shallbugh-wetland-conservation-reserve-ramsar",
      "surinsar-mansar-lakes-ramsar",
      "surinsar-mansar-wls",
      "trikuta-wls",
      "wular-lake-ramsar"
    ]
  },
  {
    "id": "jharkhand",
    "name": "Jharkhand",
    "admin_type": "state",
    "capital": "Ranchi",
    "rivers_flowing_through": [
      "ajay",
      "baitarani",
      "barakar",
      "brahmani",
      "damodar",
      "ganga",
      "son",
      "subarnarekha"
    ],
    "basin_rivers": [
      "ajay",
      "baitarani",
      "barakar",
      "brahmani",
      "damodar",
      "ganga",
      "son",
      "subarnarekha"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "betla-np",
      "dalma-wls",
      "gautam-budha-wls",
      "hazaribagh-wls",
      "koderma-wls",
      "lawalong-wls",
      "mahauaduar-wls",
      "palamau-tr",
      "palamau-wls",
      "palkot-wls",
      "parasnath-wls",
      "topchanchi-wls",
      "udhwa-lake-bird-wls",
      "udhwa-lake-ramsar"
    ]
  },
  {
    "id": "karnataka",
    "name": "Karnataka",
    "admin_type": "state",
    "capital": "Bengaluru",
    "rivers_flowing_through": [
      "aghanashini",
      "arkavathi",
      "bhima",
      "hemavathi",
      "kabini",
      "kali-karnataka",
      "kaveri",
      "krishna",
      "mandovi",
      "manjira",
      "netravati",
      "palar",
      "ponnaiyar",
      "sharavati",
      "shimsha",
      "tungabhadra"
    ],
    "basin_rivers": [
      "aghanashini",
      "arkavathi",
      "bhima",
      "godavari",
      "hemavathi",
      "kabini",
      "kali-karnataka",
      "kaveri",
      "krishna",
      "mandovi",
      "manjira",
      "netravati",
      "palar",
      "ponnaiyar",
      "sharavati",
      "shimsha",
      "tungabhadra"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "adichunchunagiri-peacock-wls",
      "aghanashini-lion-tailed-macaque-reserve-ramsar",
      "anaghasamudra-ramsar",
      "anshi-np",
      "arabithittu-wls",
      "attiveri-bird-wls",
      "bandipur-np",
      "bandipur-tr",
      "bannerghatta-np",
      "bhadra-tr",
      "bhadra-wls",
      "bhimgad-wls",
      "biligiri-ranganatha-temple-tr",
      "biligiri-rangaswamy-temple-wls",
      "brahmagiri-wls",
      "bukkapatna-wls",
      "cauvery-wls",
      "chincholi-wls",
      "dandeli-wls",
      "daroji-bear-wls",
      "ghataprabha-wls",
      "gudavi-bird-wls",
      "gudekote-sloth-bear-wls",
      "gudekote-wls",
      "jogimatti-wls",
      "kali-anshi-dandeli-tr",
      "kamasandra-wls",
      "kappathagudda-wls",
      "kudremukh-np",
      "magadi-kere-conservation-reserve-ramsar",
      "malaimahadeswara-wls",
      "melkote-temple-wls",
      "mookambika-wls",
      "nagarhole-tr",
      "nilgiri-br",
      "nugu-wls",
      "pushpagiri-wls",
      "rajiv-gandhi-nagarahole-np",
      "ramadevara-betta-vulture-wls",
      "ranebennur-black-buck-wls",
      "ranganathittu-bird-sanctuary-ramsar",
      "ranganathittu-bird-wls",
      "rangayyanadurga-four-horned-antelope-wls",
      "sharavathi-valley-ltm-wls",
      "shettihalli-wls",
      "someshwara-wls",
      "talakaveri-wls",
      "yedahalli-chinkara-wildlife-sanctury-wls"
    ]
  },
  {
    "id": "kerala",
    "name": "Kerala",
    "admin_type": "state",
    "capital": "Thiruvananthapuram",
    "rivers_flowing_through": [
      "amaravathi",
      "bharathapuzha",
      "bhavani",
      "kabini",
      "kallada",
      "kaveri",
      "pamba",
      "periyar"
    ],
    "basin_rivers": [
      "amaravathi",
      "bharathapuzha",
      "bhavani",
      "kabini",
      "kallada",
      "kaveri",
      "pamba",
      "periyar"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "agasthyamalai-br",
      "anamudi-shola-np",
      "aralam-wls",
      "asthamudi-wetland-ramsar",
      "chimmony-wls",
      "chinnar-wls",
      "chulannur-peafowl-wls",
      "eravikulam-np",
      "idukki-wls",
      "karimpuzha-wls",
      "kottiyoor-wls",
      "kurinjimala-wls",
      "malabar-wls",
      "mangalavanam-bird-wls",
      "mathikettan-shola-np",
      "neyyar-wls",
      "nilgiri-br",
      "pambadum-shola-np",
      "parambikulam-tr",
      "parambikulam-wls",
      "peechi-vazhani-wls",
      "peppara-wls",
      "periyar-np",
      "periyar-tr",
      "periyar-wls",
      "sasthamkotta-lake-ramsar",
      "shendurney-wls",
      "silent-valley-np",
      "thattekad-bird-wls",
      "vembanad-kol-wetland-ramsar",
      "wayanad-wls"
    ]
  },
  {
    "id": "ladakh",
    "name": "Ladakh",
    "admin_type": "ut",
    "capital": "Leh",
    "rivers_flowing_through": [
      "indus",
      "shyok",
      "zanskar"
    ],
    "basin_rivers": [
      "indus",
      "shyok",
      "zanskar"
    ],
    "notable_city_ids": [
      "leh"
    ],
    "protected_area_ids": [
      "changthang-wls",
      "hemis-np",
      "karakoram-nubra-shyok-wls",
      "tso-kar-wetland-complex-ramsar",
      "tsomoriri-lake-ramsar"
    ]
  },
  {
    "id": "lakshadweep",
    "name": "Lakshadweep",
    "admin_type": "ut",
    "capital": "Kavaratti",
    "rivers_flowing_through": [],
    "basin_rivers": [],
    "notable_city_ids": [],
    "protected_area_ids": [
      "pitti-bird-island-wls"
    ]
  },
  {
    "id": "madhya-pradesh",
    "name": "Madhya Pradesh",
    "admin_type": "state",
    "capital": "Bhopal",
    "rivers_flowing_through": [
      "betwa",
      "chambal",
      "kali-sindh",
      "ken",
      "mahi",
      "narmada",
      "parbati",
      "son",
      "tapi",
      "wainganga",
      "wardha"
    ],
    "basin_rivers": [
      "betwa",
      "chambal",
      "godavari",
      "kali-sindh",
      "ken",
      "mahi",
      "narmada",
      "parbati",
      "pranhita",
      "son",
      "tapi",
      "wainganga",
      "wardha",
      "yamuna"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "achanakmar-amarkantak-br",
      "bagdara-wls",
      "bandhavgarh-np",
      "bandhavgarh-tr",
      "bhoj-wetlands-ramsar",
      "bori-wls",
      "dinosaur-fossil-np",
      "fossil-np",
      "gandhi-sagar-wls",
      "ghatigaon-wls",
      "kanha-np",
      "kanha-tr",
      "karera-wls",
      "ken-gharial-wls",
      "kheoni-wls",
      "kuno-np",
      "madhav-np",
      "madhav-tr",
      "narsighgarh-wls",
      "national-chambal-wls",
      "noradehi-wls",
      "orcha-wls",
      "pachmarhi-br",
      "pachmarhi-wls",
      "panna-br",
      "panna-gangau-wls",
      "panna-np",
      "panna-tr",
      "panpatha-wls",
      "pench-moghli-wls",
      "pench-priyadarshni-np",
      "pench-tr",
      "phen-wls",
      "ralamandal-wls",
      "ratapani-tr",
      "ratapani-wls",
      "sailana-wls",
      "sakhya-sagar-ramsar",
      "sanjay-dubri-tr",
      "sanjay-dubri-wls",
      "sanjay-np",
      "sardarpur-wls",
      "satpura-np",
      "satpura-tr",
      "singhori-wls",
      "sirpur-wetland-ramsar",
      "son-gharial-wls",
      "tawa-reservoir-ramsar",
      "van-vihar-np",
      "veerangana-durgavati-tr",
      "veerangna-durgawati-wls",
      "yashwant-sagar-ramsar"
    ]
  },
  {
    "id": "maharashtra",
    "name": "Maharashtra",
    "admin_type": "state",
    "capital": "Mumbai",
    "rivers_flowing_through": [
      "bhima",
      "damanganga",
      "godavari",
      "indravati",
      "krishna",
      "mandovi",
      "manjira",
      "narmada",
      "pranhita",
      "tapi",
      "ulhas",
      "vaitarna",
      "wainganga",
      "wardha"
    ],
    "basin_rivers": [
      "bhima",
      "damanganga",
      "godavari",
      "indravati",
      "krishna",
      "mandovi",
      "manjira",
      "narmada",
      "pranhita",
      "tapi",
      "ulhas",
      "vaitarna",
      "wainganga",
      "wardha"
    ],
    "notable_city_ids": [
      "nashik"
    ],
    "protected_area_ids": [
      "amba-barwa-wls",
      "andhari-wls",
      "aner-dam-wls",
      "bhamragarh-wls",
      "bhimashankar-wls",
      "bor-tr",
      "bor-wls",
      "chandoli-np",
      "chaprala-wls",
      "deolgaon-rehkuri-wls",
      "dhyanganga-wls",
      "gautala-autramghat-wls",
      "ghodazari-wls",
      "great-indian-bustard-wls",
      "gugamal-np",
      "jaikwadi-wls",
      "kalsubai-wls",
      "karanja-sohol-blackbuck-wls",
      "karnala-wls",
      "katepurna-wls",
      "koka-wls",
      "koyana-wls",
      "lonar-lake-ramsar",
      "lonar-wls",
      "malvan-marine-wls",
      "mansingdeo-wls",
      "mayureswar-supe-wls",
      "melghat-tr",
      "melghat-wls",
      "nagzira-wls",
      "naigaon-mayur-wls",
      "nandur-madhameshwar-ramsar",
      "nandur-madhameshwar-wls",
      "narnala-wls",
      "nawegaon-nagzira-tr",
      "nawegaon-np",
      "nawegaon-wls",
      "new-bor-wls",
      "new-nagzira-wls",
      "painganga-wls",
      "pauni-karhandla-wildlife-sanctuary-and-tiger-reserve-wls",
      "pench-jawaharlal-nehru-np",
      "pench-maharashtra-tr",
      "phansad-wls",
      "radhanagari-wls",
      "sagareshwar-wls",
      "sahyadri-tr",
      "sanjay-gandhi-borivilli-np",
      "sudha-gad-fort-wls",
      "tadoba-andhari-tr",
      "tadoba-np",
      "tamhini-wildlife-sanctury-wls",
      "tansa-wls",
      "thane-creek-flamingo-sanctuary-wls",
      "thane-creek-ramsar",
      "tipeshwar-wls",
      "tungareshwar-wls",
      "wan-wls",
      "yawal-wls",
      "yedsi-ramlinghat-wls"
    ]
  },
  {
    "id": "manipur",
    "name": "Manipur",
    "admin_type": "state",
    "capital": "Imphal",
    "rivers_flowing_through": [
      "barak"
    ],
    "basin_rivers": [
      "barak"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "bunning-wls",
      "jiri-makru-wls",
      "kailam-wls",
      "keibul-lamjao-np",
      "loktak-lake-ramsar",
      "shirui-np-sirohi-np",
      "yangoupokpi-lokchao-wls",
      "zeilad-wls"
    ]
  },
  {
    "id": "meghalaya",
    "name": "Meghalaya",
    "admin_type": "state",
    "capital": "Shillong",
    "rivers_flowing_through": [
      "kopili"
    ],
    "basin_rivers": [
      "barak",
      "brahmaputra",
      "kopili"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "baghmara-pitcher-plant-wls",
      "balphakram-np",
      "narpuh-wls",
      "nokrek-br",
      "nokrek-ridge-np",
      "nongkhyllem-wls",
      "siju-wls"
    ]
  },
  {
    "id": "mizoram",
    "name": "Mizoram",
    "admin_type": "state",
    "capital": "Aizawl",
    "rivers_flowing_through": [
      "barak"
    ],
    "basin_rivers": [
      "barak"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "dampa-tr",
      "dampa-wls",
      "khawnglung-wls",
      "lengteng-wls",
      "murlen-np",
      "ngengpui-wls",
      "pala-wetland-ramsar",
      "phawngpui-blue-mountain-np",
      "pualreng-wls",
      "tawi-wls",
      "thorangtlang-wls",
      "tokalo-wls"
    ]
  },
  {
    "id": "nagaland",
    "name": "Nagaland",
    "admin_type": "state",
    "capital": "Kohima",
    "rivers_flowing_through": [
      "barak"
    ],
    "basin_rivers": [
      "barak",
      "brahmaputra"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "fakim-wls",
      "intanki-np",
      "puliebadze-wls",
      "rangapahar-wls",
      "singphan-national-park-wls"
    ]
  },
  {
    "id": "odisha",
    "name": "Odisha",
    "admin_type": "state",
    "capital": "Bhubaneswar",
    "rivers_flowing_through": [
      "baitarani",
      "brahmani",
      "godavari",
      "indravati",
      "mahanadi",
      "nagavali",
      "subarnarekha",
      "vamsadhara"
    ],
    "basin_rivers": [
      "baitarani",
      "brahmani",
      "godavari",
      "indravati",
      "mahanadi",
      "nagavali",
      "subarnarekha",
      "vamsadhara"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "ansupa-lake-ramsar",
      "badrama-wls",
      "baisipalli-wls",
      "balukhand-konark-wls",
      "bhitarkanika-mangroves-ramsar",
      "bhitarkanika-np",
      "bhitarkanika-wls",
      "chandaka-dampara-wls",
      "chilika-nalaban-wls",
      "chilka-lake-ramsar",
      "debrigarh-wls",
      "gahirmatha-marine-wls",
      "hadgarh-wls",
      "hirakud-reservoir-ramsar",
      "kapilash-wls",
      "karlapat-wls",
      "khalasuni-wls",
      "kotagarh-wls",
      "kuldiha-wls",
      "lakhari-valley-wls",
      "nandankanan-wls",
      "satkosia-gorge-ramsar",
      "satkosia-gorge-wls",
      "satkosia-tr",
      "similipal-tr",
      "simlipal-br",
      "simlipal-np",
      "simlipal-wls",
      "sunabeda-wls",
      "tampara-lake-ramsar"
    ]
  },
  {
    "id": "puducherry",
    "name": "Puducherry",
    "admin_type": "ut",
    "capital": "Puducherry",
    "rivers_flowing_through": [
      "kaveri"
    ],
    "basin_rivers": [
      "kaveri"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "oussudu-lake-wls"
    ]
  },
  {
    "id": "punjab",
    "name": "Punjab",
    "admin_type": "state",
    "capital": "Chandigarh",
    "rivers_flowing_through": [
      "beas",
      "ghaggar-hakra",
      "ravi",
      "sutlej"
    ],
    "basin_rivers": [
      "beas",
      "ghaggar-hakra",
      "ravi",
      "sutlej"
    ],
    "notable_city_ids": [
      "ludhiana"
    ],
    "protected_area_ids": [
      "abohar-wls",
      "beas-conservation-reserve-ramsar",
      "bir-aishvan-wls",
      "bir-bhadson-wls",
      "bir-bunerheri-wls",
      "bir-dosanjh-wls",
      "bir-gurdialpura-wls",
      "bir-mehaswala-wls",
      "bir-motibagh-wls",
      "harike-lake-ramsar",
      "harike-lake-wls",
      "jhajjar-bachauli-wls",
      "kanjli-lake-ramsar",
      "kathlaur-kushlian-wls",
      "keshopur-miani-community-reserve-ramsar",
      "nangal-wildlife-sanctuary-ramsar",
      "nangal-wls",
      "ropar-lake-ramsar",
      "takhni-rehampur-wls"
    ]
  },
  {
    "id": "rajasthan",
    "name": "Rajasthan",
    "admin_type": "state",
    "capital": "Jaipur",
    "rivers_flowing_through": [
      "banas",
      "chambal",
      "ghaggar-hakra",
      "kali-sindh",
      "luni",
      "mahi",
      "parbati",
      "sabarmati"
    ],
    "basin_rivers": [
      "banas",
      "chambal",
      "ghaggar-hakra",
      "kali-sindh",
      "luni",
      "mahi",
      "parbati",
      "sabarmati",
      "yamuna"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "bandh-baratha-wls",
      "bassi-wls",
      "bhensrodgarh-wls",
      "darrah-wls",
      "desert-np",
      "dholpur-karauli-tr",
      "jaisamand-wls",
      "jamwa-ramgarh-wls",
      "jawahar-sagar-wls",
      "kailadevi-wls",
      "keoladeo-ghana-np",
      "keoladeo-ghana-np-ramsar",
      "kesarbagh-wls",
      "khichan-wetland-ramsar",
      "kumbhalgarh-wls",
      "menar-wetland-ramsar",
      "mount-abu-wls",
      "mukundra-hills-np",
      "mukundra-hills-tr",
      "nahargarh-wls",
      "phulwari-ki-nal-wls",
      "ramgarh-vishdhari-tr",
      "ramgarh-vishdhari-wls",
      "ramsagar-wls",
      "ranthambhore-np",
      "ranthambhore-tr",
      "sajjangarh-wls",
      "sambhar-lake-ramsar",
      "sariska-np",
      "sariska-tr",
      "sariska-wls",
      "sawai-man-singh-wls",
      "sawaimadhopur-wls",
      "shergarh-wls",
      "silserah-lake-ramsar",
      "sitamata-wls",
      "tadgarh-raoli-wls",
      "tal-chhapper-wls",
      "van-vihar-wls"
    ]
  },
  {
    "id": "sikkim",
    "name": "Sikkim",
    "admin_type": "state",
    "capital": "Gangtok",
    "rivers_flowing_through": [
      "jaldhaka",
      "rangeet",
      "teesta"
    ],
    "basin_rivers": [
      "brahmaputra",
      "jaldhaka",
      "rangeet",
      "teesta"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "barsey-rhododendron-wls",
      "fambong-lho-wls",
      "kacheopalri-ramsar",
      "khangchendzonga-br",
      "khangchendzonga-np",
      "kitam-bird-sanctuary-wls",
      "kyongnosla-alpine-wls",
      "maenam-wls",
      "pangolakha-wls",
      "shingba-rhododendron-wls"
    ]
  },
  {
    "id": "tamil-nadu",
    "name": "Tamil Nadu",
    "admin_type": "state",
    "capital": "Chennai",
    "rivers_flowing_through": [
      "amaravathi",
      "bharathapuzha",
      "bhavani",
      "kaveri",
      "palar",
      "periyar",
      "ponnaiyar",
      "tamiraparani",
      "vaigai",
      "vaippar",
      "vellar"
    ],
    "basin_rivers": [
      "amaravathi",
      "bharathapuzha",
      "bhavani",
      "kaveri",
      "palar",
      "periyar",
      "ponnaiyar",
      "tamiraparani",
      "vaigai",
      "vaippar",
      "vellar"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "agasthyamalai-br",
      "anamalai-tr",
      "cauvery-north-wls",
      "chitrangudi-bird-sanctuary-ramsar",
      "chitrangudi-wls",
      "gangaikondam-spotted-deer-wls",
      "guindy-np",
      "gulf-of-mannar-br",
      "gulf-of-mannar-marine-biosphere-reserve-ramsar",
      "gulf-of-mannar-marine-np",
      "indira-gandhi-annamalai-np",
      "indira-gandhi-annamalai-wls",
      "kalakad-mundanthurai-tr",
      "kalakad-wls",
      "kanjirankulam-bird-sanctuary-ramsar",
      "kanjirankulam-wls",
      "kanyakumari-wls",
      "karaivettai-ramsar",
      "karaivetti-wls",
      "karikili-bird-sanctuary-ramsar",
      "karikili-wls",
      "kazhuveli-bird-sanctuary-ramsar",
      "kodaikanal-wls",
      "koonthankulam-bird-sanctuary-ramsar",
      "koonthankulam-kadankulam-wls",
      "longwood-shola-reserve-forest-ramsar",
      "megamalai-wls",
      "melaselvanur-kilaselvanur-wls",
      "mudumalai-np",
      "mudumalai-tr",
      "mudumalai-wls",
      "mukurthi-np",
      "mundanthurai-wls",
      "nanjarayan-tank-bird-sanctuary-ramsar",
      "nellai-wls",
      "nilgiri-br",
      "oussudu-lake-bird-wls",
      "pallikaranai-marsh-reserve-forest-ramsar",
      "pichavaram-mangrove-ramsar",
      "point-calimere-block-a-block-b-wls",
      "point-calimere-wildlife-and-bird-sanctuary-ramsar",
      "pulicat-lake-wls",
      "sakkarakottai-bird-sanctuary-ramsar",
      "sakkarakottai-bird-wls",
      "sathyamangalam-tr",
      "sathyamangalam-wls",
      "srivilliputhur-giant-squirrel-wls",
      "srivilliputhur-megamalai-tr",
      "suchindram-theroor-wetland-complex-ramsar",
      "theerthangal-bird-wls",
      "theerthangal-ramsar",
      "udayamarthandapuram-lake-wls",
      "udhayamarthandapuram-bird-sanctuary-ramsar",
      "vaduvoor-bird-wls",
      "vaduvur-bird-sanctuary-ramsar",
      "vedanthangal-bird-sanctuary-ramsar",
      "vedanthangal-lake-bird-wls",
      "vellanadu-blackbuck-wls",
      "vellode-bird-sanctuary-ramsar",
      "vellode-bird-wls",
      "vembannur-wetland-complex-ramsar",
      "vettangudi-bird-wls"
    ]
  },
  {
    "id": "telangana",
    "name": "Telangana",
    "admin_type": "state",
    "capital": "Hyderabad",
    "rivers_flowing_through": [
      "bhima",
      "godavari",
      "indravati",
      "krishna",
      "manjira",
      "musi",
      "pranhita",
      "wardha"
    ],
    "basin_rivers": [
      "bhima",
      "godavari",
      "indravati",
      "krishna",
      "manjira",
      "musi",
      "pranhita",
      "wardha"
    ],
    "notable_city_ids": [
      "hyderabad"
    ],
    "protected_area_ids": [
      "amrabad-nagarjunasagar-srisailam-wls",
      "amrabad-tr",
      "eturnagaram-wls",
      "kasu-brahmananda-reddy-np",
      "kawal-tr",
      "kawal-wls",
      "kinnersani-wls",
      "lanja-madugu-sivaram-wls",
      "mahaveer-harina-vanasthali-np",
      "manjira-wls",
      "mrugavani-np",
      "pakhal-wls",
      "pocharam-wls",
      "pranahita-wls"
    ]
  },
  {
    "id": "tripura",
    "name": "Tripura",
    "admin_type": "state",
    "capital": "Agartala",
    "rivers_flowing_through": [],
    "basin_rivers": [
      "barak"
    ],
    "notable_city_ids": [],
    "protected_area_ids": [
      "bison-np",
      "clouded-leopard-np",
      "gumti-wls",
      "rowa-wls",
      "rudrasagar-lake-ramsar",
      "sepahijala-wls",
      "trishna-wls"
    ]
  },
  {
    "id": "uttar-pradesh",
    "name": "Uttar Pradesh",
    "admin_type": "state",
    "capital": "Lucknow",
    "rivers_flowing_through": [
      "betwa",
      "chambal",
      "gandak",
      "ganga",
      "ghaghra",
      "gomti",
      "ken",
      "sarda",
      "son",
      "yamuna"
    ],
    "basin_rivers": [
      "betwa",
      "chambal",
      "gandak",
      "ganga",
      "ghaghra",
      "gomti",
      "ken",
      "sarda",
      "son",
      "yamuna"
    ],
    "notable_city_ids": [
      "agra",
      "prayagraj",
      "varanasi"
    ],
    "protected_area_ids": [
      "bakhira-wildlife-sanctuary-ramsar",
      "bakhira-wls",
      "chandraprabha-wls",
      "dr-bhimrao-ambedkar-bird-wls",
      "dudhwa-np",
      "dudhwa-tr",
      "haiderpur-wetland-ramsar",
      "hastinapur-wls",
      "jai-prakash-narayan-bird-sanctuary-ramsar",
      "kaimur-wls",
      "katerniaghat-wls",
      "kishanpur-wls",
      "lakh-bahosi-wls",
      "mahavir-swami-wls",
      "nawabganj-bird-sanctuary-ramsar",
      "nawabganj-wls",
      "okhala-wls",
      "parvati-aranga-wls",
      "parvati-arga-bird-sanctuary-ramsar",
      "patna-bird-sancutary-ramsar",
      "patna-wls",
      "pilibhit-tr",
      "pilibhit-wls",
      "ranipur-tr",
      "ranipur-wls",
      "saman-bird-sanctuary-ramsar",
      "saman-bird-wls",
      "samaspur-bird-sanctuary-ramsar",
      "samaspur-bird-wls",
      "sandi-bird-sanctuary-ramsar",
      "sandi-bird-wls",
      "sarsai-nawar-jheel-ramsar",
      "shekha-bird-sanctuary-wls",
      "shekha-jheel-bird-sanctuary-ramsar",
      "sohagibarwa-wls",
      "sohelwa-wls",
      "sur-sarovar-bird-wls",
      "sur-sarovar-ramsar",
      "surha-tal-wls",
      "turtle-wls",
      "upper-ganga-river-brijghat-to-narora-stretch-ramsar",
      "vijai-sagar-wls"
    ]
  },
  {
    "id": "uttarakhand",
    "name": "Uttarakhand",
    "admin_type": "state",
    "capital": "Dehradun",
    "rivers_flowing_through": [
      "alaknanda",
      "bhagirathi",
      "ganga",
      "sarda",
      "yamuna"
    ],
    "basin_rivers": [
      "alaknanda",
      "bhagirathi",
      "ganga",
      "sarda",
      "yamuna"
    ],
    "notable_city_ids": [
      "haridwar",
      "rishikesh"
    ],
    "protected_area_ids": [
      "asan-conservation-reserve-ramsar",
      "askot-musk-deer-wls",
      "binsar-wls",
      "corbett-np",
      "corbett-tr",
      "gangotri-np",
      "govind-np",
      "govind-pashu-vihar-wls",
      "kedarnath-wls",
      "mussoorie-wls",
      "nanda-devi-br",
      "nanda-devi-np",
      "nandhaur-wls",
      "rajaji-np",
      "rajaji-tr",
      "sonanadi-wls",
      "valley-of-flowers-np"
    ]
  },
  {
    "id": "west-bengal",
    "name": "West Bengal",
    "admin_type": "state",
    "capital": "Kolkata",
    "rivers_flowing_through": [
      "ajay",
      "barakar",
      "damodar",
      "ganga",
      "hooghly",
      "jaldhaka",
      "mahananda",
      "subarnarekha",
      "teesta",
      "torsa"
    ],
    "basin_rivers": [
      "ajay",
      "barakar",
      "brahmaputra",
      "damodar",
      "ganga",
      "hooghly",
      "jaldhaka",
      "mahananda",
      "subarnarekha",
      "teesta",
      "torsa"
    ],
    "notable_city_ids": [
      "kolkata"
    ],
    "protected_area_ids": [
      "ballavpur-wls",
      "bethuadahari-wls",
      "bibhutibhusan-wls",
      "buxa-np",
      "buxa-tr",
      "buxa-wls",
      "chapramari-wls",
      "chintamani-kar-bird-wls",
      "east-kolkata-wetlands-ramsar",
      "gorumara-np",
      "haliday-island-wls",
      "jaldapara-np",
      "jorepokhri-salamander-wls",
      "lothian-island-wls",
      "mahananda-wls",
      "neora-valley-np",
      "pakhi-bitan-bird-wls",
      "raiganj-wls",
      "ramnabagan-wls",
      "sajnakhali-wls",
      "senchal-wls",
      "singalila-np",
      "sundarbans-br",
      "sundarbans-tr",
      "sunderban-np",
      "sunderbans-wetland-ramsar",
      "west-sunderbans-wls"
    ]
  }
]
VMAPS_PATCH_EOF

mkdir -p "public/data/rivers"
cat > 'public/data/rivers/bagmati.json' << 'VMAPS_PATCH_EOF'
{
  "id": "bagmati",
  "name": "Bagmati",
  "aliases": [],
  "local_names": { "hi": "बागमती" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "spring-fed",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Bāghdwār (\"Tiger Gate\"), Shivapuri Hills",
    "state": "nepal",
    "altitude_m": 2740,
    "coordinates": [85.42722, 27.77111]
  },
  "sink": {
    "name": "Confluence with the Kamala River",
    "type": "river",
    "location": "Jagmohra, Bihar, India",
    "coordinates": [86.364722, 25.73225]
  },
  "length_km_india": 201.5,
  "length_km_total": 586,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["bihar"],
  "basin_states": ["bihar"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["nepal"],
  "significance": ["major Kosi/Ganga tributary", "irrigation across north Bihar", "sacred river in Nepal's Kathmandu Valley (upstream)"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Bagmati is worshipped as a sacred river in Nepal's Kathmandu Valley, flowing past the Pashupatinath Temple before crossing into Bihar.",
    "Unlike the glacier-fed Himalayan giants nearby, the Bagmati begins as a spring at Bāghdwār (\"Tiger Gate\") in the Shivapuri hills north of Kathmandu — not from a glacier."
  ]
}
VMAPS_PATCH_EOF

mkdir -p "public/data/rivers"
cat > 'public/data/rivers/tamiraparani.json' << 'VMAPS_PATCH_EOF'
{
  "id": "tamiraparani",
  "name": "Tamiraparani",
  "aliases": ["Thamirabarani", "Porunai", "Tamraparni"],
  "local_names": { "ta": "தாமிரபரணி" },
  "basin": "tamiraparani-basin",
  "type": "main",
  "drainage_type": "peninsular",
  "seasonal_type": "perennial",
  "origin_type": "rain-fed",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Agastyarkoodam peak, Pothigai Hills, Western Ghats",
    "state": "tamil-nadu",
    "altitude_m": 1868,
    "coordinates": [77.24167, 8.64583]
  },
  "sink": {
    "name": "Gulf of Mannar",
    "type": "sea",
    "location": "Punnakayal, Thoothukudi district, Tamil Nadu, India",
    "coordinates": [78.127298, 8.641316]
  },
  "length_km_india": 135.1,
  "length_km_total": 135.1,
  "basin_area_total_km2": 5717,
  "basin_area_india_km2": 5717,
  "states_flows_through": ["tamil-nadu"],
  "basin_states": ["tamil-nadu"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["only fully perennial river system in Tamil Nadu", "ancient Sangam-era irrigation network", "drinking water and agriculture for Tirunelveli/Thoothukudi"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "Known in Sangam-era Tamil literature as the Porunai, the Tamiraparani is the only river system in Tamil Nadu that flows year-round without drying up.",
    "The river's reddish tinge — the source of its name (\"thamiram\", copper) — comes from copper-bearing minerals it picks up flowing off the Western Ghats."
  ]
}
VMAPS_PATCH_EOF

mkdir -p "public/data/rivers"
cat > 'public/data/rivers/vaitarna.json' << 'VMAPS_PATCH_EOF'
{
  "id": "vaitarna",
  "name": "Vaitarna",
  "aliases": [],
  "local_names": { "mr": "वैतरणा" },
  "basin": "vaitarna-basin",
  "type": "main",
  "drainage_type": "coastal",
  "seasonal_type": "perennial",
  "origin_type": "rain-fed",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Triambak-Anjaneri range, Western Ghats, near Trimbakeshwar",
    "state": "maharashtra",
    "altitude_m": 900,
    "coordinates": [73.54792, 19.90833]
  },
  "sink": {
    "name": "Arabian Sea",
    "type": "sea",
    "location": "Near Arnala, Palghar district, Maharashtra, India",
    "coordinates": [72.73247, 19.46577]
  },
  "length_km_india": 149.2,
  "length_km_total": 149.2,
  "basin_area_total_km2": 3795,
  "basin_area_india_km2": 3795,
  "states_flows_through": ["maharashtra"],
  "basin_states": ["maharashtra"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["supplies a large share of Mumbai's drinking water", "hydropower (Upper Vaitarna project)", "largest river of the Northern Konkan region"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Vaitarna rises just 2 km from the source of the Godavari on the same Trimbakeshwar hillside, yet the two rivers flow in opposite directions to opposite coasts.",
    "Three major dams on the Vaitarna — including the Upper and Lower Vaitarna dams — together supply a large share of Mumbai's drinking water."
  ]
}
VMAPS_PATCH_EOF

mkdir -p "scripts"
cat > 'scripts/rebuildRiversPmtiles.mjs' << 'VMAPS_PATCH_EOF'
// Rebuilds public/tiles/rivers.pmtiles with new rivers appended, at full maxzoom (z14) fidelity.
// Re-extracts the 88 EXISTING rivers losslessly from the current pmtiles by scanning each river's
// own bbox (from rivers-index.json) at z14 — not the whole-India grid, which would be ~1.4M tiles
// to probe at z14; per-river bbox scoping keeps each scan small while still hitting full maxzoom.
// Preserves the existing numeric vector-tile feature ids (rivers-id-map.json) byte-for-byte; new
// rivers get fresh sequential ids appended after the current max.
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import { PMTiles } from 'pmtiles';
import { VectorTile } from '@mapbox/vector-tile';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { PbfReader: Protobuf } = require('pbf');

class NodeFileSource {
  constructor(path) {
    this.path = path;
    this.fd = fs.openSync(path, 'r');
  }
  getKey() {
    return this.path;
  }
  async getBytes(offset, length) {
    const buf = Buffer.alloc(length);
    fs.readSync(this.fd, buf, 0, length, offset);
    return { data: buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) };
  }
}

const EXTRACT_ZOOM = 14;

function lonToTileX(lon, z) {
  return Math.floor(((lon + 180) / 360) * 2 ** z);
}
function latToTileY(lat, z) {
  const rad = (lat * Math.PI) / 180;
  return Math.floor(((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) * 2 ** z);
}

async function extractRiverAtBbox(p, z, [minLon, minLat, maxLon, maxLat]) {
  // pad by 1 tile so a river's line isn't clipped right at its own bbox edge
  const xMin = lonToTileX(minLon, z) - 1;
  const xMax = lonToTileX(maxLon, z) + 1;
  const yMin = latToTileY(maxLat, z) - 1;
  const yMax = latToTileY(minLat, z) + 1;

  const segmentsById = new Map();
  for (let x = xMin; x <= xMax; x++) {
    for (let y = yMin; y <= yMax; y++) {
      const tile = await p.getZxy(z, x, y);
      if (!tile) continue;
      const vt = new VectorTile(new Protobuf(tile.data));
      const layer = vt.layers['rivers'];
      if (!layer) continue;
      for (let i = 0; i < layer.length; i++) {
        const feat = layer.feature(i);
        const strId = feat.properties.id;
        const numId = feat.id;
        if (strId === undefined || numId === undefined) continue;
        const geo = feat.toGeoJSON(x, y, z);
        const coordsList =
          geo.geometry.type === 'LineString'
            ? [geo.geometry.coordinates]
            : geo.geometry.type === 'MultiLineString'
              ? geo.geometry.coordinates
              : [];
        for (const c of coordsList) {
          if (!segmentsById.has(strId)) segmentsById.set(strId, { numId, strOrder: feat.properties.stream_order, segments: [] });
          segmentsById.get(strId).segments.push(c);
        }
      }
    }
  }
  return segmentsById;
}

async function run() {
  const source = new NodeFileSource('public/tiles/rivers.pmtiles');
  const p = new PMTiles(source);
  const header = await p.getHeader();
  const z = Math.min(EXTRACT_ZOOM, header.maxZoom);

  const riversIndex = JSON.parse(fs.readFileSync('public/data/rivers-index.json', 'utf-8'));
  const idMap = JSON.parse(fs.readFileSync('public/data/rivers-id-map.json', 'utf-8'));
  const existingIds = new Set(Object.keys(idMap));

  const NEW_RIVER_IDS = ['bagmati', 'tamiraparani', 'vaitarna'];
  const existingRivers = riversIndex.filter((r) => !NEW_RIVER_IDS.includes(r.id));
  const newRivers = riversIndex.filter((r) => NEW_RIVER_IDS.includes(r.id));

  if (existingRivers.length !== existingIds.size) {
    throw new Error(`existing river count mismatch: index has ${existingRivers.length}, id-map has ${existingIds.size}`);
  }

  const features = [];
  const finalIdMap = {};

  console.log(`Re-extracting ${existingRivers.length} existing rivers at z${z} (per-river bbox)...`);
  let done = 0;
  for (const river of existingRivers) {
    const found = await extractRiverAtBbox(p, z, river.bounds);
    const entry = found.get(river.id);
    if (!entry) throw new Error(`river "${river.id}" not found in re-extraction — bbox or id mismatch`);
    const expectedNumId = idMap[river.id][0];
    if (entry.numId !== expectedNumId) {
      throw new Error(`river "${river.id}" numeric id mismatch: expected ${expectedNumId}, got ${entry.numId}`);
    }
    features.push({
      type: 'Feature',
      id: entry.numId,
      properties: { id: river.id, stream_order: entry.strOrder },
      geometry:
        entry.segments.length === 1
          ? { type: 'LineString', coordinates: entry.segments[0] }
          : { type: 'MultiLineString', coordinates: entry.segments },
    });
    finalIdMap[river.id] = [entry.numId];
    done++;
    if (done % 20 === 0) console.log(`  ${done}/${existingRivers.length}`);
  }

  let nextId = Math.max(...Object.values(idMap).flat()) + 1;
  console.log(`Appending ${newRivers.length} new rivers starting at id ${nextId}...`);
  for (const river of newRivers) {
    // shipped geometry = India-portion trace coords, produced during tracing (scripts_tmp/*.json)
    const traceOut = JSON.parse(fs.readFileSync(`/tmp/${river.id}.json`, 'utf-8'));
    const numId = nextId++;
    features.push({
      type: 'Feature',
      id: numId,
      properties: { id: river.id, stream_order: river.stream_order },
      geometry: { type: 'LineString', coordinates: traceOut.indiaCoords },
    });
    finalIdMap[river.id] = [numId];
  }

  fs.mkdirSync('build', { recursive: true });
  fs.writeFileSync('build/rivers-prepared-v4.geojson', features.map((f) => JSON.stringify(f)).join('\n'));
  fs.writeFileSync('public/data/rivers-id-map.json', JSON.stringify(finalIdMap, null, 2) + '\n');

  console.log('Running tippecanoe...');
  execSync(
    `tippecanoe --output=build/rivers-v4.pmtiles --layer=rivers --minimum-zoom=4 --maximum-zoom=14 --drop-smallest-as-needed --include=id --include=stream_order --name="India Rivers" --attribution="OpenStreetMap contributors" --force build/rivers-prepared-v4.geojson`,
    { stdio: 'inherit' }
  );
  fs.copyFileSync('build/rivers-v4.pmtiles', 'public/tiles/rivers.pmtiles');
  console.log('Wrote public/tiles/rivers.pmtiles');
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
VMAPS_PATCH_EOF

mkdir -p public/tiles
if [ -f "$SCRIPT_DIR/rivers.pmtiles" ]; then
  cp "$SCRIPT_DIR/rivers.pmtiles" public/tiles/rivers.pmtiles
else
  echo "ERROR: rivers.pmtiles not found next to this script — copy it alongside step55-patch.sh" >&2
  exit 1
fi

echo "Step 55 patch applied."
