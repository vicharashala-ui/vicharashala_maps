import { useEffect, useRef } from 'preact/hooks';
import maplibregl from 'maplibre-gl';
import { riversIndex, loadRiversIdMap, loadPAData, paDataLoaded } from '../../utils/dataStore';
import { selectedRiverId, selectRiver } from '../../utils/mapStore';
import { matchingRiverIds } from '../../utils/filterStore';
import { debouncedUpdateUrl } from '../../utils/urlState';

const SOURCE_ID = 'rivers';
const SOURCE_LAYER = 'rivers';
const LINE_LAYER = 'rivers-line';
// Transnational rivers' course outside India (extendTransnationalRivers.js) — decorative-only
// per MapView.tsx's original comment, but there's no reason a click on a river's Bangladesh/
// Pakistan/etc. reach shouldn't open the same info panel as its India reach. Same handlers,
// keyed off `river_id` (this layer's property) instead of `id` (the pmtiles layer's).
const CONTEXT_LAYER = 'rivers-context-line';

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
          // Widened/brightened at the low end (zoom 4 ≈ the default India-wide view) so rivers
          // read clearly against the basemap without waiting for the user to zoom in.
          'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1.2, 10, 2.4],
          'line-opacity': [
            'case',
            ['boolean', ['feature-state', 'selected'], false],
            1.0,
            ['boolean', ['feature-state', 'highlighted'], false],
            0.85,
            0.75,
          ],
        },
      });
    }

    const popup = new maplibregl.Popup({ closeButton: false, closeOnClick: false, offset: 8 });

    // Factories instead of duplicating the handler body per layer — LINE_LAYER keys its river
    // id under `id` (pmtiles), CONTEXT_LAYER under `river_id` (geojson, see extendTransnationalRivers.js).
    function makeMouseMoveHandler(propKey: 'id' | 'river_id') {
      return (e: maplibregl.MapMouseEvent & { features?: maplibregl.MapGeoJSONFeature[] }) => {
        map.getCanvas().style.cursor = 'pointer';
        const f = e.features?.[0];
        if (!f) return;
        const id = f.properties?.[propKey];
        const entry = riversIndex.find((r) => r.id === id);
        popup
          .setLngLat(e.lngLat)
          .setHTML(`<strong>${entry?.name ?? id}</strong>${entry ? `<br/>${entry.length_km_india} km` : ''}`)
          .addTo(map);
      };
    }
    function onMouseLeave() {
      map.getCanvas().style.cursor = '';
      popup.remove();
    }
    function makeClickHandler(propKey: 'id' | 'river_id') {
      return async (e: maplibregl.MapMouseEvent & { features?: maplibregl.MapGeoJSONFeature[] }) => {
        const f = e.features?.[0];
        const id = f?.properties?.[propKey] as string | undefined;
        if (!id) return;
        await applySelection(id);
        selectRiver(id);
        debouncedUpdateUrl({ river: id });
      };
    }

    const onMouseMove = makeMouseMoveHandler('id');
    const onClick = makeClickHandler('id');
    const onContextMouseMove = makeMouseMoveHandler('river_id');
    const onContextClick = makeClickHandler('river_id');
    const hasContextLayer = !!map.getLayer(CONTEXT_LAYER);

    map.on('mousemove', LINE_LAYER, onMouseMove);
    map.on('mouseleave', LINE_LAYER, onMouseLeave);
    map.on('click', LINE_LAYER, onClick);
    if (hasContextLayer) {
      map.on('mousemove', CONTEXT_LAYER, onContextMouseMove);
      map.on('mouseleave', CONTEXT_LAYER, onMouseLeave);
      map.on('click', CONTEXT_LAYER, onContextClick);
    }

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

    // §3.6: river filter panel narrows which segments render, via `setFilter` — orthogonal to
    // `selected`/`highlighted` feature-state above (never conflate the two, see RiversLayer's
    // sibling comment on ProtectedAreasLayer for why setFilter must stay out of highlighting).
    const unsubFilters = matchingRiverIds.subscribe((ids) => {
      const filter: maplibregl.FilterSpecification | null = ids ? ['in', ['get', 'id'], ['literal', [...ids]]] : null;
      map.setFilter(LINE_LAYER, filter);
    });

    return () => {
      map.off('mousemove', LINE_LAYER, onMouseMove);
      map.off('mouseleave', LINE_LAYER, onMouseLeave);
      map.off('click', LINE_LAYER, onClick);
      if (hasContextLayer) {
        map.off('mousemove', CONTEXT_LAYER, onContextMouseMove);
        map.off('mouseleave', CONTEXT_LAYER, onMouseLeave);
        map.off('click', CONTEXT_LAYER, onContextClick);
      }
      unsubscribe();
      unsubFilters();
      popup.remove();
    };
  }, [map]);

  return null;
}
