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
  // §3.12: initial-load placeholder + tile/style-error banner. `retryAttempt` re-runs the
  // effect below on demand (Retry button) — everything else about init() is unchanged.
  const [mapError, setMapError] = useState(false);
  const [retryAttempt, setRetryAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    let errorReported = false;
    setMapError(false);

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
        // MapLibre can emit multiple 'error' events for one failed load (e.g. several failed
        // tile requests) — report the banner once per attempt, not once per event.
        if (!errorReported && !cancelled) {
          errorReported = true;
          setMapError(true);
        }
      });
    }

    init();

    return () => {
      cancelled = true;
      mapInstance.get()?.remove();
      mapInstance.set(null);
      setMap(null);
    };
  }, [retryAttempt]);

  function handleRetry() {
    setMapError(false);
    setRetryAttempt((n) => n + 1);
  }

  return (
    <div className="relative h-full w-full">
      <div ref={containerRef} className="map-container h-full w-full" />
      {!map && !mapError && (
        <div
          role="status"
          aria-live="polite"
          className="absolute inset-0 flex flex-col items-center justify-center gap-3"
          style={{ background: 'var(--color-bg)' }}
        >
          <div
            className="map-loading-spinner h-8 w-8 rounded-full border-2"
            style={{ borderColor: 'var(--color-border)', borderTopColor: 'var(--color-accent)' }}
            aria-hidden="true"
          />
          <span className="text-sm" style={{ color: 'var(--color-text-muted)' }}>Loading map…</span>
        </div>
      )}
      {mapError && (
        <div
          role="alert"
          className="absolute inset-0 flex flex-col items-center justify-center gap-3 px-4 text-center"
          style={{ background: 'var(--color-bg)' }}
        >
          <span className="text-sm" style={{ color: 'var(--color-text)' }}>Could not load map data.</span>
          <button
            type="button"
            onClick={handleRetry}
            className="rounded border px-4 py-1.5 text-sm font-medium"
            style={{ borderColor: 'var(--color-border)', color: 'var(--color-accent)' }}
          >
            Retry
          </button>
        </div>
      )}
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
