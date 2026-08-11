# HydroRIVERS tracer

Used to add rivers not covered by OSM/govt-shapefile matching (§4.9's spec list is ~105
rivers; 85 shipped from OSM/govt sourcing — the rest need HydroRIVERS since OSM has no
name-matched geometry for them).

## Requirements
- `HydroRIVERS_v10_as.shp` (+ .shx/.dbf/.prj) from hydrosheds.org/products/hydrorivers,
  staged at `build/raw/hydrorivers/` (gitignored, re-supply each session — see
  `scripts/joinHydroRivers.js` for the same requirement on the existing 85's pipeline).
- `tippecanoe` + `tile-join` (apt-get install -y tippecanoe on Debian/Ubuntu; not available
  on Windows — sandbox-only, matches the project's existing tippecanoe precedent).

## Pipeline
1. Clip to India: `pnpm exec mapshaper build/raw/hydrorivers/HydroRIVERS_v10_as.shp -proj wgs84 -clip bbox=68,6,98,36 -o build/hydrorivers-india-clip.geojson format=geojson`
2. Build the compact network index: `node scripts/hydrorivers-tracer/buildIndex.js` → `build/hydrorivers-network.json`
3. For each river, research ONE unambiguous mid-river waypoint (a town clearly on the
   channel — NOT the source, which is ambiguous near passes/divides where two valleys can
   share a headwater ridge, and NOT the confluence, which is ambiguous for a tributary since
   the larger river being joined always has more catchment area) and the mouth/confluence
   point, then: `import { traceRiver } from './trace.js'; traceRiver([lng,lat] /* waypoint */, [lng,lat] /* mouth */)`
4. Sanity-check `totalLenKm` and `strahlerOrder` against a literature reference before
   trusting the result — HydroRIVERS' static-DEM network is unreliable in flat floodplain
   and especially tidal/deltaic terrain (see Rupnarayan case below).

## Known limitations (found via real tracing, not theoretical)
- **Flat floodplain terrain**: naive nearest-vertex matching finds tiny disconnected
  field-drain fragments (~10 km² catchment) closer to a query point than the actual named
  river passing nearby. Fixed via `nearestOnSubstantialChannel()` — picks the
  largest-catchment reach within radius, not the closest one.
- **Confluences**: the downstream walk can overshoot by exactly one reach onto the larger
  river's own channel before a distance-tolerance check catches it (that reach's end
  coordinate is often still within tolerance of the confluence point, since it's the same
  location). Fixed via a catchment-jump detector (>3x and >500 km² single-step jump = stop
  before crossing).
- **Tidal/deltaic confluence zones** (e.g. Rupnarayan, which converges with the Hooghly and
  Damodar in a maze of tidal channels near Geonkhali): the network's own topology breaks
  down here — even the largest nearby reach can dead-end (`next=0`) with an implausibly
  large catchment value (indicating it's actually merged/shared tidal-creek data, not a
  single river's channel). This is a genuine HydroRIVERS limitation in this terrain type,
  not a bug — needs manual/OSM sourcing instead, same as the original 85's flagged rivers.

## Output → shipping a new river
`traceRiver()` returns `{ coords, totalLenKm, strahlerOrder, ... }`. To ship:
1. Author `public/data/rivers/{id}.json` (RiverDetail schema) — `length_km_india` should
   match the traced geometry's length exactly (the project's convention, confirmed against
   the existing 85: it's a measured length of the shipped line, not a quoted reference figure).
2. Append an entry to `public/data/rivers-index.json` (RiverIndexEntry schema) — `bounds` is
   the traced coords' bbox.
3. Re-extract the CURRENT `rivers.pmtiles` at full maxzoom fidelity, per-river-bbox-scoped
   (NOT `scripts/extractRiversFromPmtiles.mjs`'s whole-India z11 probe — that's simplified/
   lossy, fine for a quick look but would visibly downgrade the existing rivers' line
   quality if used as the rebuild source). Append the new river's feature(s), assign fresh
   sequential top-level numeric `id`s to every feature, rebuild via tippecanoe with the
   exact command from Spec_file.md §4.9 (`--include=id --include=stream_order`, z4–z14).
4. Regenerate `rivers-id-map.json` (riverId → array of that river's numeric feature ids).
