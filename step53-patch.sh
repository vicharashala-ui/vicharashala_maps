#!/usr/bin/env bash
set -euo pipefail

# step53-patch.sh -- idempotent, tested on a fresh clone.
# 1) State Borders toggle added to LayerControl, off by default. New 'stateBordersVisible'
#    atom (mapStore.ts) + new StateBordersLayer.tsx sibling component controls the existing
#    'state-borders' line layer's visibility; 'india-border' (national outline) and 'land-fill'
#    (state click hit-test) are untouched and stay on regardless of the toggle.
# 2) Fixed river-hover popup text being invisible in dark mode: MapLibre's default popup CSS
#    ships a fixed white background but inherits body's text color, which is light in dark mode.
#    global.css now pins both the popup background and text color to the theme.

if [ ! -f "package.json" ] || [ ! -d "src/components/Map" ]; then
  echo "Run this from the repo root (vicharashala_maps/)." >&2
  exit 1
fi

cat > "src/utils/mapStore.ts" << 'STEP53_EOF'
import { atom } from 'nanostores';
import type maplibregl from 'maplibre-gl';

// Set once by MapView.tsx after `load`; consumed by LayerControl/panels (separate islands)
// to call MapLibre methods (setLayoutProperty, flyTo, setFeatureState) without prop drilling.
export const mapInstance = atom<maplibregl.Map | null>(null);

export const selectedRiverId = atom<string | null>(null);
export const selectedPAId = atom<string | null>(null);
export const selectedStateId = atom<string | null>(null);
export const activePanel = atom<'river' | 'pa' | 'state' | null>(null);

export const paLayerVisible = atom<boolean>(false);
export const paLayerCategories = atom<Set<string>>(new Set(['np', 'wls', 'tr', 'br', 'ramsar']));

// State-borders line layer (MapView.tsx) — off by default (borders are namable via State
// panel/search without needing every internal line drawn up front); toggled from LayerControl.
export const stateBordersVisible = atom<boolean>(false);

export { paDataLoaded } from './dataStore';

export function selectRiver(id: string | null): void {
  selectedPAId.set(null);
  selectedStateId.set(null);
  selectedRiverId.set(id);
  activePanel.set(id ? 'river' : null);
}

export function selectPA(id: string | null): void {
  selectedRiverId.set(null);
  selectedStateId.set(null);
  selectedPAId.set(id);
  activePanel.set(id ? 'pa' : null);
}

export function selectState(id: string | null): void {
  selectedRiverId.set(null);
  selectedPAId.set(null);
  selectedStateId.set(id);
  activePanel.set(id ? 'state' : null);
}

export function closePanel(): void {
  selectedRiverId.set(null);
  selectedPAId.set(null);
  selectedStateId.set(null);
  activePanel.set(null);
}

// Browse/List mode (§3.7) — the primary keyboard-accessible route to feature selection,
// since MapLibre's KeyboardHandler is pointer-only for selection (§12).
export const browseOpen = atom<boolean>(false);
export const browseTab = atom<'rivers' | 'pa'>('rivers');
STEP53_EOF

cat > "src/components/Map/MapView.tsx" << 'STEP53_EOF'
import { useEffect, useRef, useState } from 'preact/hooks';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import { Protocol } from 'pmtiles';
import { riversIndex, loadPAData } from '../../utils/dataStore';
import { mapInstance, selectRiver, selectPA, selectState } from '../../utils/mapStore';
import { readInitialSelection, readInitialFilters, debouncedUpdateUrl } from '../../utils/urlState';
import { riverFilters, paFilters } from '../../utils/filterStore';
import type { RiverFilters, PAFilters } from '../../utils/filterStore';
import { centroidFallbackBounds, geometryBounds } from '../../utils/geoUtils';
import RiversLayer from './RiversLayer';
import ProtectedAreasLayer from './ProtectedAreasLayer';
import StateHighlightLayer from './StateHighlightLayer';
import StateBordersLayer from './StateBordersLayer';

const INDIA_BOUNDS: [number, number, number, number] = [68.1, 6.4, 97.4, 37.1];
// Pan limit, well beyond INDIA_BOUNDS so users can still see neighbouring countries/context
// while panning, but can't scroll off into open ocean or wrap the globe. Matches ecoguesser's
// MAP_CONFIG.MAX_BOUNDS (config.js) so both apps frame/constrain the subcontinent identically.
const MAX_BOUNDS: [[number, number], [number, number]] = [
  [45, -18],
  [112, 52],
];
// OFM Liberty (https://openfreemap.org) — full-detail OSM Liberty fork, single style (no
// separate dark variant, unlike Positron/Dark). Previously ran Positron/Dark instead (see Step
// 50's rejection rationale in git history for the "Liberty competes with the rivers/PA layers"
// concern) — switched to Liberty per explicit request. The theme toggle no longer affects the
// basemap tiles themselves, only the site's own UI chrome.
const BASEMAP_STYLE = 'https://tiles.openfreemap.org/styles/liberty';

// Liberty (OpenMapTiles schema) puts every settlement label on symbol layers sourced from
// `place`, same ids/schema this was originally tuned against on Positron/Dark. Matching on
// `source-layer` + a name pattern and calling setLayerZoomRange works regardless of which
// OpenFreeMap style is active. Country labels are left alone: low density, and they're useful
// context for where transnational rivers cross into Nepal/Bangladesh/Pakistan/China/Myanmar.
const SETTLEMENT_MIN_ZOOM: [RegExp, number][] = [
  [/city/i, 6],
  [/town/i, 7],
  [/village|suburb|hamlet|other/i, 8],
  [/state/i, 5],
];

function raiseSettlementLabelZoom(m: maplibregl.Map) {
  for (const layer of m.getStyle()?.layers ?? []) {
    if (layer.type !== 'symbol' || (layer as { 'source-layer'?: string })['source-layer'] !== 'place') continue;
    if (/country/i.test(layer.id)) continue;
    const minzoom = SETTLEMENT_MIN_ZOOM.find(([re]) => re.test(layer.id))?.[1];
    if (minzoom !== undefined) m.setLayerZoomRange(layer.id, minzoom, layer.maxzoom ?? 24);
  }
}

// This atlas's own data (rivers, PAs) is the subject — the basemap's road/rail network is noise
// competing for attention, not context anyone needs here (unlike place labels/borders, kept for
// orientation). Matched by `source-layer` (stable OpenMapTiles-schema names), not layer id, so
// this keeps working if the style URL ever changes again.
const TRANSPORT_SOURCE_LAYERS = new Set(['transportation', 'transportation_name', 'aeroway', 'aerodrome_label']);

function removeTransportLayers(m: maplibregl.Map) {
  for (const layer of m.getStyle()?.layers ?? []) {
    if (TRANSPORT_SOURCE_LAYERS.has((layer as { 'source-layer'?: string })['source-layer'] ?? '')) {
      m.removeLayer(layer.id);
    }
  }
}

export default function MapView() {
  const containerRef = useRef<HTMLDivElement>(null);
  const [map, setMap] = useState<maplibregl.Map | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function init() {
      const protocol = new Protocol();
      maplibregl.addProtocol('pmtiles', protocol.tile);

      const { riverId, paId, stateId } = readInitialSelection();
      // §3.6/§3.13: filters are deep-linkable and independent of selection — hydrate before
      // RiversLayer/ProtectedAreasLayer mount so their first `setFilter` call is correct.
      const initialFilters = readInitialFilters();
      riverFilters.set({
        states: initialFilters.riverStates,
        basins: initialFilters.basins,
        drainageType: initialFilters.drainageType as RiverFilters['drainageType'],
        transnational: initialFilters.transnational,
      });
      paFilters.set({ categories: initialFilters.paCategories as PAFilters['categories'], states: initialFilters.paStates });
      let initialBounds: [number, number, number, number] | undefined;
      if (riverId) {
        initialBounds = riversIndex.find((r) => r.id === riverId)?.bounds;
      } else if (paId) {
        // §3.13: /?pa=... force-triggers loadPAData() before construction so bounds are available.
        const pa = (await loadPAData()).protectedAreas.find((p) => p.id === paId);
        if (pa) initialBounds = pa.bounds ?? centroidFallbackBounds(pa);
      } else if (stateId) {
        const gj = await fetch('/geojson/india-states.geojson').then((r) => r.json());
        const feature = gj.features.find((f: { properties: { id: string } }) => f.properties.id === stateId);
        if (feature) initialBounds = geometryBounds(feature.geometry);
      }
      if (cancelled || !containerRef.current) return;

      const stateBorderColor = getComputedStyle(document.documentElement)
        .getPropertyValue('--color-state-border')
        .trim();
      const riverContextColor = getComputedStyle(document.documentElement)
        .getPropertyValue('--color-river-context')
        .trim();

      const m = new maplibregl.Map({
        container: containerRef.current,
        style: BASEMAP_STYLE,
        bounds: initialBounds ?? INDIA_BOUNDS,
        fitBoundsOptions: { padding: 20 },
        maxBounds: MAX_BOUNDS,
        minZoom: 4,
        maxZoom: 14,
        dragRotate: false,
        pitchWithRotate: false,
        touchPitch: false,
      });

      m.on('load', () => {
        removeTransportLayers(m);
        raiseSettlementLabelZoom(m);

        m.addSource('india-states', { type: 'geojson', data: '/geojson/india-states.geojson' });
        // Invisible but still present — 'land-fill' exists purely as a click/hit-test target
        // for the state-select handler below. The real basemap (roads, place labels) now
        // shows through India the same as everywhere else on the map.
        m.addLayer({ id: 'land-fill', type: 'fill', source: 'india-states', paint: { 'fill-opacity': 0 } });
        m.addLayer({
          id: 'state-borders',
          type: 'line',
          source: 'india-states',
          layout: { visibility: 'none' },
          paint: { 'line-color': stateBorderColor, 'line-width': 1 },
        });

        // Dissolved national outline (generateIndiaOutline.js) — state-borders above draws
        // every internal state edge at the same weight, so the actual international border
        // wasn't visually distinct from, say, the Bihar/UP line. This is the same colour,
        // just heavier, so the true edge of the country reads clearly against the basemap.
        m.addSource('india-outline', { type: 'geojson', data: '/geojson/india-outline.geojson' });
        m.addLayer({
          id: 'india-border',
          type: 'line',
          source: 'india-outline',
          paint: { 'line-color': stateBorderColor, 'line-width': 2.5 },
        });

        // Transnational rivers' course outside India (extendTransnationalRivers.js), added
        // after india-states so it draws over the land fill, but before RiversLayer mounts
        // its interactive 'rivers-line' pmtiles layer — so the interactive India portion of
        // each river still draws on top of, and visually continues into, this context line.
        // Purely decorative: no click/hover handlers, no click-to-highlight involvement.
        m.addSource('rivers-context', { type: 'geojson', data: '/data/rivers-context.geojson' });
        m.addLayer({
          id: 'rivers-context-line',
          type: 'line',
          source: 'rivers-context',
          paint: { 'line-color': riverContextColor, 'line-width': 1, 'line-opacity': 0.7 },
        });

        // §3.5: click state polygon → open state panel. Lowest click priority — a river/PA
        // feature drawn on top of the state fill owns the click first, so this only fires
        // when nothing else at the point handled it.
        m.on('click', 'land-fill', (e) => {
          const onTopLayers = ['rivers-line', 'pa-np-fill', 'pa-tr-fill', 'pa-br-fill', 'pa-ramsar-fill', 'pa-wls-fill'].filter(
            (id) => m.getLayer(id),
          );
          if (onTopLayers.length && m.queryRenderedFeatures(e.point, { layers: onTopLayers }).length) return;
          const id = e.features?.[0]?.properties?.id as string | undefined;
          if (!id) return;
          selectState(id);
          debouncedUpdateUrl({ state: id });
        });
        m.on('mouseenter', 'land-fill', () => (m.getCanvas().style.cursor = 'pointer'));
        m.on('mouseleave', 'land-fill', () => (m.getCanvas().style.cursor = ''));

        if (cancelled) return;
        mapInstance.set(m);
        setMap(m);

        // Deep-link auto-select (§3.13) — after layers exist so selection has something to target.
        if (riverId) selectRiver(riverId);
        else if (paId) selectPA(paId);
        else if (stateId) selectState(stateId);
      });

      m.on('error', (e) => {
        console.error('MapLibre error:', e.error);
      });
    }

    init();

    return () => {
      cancelled = true;
      mapInstance.get()?.remove();
      mapInstance.set(null);
    };
  }, []);

  return (
    <div className="relative h-full w-full">
      <div ref={containerRef} className="map-container h-full w-full" />
      {map && (
        <>
          <RiversLayer map={map} />
          <ProtectedAreasLayer map={map} />
          <StateHighlightLayer map={map} />
          <StateBordersLayer map={map} />
        </>
      )}
    </div>
  );
}
STEP53_EOF

cat > "src/components/Map/LayerControl.tsx" << 'STEP53_EOF'
import { useStore } from '@nanostores/preact';
import { paLayerVisible, paLayerCategories, stateBordersVisible } from '../../utils/mapStore';

const PA_CATEGORIES: { id: string; label: string }[] = [
  { id: 'np', label: 'National Parks' },
  { id: 'wls', label: 'Wildlife Sanctuaries' },
  { id: 'tr', label: 'Tiger Reserves' },
  { id: 'br', label: 'Biosphere Reserves' },
  { id: 'ramsar', label: 'Ramsar Sites' },
];

export default function LayerControl() {
  const visible = useStore(paLayerVisible);
  const categories = useStore(paLayerCategories);
  const bordersVisible = useStore(stateBordersVisible);

  function toggleCategory(id: string) {
    const next = new Set(categories);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    paLayerCategories.set(next);
  }

  return (
    <div
      className="absolute top-4 right-4 z-10 w-56 rounded-lg border shadow-sm"
      style={{ background: 'var(--color-surface)', borderColor: 'var(--color-border)' }}
    >
      <div className="px-3 py-2 border-b text-sm font-semibold" style={{ borderColor: 'var(--color-border)' }}>
        Layers
      </div>
      <div className="px-3 py-2 border-b text-sm" style={{ borderColor: 'var(--color-border)' }}>
        <label className="flex items-center gap-2">
          <input type="checkbox" checked readOnly disabled />
          Rivers
        </label>
      </div>
      <div className="px-3 py-2 border-b text-sm" style={{ borderColor: 'var(--color-border)' }}>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={bordersVisible}
            onChange={(e) => stateBordersVisible.set((e.target as HTMLInputElement).checked)}
          />
          State Borders
        </label>
      </div>
      <div className="px-3 py-2 text-sm">
        <label className="flex items-center gap-2 font-medium">
          <input
            type="checkbox"
            checked={visible}
            onChange={(e) => paLayerVisible.set((e.target as HTMLInputElement).checked)}
          />
          Protected Areas
        </label>
        {visible && (
          <div className="mt-2 ml-6 flex flex-col gap-1">
            {PA_CATEGORIES.map((cat) => (
              <label key={cat.id} className="flex items-center gap-2 text-xs" style={{ color: 'var(--color-text-muted)' }}>
                <input type="checkbox" checked={categories.has(cat.id)} onChange={() => toggleCategory(cat.id)} />
                {cat.label}
              </label>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
STEP53_EOF

cat > "src/components/Map/StateBordersLayer.tsx" << 'STEP53_EOF'
import { useEffect } from 'preact/hooks';
import maplibregl from 'maplibre-gl';
import { stateBordersVisible } from '../../utils/mapStore';

const LAYER_ID = 'state-borders';

export default function StateBordersLayer({ map }: { map: maplibregl.Map }) {
  useEffect(() => {
    if (!map.getLayer(LAYER_ID)) return;
    const unsubscribe = stateBordersVisible.subscribe((visible) => {
      map.setLayoutProperty(LAYER_ID, 'visibility', visible ? 'visible' : 'none');
    });
    return () => unsubscribe();
  }, [map]);

  return null;
}
STEP53_EOF

cat > "src/styles/global.css" << 'STEP53_EOF'
@import "tailwindcss";
@import "@fontsource/sora/600.css";
@import "@fontsource/inter/400.css";
@import "@fontsource/inter/600.css";

:root {
  --color-bg: #FFFFFF;          --color-surface: #F4F6F9;    --color-border: #D1D9E0;
  --color-text: #111827;        --color-text-muted: #4B5563; --color-accent: #1D6FE8;
  --color-accent-warm: #A45A05; --color-land: #D4E6C3;       --color-state-border: #577E43;
  --color-river-context: #6D93B8;

  --color-pa-np-label: #1B5E20;
  --color-pa-wls-label: #2A712D;
  --color-pa-tr-label: #AF3E00;
  --color-pa-br-label: #4527A0;
  --color-pa-ramsar-label: #0D47A1;

  --color-river-default: #2E75B6;
}

[data-theme="dark"] {
  --color-bg: #0F1923;          --color-surface: #1A2634;    --color-border: #2D4159;
  --color-text: #E8EFF7;        --color-text-muted: #8FA6BF; --color-accent: #3B9EFF;
  --color-accent-warm: #F5A623; --color-land: #1E3A2F;       --color-state-border: #539278;
  --color-river-context: #3C5670;

  --color-pa-np-label: #30B439;
  --color-pa-wls-label: #3EB344;
  --color-pa-tr-label: #FF7225;
  --color-pa-br-label: #A58FE6;
  --color-pa-ramsar-label: #639DF6;

  --color-river-default: #5B9BD5;
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --color-bg: #0F1923;          --color-surface: #1A2634;    --color-border: #2D4159;
    --color-text: #E8EFF7;        --color-text-muted: #8FA6BF; --color-accent: #3B9EFF;
    --color-accent-warm: #F5A623; --color-land: #1E3A2F;       --color-state-border: #539278;
    --color-river-context: #3C5670;

    --color-pa-np-label: #30B439;
    --color-pa-wls-label: #3EB344;
    --color-pa-tr-label: #FF7225;
    --color-pa-br-label: #A58FE6;
    --color-pa-ramsar-label: #639DF6;

    --color-river-default: #5B9BD5;
  }
}

html, body {
  height: 100%;
  margin: 0;
  background: var(--color-bg);
  color: var(--color-text);
  font-family: "Inter", system-ui, sans-serif;
}

.map-container {
  touch-action: none;
}

/* MapLibre's default popup (river-hover tooltip, RiversLayer.tsx) ships a fixed white
   background but doesn't set its own text color — it inherits `body`'s `color`, which is
   light in dark mode, so the box became light-on-white/invisible. Pin both explicitly to the
   theme so it reads correctly either way. */
.maplibregl-popup-content {
  background: var(--color-surface);
  color: var(--color-text);
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3);
}
.maplibregl-popup-anchor-bottom .maplibregl-popup-tip {
  border-top-color: var(--color-surface);
}
.maplibregl-popup-anchor-top .maplibregl-popup-tip {
  border-bottom-color: var(--color-surface);
}
.maplibregl-popup-anchor-left .maplibregl-popup-tip {
  border-right-color: var(--color-surface);
}
.maplibregl-popup-anchor-right .maplibregl-popup-tip {
  border-left-color: var(--color-surface);
}

/* Boundary-less TR marker (§4.6) */
.pa-marker {
  width: 14px;
  height: 14px;
  border-radius: 50%;
  border: 2px dashed var(--color-pa-tr-label);
  background: transparent;
  cursor: pointer;
}
.pa-marker.highlighted {
  background: color-mix(in srgb, var(--color-pa-tr-label) 35%, transparent);
}

.panel-slide-in {
  animation: panel-slide-in 300ms cubic-bezier(0.16, 1, 0.3, 1);
}
@keyframes panel-slide-in {
  from { transform: translateX(16px); opacity: 0; }
  to   { transform: translateX(0);    opacity: 1; }
}
@media (prefers-reduced-motion: reduce) {
  .panel-slide-in { animation: none; }
}

/* Visually-hidden but screen-reader-accessible (WCAG 4.1.3 aria-live status regions, §12) */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
STEP53_EOF

echo "Files written. Installing deps and verifying build..."
pnpm install
pnpm exec astro check
pnpm build
echo "step53-patch.sh applied and verified."
