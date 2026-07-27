# Vicharashala Maps — Progress

Spec: `VICHARASHALA_MAPS_SPEC.md` (upload alongside this file if starting a new session).
Package manager: **pnpm**.

## How to resume in a new session
1. Upload this `PROGRESS.md` + the project zip (or just this file if the user already has the repo locally).
2. `pnpm install` — `pnpm-lock.yaml` is committed, so this restores the exact versions below, not "latest."
3. `pnpm build` to confirm the scaffold still builds before adding new code.
4. Continue at "Next step" below.

## Status: Step 1 complete — project scaffold

### Done
- [x] Astro project initialized manually with `pnpm init` (not `create-astro`, to control exact versions — see Decisions)
- [x] Runtime deps installed: preact, @astrojs/preact, maplibre-gl, pmtiles, nanostores, @nanostores/preact, fuse.js, virtua, @fontsource/sora, @fontsource/inter, tailwindcss + @tailwindcss/vite
- [x] Dev dep: zod (build-time validation, §4.7)
- [x] `astro.config.mjs` — static output, Preact integration, Tailwind v4 Vite plugin
- [x] `tsconfig.json` extending `astro/tsconfigs/strict`
- [x] Full folder skeleton per spec §5.2 (`src/components/{Map,Panels,Browse,RiverOfTheDay,Search,QuickStats,Layout}`, `src/content/blog`, `src/pages/{river,state,basin,blog}`, `src/boundaries`, `src/scripts`, `public/{tiles,geojson,data}`, top-level `scripts/`, `build/`)
- [x] `src/styles/global.css` with Tailwind v4 `@import`
- [x] Placeholder `src/pages/index.astro` — verifies the pipeline renders
- [x] `pnpm build` verified clean (static output to `dist/`, Tailwind classes confirmed in compiled CSS)
- [x] `pnpm dev` verified serving on localhost
- [x] `.gitignore`, git repo initialized, initial commit made

### Pinned versions (locked in `pnpm-lock.yaml`)
| Package | Version | Note |
|---|---|---|
| astro | 6.4.8 | Spec requires v6; latest is 7.1.4 — do not upgrade without re-checking spec compatibility |
| @astrojs/preact | 5.1.5 | NOT 6.0.1 — see Decisions |
| preact | 10.29.7 | |
| vite | 7.3.6 | Pinned explicitly — see Decisions |
| maplibre-gl | 5.24.0 | Spec asks for v5.x ✓ |
| pmtiles | 4.4.1 | |
| tailwindcss / @tailwindcss/vite | 4.3.3 | |
| nanostores / @nanostores/preact | 1.4.1 / 1.1.0 | |
| fuse.js | 7.5.0 | Version-drift guard in §4.7 step ⑬ depends on this staying in sync with the build script |
| virtua | 0.44.3 | |
| zod | 3.25.76 | v3, not v4 — v4 not tested against this spec's `.refine()` usage |

### Decisions / gotchas log
- **Scaffolded manually, not via `create-astro`**: needed exact version pinning (spec targets Astro v6; registry default is v7). `pnpm create astro` doesn't cleanly accept a pinned version.
- **`@astrojs/preact` downgraded 6.0.1 → 5.1.5**: 6.0.1 pulls in Vite 8 (rolldown-based, still experimental) via `@preact/preset-vite`, which conflicts with `@tailwindcss/vite@4.3.3` and breaks the build (`Missing field tsconfigPaths...` rolldown error). 5.1.5 is the line built against Vite 7, matching Astro 6's own `vite: ^7.3.2` requirement.
- **`vite` added as an explicit devDependency (`^7.3.2`)**: without this, pnpm's peer resolution let a second copy of Vite 8 sneak in via `@tailwindcss/vite`'s peer range (`^5||^6||^7||^8`), causing "Found 2 versions of vite" and the same build failure. Pinning collapses everything to one Vite 7 instance.
- **zod v3, not v4**: spec's `scripts/schemas.js` uses `.refine()` patterns written against v3; not re-verified against v4's API changes.

### Not started yet
Everything in spec §4.7 (data pipeline scripts), §5 (stores, MapView, components), §6 onward (theming, SEO, a11y, deployment). See spec Phase 1 checklist (§14) for the full list — nothing there is checked off yet.

## Next step
**Step 2: Data pipeline foundation** — `scripts/schemas.js` (Zod schemas from spec §4.7) first, since every later pipeline script validates against it. Needs input files from the user before it can run for real: raw `india-states.geojson`, the 837 PA boundary GeoJSONs, and `protected-areas.json` (spec says these are "pre-processed / done" — user has them, not yet uploaded).

**Open question for the user**: does the user have those source data files ready to upload, or should Step 2 start with the non-data-dependent pieces first (NanoStores setup, MapView.tsx skeleton, theme tokens)?
