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

## Current status: Step 7 in progress — rivers-index.json metadata research, 20/105 rivers done

### rivers-index.json research progress (`research/rivers-index-draft.json`)
Built via web research (batched by river system per spec §4.9), NOT the shapefile's `build/rivers-govt-metadata.json` seed from Step 5c — that file lives in your gitignored `build/` dir from a prior session and wasn't available to cross-check here. **Action needed**: if you still have that file, share it so the overlapping fields (basin/origin text for the 61 matched rivers) can be reconciled against this research — government-sourced beats web-sourced where they conflict.

**Correction**: spec §4.9 actually defines 7 river-system groups, not 9 — Indus, Ganga, Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage. Fixing the miscount from the last update.

- **Indus system** (9/9 done): Indus, Jhelum, Chenab, Ravi, Beas, Sutlej, Spiti, Zanskar, Shyok
- **Ganga system** (11/26 done): Ganga, Bhagirathi, Alaknanda, Yamuna, Chambal, Banas, Kali Sindh, Parbati, Betwa, Ken, Son — remaining 15: Gomti, Ghaghra/Karnali, Sarda/Sharda, Gandak, Burhi Gandak, Kosi, Mahananda, Mechi, Kamla, Bagmati, Damodar, Hooghly, Barakar, Ajay, Rupnarayan
- Each entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)
- Fields with genuine sourcing gaps are flagged in each entry's `_needs_verification` array with the specific gap — not silently guessed. Worst offenders so far: **Chenab** (conflicting India-length figures, 960-1180km); **Yamuna** `basin_area_india_km2` (366,223km2 is the standard textbook figure, not independently re-confirmed this session); several MP/Rajasthan Chambal tributaries have inferred (not sourced) `seasonal_type`
- `_source` field on each entry records what was used (CWC preferred where available, then India-WRIS wiki, then Wikipedia/secondary) — strip before final schema validation
- 5 river-system groups remaining after Ganga: Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage

### Not started yet
- Rest of Ganga system (15 rivers) + 5 remaining river-system groups for rivers-index.json (see above)
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
1. Continue rivers-index.json research: rest of Ganga system (Gomti/Ghaghra/Gandak/Kosi group next, or reorder if you'd rather)
2. In parallel/after: rescoped Overpass for the 44 unmatched rivers' geometry
3. Once both are further along: reconcile `research/rivers-index-draft.json` against Step 5c's `build/rivers-govt-metadata.json` seed (send it over if you have it) before running `prepareRivers.js`

---

## Completed steps log

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
