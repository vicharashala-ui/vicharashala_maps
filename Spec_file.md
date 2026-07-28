# Vicharashala Maps — Implementation Specification

**URL**: `vicharashalamaps.pages.dev`
**Purpose**: Multi-category interactive atlas of India — Rivers and Protected Areas as V1 categories
**Status**: Implementation-ready

---

## 1. Project Overview

Free, static, interactive atlas of India. V1 ships two categories: **Rivers** and **Protected Areas**. Future categories (Cities, Geological Features) share the same map canvas/architecture. All categories view simultaneously; any entry links to associated entries in other categories. Lakes and Dams are out of scope — not tracked in any form (no schema fields, no data pipeline, no future-phase entry).

**Audience**: Students (grades 6–12), UPSC aspirants, educators, general public.
**Monetisation**: Affiliate links at launch; Google AdSense added post-V1 (Phase 4, §7, §9). Zero infrastructure cost.

## 2. Goals

| Goal | Description |
|---|---|
| Educational accuracy | Data from NWDA, CWC, MoEFCC, WII, NCERT, Survey of India |
| Visual clarity | Layers distinguishable at a glance; toggleable independently |
| Cross-category linking | Every river shows associated PAs and vice versa |
| Performance | Lighthouse > 90 mobile; initial load < 2s on 4G |
| SEO | Static pages for rivers; PA discoverability via map + blog |
| Zero cost | No paid infrastructure, domains, or data sources |

---

## 3. Functional Requirements

### 3.1 Core Map

- MapLibre GL JS renders all layers on one WebGL canvas.
- **Style stack** (bottom → top): `background` (ocean) → land fill → state borders → rivers → `pa-wls-fill` → `pa-ramsar-fill` → `pa-br-fill` → `pa-tr-fill` → `pa-np-fill` → PA outlines (same order as fills) → labels. The 10 PA layers (5 fill + 5 outline) are intentionally *not* consolidated into 2 via data-driven `match` expressions — not a bottleneck at 839 features, and consolidating would trade the current simple paint-order guarantee for a fragile dependency on tippecanoe's feature ordering within one layer.
- State boundaries always visible. No external tile CDN — all geometry from local PMTiles/GeoJSON.
- **Layer Control** (top-right): independent Rivers/Protected Areas toggles; PA sub-category checkboxes expand when PA enabled.
- **Reset View**: `map.fitBounds([68.1, 6.4, 97.4, 37.6], { duration: 400, padding: 20 })` — `[west, south, east, north]`. Same array is the constructor's `bounds` option below.
- `minZoom: 4, maxZoom: 14` set explicitly on the `Map` constructor — prevents over-zoom past the deepest available tile.
- `dragRotate: false, pitchWithRotate: false, touchPitch: false` on the constructor — north-up lock (state borders/basin legend depend on it).
- Click priority at overlapping features: NP > TR > BR > Ramsar > WLS > River (matches fill z-order; NP wins ties as highest conservation status).

**Source registration** (`MapView.tsx`):
```ts
import { Protocol } from 'pmtiles';
const protocol = new Protocol();
maplibregl.addProtocol('pmtiles', protocol.tile); // unbound — matches pmtiles v5.x examples

map.addSource('india-states',    { type: 'geojson', data: '/geojson/india-states.geojson' });
map.addSource('rivers',          { type: 'vector', url: 'pmtiles:///tiles/rivers.pmtiles' });
map.addSource('protected-areas', { type: 'vector', url: 'pmtiles:///tiles/protected-areas.pmtiles' });
```

**Initial bounds on deep link** (read client-side before constructing the map — `output: 'static'` has no per-request server):
```ts
import { riversIndex } from '../../utils/dataStore'; // §5.3 — inlined at build time, no fetch

const params = new URLSearchParams(location.search);
let initialBounds: [number, number, number, number] | undefined;

const riverId = params.get('river');
if (riverId) initialBounds = riversIndex.find(r => r.id === riverId)?.bounds;

const paId = params.get('pa');
if (paId) {
  // §3.13 force-triggers loadPAData() for a direct /?pa=... load
  const pa = (await loadPAData()).protectedAreas.find(p => p.id === paId);
  initialBounds = pa?.bounds ?? (pa ? centroidFallbackBounds(pa) : undefined); // §4.2
}

const map = new maplibregl.Map({
  container: 'map',
  style: mapStyle,
  bounds: initialBounds ?? [68.1, 6.4, 97.4, 37.6],
  fitBoundsOptions: { padding: 20 },
  minZoom: 4, maxZoom: 14,
  dragRotate: false, pitchWithRotate: false, touchPitch: false,
});
```
`bounds` is a native constructor option — sets the initial camera directly, no post-mount `fitBounds()` jump. `river.bounds`/`pa.bounds` are `[west, south, east, north]`, precomputed at build time via Turf.js `bbox()` (§4.1, §4.2) — never computed in-browser. `centroidFallbackBounds()` (§4.2) builds a fixed-radius box around `[centroid_lng, centroid_lat]`; shared with the PA cross-link fallback (§3.3).

### 3.2 Layer Control Panel

```
┌─────────────────────────┐
│  Layers                 │
├─────────────────────────┤
│  ✓ Rivers               │
├─────────────────────────┤
│  ○ Protected Areas      │
│    □ National Parks     │
│    □ Wildlife Sanctuaries│
│    □ Tiger Reserves     │
│    □ Biosphere Reserves │
│    □ Ramsar Sites       │
└─────────────────────────┘
```

Enabling "Protected Areas" (or first PA Browse tab visit) calls `loadPAData()` (§5.3) if not loaded, then enables PA layers. Sub-category toggles call `map.setLayoutProperty('pa-{category}-fill'/'outline', 'visibility', ...)` — no re-fetch. Spinner during in-flight fetch; see §3.12 for error state.

### 3.3 Rivers — Selection & Detail Panel

Click on river polyline or Browse row:
- River glows (`selected: true`); tributaries/distributaries → `highlighted: true`. IDs resolve via `rivers-id-map.json` (string river ID → array of segment Feature IDs — one river is usually several OSM way segments), one `setFeatureState` call per segment.
- All other rivers dim: `['case', ['boolean', ['feature-state', 'selected'], false], 1.0, ['boolean', ['feature-state', 'highlighted'], false], 0.7, 0.15]`
- Associated PA polygons highlight regardless of PA layer visibility.
- Detail panel (right side desktop; bottom sheet mobile):
  - Name · local name · basin badge
  - Source: name, district, state, altitude m
  - Sink: name, type, location
  - Length km (India) · Total km if transboundary
  - Basin area km² (India / total)
  - States it flows through (clickable chips)
  - Tributaries: left/right bank (clickable) · Distributaries (clickable)
  - Seasonal type · Drainage type · Significance tags · Transnational flag
  - **Associated Protected Areas**: name · category badge · "Show on map"
    - **Polygon case** (`has_boundary: true`): enables that category's PA layer, highlights via `map.setFeatureState({ source: 'protected-areas', sourceLayer: 'protected-areas', id: numericId }, { highlighted: true })`. `numericId` from `pa-id-map.json` (part of `loadPAData()`, §5.3).
    - **Boundary-less case** (`has_boundary: false` — 2 TRs rendered as DOM `Marker`s, §4.6): no PMTiles feature to target `setFeatureState` on; instead `map.flyTo(pa.bounds ?? centroidFallbackBounds(pa))` + toggle `highlighted` CSS class on the `Marker` element.
    - Clearing selection resets feature state (polygon) or removes the class (marker). Never use `setFilter` for highlighting — destructive to existing visibility filters.
  - Basin map inset: 200×160 SVG pre-rendered at build time

### 3.4 Protected Areas — Info Panel

Click on PA polygon, boundary-less `Marker`, or Browse row:
- Polygon: fill opacity → full; river lines inside remain visible. Marker: gets a selected style (no fill to brighten).
- Info panel:
  - Category badge · Name · State(s) · Area km²
  - **Associated rivers**: clickable list → opens river detail panel (back nav maintained)
  - "Show on map" per river (rivers always have geometry — no boundary-less case this direction)
  - Year established (if available)
  - [Open Wikipedia →] (`rel="noopener noreferrer"`)
  - Centroid coordinates (2 TRs without polygons: point marker, dashed circle)

No static PA pages — Wikipedia handles deep content.

### 3.5 State Panel

Click state/UT polygon (`india-states` source) or state chip:
- Panel (same side/sheet behavior as §3.3/§3.4):
  - Name · capital · admin type (State/UT) badge
  - Rivers flowing through (chips, `states.json.rivers_flowing_through`)
  - Associated Protected Areas (chips, `states.json.protected_area_ids`)
  - Notable cities (`states.json.notable_city_ids`, if any)
- No fetch — all fields already in `states.json`, loaded upfront as part of core data (§5.3).
- `/?state={id}` deep-links to this panel (§3.13); `/state/[id].astro` is the static SEO equivalent (§5.5).

### 3.6 Filter Panels

**River filter panel** (left rail desktop; drawer mobile):

| Filter | Type | Phase |
|---|---|---|
| State/UT | Multi-select (36) | V1 |
| Basin | Multi-select (color-coded) | V1 |
| Drainage Type | Single-select: Himalayan / Peninsular / Coastal / Inland | V1 |
| Transnational | Toggle | V1 |
| Origin | Glacial / Rain-fed / Spring-fed / Mixed | Phase 2 |
| Seasonality | Perennial / Seasonal / Ephemeral | Phase 2 |
| Length | Range slider 0–3,000 km | Phase 2 |
| Navigability | Toggle | Phase 2 |

**PA filter panel**:

| Filter | Type | Phase |
|---|---|---|
| Category | Multi-select: NP/WLS/TR/BR/Ramsar | V1 |
| State/UT | Multi-select (36) | V1 |
| Area | Range slider km² | Phase 2 |
| Year established | Range slider | Phase 2 |

Both panels: active filter chips with individual dismiss; **Reset All** with count badge.

### 3.7 Browse / List Mode

Sidebar tabs: **[Rivers]** | **[Protected Areas]**

- **Rivers**: basin-grouped; row = name · length km · drainage type badge · transnational flag. Tap → fly to river + open detail panel.
- **PA**: category-grouped or flat (filter-driven); row = name · category badge · state · area km². Tap → fly to centroid, highlight polygon, open info panel.
- Both use `virtua` virtual scrolling (rivers ~105 — §4.9; PAs 839).

### 3.8 Global Search

- Searches Rivers (name+aliases), PAs (name+aliases), States. Results grouped by type.
- Fuse.js fuzzy match over a merged index: `rivers-index.json` + `states.json` (core data, §5.3), with `protected-areas.json` merged in once `loadPAData()` resolves. Before that, search returns River/State results only (no PA-results indicator).
- `aliases` sit in Fuse `keys` at lower weight than `name` — e.g. "Ganges" matches "Ganga" without outranking an exact name hit.
- Indexes pre-compiled at build time (`Fuse.createIndex()` → `search-index-primary.json`/`search-index-pa.json`, §4.7 step ⑬), loaded via `Fuse.parseIndex()` — avoids client-side tokenization, most valuable when merging 839 PA records synchronously. Fuse.js version must match exactly between build script and client bundle (single `package.json` entry); step ⑬ stamps + asserts this at build time.
- Input debounced ~150ms before `fuse.search()` (separate from the 300ms URL-state debounce in §3.13) — avoids re-rendering results and re-firing the `aria-live` announcement (§12) on every keystroke.
- Click result → fly to feature, select, open panel. Keyboard shortcut `/` on desktop.

### 3.9 River of the Day

Rotation: `Math.floor((Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) - Date.UTC(2026, 0, 1)) / 86400000) % rivers.length` — UTC-based, same river globally per calendar day.
Card: name · local name · basin banner · length · basin area · states count · "Explore". Renders from `rivers-index.json` fields already in core data (§5.3) — no fetch. "Explore" opens full detail panel (fetches `/data/rivers/{id}.json`, §3.3).
`localStorage` key `rotd_collapsed` persists collapse state. Mobile: collapsed by default after first view.

### 3.10 Comparison Mode (Rivers only, V1)

`/compare`. Select 2–3 rivers. Table: Length, Total Length, Basin Area, Drainage Type, Seasonal Type, States, Tributaries, Navigable, Flows into. Shareable: `/compare?r1=ganga&r2=yamuna[&r3=ghaghra]`. PA comparison — Phase 2.

### 3.11 Quick Stats Banner

Desktop only, static strip: "**X rivers** · **Y protected areas** across **Z categories** · all **28 states + 8 UTs**."

### 3.12 Loading & Error States

- **Initial load**: `<img src="/india-placeholder.svg">` until MapLibre initializes; slim progress bar.
- **Search index fetch failure**: `search-index-primary.json` is the only network-fetched member of former "core data" (rivers-index/states are now inlined, §5.3) — failure only affects search readiness. `SearchBar.tsx` shows inline "Search unavailable. [Retry]"; everything else stays usable.
- **PA data fetch failure**: `loadPAData()`'s three files can fail independently. Spinner (§3.2/§3.7) replaced by inline "Couldn't load protected areas. [Retry]" in Layer Control/PA Browse tab — no full-page escalation (rivers-only browsing unaffected).
- **Detail fetch**: skeleton card while `/data/rivers/{id}.json` loads.
- **Tile load failure**: "Could not load map data. [Retry]" on MapLibre `error` event.
- **No search results**: "No results for '{query}'" + "Clear" link.

### 3.13 URL State Management

`history.replaceState` throughout — never `pushState`. Back button always lands on the prior document, not an in-app state; no `popstate` handler needed (full navigations, including Back/Forward, are handled by the "read `location.search` at construction" logic in §3.1).

**300ms debounce in `urlState.ts`, scoped to exactly the `replaceState` call.** NanoStores writes and MapLibre calls (`setFeatureState`, `fitBounds`, `flyTo`, `setLayoutProperty`) execute synchronously in the originating handler — never wrapped in the same debounced function as the URL write:
```ts
// WRONG
debounce(() => { store.set(x); map.flyTo(y); updateUrl(z); })
// CORRECT — URL sync lags the UI; the UI never does
store.set(x); map.flyTo(y); debouncedUpdateUrl(z);
```

| Action | URL |
|---|---|
| Select river | `/?river=ganga` |
| Select PA | `/?pa=kaziranga` |
| Open state panel | `/?state=assam` |
| River filters | `/?basin=ganga-basin&type=himalayan` |
| PA filters | `/?pa-categories=np,tr&pa-state=assam` |
| Active layers | `/?layers=rivers,protected-areas` |
| Reset | `/?` |

Direct URL load auto-selects the feature and opens its panel. `/?pa=...` force-triggers `loadPAData()` (§5.3) and enables the PA layer even without prior Layer Control interaction; `MapView.tsx` awaits this fetch before constructing the map (deep-link case only) so `bounds` is available for the constructor (§3.1). Normal loads (no `pa=`) stay on-demand.

---

## 4. Data Architecture

### 4.1 Rivers Schema

**`/data/rivers-index.json`** — index for browse/filter/search/ROTD; part of core data (§5.3):
```json
[{
  "id": "brahmaputra", "name": "Brahmaputra", "local_name_hi": "ब्रह्मपुत्र",
  "basin": "brahmaputra-basin", "length_km_india": 916, "basin_area_india_km2": 194413,
  "drainage_type": "himalayan", "stream_order": 1, "seasonal_type": "perennial",
  "origin_type": "glacial", "navigable": true, "transnational": true,
  "states": ["arunachal-pradesh", "assam"], "aliases": ["Yarlung Tsangpo", "Jamuna"],
  "bounds": [88.0, 24.6, 97.4, 30.5]
}]
```
- `states`: required here (not just in detail JSON) so the V1 State/UT filter doesn't need per-river fetches.
- `local_name_hi`, `basin_area_india_km2`: duplicated from detail JSON so River of the Day (§3.9) needs no fetch.
- `stream_order`: manually assigned for curated rivers (~105, §4.9); cross-checked against HydroRIVERS Strahler data (§4.8).
- `aliases`: duplicated from `rivers/{id}.json.aliases` (plain names, parenthetical country tags stripped) — this is the file the upfront Fuse index (§3.8) reads.
- `bounds`: `[west, south, east, north]`, computed by `prepareRivers.js` via Turf.js `bbox()` over the merged river geometry — feeds §3.1.

**`/data/rivers/{id}.json`** — detail, fetched on selection. Manually authored (like `states.json`/`basins.json`/`cities.json`); `spatialIntersect.js` (§4.7 step ⑪) only writes `protected_area_ids`:
```json
{
  "id": "brahmaputra", "name": "Brahmaputra",
  "aliases": ["Yarlung Tsangpo (Tibet)", "Jamuna (Bangladesh)"],
  "local_names": { "hi": "ब्रह्मपुत्र", "as": "ব্ৰহ্মপুত্ৰ" },
  "basin": "brahmaputra-basin", "type": "main", "drainage_type": "himalayan",
  "seasonal_type": "perennial", "origin_type": "glacial", "stream_order": 1,
  "wikimedia_image_id": null,
  "source": { "name": "Angsi Glacier", "state": "tibet", "altitude_m": 5210, "coordinates": [82.0, 30.5] },
  "sink": { "name": "Bay of Bengal", "type": "sea", "location": "Bangladesh (as Jamuna)", "coordinates": [89.8, 23.0] },
  "length_km_india": 916, "length_km_total": 2900,
  "basin_area_total_km2": 712035, "basin_area_india_km2": 194413,
  "states_flows_through": ["arunachal-pradesh", "assam"],
  "basin_states": ["arunachal-pradesh", "assam", "nagaland", "meghalaya"],
  "tributaries": { "left": ["dibang", "lohit", "dhansiri"], "right": ["subansiri", "kameng", "manas"] },
  "distributaries": [],
  "protected_area_ids": ["kaziranga", "manas", "dibru-saikhowa", "orang", "pakke"],
  "navigable": true, "transnational": true,
  "transnational_countries": ["china", "bhutan", "bangladesh"],
  "significance": ["irrigation", "navigation", "biodiversity"],
  "notable_city_ids": ["guwahati", "dibrugarh"], "upsc_relevant": true,
  "did_you_know": ["The Brahmaputra is one of the world's largest rivers by discharge."]
}
```

**Field notes**:
- `type`: `main | tributary | distributary` · `drainage_type`: `himalayan | peninsular | coastal | inland` · `seasonal_type`: `perennial | seasonal | ephemeral` · `origin_type`: `glacial | rain-fed | spring-fed | mixed`
- All `coordinates` fields: `[lng, lat]` (GeoJSON convention), throughout every schema in this section
- `length_km_total` > `length_km_india` for all `transnational: true`
- Left/right bank defined facing downstream
- `protected_area_ids`: populated by `spatialIntersect.js`
- `wikimedia_image_id`: Commons filename, e.g. `"Brahmaputra_River_at_Guwahati.jpg"` → `https://commons.wikimedia.org/wiki/Special:FilePath/{id}?width=800`. `null` in V1, populated Phase 2.

### 4.2 Protected Areas Schema (`/data/protected-areas.json`)

Flat array, 839 records — both browse index and full data (no per-site detail files). Loaded on demand by `loadPAData()` (§5.3):
```json
[{
  "id": "kaziranga", "name": "Kaziranga National Park", "category": "np",
  "state": ["assam"], "area_km2": 858.98,
  "centroid_lat": 26.6779, "centroid_lng": 93.3714,
  "has_boundary": true, "river_ids": ["brahmaputra", "dhansiri", "diphlu"],
  "year_established": 1974,
  "wikipedia_url": "https://en.wikipedia.org/wiki/Kaziranga_National_Park",
  "upsc_relevant": true, "aliases": [], "bounds": [93.05, 26.57, 93.61, 26.78],
  "iucn_status": "IV", "biome_type": "tropical-moist-broadleaf-forest",
  "endemic_species": ["Eastern swamp deer"]
}]
```

**Field notes**:
- `category`: `np | wls | tr | br | ramsar` — one per record; sites with multiple designations get one canonical record per designation (different boundaries)
- `state`: array (some PAs span multiple states)
- `has_boundary: false` for 2 TRs — centroid point markers with dashed circle (§4.6, §3.3, §3.4)
- `river_ids`: populated by `spatialIntersect.js`; may be empty
- `wikipedia_url`: auto-derived `https://en.wikipedia.org/wiki/${name.replace(/ /g, '_')}`, manually corrected for disambiguation pages
- `year_established`: `null` when unknown (never omitted — callers do `pa.year_established !== null`); available for ~107 NPs, sparse for WLS
- `aliases`: alternate names (e.g. "Corbett"); `[]` for most sites; feeds same Fuse index as `rivers-index.json.aliases`
- `bounds`: `[west, south, east, north]` via Turf.js `bbox()` (§4.7 step ④); `null` for the 2 boundary-less TRs (use `centroidFallbackBounds()`, §3.1)
- `iucn_status`: IUCN **Protected Area Management Category** (`Ia|Ib|II|III|IV|V|VI`, nullable) — distinct from IUCN Red List species status. `null` for PAs without a recorded category; do not infer from `category` (India's legal designations don't map 1:1 to IUCN's tiers)
- `biome_type`: WWF terrestrial/freshwater biome enum (e.g. `tropical-moist-broadleaf-forest`, `montane-grassland-shrubland`, `mangrove`, `desert`, `freshwater-wetland`)
- `endemic_species`: curated, 1–3 flagship species per site — not exhaustive (size budget, §11.3)
- Size: ~839 × ~230 bytes ≈ ~195KB raw / ~38KB Brotli — re-measure at implementation

**ID prefix → category** (`ensureProperties.js`, §4.7 step ③): `np_→np` `ws_→wls` `tr_→tr` `br_→br` `rs_→ramsar`

### 4.3 Basin Schema (`/data/basins.json`)

```json
{
  "id": "brahmaputra-basin", "name": "Brahmaputra Basin",
  "color_light": "#288948", "color_dark": "#50C878",
  "area_km2": 712035, "states": ["arunachal-pradesh", "assam", "meghalaya"],
  "main_river": "brahmaputra", "rivers": ["brahmaputra", "dibang", "lohit", "subansiri", "manas"],
  "area_rank": 3
}
```
Basin color is supplementary — identity always also shown via text label/badge, so no separate colorblind-safe palette needed (§12). `color_light`/`color_dark` split because one flat value can't clear 3:1 non-text contrast against `--color-land` in both themes (§6.1). River line layers read the active variant via `getComputedStyle`/`data-theme` (same mechanism as `--color-water`, §5.6). The `Basin` Zod schema (§4.7) enforces the contrast ratio on every edit.

### 4.4 State Schema (`/data/states.json`)

```json
{
  "id": "assam", "name": "Assam", "admin_type": "state", "capital": "Dispur",
  "rivers_flowing_through": ["brahmaputra", "barak"], "basin_rivers": ["brahmaputra", "barak"],
  "notable_city_ids": ["guwahati"], "protected_area_ids": ["kaziranga", "manas", "dibru-saikhowa", "orang"]
}
```
`admin_type`: `state | ut`. GeoJSON lookup: `feature.properties.id === state.id`.

### 4.5 Ancillary Schemas

**`/data/cities.json`** (canonical ghat data source):
```json
{ "id": "guwahati", "name": "Guwahati", "state": "assam", "river": "brahmaputra",
  "river_bank": "left", "coordinates": [91.7362, 26.1445], "significance": ["religious", "tourism"],
  "ghats": [{ "id": "umananda-ghat", "name": "Umananda Ghat", "significance": "religious" }] }
```
`river_bank`: left/right facing downstream.

Lakes and Dams are out of scope entirely — no `dams.json`/`dams.geojson`/`lakes.json`/`hydraulic_structures` at any phase.

**Manual authorship**: `name`/`admin_type`/`capital` (`states.json`), `color_light`/`color_dark`/`area_km2` (`basins.json`), city `coordinates`/`ghats` (`cities.json`) — small, fixed datasets, no generation script. Exception: `states.json`'s relational arrays (`rivers_flowing_through`, `protected_area_ids`, `notable_city_ids`) are derived by `deriveStateCrossRefs.js` (§4.7 step ⑫) from the already-authoritative river/PA/city records.

### 4.6 Tile & GeoJSON Files

```
public/
  tiles/
    rivers.pmtiles            — all river tiers, zoom 4–14; source-layer: "rivers"
    protected-areas.pmtiles   — 837 PA polygons, zoom 4–14; source-layer: "protected-areas"
  geojson/
    india-states.geojson      — 36 features; id/admin_type/capital enriched; ~90kB Brotli
  india-placeholder.svg       — pre-load state; generated from india-boundary.geojson at 0.05°
  data/
    rivers-index.json
    rivers/{id}.json
    protected-areas.json
    pa-id-map.json             — { "kaziranga": 1, ... } string ID → numeric Feature ID
    rivers-id-map.json         — { "dibang": [14, 15, 22], ... } river ID → segment Feature IDs
    basins.json  states.json  cities.json
```

`india-states.geojson`: loaded as a MapLibre GeoJSON source at runtime (36 features, 90kB — fine as direct GeoJSON). `india-boundary.geojson` is setup-time only (SVG placeholder gen); never served — MapLibre uses a `background` layer for ocean.

**Boundary-less TR handling**: 2 TRs (`has_boundary: false`) absent from `protected-areas.pmtiles`. At PA layer activation, `ProtectedAreasLayer.tsx` filters `protected-areas.json` for `has_boundary === false`, adds them as MapLibre `Marker`s at `[centroid_lng, centroid_lat]` with a dashed circle. Any PA-by-ID highlight code (§3.3) must branch on this flag rather than assume a paintable feature exists.

### 4.7 Data Pipeline

One-time, at project setup; outputs committed to `public/`. Not part of the Astro build.

**Validation**: `scripts/schemas.js` — one Zod schema per record shape in §4.1–§4.4 (`RiverIndexEntry`, `ProtectedArea`, `Basin`, `State`); build-only devDependency, never shipped. Each pipeline step calls the matching `.parse()` immediately before writing:
- ① `processData.js` validates all 839 records (`ProtectedArea`) on initial write
- ④ `mergeFeatures.js` re-validates after writing `bounds`
- ⑦ `prepareRivers.js` validates each entry (`RiverIndexEntry`) after writing `bounds`
- ⑫ `deriveStateCrossRefs.js` validates every `states.json` record (`State`) after deriving relational arrays
- `basins.json` is hand-edited, no pipeline step writes it — its `Basin` schema (incl. contrast guard) runs via `scripts/validateBasins.js`, wired as `package.json` `"prebuild"` so it fires on every `npm run build`, not just initial setup
- Steps ③ (`ensureProperties.js`) and ⑨ (`enrichStates.js`) write to `src/boundaries/`/`public/geojson/`, no record schema. Step ⑬ (`buildSearchIndex.js`) has its own version-drift guard instead (see step ⑬)

```js
// scripts/schemas.js — single source of truth, mirrors §4.1–§4.4
import { z } from 'zod';

export const RiverIndexEntry = z.object({
  id: z.string(), name: z.string(), local_name_hi: z.string(),
  basin: z.string(), length_km_india: z.number().positive(),
  basin_area_india_km2: z.number().positive(),
  drainage_type: z.enum(['himalayan', 'peninsular', 'coastal', 'inland']),
  stream_order: z.number().int().positive(),
  seasonal_type: z.enum(['perennial', 'seasonal', 'ephemeral']),
  origin_type: z.enum(['glacial', 'rain-fed', 'spring-fed', 'mixed']),
  navigable: z.boolean(), transnational: z.boolean(),
  states: z.array(z.string()), aliases: z.array(z.string()),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]),
});

export const ProtectedArea = z.object({
  id: z.string(), name: z.string(),
  category: z.enum(['np', 'wls', 'tr', 'br', 'ramsar']),
  state: z.array(z.string()), area_km2: z.number().positive(),
  centroid_lat: z.number(), centroid_lng: z.number(),
  has_boundary: z.boolean(), river_ids: z.array(z.string()),
  year_established: z.number().int().nullable(),
  wikipedia_url: z.string().url(), upsc_relevant: z.boolean(),
  aliases: z.array(z.string()),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]).nullable(),
  iucn_status: z.enum(['Ia', 'Ib', 'II', 'III', 'IV', 'V', 'VI']).nullable(),
  biome_type: z.string(),
  endemic_species: z.array(z.string()).max(3),
});

export const State = z.object({
  id: z.string(), name: z.string(),
  admin_type: z.enum(['state', 'ut']), capital: z.string(),
  rivers_flowing_through: z.array(z.string()), basin_rivers: z.array(z.string()),
  notable_city_ids: z.array(z.string()), protected_area_ids: z.array(z.string()),
});

// Contrast guard — same luminance math as §6.1; run here so a bad basin color fails the build.
function contrastRatio(hexA, hexB) { /* WCAG relative-luminance formula */ }
const LAND_LIGHT = '#D4E6C3', LAND_DARK = '#1E3A2F';
export const Basin = z.object({
  id: z.string(), name: z.string(),
  color_light: z.string(), color_dark: z.string(),
  area_km2: z.number().positive(), states: z.array(z.string()),
  main_river: z.string(), rivers: z.array(z.string()), area_rank: z.number().int(),
}).refine(b => contrastRatio(b.color_light, LAND_LIGHT) >= 3.0, {
  message: 'color_light fails 3:1 non-text contrast against --color-land (light)',
}).refine(b => contrastRatio(b.color_dark, LAND_DARK) >= 3.0, {
  message: 'color_dark fails 3:1 non-text contrast against --color-land (dark)',
});
```

**Protected Areas pipeline** (`src/boundaries/` = 837 simplified boundary GeoJSONs):

```
① scripts/processData.js → public/data/protected-areas.json (839 records)

② scripts/simplifyBoundaries.js → src/boundaries/*.geojson (837 files; Visvalingam 200m tolerance; keep-shapes)
   Note: 2 TRs have has_boundary:false — centroid only, no boundary file

③ scripts/ensureProperties.js
   → injects {name, category, area_km2} into each boundary file's properties; RESOLVES AND
     OVERWRITES properties.id with the canonical protected-areas.json slug
   → Raw properties.id on disk carries the prefixed filename ID (e.g. "br_nokrek_biosphere_reserve",
     "np_dinosaur_fossil_np", "tr_bor"). Top-level Feature id is absent — assigned in step ④.
   → Two-stage ID resolution (filenames inconsistently suffixed):
       1. Derive category from prefix; strip prefix + first "_"      e.g. "ws_bakhira_wls" → "bakhira_wls"
       2. Replace "_" with "-" → "bakhira-wls"; look up in protected-areas.json
       3. If no match: strip a trailing _np/_ws/_tr/_br/_rs/_ramsar token, retry
          (e.g. "ws_bakhira_wls" → "bakhira")
       4. If still no match: write {file, attempted_keys} to build/unmatched-boundaries.json,
          continue — reconcile by hand before step ④
   → prefix → category: np_→np ws_→wls tr_→tr br_→br rs_→ramsar

④ scripts/mergeFeatures.js
   → merges 837 files → build/pa-merged.geojson (single FeatureCollection)
   → assigns a sequential integer (1-based) as top-level Feature id — tippecanoe preserves it in
     tiles, enabling map.setFeatureState({ id: numericId, ... })
   → reads properties.id directly (already canonical, from step ③)
   → writes public/data/pa-id-map.json: { "kaziranga": 1, ... } (must live in public/, not build/)
   → computes turf.bbox() per feature → protected-areas.json.bounds; null for the 2 boundary-less TRs

⑤ tippecanoe
   tippecanoe --output=public/tiles/protected-areas.pmtiles \
     --layer=protected-areas \
     --minimum-zoom=4 --maximum-zoom=14 \
     --drop-smallest-as-needed \
     --include=id --include=category \
     --name="India Protected Areas" --attribution="MoEFCC, WII" --force \
     build/pa-merged.geojson
   → --layer required: omitting it makes tippecanoe use the input filename as source-layer name,
     breaking every MapLibre source-layer reference. Same for step ⑧'s --layer=rivers.
   → source-layer: "protected-areas"
   → minimum-zoom=4 matches global minZoom (§3.1) — z3 tiles would be wasted output
   → --include allowlist: `id` (click-to-select, §3.3) + `category` (the 5 fill/outline layers
     filter on this). Everything else already lives in protected-areas.json. Not --exclude-all —
     that drops id/category too.
```

**Rivers pipeline**:

```
⑥ OSM Overpass API pull → build/rivers-raw.geojson

⑦ scripts/prepareRivers.js
   → Data cleaning only (dedupe overlapping ways, fix topology, strip irrelevant tags) — NOT
     geometric simplification (tippecanoe handles that; pre-simplifying causes double-simplification)
   → Matches each way's OSM `name` against rivers-index.json; matched ways get properties.id set
     to the canonical river ID. Unmatched ways still render, just aren't cross-linked/highlightable.
   → Promotes a sequential numeric top-level Feature id to every way; writes
     public/data/rivers-id-map.json: { "dibang": [14, 15, 22], ... } — required for tributary
     highlighting (§3.3); without it, setFeatureState on a name string silently no-ops
   → Side-output: build/rivers-by-id/{id}.geojson — one merged LineString/MultiLineString per
     river (used by spatialIntersect.js); also feeds turf.bbox() → rivers-index.json.bounds (§3.1)
   → Main output: build/rivers-prepared.geojson

⑧ tippecanoe --output=public/tiles/rivers.pmtiles \
     --layer=rivers --minimum-zoom=4 --maximum-zoom=14 --drop-smallest-as-needed \
     --include=id --include=stream_order \
     --name="India Rivers" --attribution="OpenStreetMap contributors" --force \
     build/rivers-prepared.geojson
   → source-layer: "rivers"
   → --include: `id` (click-to-select) + `stream_order` (label text-size, §6.2)

CHECKPOINT — after ⑤ and ⑧: `ls -lh public/tiles/*.pmtiles` against Cloudflare Pages' 25 MiB
per-file hard limit. Under: proceed with public/tiles/. Over: move the offending file to a
Cloudflare R2 public bucket (free tier, 10GB/zero egress); update its MapLibre source URL + the
matching _headers cache rule (§11.2). Smoke-test click-to-select, PA category filtering, and
river label sizing here.

**Do not use `--coalesce-smallest-as-needed`/`--coalesce-densest-as-needed` as a further size
lever if a file lands over 25 MiB** — move to R2 instead. Coalescing merges small nearby features
at low zoom, destroying the individual numeric Feature IDs that `setFeatureState`-based
click-to-highlight depends on (§3.3, §3.4). `--drop-smallest-as-needed` only omits features
outright at zooms with no room; rendered features keep their individual identity.
```

**State boundaries pipeline** (one-time; outputs committed):
```
⑨ scripts/enrichStates.js
   → Step A — Simplify (Mapshaper CLI, not Turf.js):
     npx mapshaper india-states.geojson -clean -simplify dp 5% keep-shapes -clean \
       -o public/geojson/india-states.geojson format=geojson
     Turf.js simplifies each of the 36 polygons independently — no awareness of vertices shared
     with a neighbour, producing slivers/overlaps along shared borders. Mapshaper detects
     exactly-coincident vertices across the whole file and stores a shared border once, so
     simplifying updates both neighbours identically. Do not swap back to Turf.js for consistency
     — it lacks this topology awareness entirely. Two -clean passes bracket the simplify (repair
     pre-existing misalignment; clean up post-simplify artifacts). keep-shapes prevents small UTs
     (Chandigarh, Puducherry, Lakshadweep) from vanishing. Target: ~90kB Brotli; adjust the 5%
     tolerance and re-run if output lands meaningfully off that.
   → Step B — Enrich: adds id, admin_type (state|ut), capital via manual lookup table, over
     Step A's output → public/geojson/india-states.geojson

⑩ scripts/generatePlaceholderSVG.js
   → Reads india-boundary.geojson (GeometryCollection); wraps as FeatureCollection in memory
     (Turf.js simplify() needs Features) — never written to disk, only the resulting SVG is
   → Simplifies at 0.05° (Douglas-Peucker; Turf.js is correct here — mainland/islands don't share
     borders, so no adjacent-topology risk)
   → Converts to SVG path elements → public/india-placeholder.svg (pre-load <img> only)
```

**Cross-linking** (needs only steps ④ and ⑦ — can run in parallel with tippecanoe builds ⑤/⑧):
```
⑪ scripts/spatialIntersect.js (Turf.js booleanIntersects)
   → Reads PA geometry from pa-merged.geojson, river linestrings from rivers-by-id/{id}.geojson
   → For each (river × PA) intersection: add river.id → PA.river_ids; add pa.id → river.protected_area_ids
   → Updates protected-areas.json in-place; writes rivers/{id}.json with protected_area_ids
   → ~105 rivers × 837 PAs ≈ 88,000 pair checks; ~2 min runtime; run once

⑫ scripts/deriveStateCrossRefs.js (after ⑪)
   → Inverts already-authoritative relationships into states.json:
       rivers/{id}.json.states_flows_through    → states.json.rivers_flowing_through
       protected-areas.json.state[]             → states.json.protected_area_ids
       cities.json.state                        → states.json.notable_city_ids
   → name/admin_type/capital/basin_rivers remain manually authored
   → Validates against State schema before writing

⑬ scripts/buildSearchIndex.js (run last)
   → Fuse.createIndex() over rivers-index.json + states.json → search-index-primary.json
   → Fuse.createIndex() over protected-areas.json → search-index-pa.json (loaded by loadPAData())
   → Fuse.js version must exactly match the client dependency (single package.json entry) —
     createIndex()'s serialized output is version-coupled
   → Version-drift guard: stamps resolved Fuse.js version as top-level "fuseVersion"; asserts
     (throws) if a committed index's fuseVersion doesn't match the version this run would write —
     catches a Fuse.js bump without re-running this step
   → Client: Fuse.parseIndex(json) + new Fuse(docs, options, index) — docs still come from the
     fetched index JSONs; prebuilding only removes tokenization cost
```

### 4.8 Data Sources

| Data | Source | Cost |
|---|---|---|
| River lengths, basin areas | NWDA, Central Water Commission | Free |
| River GeoJSON paths | OpenStreetMap/Overpass API | Free (ODbL) |
| River paths — supplementary | HydroRIVERS/HydroSHEDS (USGS) | Free (CC-BY) |
| State/UT boundaries | Supplied GoI-compliant files; 36 features verified | — |
| PA boundaries (837 files) | Pre-processed from MoEFCC/WII shapefiles | Done |
| PA index (839 records) | `protected-areas.json` — pre-processed | Done |
| Basin polygons | WRIS India, Ministry of Jal Shakti | Free (registration) |
| City/ghat data | Wikidata SPARQL | Free |
| Educational content | NCERT Geography (Class 9, 11), NIOS | Free |

### 4.9 Complete River List

**Total: ~105 named rivers** — single source of truth for counts elsewhere (§3.7, §3.9, §4.1, §5.5, §14).

**Himalayan — Indus System**: Indus, Jhelum, Chenab, Ravi, Beas, Sutlej, Spiti, Zanskar, Shyok

**Himalayan — Ganga System**: Ganga, Bhagirathi, Alaknanda, Yamuna, Chambal (incl. Banas, Kali Sindh, Parbati), Betwa, Ken, Son, Gomti, Ghaghra/Karnali, Sarda/Sharda, Gandak, Burhi Gandak, Kosi, Mahananda, Mechi, Kamla, Bagmati, Damodar, Hooghly, Barakar, Ajay, Rupnarayan

**Himalayan — Brahmaputra System**: Brahmaputra, Dibang, Lohit, Subansiri, Kameng, Dhansiri, Manas, Sankosh, Teesta, Rangeet, Torsa, Jaldhaka, Barak, Kopili, Kapili

**Peninsular — East flowing**: Mahanadi, Brahmani, Baitarani, Subarnarekha, Rushikulya, Vamsadhara, Nagavali, Godavari, Krishna, Tungabhadra, Bhima, Musi, Manjira, Indravati, Pranhita, Wainganga, Wardha, Kaveri, Amaravathi, Kabini, Hemavathi, Shimsha, Arkavathi, Bhavani, Palar, Ponnaiyar, Vellar, Vaigai, Tamiraparani

**Peninsular — West flowing**: Narmada, Tapi, Mahi, Sabarmati, Periyar, Chaliyar, Bharathapuzha, Pamba, Kallada, Sharavati, Zuari, Mandovi, Purna, Girna

**Coastal** (basin area < 2,500 km², drain directly to coast): Ulhas, Vaitarna, Savitri, Vashisthi, Kali (Karnataka), Netravati, Gurupur, Aghanashini, Damanganga *(west)*; Swarnamukhi, Manimuktha, Vaippar *(east)*

**Inland Drainage**: Luni (Rann of Kutch), Ghaggar-Hakra

*Note: Banas (Rajasthan) is `drainage_type: peninsular` (joins Chambal → Yamuna → Ganga), listed under Chambal above — distinct from Banas/Rupen of Gujarat.*

---

## 5. Technical Architecture

### 5.1 Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Framework | Astro v6 (static output) | |
| UI Components | Preact (Astro islands) | Lightweight React-compatible |
| Map Engine | MapLibre GL JS v5.x | WebGL, no DOM node ceiling — 556 WLS polygons alone would exceed a Leaflet SVG ceiling on mobile |
| Tile Format | PMTiles | Single-file binary, byte-range fetched, zero CDN; `pmtiles` npm package |
| Tile Build | tippecanoe | One-time CLI, GeoJSON → PMTiles |
| Spatial Ops | Turf.js (build scripts) | `spatialIntersect.js`, bbox precomputation — not used for `india-states.geojson` (see Mapshaper) |
| Geometry Simplification | Mapshaper (CLI, `npx`) | One-time, `india-states.geojson` only — topology-aware across 36 shared-border polygons (§4.7 step ⑨) |
| State | NanoStores | `mapStore.ts` + `filterStore.ts` + `dataStore.ts` |
| Styling | Tailwind CSS v4 + `@tailwindcss/vite` | Native Vite plugin; `@astrojs/tailwind` deprecated, not used |
| Data | Static JSON in `public/data/` | Zero backend, edge-cached |
| Search | Fuse.js | Client-side; index pre-compiled at build (§4.7 step ⑬) |
| Data validation | Zod | Build-only devDependency; no client bundle impact |
| Fonts | `@fontsource/sora` + `@fontsource/inter` | Self-hosted, no external CDN |
| Virtual scroll | virtua | Preact-compatible; PA list = 839 entries |
| Deployment | Cloudflare Pages | Free, global CDN, auto-deploy |
| Analytics | Cloudflare Web Analytics | Free, cookie-less |
| Ads | Google AdSense | Post-V1 (Phase 4) — manual placements, `async` only (§7) |

### 5.2 Project Structure

```
vicharashala-maps/
├── public/
│   ├── favicon.svg
│   ├── og-image.png                    — 1200×630
│   ├── robots.txt
│   ├── india-placeholder.svg
│   ├── google{16-char-code}.html
│   ├── tiles/{rivers,protected-areas}.pmtiles
│   ├── geojson/india-states.geojson    — 36 features
│   └── data/
│       ├── rivers-index.json           — inlined into index.astro at build (§5.3), not fetched
│       ├── rivers/{id}.json
│       ├── protected-areas.json        — 839 records; loaded by loadPAData()
│       ├── pa-id-map.json              — loaded by loadPAData()
│       ├── rivers-id-map.json          — fetched alongside rivers-index.json
│       ├── search-index-primary.json   — prebuilt Fuse index; on-demand fetch (§5.3)
│       ├── search-index-pa.json        — prebuilt Fuse index; loaded by loadPAData()
│       ├── basins.json  states.json  cities.json
├── src/
│   ├── boundaries/                     — 837 boundary GeoJSONs; build input, not served
│   ├── scripts/
│   │   └── themeInit.raw.ts            — raw-imported FOUC-prevention script (§5.6)
│   ├── components/
│   │   ├── Map/
│   │   │   ├── MapView.tsx             — MapLibre instance + PMTiles protocol
│   │   │   ├── RiversLayer.tsx
│   │   │   ├── ProtectedAreasLayer.tsx — 5 category fill/outline layers + boundary-less TR markers
│   │   │   ├── LayerControl.tsx
│   │   │   ├── MapLegend.tsx
│   │   │   └── MapControls.tsx
│   │   ├── Panels/
│   │   │   ├── RiverDetailPanel.tsx  PAInfoPanel.tsx  StatePanel.tsx
│   │   │   ├── RiverFilterPanel.tsx  PAFilterPanel.tsx
│   │   ├── Browse/
│   │   │   ├── RiverBrowseList.tsx  PABrowseList.tsx  — virtua
│   │   ├── RiverOfTheDay/RiverOfTheDayCard.tsx
│   │   ├── Search/SearchBar.tsx
│   │   ├── QuickStats/QuickStatsBanner.astro
│   │   └── Layout/Header.astro  Footer.astro  Sidebar.astro
│   ├── content/blog/{slug}.md
│   ├── content.config.ts               — Content Layer API, glob() loader over content/blog/
│   ├── pages/
│   │   ├── index.astro
│   │   ├── river/[id].astro  state/[id].astro  basin/[id].astro
│   │   ├── compare.astro  about.astro  privacy-policy.astro  terms.astro
│   │   ├── blog/index.astro  blog/[slug].astro  404.astro
│   ├── styles/global.css
│   └── utils/
│       ├── riverUtils.ts  geoUtils.ts (centroidFallbackBounds, §3.1)  rotdUtils.ts
│       ├── urlState.ts  themeUtils.ts
│       ├── searchIndex.ts              — Fuse.parseIndex() against prebuilt indices
│       ├── dataStore.ts                — riversIndex/states (inline, sync) + loadSearchIndex()/loadPAData() (§5.3)
│       ├── mapStore.ts  filterStore.ts
├── scripts/                            — build-time pipeline; not part of Astro build
│   ├── processData.js  simplifyBoundaries.js  verifyStates.js
│   ├── enrichStates.js                 — step ⑨
│   ├── ensureProperties.js             — step ③
│   ├── mergeFeatures.js                — step ④
│   ├── prepareRivers.js                — step ⑦
│   ├── spatialIntersect.js             — step ⑪
│   ├── deriveStateCrossRefs.js         — step ⑫
│   ├── generatePlaceholderSVG.js       — step ⑩
│   ├── buildSearchIndex.js             — step ⑬
│   ├── validateBasins.js               — "prebuild" hook (§4.7)
│   └── schemas.js                      — Zod schemas, imported by every writer + validateBasins.js
├── build/                               — gitignored intermediate artifacts
│   ├── pa-merged.geojson  rivers-prepared.geojson  rivers-by-id/
├── _headers  astro.config.mjs  tsconfig.json  package.json
```
AdSense-related files (`public/ads.txt`, `src/scripts/adsensePush.raw.ts`, `src/components/AdUnit.astro`) are added in Phase 4 (§7, §14) — omitted above since AdSense is post-V1.

**`astro.config.mjs`**:
```js
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import preact from '@astrojs/preact';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://vicharashalamaps.pages.dev',
  output: 'static',
  integrations: [sitemap(), preact()],
  vite: { plugins: [tailwindcss()] },
});
```
`@astrojs/tailwind` not used (deprecated in favor of the native Vite plugin). `global.css` starts with `@import "tailwindcss";`; the `:root`/`[data-theme]` custom-property blocks (§5.6) are unchanged. `compat: true` omitted from `preact()` — no React-only libraries used (virtua has a native Preact export); saves ~5kB. Restore it if a React-only dependency is added later.

**Content collections**: Astro 6 removed the legacy Content Collections API — use `src/content.config.ts` at `src/` root with a `glob()` loader over `src/content/blog/`; import `z` from `astro/zod`, not `astro:content` (Astro 6 runs Zod 4). Correctness requirement — the old shape doesn't build.

**External link safety**: blog markdown → `rehype-external-links` with `{ target: '_blank', rel: ['noopener', 'noreferrer'] }`. The two hardcoded external links outside blog content (Wikipedia link in `PAInfoPanel.tsx`; Wikimedia Commons attribution in `RiverDetailPanel.tsx`) set `rel="noopener noreferrer"` directly.

**`src/boundaries/` commit policy**: 837 simplified boundary GeoJSONs are committed (pipeline step ② output, inputs to ③–⑤; re-running the pipeline without them needs the non-redistributable MoEFCC shapefiles). ~15–25 MB total. `npm run build` doesn't touch `src/boundaries/`; only `public/` is served.

**`tsconfig.json`**: `{ "extends": "astro/tsconfigs/strict" }`

**`public/robots.txt`**:
```
User-agent: *
Allow: /
Sitemap: https://vicharashalamaps.pages.dev/sitemap.xml
```

### 5.3 Shared Data Loading

`rivers-index.json` and `states.json` are needed before anything meaningful renders (initial camera on deep link, ROTD card, every filter panel). Both are small and 100% static/build-time-known, so `index.astro` embeds them directly into the page HTML as inert JSON rather than fetching — removing 2 of 3 "core data" round-trips, most valuable on deep links where a fetch would otherwise block map construction.

```astro
---
// index.astro frontmatter (build time, output: 'static')
import { readFileSync } from 'node:fs';
const riversIndex = JSON.parse(readFileSync('public/data/rivers-index.json', 'utf-8'));
const states = JSON.parse(readFileSync('public/data/states.json', 'utf-8'));
const inlinePayload = JSON.stringify({ riversIndex, states }).replace(/</g, '\\u003c'); // prevent early </script>
---
<script type="application/json" id="core-data" set:html={inlinePayload}></script>
```
`type="application/json"` is inert — never executed, sits outside `script-src`, no CSP hash needed. Any other page mounting `MapView.tsx` needs the same two lines in its frontmatter.

```ts
// utils/dataStore.ts
import { atom } from 'nanostores';

interface PAData {
  protectedAreas: ProtectedArea[];
  paIdMap: Record<string, number>;
  searchIndexPA: unknown;
}

function readInline<T>(id: string): T {
  const el = document.getElementById(id);
  if (!el?.textContent) throw new Error(`Missing inline data block: #${id}`);
  return JSON.parse(el.textContent);
}
const inline = readInline<{ riversIndex: RiverIndexEntry[]; states: State[] }>('core-data');

// Synchronous — DOM content already present, not a Promise. A missing element is a build-time
// wiring bug, not a runtime failure, so it throws rather than entering the §3.12 retry UI.
export const riversIndex: RiverIndexEntry[] = inline.riversIndex;
export const states: State[] = inline.states;

// Genuine network fetch — needed only for search (§3.8), never for map construction or ROTD.
let searchIndexPromise: Promise<unknown> | null = null;
export function loadSearchIndex(): Promise<unknown> {
  searchIndexPromise ??= fetch('/data/search-index-primary.json').then(r => r.json());
  return searchIndexPromise;
}

export const paDataLoaded = atom<boolean>(false); // consumed by mapStore.ts (§5.4)
let paDataPromise: Promise<PAData> | null = null;
export function loadPAData(): Promise<PAData> {
  paDataPromise ??= Promise.all([
    fetch('/data/protected-areas.json').then(r => r.json()),
    fetch('/data/pa-id-map.json').then(r => r.json()),
    fetch('/data/search-index-pa.json').then(r => r.json()),
  ]).then(([protectedAreas, paIdMap, searchIndexPA]) => {
    paDataLoaded.set(true);
    return { protectedAreas, paIdMap, searchIndexPA };
  });
  return paDataPromise;
}
```

**Why `riversIndex`/`states` are separate exports, not one shared object with the search index**: a single `Promise.all()` over all three only resolves once every input has — destructuring one field still blocks on the slowest of the three. Keeping the two inlined datasets as plain sync values and giving `search-index-primary.json` its own independent promise avoids that coupling by construction.

For the `?river=ganga` deep link (§3.1): bounds lookup is `riversIndex.find(r => r.id === riverId)?.bounds` with no `await` — the map constructs with correct camera as soon as the island hydrates. Search becomes usable once `loadSearchIndex()` resolves — never blocking first paint either way.

`rivers-id-map.json` stays a plain lazy `fetch()` (needed only for tributary-highlight after selection, §3.3 — not first paint). `SearchBar.tsx`/`RiverOfTheDayCard.tsx` read `riversIndex`/`states` directly on hydration, same as `MapView.tsx` — no cross-island coordination needed for an already-parsed module export.

`<link rel="preload" as="fetch" crossorigin="anonymous">` for `/data/search-index-primary.json` in the layout `<head>` starts that fetch in parallel with JS parsing (§11.3). `protected-areas.json` and companions stay unpreloaded (defeats the on-demand strategy) — except for a direct `/?pa=...` load, where a small inline script checks `location.search` and injects the PA preload only then (a static `<link>` can't vary per request under `output: 'static'`).

### 5.4 NanoStores

**`mapStore.ts`**:
```ts
import { atom } from 'nanostores';
export const selectedRiverId   = atom<string | null>(null);
export const selectedPAId      = atom<string | null>(null);
export const activePanel       = atom<'river' | 'pa' | 'state' | null>(null); // null = no panel open
export const paLayerVisible    = atom<boolean>(false);
export const paLayerCategories = atom<Set<string>>(new Set(['np','wls','tr','br','ramsar']));
export { paDataLoaded } from './dataStore'; // re-exported for convenience
```

**`Set` mutation**: mutating in-place does not signal NanoStores — always create a new `Set`:
```ts
// WRONG — no reactivity signal
paLayerCategories.get().add('np');
// CORRECT
paLayerCategories.set(new Set([...paLayerCategories.get(), 'np']));
paLayerCategories.set(new Set([...paLayerCategories.get()].filter(c => c !== 'np')));
```
Same pattern for `paFilters.categories` in `filterStore.ts` — use `setKey('categories', new Set([...]))`.

Consumed by: `MapView`, `RiverDetailPanel`, `PAInfoPanel`, `StatePanel`, `LayerControl`, `RiverBrowseList`, `PABrowseList`.

**`filterStore.ts`**:
```ts
import { map } from 'nanostores';

interface RiverFilters { basin: string[]; states: string[]; drainageType: string | null; transnational: boolean; }
interface PAFilters    { categories: Set<string>; states: string[]; }

export const riverFilters = map<RiverFilters>({ basin: [], states: [], drainageType: null, transnational: false });
export const paFilters    = map<PAFilters>({ categories: new Set(['np','wls','tr','br','ramsar']), states: [] });
```
`paLayerCategories` (mapStore) controls MapLibre visibility; `paFilters.categories` controls the browse-list — distinct, a category can be map-hidden while still browse-visible.

Consumed by: `RiverFilterPanel`, `RiverBrowseList`, `PAFilterPanel`, `PABrowseList`.

### 5.5 Routing & Hydration

| Route | Static pages | SEO value |
|---|---|---|
| `/` | 1 | Primary landing |
| `/river/[id]` | ~105 (Phase 1 ships 25, §14) | High |
| `/state/[id]` | 36 | Medium |
| `/basin/[id]` | ~12 | Medium |
| `/compare` | 1 | Low–medium |
| `/blog/[slug]` | 5+ (Phase 2) | High |
| `/about`, `/privacy-policy`, `/terms` | 3 | — |

No static PA detail pages in V1. Phase 2: `/protected-areas` (static listing, all 839 sites).

**Island hydration directives**:

| Component | Directive | Rationale |
|---|---|---|
| `MapView.tsx` | `client:load` | Critical path |
| `LayerControl.tsx` | `client:load` | Attached to map; must be ready with it |
| `RiverDetailPanel`/`PAInfoPanel`/`StatePanel` | `client:load` | Opens on interaction; must be ready |
| `RiverFilterPanel`/`PAFilterPanel` | `client:idle` | Toggle-revealed, not scroll-revealed. `client:visible` is wrong here even though off-screen on desktop — `IntersectionObserver` never registers a `display:none`/off-screen element until shown, so it'd fire late or never |
| `RiverBrowseList`/`PABrowseList` | `client:idle` | Same toggle-panel reasoning |
| `SearchBar.tsx` | `client:idle` | Needed only once focused |
| `RiverOfTheDayCard.tsx` | `client:visible` | Genuinely below-the-fold on mobile — correct use of the directive |
| `QuickStatsBanner.astro` | Static | Pure Astro, no interactivity |

### 5.6 Dark/Light Mode

`data-theme` on `<html>`; inline `<head>` script applies before body render (no FOUC).

**CSP hash source**: theme script lives in `src/scripts/themeInit.raw.ts` (bare source, no `export const` wrapper), imported via `import themeInit from './themeInit.raw.ts?raw'`, rendered as `<script is:inline set:html={themeInit.trim()}>`. `.trim()` at insertion is required: the `_headers` (§11.2) hash is computed from `readFileSync(path, 'utf8').trim()`, and CSP hashes require byte-identical strings — an untrimmed render with a trailing newline (common editor/git default) would silently break the site's own CSP (CSP failures are invisible, no error toast). `is:inline` is required regardless of CSP, for synchronous pre-Vite execution.

```css
:root {
  --color-bg: #FFFFFF;        --color-surface: #F4F6F9;    --color-border: #D1D9E0;
  --color-text: #111827;      --color-text-muted: #4B5563; --color-accent: #1D6FE8;
  --color-accent-warm: #A45A05; --color-land: #D4E6C3;     --color-state-border: #577E43;
  --color-water: #B3D4F0;
}
[data-theme="dark"] {
  --color-bg: #0F1923;        --color-surface: #1A2634;    --color-border: #2D4159;
  --color-text: #E8EFF7;      --color-text-muted: #8FA6BF; --color-accent: #3B9EFF;
  --color-accent-warm: #F5A623; --color-land: #1E3A2F;     --color-state-border: #539278;
  --color-water: #0A1520;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --color-bg: #0F1923;        --color-surface: #1A2634;    --color-border: #2D4159;
    --color-text: #E8EFF7;      --color-text-muted: #8FA6BF; --color-accent: #3B9EFF;
    --color-accent-warm: #F5A623; --color-land: #1E3A2F;     --color-state-border: #539278;
    --color-water: #0A1520;
  }
}
```
All 10 tokens must appear in both the `[data-theme="dark"]` override and the `@media` fallback — an omitted token causes `setPaintProperty` to read a stale light-mode value when OS dark preference triggers without an explicit toggle. `--color-accent-warm`/`--color-state-border` are the WCAG-corrected values — see §6.1.

MapLibre background tracks `--color-water`: `map.setPaintProperty('background', 'background-color', getComputedStyle(document.documentElement).getPropertyValue('--color-water').trim())` on theme change.

---

## 6. UI/UX Design System

### 6.1 Color Palette

| Token | Light | Dark | Usage |
|---|---|---|---|
| `--color-bg` | `#FFFFFF` | `#0F1923` | Page background |
| `--color-surface` | `#F4F6F9` | `#1A2634` | Card/panel |
| `--color-border` | `#D1D9E0` | `#2D4159` | Borders |
| `--color-text` | `#111827` | `#E8EFF7` | Primary text |
| `--color-text-muted` | `#4B5563` | `#8FA6BF` | Secondary text |
| `--color-accent` | `#1D6FE8` | `#3B9EFF` | Links, CTAs, focus |
| `--color-accent-warm` | `#A45A05` | `#F5A623` | Selected river glow |
| `--color-land` | `#D4E6C3` | `#1E3A2F` | Map land fill |
| `--color-state-border` | `#577E43` | `#539278` | State boundary lines |
| `--color-water` | `#B3D4F0` | `#0A1520` | Map background (ocean) |

**Contrast requirements** (verified via WCAG relative-luminance, not visual check):
- `--color-state-border` and `--color-accent-warm` must clear **3:1** non-text contrast against `--color-land`/map surfaces in both themes — both are map lines/glows carrying real information (state boundaries §3.1, selected-river glow §3.3/§6.5), not decoration. The values above already satisfy this (state-border: 3.56:1/3.38:1; accent-warm: 3.93:1 light / 6.09:1 dark against land, 3.36:1/9.08:1 against water).
- **Basin colors** (`color_light`/`color_dark` per basin) must clear ≥3:1 against `--color-land` in both themes — enforced by the `Basin` Zod schema (§4.7) on every edit. Basin color is supplementary; identity is always also shown via text label/badge (§12).

| Basin | `color_light` | `color_dark` | Basin | `color_light` | `color_dark` |
|---|---|---|---|---|---|
| Ganga | `#277AD0` | `#4A90D9` | Mahanadi | `#158680` | `#20B2AA` |
| Indus | `#7564EB` | `#9B8FEE` | Narmada | `#CD5000` | `#FF8C42` |
| Brahmaputra | `#288948` | `#50C878` | Krishna | `#977204` | `#F5C842` |
| Godavari | `#E03C00` | `#FF7F50` | Kaveri | `#D913BE` | `#F07BE0` |
| Tapi | `#CB30C5` | `#DA70D6` | Western Coastal | `#378655` | `#7EC89A` |
| Inland (Luni/Ghaggar-Hakra) | `#927331` | `#C4A35A` | Eastern Coastal | `#C0392B` | `#D85F52` |

**Protected Area colors** (fills 0.25–0.40 opacity; labels full opacity, 11px map text, §6.2). Fill is a single flat value (supplementary — colorblind differentiation is via outline dash pattern, §12, not fill hue, which is near-invisible at this opacity regardless). **Label colors are theme-split** and must clear **4.5:1** against `--color-land` (small-text threshold for 9–13px map labels — stricter than the 3:1 line/fill bar):

| Category | Fill | Label (light) | Label (dark) |
|---|---|---|---|
| National Park (`np`) | `#41AB5D` | `#1B5E20` | `#30B439` |
| Wildlife Sanctuary (`wls`) | `#74C476` | `#2A712D` | `#3EB344` |
| Tiger Reserve (`tr`) | `#FD8D3C` | `#AF3E00` | `#FF7225` |
| Biosphere Reserve (`br`) | `#9E9AC8` | `#4527A0` | `#A58FE6` |
| Ramsar Site (`ramsar`) | `#4292C6` | `#0D47A1` | `#639DF6` |

Promote both label columns to CSS custom properties (`--color-pa-np-label`, etc.) alongside §5.6's palette, switched via the same `data-theme` mechanism — map style label paint properties read these, never hardcoded literals.

### 6.2 Typography

- Headings: Sora, self-hosted (`@fontsource/sora`, Latin subset)
- Body: Inter, self-hosted (`@fontsource/inter`, Latin subset)
- `@font-face` in `global.css`; `font-display: swap`
- **Weight-scoped imports**: `@fontsource` ships one file/weight; import only what's used — `@fontsource/sora/600.css` (headings) + `@fontsource/inter/400.css` + `@fontsource/inter/600.css` (body + UI emphasis), not the full 9-weight package (§11.3 budget)
- Map labels: Sora semi-bold; order-1 rivers 13px, order-4 9px; PA labels 11px at zoom ≥ 7

### 6.3 Desktop Layout (≥1024px)

```
┌─────────────────────────────────────────────────────────────────────┐
│  HEADER: [Logo] [Search ···] [Compare] [Blog] [About] [Theme]       │
├─────────────────────────────────────────────────────────────────────┤
│  [AdSense 728×90 leaderboard]                                       │
├─────────────────────────────────────────────────────────────────────┤
│  [Quick Stats: X rivers · Y protected areas · 28 states + 8 UTs]   │
├─────────────┬────────────────────────────┬─────────┬───────────────┤
│  SIDEBAR    │                            │  Layer  │ DETAIL PANEL  │
│  (280px)    │    MAP (MapLibre GL)        │ Control │ (360px)       │
│  [Rivers]   │                            │ (top-R) │ (hidden until │
│  [Prot.     │    [Legend — bottom-left]  │         │  feature sel) │
│   Areas]    │                            │         │ [AdSense      │
│  [Filters]  │                            │         │  300×250]     │
├─────────────┴────────────────────────────┴─────────┴───────────────┤
│  FOOTER: About · Sources · Blog · Privacy · Terms   [AdSense 728×90]│
└─────────────────────────────────────────────────────────────────────┘
```
`[Theme]` is a self-hosted sun/moon SVG pair, not emoji (consistent with no-external-asset principle, avoids cross-platform emoji rendering issues). The `[AdSense ...]` blocks above ship in Phase 4 (§7) — V1 renders this layout without them, with sidebar/footer collapsing to their natural height in the interim.

### 6.4 Mobile Layout (<768px)

```
┌───────────────────────────┐
│  HEADER: [Logo] [Search]  │
│  [Layer chips: R | PA]    │
├───────────────────────────┤
│  ROTD card (collapsible)  │
├───────────────────────────┤
│  [Map] | [Browse] ← tabs  │
├───────────────────────────┤
│  MAP (full width, 55vh)   │
│  or BROWSE LIST           │
├───────────────────────────┤
│  [AdSense 320×50]         │
├───────────────────────────┤
│  BOTTOM SHEET              │
│  (slides up on feature    │
│   tap; river or PA panel) │
└───────────────────────────┘
```
**Touch-action conflict**: `touch-action: none` on `.map-container`; `touch-action: pan-y` on `.bottom-sheet`; drag-handle `touchstart` → `map.dragPan.disable()`; `touchend`/`touchcancel` → `map.dragPan.enable()`.

The `[AdSense 320×50]` block above ships in Phase 4 (§7) — omitted from V1.

### 6.5 Micro-interactions

- River hover: `mousemove` → tooltip (name · length · basin)
- River click: `selected: true` glow via paint expression; tributaries `highlighted: true`; others dim (§3.3)
- PA hover: polygon brightens, `cursor: pointer`
- PA click: fill-opacity increases; rivers inside stay visible if shown
- **Flow direction animation** on selected river: `line-dasharray` animated via `requestAnimationFrame`, incrementing offset each frame via `setPaintProperty('rivers-selected', 'line-dasharray', [offset, gap])` — pure CSS `stroke-dashoffset` doesn't apply to WebGL layers. Disabled under `prefers-reduced-motion`.
- Detail panel: slide-in `cubic-bezier(0.16, 1, 0.3, 1)` ease-out
- Layer toggle: immediate `setLayoutProperty`, no loading state (tiles already fetched)
- Lists: virtual scroll via `virtua`
- Bottom sheet drag: disables/re-enables `map.dragPan` (§6.4)
- Map reset: §3.1

---

## 7. AdSense Placement (Post-V1 — Phase 4)

Deferred entirely to Phase 4 (§14) — not built, wired, or referenced in the V1 CSP/project structure. Kept here as the implementation spec for when it ships.

| Unit | Size | Location | Pages |
|---|---|---|---|
| Below-header leaderboard | 728×90 / 320×50 mobile | Full-width strip | All |
| Sidebar — below panel | 300×250 | Right panel, after data | Index |
| In-content | 336×280 | After 3rd paragraph | Blog |
| Footer leaderboard | 728×90 | Above footer links | All |

`async` only (`async`/`defer` mutually exclusive; AdSense requires `async`). Note: `async` doesn't guarantee execution after `DOMContentLoaded` — a fast script can execute before that fires. Auto-ads disabled; all placements manual. `/privacy-policy` and `/terms` required before applying.

**Single push-snippet source**: `(adsbygoogle = window.adsbygoogle || []).push({});` lives once in `src/scripts/adsensePush.raw.ts` (same raw-import + `.trim()`-at-insertion pattern as the theme script, §5.6); `AdUnit.astro` is the only component rendering it — all four placements instantiate that component. This makes a single CSP `sha256-` hash valid for all four (§11.2) by construction. The ad creative itself renders inside a Google-controlled iframe regardless of CSP.

---

## 8. SEO Strategy

- Static HTML for river/state/basin/blog pages
- Canonical URL on every page; `@astrojs/sitemap` auto-generates `sitemap.xml` (needs `site` in `astro.config.mjs`)
- **Homepage canonical is query-string-independent**: `/` carries many valid URL states (§3.13) — all the same document for indexing. `index.astro`'s canonical is fixed `https://vicharashalamaps.pages.dev/`, never reflecting `location.search`. `/river/[id]`, `/state/[id]`, `/basin/[id]` remain canonical for their entity content; `/?river=ganga` is a deep link, not a competing page.
- **Meta title/description per route type**: river — `{name} River — Length, Tributaries & Map | Vicharashala Maps`; state — `Rivers & Protected Areas in {name} | Vicharashala Maps`; basin — `{name} Basin — Rivers, Area & Map | Vicharashala Maps`. Descriptions interpolate 1–2 concrete facts (length, state count, basin area), not boilerplate.
- Open Graph + Twitter Card meta on all pages
- JSON-LD: `Dataset` on index; `Article` on blog; `Place` on river/state pages
- CWV targets: LCP < 2.5s · CLS < 0.1 · INP < 200ms
- Keyword targets — river pages: "Brahmaputra river source", "tributaries of Ganga", "rivers in Assam"; state pages: "rivers flowing through Assam", "national parks in Assam"; blog: "national parks on Brahmaputra", "Ramsar sites India rivers", "tiger reserves UPSC"
- Google Search Console: place supplied `google{16-char-code}.html` in `public/`

**Blog seed articles** (5, needed before AdSense application in Phase 4, §7):
1. `major-rivers-of-india.md`
2. `national-parks-rivers-india.md` — cross-category
3. `tiger-reserves-india-guide.md`
4. `himalayan-vs-peninsular-rivers.md`
5. `ramsar-sites-india-rivers.md` — cross-category

---

## 9. Monetisation

| Channel | Program | Placement | Phase |
|---|---|---|---|
| Display ads | Google AdSense (free) | 4 manual placements | Post-V1 (Phase 4) |
| Books | Amazon Associates India (free) | "Study more" in detail panels | Phase 2 |
| Courses | Unacademy affiliate (free) | Blog post CTAs | Phase 2 |
| Newsletter | Substack free plan | Footer embed | Phase 3 |

---

## 10. Post-V1 Features

Full wishlist; §14 selects the committed Phase 2/3 subset in priority order (overlap between §10 and §14 is not duplication).

| # | Feature | Notes |
|---|---|---|
| 10.1 | Timeline View | River treaties, floods, ecological events |
| 10.2 | UPSC Key Facts | `did_you_know`/`upsc_relevant` already in V1 schema; UI deferred |
| 10.3 | Quiz Mode | MCQ + map identification, UPSC-style, shareable score |
| 10.4 | Cities on Rivers Layer | `cities.json` in V1; GeoJSON layer deferred |
| 10.5 | Ghats Explorer | Per river; significance + best time |
| 10.6 | River Photography | Wikimedia Commons; needs `wikimedia_image_id` populated |
| 10.7 | Water Disputes Overlay | Cauvery, Mahadayi, Krishna Tribunal; explainer modals |
| 10.8 | River Festivals Calendar | Monthly calendar; links to river |
| 10.9 | Trace This River | Click → animated path upstream to source + downstream to sea |
| 10.10 | Seasonal Flow Animation | Time-slider; static seasonal data |
| 10.11 | `/protected-areas` static listing | 839 sites, SEO for "list of NPs India" |
| 10.12 | PA Comparison Mode | Side-by-side PA table |
| 10.13 | Pollution & Water Quality | CPCB Class A–E river stretch overlay |
| 10.14 | Flood Zones Layer | NDMA flood-prone district polygons, June–Sep seasonality |
| 10.15 | PWA/Offline Mode | Service Worker + cache-first; PMTiles cache-able |
| 10.16 | Multilingual (Hindi first) | Astro i18n; `local_names`/`local_name_hi` already collected |
| 10.17 | Fuse.js Web Worker | Only if search index grows past ~500 entities or measurable main-thread blocking appears — at V1 scale search is <1ms, a Worker round-trip costs more than it saves |
| 10.18 | AdSense Display Ads | Full activation — see §7 for placements/technical spec, §9 for monetisation context, §13 for legal prerequisites |

---

## 11. Deployment & Infrastructure

### 11.1 Cloudflare Pages

```
Project:       vicharashala-maps
Build Command: npm run build
Build Output:  dist/
Node Version:  22 (Astro 6 requires Node ≥22.12.0 — confirm the resolved patch satisfies this)
Env Vars:
  PUBLIC_SITE_URL=https://vicharashalamaps.pages.dev
```
`PUBLIC_ADSENSE_ID` added in Phase 4 (§7) — not set for V1.

`tippecanoe` and pipeline scripts (§4.7) run locally, one-time — not in the Cloudflare build. `npm run build` runs `validateBasins.js` as a `prebuild` step before `astro build`. PMTiles and processed data are committed and served as static assets.

### 11.2 `_headers` — Security & Caching

Last-matching-rule wins; `/*` catch-all first, specific rules override.

```
/*
  Cache-Control: no-cache
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Content-Security-Policy: default-src 'self'; script-src 'self' 'sha256-{THEME_INIT_HASH}' https://static.cloudflareinsights.com; worker-src 'self' blob:; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; connect-src 'self' https://cloudflareinsights.com

/tiles/*
  Cache-Control: public, max-age=604800, stale-while-revalidate=86400

/geojson/*
  Cache-Control: public, max-age=604800, stale-while-revalidate=86400

/data/*
  Cache-Control: public, max-age=86400, stale-while-revalidate=3600

/_astro/*
  Cache-Control: public, max-age=31536000, immutable
```

- `worker-src 'self' blob:` — required for MapLibre Web Workers.
- `img-src 'self' data: blob:`, no `https:` wildcard — V1 has no external image source (`wikimedia_image_id` is `null` until Phase 2; `og-image.png`/favicon self-hosted). When Phase 2 populates it, add the specific host (`https://commons.wikimedia.org`) rather than opening to any HTTPS origin.
- `static.cloudflareinsights.com` (script-src) and `cloudflareinsights.com` (connect-src) are separate origins for Cloudflare Web Analytics (beacon script vs. its POST target).
- `/data/*` covers all `public/data/` files — no per-file rules needed.

**CSP is enforced, not report-only**: `script-src` drops `'unsafe-inline'` for a `sha256-` hash source covering the site's only first-party inline script in V1 (theme FOUC script, §5.6). Static and build-time-known (`output: 'static'`), so the hash is computed once, not regenerated per build:
```bash
node -e "console.log('sha256-' + require('crypto').createHash('sha256').update(require('fs').readFileSync('src/scripts/themeInit.raw.ts','utf8').trim()).digest('base64'))"
```
Paste the result over `{THEME_INIT_HASH}` by hand; re-run and update if the script's source changes. It must be rendered with the identical `.trim()` at insertion (`set:html={themeInit.trim()}`) — a stray trailing newline in source otherwise silently breaks the site's own CSP.

Per-request nonces (Cloudflare Worker) were rejected — incompatible with `output: 'static'`/zero-backend, and unnecessary since the theme script is fixed content a static hash already covers. Astro 6's `csp: true` flag was also rejected — it delivers via `<meta http-equiv>`, not a true HTTP header, can't cover markup preceding that tag, and can't express `frame-ancestors`/`report-uri`.

**Phase 4 CSP addendum (AdSense, §7)**: activating AdSense adds a second `sha256-` hash (`src/scripts/adsensePush.raw.ts`, same trimmed-hash procedure above) plus a domain allowlist to `script-src` (`https://pagead2.googlesyndication.com`, `https://adservice.google.com`, `https://googleads.g.doubleclick.net`, `https://adtrafficquality.google`, `https://*.adtrafficquality.google`, `https://fundingchoicesmessages.google.com`), a new `frame-src` directive (`https://googleads.g.doubleclick.net`, `https://tpc.googlesyndication.com`, `https://*.adtrafficquality.google`, `https://fundingchoicesmessages.google.com`), and `https://*.adtrafficquality.google` to `connect-src`. Google doesn't formally support allowlist-style CSP for AdSense (its ad-serving domains change over time); it only guarantees `nonce '{random}' 'strict-dynamic'`-style CSP, which needs per-request server nonces — ruled out by the zero-backend constraint. Re-verify this allowlist against live DevTools console errors at Phase 4 implementation and periodically after — `adtrafficquality.google`/`*.adtrafficquality.google` and `fundingchoicesmessages.google.com` are most likely to need re-checking.

**PMTiles hotlinking**: no CORS header added — `Access-Control-Allow-Origin` governs cross-origin JS *read* access, not who can *fetch*. This app's own requests are same-origin. A third party embedding the tiles is already blocked by default-deny CORS; non-browser hotlinking isn't CORS-governed at all. Cloudflare Pages doesn't bill egress, so risk is largely theoretical — if it matters later, use a Referer/Origin check (Scrape Shield or a Worker), not a `_headers` addition.

### 11.3 Performance Targets

| Metric | Target |
|---|---|
| Lighthouse Performance | >90 mobile · >95 desktop |
| First Contentful Paint | <1.2s |
| Largest Contentful Paint | <2.5s |
| Cumulative Layout Shift | <0.1 |
| Initial JS bundle | <320kB **gzipped** total. MapLibre GL JS v5.x runs ~220–250kB gzipped even minimal — re-measure with `npx bundlephobia maplibre-gl` against the locked version before launch; remainder (~70–100kB) budgets Preact, NanoStores, virtua, Fuse.js, PMTiles client, app code |
| Initial HTML (`index.astro`, incl. inlined `rivers-index.json`+`states.json`) | <50kB Brotli |
| `protected-areas.json` on wire | <38kB Brotli (on demand) |
| `search-index-primary.json` on wire | <15kB Brotli (on demand) |
| `search-index-pa.json` on wire | <25kB Brotli (part of `loadPAData()`) |
| PMTiles initial viewport fetch | <200kB (byte-range, visible tiles only) |
| `india-states.geojson` on wire | <90kB Brotli |

**Optimisation tactics**:
- `loadPAData()`'s three files load only on first PA access (layer activation or browse tab) — `?pa=...` deep link is the one eager exception (§3.1, §3.13)
- `rivers-index.json`/`states.json` embedded in initial HTML, not fetched (§5.3) — removes 2 of 3 former core-data round-trips
- PMTiles byte-range requests — only current-viewport tiles
- tippecanoe `--drop-smallest-as-needed` — small PAs/minor rivers absent from low-zoom tiles automatically
- `india-states.geojson` cached by MapLibre + `Cache-Control`
- Sora/Inter: Latin subset, `font-display: swap`, weight-scoped imports (§6.2). Preload the two above-the-fold weight files (header Sora 600, first-viewport Inter 400) via `<link rel="preload" as="font" type="font/woff2" crossorigin>` — avoids the swap flash on visible text; no `preconnect` needed (self-hosted, same-origin). Other weights use normal `@font-face` resolution.
- `<link rel="preconnect">` for `https://static.cloudflareinsights.com`. Add `https://pagead2.googlesyndication.com`, reserved ad-slot dimensions, and the `async` AdSense script when Phase 4 activates ads (§7) — none of this applies to V1.
- `<link rel="preload" as="fetch" crossorigin="anonymous">` for `/data/search-index-primary.json` (§5.3) — `crossorigin` must match the runtime `fetch()`'s credentials mode or the browser double-fetches. `protected-areas.json` and companions stay unpreloaded except the `?pa=...` inline-script case (§5.3).

---

## 12. Accessibility

- WCAG 2.1 AA throughout
- River lines: dash patterns for colorblind differentiation (not color alone) — major rivers solid, tributaries dashed
- PA polygons: colorblind differentiation via **outline dash pattern** per category (NP solid, WLS `[4,2]`, TR `[2,2]`, BR `[8,4]`, Ramsar `[4,4,1,4]`) as `line-dasharray` on the outline layer. Fill patterns not used (invisible at 0.25–0.40 opacity on WebGL). Category badge in info panel is the non-visual fallback.
- Basin color-coding is supplementary — identity always also shown via text label/badge. All 12 basin colors verified ≥3:1 against `--color-land` in both themes (§6.1).
- `--color-state-border`/`--color-accent-warm` verified ≥3:1 against map surfaces in both themes (§6.1) — both convey real information.
- PA category label colors theme-split, verified ≥4.5:1 against land in both themes (§6.1).
- **Browse/List mode** (§3.7) is the primary route to feature selection for keyboard-only users — MapLibre's default `KeyboardHandler` supports pan/zoom but not feature selection via keyboard (pointer-only by library design).
- **Skip-to-main-content link**: visually-hidden-until-focused, first focusable element on every page, jumps past the header directly to the map/main region (WCAG 2.4.1).
- `aria-label` on all MapLibre interactive elements
- Keyboard nav: Tab through Layer Control, filter panel, browse list; Enter to select
- **Focus management on panel open**: selecting a river/PA/state (map click or Browse row) moves DOM focus to the newly opened panel (`tabIndex={-1}` on the container, `.focus()` in an effect keyed off `mapStore.activePanel`) — without this, a screen reader user's focus stays on the activated row while content renders elsewhere. On close, focus returns to the triggering control. External links use `rel="noopener noreferrer"` throughout.
- **Mobile bottom sheet**: functionally modal (overlays the map, unlike the desktop side panel). `Escape` closes it; Tab is trapped within it while open (first/last focusable elements wrap). Focus-in-on-open/return-on-close applies on both breakpoints.
- **`aria-live="polite"` region** for dynamic status text (search result counts, "No results for '{query}'" §3.12, filter-result counts §3.6) — none of the focus-management above covers in-place text updates (WCAG 4.1.3).
- `prefers-reduced-motion`: decorative animations disabled (fly animations, `line-dasharray` flow animation, hover glows); functional transitions (panel slide-in, badge updates) preserved
- `forced-colors` media query: CSS high-contrast support
- Touch targets ≥44×44px (WCAG 2.5.5)
- Minimum body font size 14px

---

## 13. Legal & Policy

- **Data disclaimer**: river/boundary data is approximate, educational only — not for navigation/legal use. Footer + map overlay.
- **Disputed territories**: J&K, Ladakh, Aksai Chin, Arunachal Pradesh shown per Government of India's official position; standard disclaimer displayed.
- **Content licence & attribution** (footer or `/about`): educational text CC BY-NC 4.0; state/boundary GeoJSON — Government of India (Survey of India); river GeoJSON — © OpenStreetMap contributors (ODbL); river GeoJSON supplementary — HydroRIVERS © HydroSHEDS/USGS (CC-BY); basin polygons — WRIS India, Ministry of Jal Shakti; PA boundaries — MoEFCC/WII.
- **Privacy Policy** (`/privacy-policy`): V1 covers Cloudflare Web Analytics (no cookies) only. In Phase 4 (§7), add Google AdSense (ad personalisation cookies) and consent management via Google's "Privacy & messaging" for EEA/UK/Switzerland visitors.
- **Terms of Use** (`/terms`): acceptable use, content licence. Drafted in V1; no AdSense-specific clauses needed until Phase 4.
- **Google Search Console**: place `google{16-char-code}.html` in `public/`; submit sitemap after verification.

**Phase 4 additions (AdSense, §7)**:
- **`ads.txt`**: `public/ads.txt` declaring the authorized AdSense seller ID (`google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`). Not contractually required but its absence is flagged in the AdSense dashboard and can suppress revenue.
- **EU/UK/Switzerland ad consent**: AdSense requires a certified CMP (IAB TCF) to serve personalised ads to EEA/UK/CH visitors — without one, that traffic falls back to lower-RPM "Limited Ads." Google's own **"Privacy & messaging"** AdSense-dashboard feature is itself a certified CMP — no separate infrastructure needed. Requires the CSP additions in §11.2.
- Privacy Policy/Terms updated with AdSense disclosures; apply to AdSense once blog articles are live and indexed.

---

## 14. Implementation Roadmap

### Phase 1 — MVP (Weeks 1–5)

**Setup (before code)**
- [ ] `npx mapshaper` simplify on `india-states.geojson` (§4.7 step ⑨) → `enrichStates.js`
- [ ] `generatePlaceholderSVG.js` → `public/india-placeholder.svg`
- [ ] `ensureProperties.js` on 837 PA boundary files (two-stage lookup + fallback; review `build/unmatched-boundaries.json`)
- [ ] `mergeFeatures.js` → `build/pa-merged.geojson` + `pa-id-map.json`
- [ ] tippecanoe (`--layer=protected-areas --minimum-zoom=4`) → `protected-areas.pmtiles`; validate source-layer name
- [ ] Pull rivers from OSM Overpass → `prepareRivers.js` (cleaning + per-river split + Feature ID promotion → `rivers-id-map.json`) → tippecanoe → `rivers.pmtiles`
- [ ] Check both `.pmtiles` against Cloudflare's 25 MiB limit; decide `public/tiles/` vs R2 per file
- [ ] `spatialIntersect.js` (parallel with tippecanoe builds) → populate `river_ids`/`protected_area_ids`
- [ ] `deriveStateCrossRefs.js` → populate `states.json` relational arrays; validates against `State` schema
- [ ] `buildSearchIndex.js` (run last) → `search-index-primary.json`/`search-index-pa.json`, stamped with Fuse.js version
- [ ] Wire `validateBasins.js` as `package.json` `"prebuild"`

**Build**
- [ ] Astro v6 + Tailwind v4 + MapLibre GL JS v5.x + PMTiles + Preact + NanoStores
- [ ] `src/content.config.ts` using the Content Layer API (`glob()` loader)
- [ ] `utils/dataStore.ts`: sync `riversIndex`/`states` (from inline `#core-data`) + `loadSearchIndex()`/`loadPAData()` (§5.3) — before dependent components
- [ ] `mapStore.ts` + `filterStore.ts` (explicit TS interfaces)
- [ ] `MapView.tsx`: MapLibre instance, PMTiles protocol, all sources/layers, `minZoom`/`maxZoom` + rotation lock, deep-link bounds (no fetch)
- [ ] Rivers data: 25 river index entries (with `states`) + detail JSONs (manual)
- [ ] Static pages for initial 25 rivers (`getStaticPaths`); per-route-type meta templates (§8); query-independent canonical on `/`
- [ ] Layer Control panel
- [ ] River detail panel (click → select → panel; feature state glow/dim via rAF; boundary-less-PA branch, §3.3)
- [ ] PA info panel (river cross-links)
- [ ] State panel (§3.5) — from `states.json`, no fetch
- [ ] `ProtectedAreasLayer.tsx`: 5 category fill+outline layers + boundary-less TR markers
- [ ] River filter panel (State + Basin + Drainage Type + Transnational); PA filter panel (Category + State)
- [ ] River/PA Browse lists (`virtua`; PA triggers `loadPAData()`)
- [ ] Global search (Fuse.js; rivers+states upfront, PA added on `loadPAData()`)
- [ ] River of the Day card (`client:visible`; core-data only; `rotd_collapsed` localStorage)
- [ ] URL state management (300ms debounce, scoped to `replaceState` only)
- [ ] Dark/Light mode (all 10 tokens in both `[data-theme="dark"]` and `@media` fallback; PA label colors as CSS custom properties)
- [ ] Mobile touch-action conflict handling
- [ ] Loading/error states: core-data (full-page retry) vs PA-data (inline retry) as separate paths; `india-placeholder.svg`
- [ ] Skip-to-main-content link; `aria-live` region; mobile bottom sheet Escape-to-close + focus trap
- [ ] Font imports scoped to used weights; preconnect (ad/analytics) + preload (search index, above-fold fonts); reserved ad-slot dimensions
- [ ] `_headers` (security headers + stale-while-revalidate); theme script as raw-import + `.trim()`-at-insertion; hash from the same trimmed read
- [ ] Privacy Policy, Terms, About, 404
- [ ] Deploy to Cloudflare Pages

### Phase 2 — Content & SEO (Weeks 6–9)
- [ ] Full river dataset: 50+ rivers, all index + detail JSONs
- [ ] Static pages: all rivers, states, basins
- [ ] Blog: 5 seed articles
- [ ] `/protected-areas` static listing page
- [ ] Wikipedia URL validation for ambiguous PA names
- [ ] `year_established` for all NPs (107 records)
- [ ] PA Comparison Mode
- [ ] Affiliate links (Amazon Associates India, Unacademy)
- [ ] `wikimedia_image_id` populated; add Wikimedia Commons host to `img-src`

### Phase 3 — Distribution & Polish (Weeks 10–12)
- [ ] Substack embed
- [ ] OG image per river page
- [ ] Sitemap submitted to Google Search Console

### Phase 4 — Post-V1 Features (Month 4+)
See §10. Priority order: AdSense activation (§7, §9, §13 — build `AdUnit.astro`/`adsensePush.raw.ts`, add CSP domains, `ads.txt`, EEA/UK/CH consent CMP, apply once blog articles are indexed) → UPSC Key Facts + Quiz Mode → Water Disputes overlay + River Festivals Calendar → Pollution + Flood Zones layers → PWA/Offline · Multilingual · Trace This River.

---

*Vicharashala Maps — Rivers + Protected Areas. MapLibre GL JS v5.x + PMTiles + Astro v6.*
