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
import { isDarkTheme } from '../../utils/theme';
import RiversLayer from './RiversLayer';
import ProtectedAreasLayer from './ProtectedAreasLayer';
import StateHighlightLayer from './StateHighlightLayer';

const INDIA_BOUNDS: [number, number, number, number] = [68.1, 6.4, 97.4, 37.6];
// Free, no-API-key, unlimited hosted vector basemap (https://openfreemap.org) — gives the
// Afghanistan-to-Myanmar region real roads/place labels/terrain instead of a flat fill. Style
// choice matches the site's own light/dark theme; picked once at mount, same as the other
// colors below — the map doesn't currently live-update on an in-page theme toggle either way.
const BASEMAP_STYLE = (dark: boolean) => `https://tiles.openfreemap.org/styles/${dark ? 'dark' : 'positron'}`;

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
        style: BASEMAP_STYLE(isDarkTheme()),
        bounds: initialBounds ?? INDIA_BOUNDS,
        fitBoundsOptions: { padding: 20 },
        minZoom: 4,
        maxZoom: 14,
        dragRotate: false,
        pitchWithRotate: false,
        touchPitch: false,
      });

      m.on('load', () => {
        m.addSource('india-states', { type: 'geojson', data: '/geojson/india-states.geojson' });
        // Invisible but still present — 'land-fill' exists purely as a click/hit-test target
        // for the state-select handler below. The real basemap (roads, place labels) now
        // shows through India the same as everywhere else on the map.
        m.addLayer({ id: 'land-fill', type: 'fill', source: 'india-states', paint: { 'fill-opacity': 0 } });
        m.addLayer({
          id: 'state-borders',
          type: 'line',
          source: 'india-states',
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
        </>
      )}
    </div>
  );
}
