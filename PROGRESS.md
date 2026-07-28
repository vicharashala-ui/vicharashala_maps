# Vicharashala Maps — Progress

Spec: `VICHARASHALA_MAPS_SPEC.md` (upload alongside this file if starting a new session).
Package manager: **pnpm**. Environment: **native Windows** (Git Bash, no WSL).

## How to resume in a new session
1. Upload this `PROGRESS.md`.
2. `pnpm install` — `pnpm-lock.yaml` is committed, restores exact versions, not "latest."
3. `pnpm build` to confirm things still build before adding new code.
4. Continue at "Next step" below.

## Workflow
- Code/config changes ship as a `stepN-patch.sh` script — run from the project root in Git Bash. Each is tested end-to-end against a clean checkout before being handed over, not just "should work." Idempotent, includes `pnpm install`.
- Generated **binary artifacts** (e.g. `.pmtiles`) ship as plain files to drop into place — they're build output, not source, so a patch script doesn't make sense for them.
- Linux-only native tools (tippecanoe) aren't available on native Windows. Sandbox builds them and hands over the finished artifact instead.
- Source data comes from `https://github.com/vicharashala-ui/ecoguesser.git`, a sibling project with already-processed PA data matching this spec almost field-for-field.

## Current status: Step 3 complete — protected-areas.pmtiles built

### Not started yet
- Rivers pipeline (spec §4.7 steps ⑥⑦⑧) — needs OSM Overpass, not reachable from this sandbox; needs to run on your machine (Git Bash + curl/node, no compiled tools needed)
- State boundaries pipeline (step ⑨) — Mapshaper simplify + enrich; source available in ecoguesser, not yet pulled. Runs fine in Git Bash (Mapshaper is an npm package, not a native binary)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬) — depend on rivers existing first
- Everything in spec §5 onward: NanoStores, `MapView.tsx`, all components, theming, SEO, a11y, deployment

## Next step
**State boundaries pipeline (step ⑨)** — no rivers dependency, fully Git-Bash-friendly, unblocks the State Panel (§3.5) and the map's base layer. Will pull `india-states.geojson` from ecoguesser and run Mapshaper simplify + enrich as a `step4-patch.sh`.

---

## Completed steps log

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
