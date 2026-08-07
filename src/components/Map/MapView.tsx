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

const INDIA_BOUNDS: [number, number, number, number] = [68.1, 6.4, 97.4, 37.6];

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

      const waterColor = getComputedStyle(document.documentElement).getPropertyValue('--color-water').trim();
      const landColor = getComputedStyle(document.documentElement).getPropertyValue('--color-land').trim();
      const stateBorderColor = getComputedStyle(document.documentElement)
        .getPropertyValue('--color-state-border')
        .trim();

      const m = new maplibregl.Map({
        container: containerRef.current,
        style: {
          version: 8,
          sources: {},
          layers: [{ id: 'background', type: 'background', paint: { 'background-color': waterColor } }],
        },
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
        m.addLayer({ id: 'land-fill', type: 'fill', source: 'india-states', paint: { 'fill-color': landColor } });
        m.addLayer({
          id: 'state-borders',
          type: 'line',
          source: 'india-states',
          paint: { 'line-color': stateBorderColor, 'line-width': 1 },
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
