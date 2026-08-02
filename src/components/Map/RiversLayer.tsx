import { useEffect, useRef } from 'preact/hooks';
import maplibregl from 'maplibre-gl';
import { riversIndex, loadRiversIdMap, loadPAData, paDataLoaded } from '../../utils/dataStore';
import { selectedRiverId, selectRiver } from '../../utils/mapStore';
import { debouncedUpdateUrl } from '../../utils/urlState';

const SOURCE_ID = 'rivers';
const SOURCE_LAYER = 'rivers';
const LINE_LAYER = 'rivers-line';

export default function RiversLayer({ map }: { map: maplibregl.Map }) {
  const currentSegmentsRef = useRef<number[]>([]);
  const currentHighlightedPAsRef = useRef<number[]>([]);

  useEffect(() => {
    if (!map.getSource(SOURCE_ID)) {
      map.addSource(SOURCE_ID, { type: 'vector', url: 'pmtiles:///tiles/rivers.pmtiles' });
    }
    if (!map.getLayer(LINE_LAYER)) {
      const style = getComputedStyle(document.documentElement);
      const accentWarm = style.getPropertyValue('--color-accent-warm').trim();
      const riverDefault = style.getPropertyValue('--color-river-default').trim();

      map.addLayer({
        id: LINE_LAYER,
        type: 'line',
        source: SOURCE_ID,
        'source-layer': SOURCE_LAYER,
        paint: {
          'line-color': ['case', ['boolean', ['feature-state', 'selected'], false], accentWarm, riverDefault],
          'line-width': ['interpolate', ['linear'], ['zoom'], 4, 0.6, 10, 2.2],
          'line-opacity': [
            'case',
            ['boolean', ['feature-state', 'selected'], false],
            1.0,
            ['boolean', ['feature-state', 'highlighted'], false],
            0.7,
            0.6,
          ],
        },
      });
    }

    const popup = new maplibregl.Popup({ closeButton: false, closeOnClick: false, offset: 8 });

    function onMouseMove(e: maplibregl.MapMouseEvent & { features?: maplibregl.MapGeoJSONFeature[] }) {
      map.getCanvas().style.cursor = 'pointer';
      const f = e.features?.[0];
      if (!f) return;
      const entry = riversIndex.find((r) => r.id === f.properties?.id);
      popup
        .setLngLat(e.lngLat)
        .setHTML(
          `<strong>${entry?.name ?? f.properties?.id}</strong>${entry ? `<br/>${entry.length_km_india} km` : ''}`,
        )
        .addTo(map);
    }
    function onMouseLeave() {
      map.getCanvas().style.cursor = '';
      popup.remove();
    }
    async function onClick(e: maplibregl.MapMouseEvent & { features?: maplibregl.MapGeoJSONFeature[] }) {
      const f = e.features?.[0];
      const id = f?.properties?.id as string | undefined;
      if (!id) return;
      await applySelection(id);
      selectRiver(id);
      debouncedUpdateUrl({ river: id });
    }

    map.on('mousemove', LINE_LAYER, onMouseMove);
    map.on('mouseleave', LINE_LAYER, onMouseLeave);
    map.on('click', LINE_LAYER, onClick);

    async function applySelection(riverId: string | null) {
      // Clear previous feature-state (§3.3: never use setFilter for highlighting)
      for (const fid of currentSegmentsRef.current) {
        map.setFeatureState({ source: SOURCE_ID, sourceLayer: SOURCE_LAYER, id: fid }, { selected: false, highlighted: false });
      }
      currentSegmentsRef.current = [];

      for (const fid of currentHighlightedPAsRef.current) {
        map.setFeatureState({ source: 'protected-areas', sourceLayer: 'protected-areas', id: fid }, { highlighted: false });
      }
      currentHighlightedPAsRef.current = [];

      if (!riverId) return;

      const idMap = await loadRiversIdMap();
      const segments = idMap[riverId] ?? [];
      currentSegmentsRef.current = segments;
      for (const fid of segments) {
        map.setFeatureState({ source: SOURCE_ID, sourceLayer: SOURCE_LAYER, id: fid }, { selected: true });
      }

      const entry = riversIndex.find((r) => r.id === riverId);
      if (entry) map.fitBounds(entry.bounds, { padding: 60, duration: 500 });

      // Highlight associated PAs regardless of PA layer visibility (§3.3) — only if PA data
      // is already loaded; river selection alone doesn't force-trigger loadPAData().
      if (paDataLoaded.get()) {
        const { protectedAreas, paIdMap } = await loadPAData();
        const relatedIds = protectedAreas.filter((pa) => pa.river_ids.includes(riverId)).map((pa) => pa.id);
        const fids = relatedIds.map((id) => paIdMap[id]).filter((fid): fid is number => fid !== undefined);
        currentHighlightedPAsRef.current = fids;
        for (const fid of fids) {
          map.setFeatureState({ source: 'protected-areas', sourceLayer: 'protected-areas', id: fid }, { highlighted: true });
        }
      }
    }

    const unsubscribe = selectedRiverId.subscribe((id) => {
      applySelection(id);
    });

    return () => {
      map.off('mousemove', LINE_LAYER, onMouseMove);
      map.off('mouseleave', LINE_LAYER, onMouseLeave);
      map.off('click', LINE_LAYER, onClick);
      unsubscribe();
      popup.remove();
    };
  }, [map]);

  return null;
}
