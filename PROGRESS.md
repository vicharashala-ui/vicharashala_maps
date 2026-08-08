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

## Status: V1 functionally complete through Step 49 — spec build-out is done
- **Data pipeline**: 85/85 `rivers/{id}.json` authored + validated. `basins.json` (35), `states.json` (36), `cities.json` (14), `protected-areas.json` (837) all complete. Cross-refs (`protected_area_ids`, `rivers_flowing_through`, etc.) derived and merged. Search indexes built. `rivers.pmtiles` + `protected-areas.pmtiles` (8.68MB) built.
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
- **~13-20 rivers from spec §4.9's list are unmatched/flagged and NOT shipped** in V1's 85: includes Burhi Gandak, Dhansiri, Rushikulya, Purna, Girna, Vaitarna, plus others from Step 16's flagged list — genuine OSM/govt-shapefile coverage gap, deferred to manual digitizing (Phase 2).
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
**Nothing left to build.** §8 + §11 are now fully implemented; V1 scope (§14) is code-complete. Only 2 items remain, both Ashwin-side, not code:
1. **Search Console verification file** — needs his real `google{16-char-code}.html` from his Search Console account; drop into `public/`, no code to write.
2. **Cloudflare Web Analytics** — enable via the Cloudflare Pages dashboard (auto-injects the beacon script; `_headers`' CSP already allowlists `static.cloudflareinsights.com`/`cloudflareinsights.com` for this). Not a repo change.

After those: a browser/visual QA pass is the only thing left before launch (sandbox has no display, so this has to be Ashwin's own pass) — check things like actual font-swap behavior, dark/light toggle, map interactions end-to-end, mobile layout at real viewport sizes. If that QA pass turns up issues, that's the next real "step."

---

## Step log (condensed — full narrative detail for older steps is in git history / prior PROGRESS.md revisions if ever needed)

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
