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

## Current status: Step 9 COMPLETE — 3 more rivers recovered from the govt shapefile via better name-matching, plus a real duplicate-rivname data bug fixed; `research/rivers-index-reconciled.json` now has 63 govt-matched rivers, 43 still need geometry

### rivers-index.json research + reconciliation: done
Built via web research (batched by river system per spec §4.9), then reconciled against Step 5c/6's govt shapefile + HydroRIVERS data in Step 8. `research/rivers-index-reconciled.json` (106 entries) is the current working file — supersedes `rivers-index-draft.json`, which is kept only as a historical record of the pre-reconciliation research.

**Count correction**: spec §4.9's river lists actually total 107 named rivers (9 Indus + 26 Ganga + 15 Brahmaputra + 29 Peninsular-East + 14 Peninsular-West + 12 Coastal + 2 Inland Drainage), not the ~105 figure used throughout this project so far. Every named entry in §4.9 has a draft record now.

- **Indus** (9/9), **Ganga** (26/26), **Brahmaputra** (15/15), **Peninsular-East** (29/29), **Peninsular-West** (14/14) — all done in prior updates
- **Coastal** (12/12 done): Ulhas, Vaitarna, Savitri, Vashisthi, Kali (Karnataka), Netravati, Gurupur, Aghanashini, Damanganga, Swarnamukhi, Manimuktha, Vaippar
- **Inland Drainage** (2/2 done): Luni, Ghaggar-Hakra
- Every entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)

### Remaining open items before `prepareRivers.js`:
1. ~~Reconcile against Step 5c's govt data~~ — done, Step 8.
2. **Naming/identity questions**:
   - ~~**Kopili vs Kapili**~~ — resolved (Step 8): govt shapefile has one feature, matched under Kopili. `kapili` entry dropped as a duplicate, 107 → 106 total.
   - ~~**Purna**~~ — resolved, but not the way expected: the govt shapefile's one "Purna" feature is the *Godavari*-tributary Purna (basin "Godavari", origin "Ajanta Range"), not the Tapi-tributary one the draft uses (spec groups it with Narmada/Tapi/Mahi/Sabarmati — all west-flowing). Govt data for this entry was discarded as a false-positive match; the draft's Tapi-tributary Purna metadata stands, and it still needs its own geometry (now in the 46-river list).
   - **Vellar** (Peninsular-East) — still open, govt shapefile didn't match it either way, no new evidence. Tamil Nadu has two rivers by this name; draft used the Southern one.
3. **Length discrepancies >20%** between web research and govt data, flagged in Step 8/9's output, govt value used but worth a manual sanity check: Chenab (700→431km), Barak (524→100km), Subarnarekha (395→480km), Vaigai (258→312km), Bharathapuzha (209→100km), Kali/Karnataka (265→179km), Vaippar (130→87km).
4. **Entries with essentially no data found** (weakest of the weak — worth dedicated re-research before trusting): **Vashisthi** (no length at all), **Manimuktha** (nothing found), **Gurupur** (length is an unsourced guess), **Sankosh**/**Rangeet** (Brahmaputra, no length found), **Kamla** (Ganga, no length found)
5. **Everything else flagged `_needs_verification`** across all 7 batches — mostly derived/estimated lengths for transboundary rivers (India-only portion of a longer river) and unconfirmed `basin_area_india_km2`/`seasonal_type` values. Strip all `_source`/`_needs_verification` fields before final schema validation regardless.

### Not started yet
- **43 rivers without geometry** — see "Next step" for the remaining approach (name-matching improvements are exhausted, see Step 9)
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
Name-matching improvements are exhausted (Step 9) — checked all 43 remaining names against every one of the raw shapefile's 110 features (exact, substring, and Levenshtein-distance-2 fuzzy matching); no further real matches, only coincidental near-misses (e.g. Ravi~Mahi, Kosi~Musi — different rivers, distance 2 purely by chance). This 110-feature shapefile is a "major rivers only" dataset; the remaining 43 are mid-size peninsular/coastal/Himalayan rivers genuinely outside its scope, not a matching problem.

**43 rivers still need geometry**: Jhelum, Ravi, Spiti, Zanskar, Shyok, Kali Sindh, Ken, Sarda (Sharda), Burhi Gandak, Kosi, Mahananda, Mechi, Kamla, Bagmati, Rupnarayan, Dibang, Dhansiri, Manas, Sankosh, Rangeet, Rushikulya, Amaravathi, Kabini, Hemavathi, Shimsha, Arkavathi, Bhavani, Vellar (Southern), Tamiraparani, Chaliyar, Pamba, Zuari, Mandovi, Purna, Girna, Vaitarna, Savitri, Vashisthi, Gurupur, Aghanashini, Damanganga, Swarnamukhi, Manimuktha.

**Overpass is the only remaining path.** Still blocked on confirming reachability — run this in Git Bash and report the result:
```bash
curl -s -o /dev/null -w "%{http_code}\n" --max-time 15 \
  -X POST -H "Content-Type: text/plain" --data '[out:json][timeout:10];way["waterway"="river"]["name"="Zuari"](14.8,73.9,15.6,74.5);out geom;' \
  https://overpass-api.de/api/interpreter
```
`200` = reachable, safe to invest in a full rewrite of `scripts/fetchRivers.js` (bbox instead of the country-wide `area["ISO3166-1"="IN"]` lookup that likely caused the earlier 504, batched by river system so one timeout doesn't lose everything, rescoped to just these 43). Anything else = report back and we go manual-research-only for whatever's left.

---

## Completed steps log

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

