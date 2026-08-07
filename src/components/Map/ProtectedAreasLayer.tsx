import { useEffect, useRef } from 'preact/hooks';
import maplibregl from 'maplibre-gl';
import { loadPAData } from '../../utils/dataStore';
import { selectedPAId, selectPA, paLayerVisible, paLayerCategories } from '../../utils/mapStore';
import { paFilters, hasActivePAFilters, paMatchesFilters } from '../../utils/filterStore';
import type { PAFilters } from '../../utils/filterStore';
import { debouncedUpdateUrl } from '../../utils/urlState';
import type { ProtectedArea } from '../../utils/types';

const SOURCE_ID = 'protected-areas';
const SOURCE_LAYER = 'protected-areas';

// Paint-order matches spec's style stack (§3.1): wls, ramsar, br, tr, np (bottom to top).
const CATEGORIES: { id: ProtectedArea['category']; fill: string; label: string }[] = [
  { id: 'wls', fill: '#74C476', label: 'Wildlife Sanctuaries' },
  { id: 'ramsar', fill: '#4292C6', label: 'Ramsar Sites' },
  { id: 'br', fill: '#9E9AC8', label: 'Biosphere Reserves' },
  { id: 'tr', fill: '#FD8D3C', label: 'Tiger Reserves' },
  { id: 'np', fill: '#41AB5D', label: 'National Parks' },
];

export default function ProtectedAreasLayer({ map }: { map: maplibregl.Map }) {
  const markersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
  const paDataRef = useRef<{ protectedAreas: ProtectedArea[]; paIdMap: Record<string, number> } | null>(null);

  useEffect(() => {
    if (!map.getSource(SOURCE_ID)) {
      map.addSource(SOURCE_ID, { type: 'vector', url: 'pmtiles:///tiles/protected-areas.pmtiles' });
    }

    for (const cat of CATEGORIES) {
      const fillId = `pa-${cat.id}-fill`;
      const outlineId = `pa-${cat.id}-outline`;
      if (!map.getLayer(fillId)) {
        map.addLayer({
          id: fillId,
          type: 'fill',
          source: SOURCE_ID,
          'source-layer': SOURCE_LAYER,
          filter: ['==', ['get', 'category'], cat.id],
          layout: { visibility: 'none' },
          paint: {
            'fill-color': cat.fill,
            'fill-opacity': ['case', ['boolean', ['feature-state', 'selected'], false], 0.4, 0.25],
          },
        });
      }
      if (!map.getLayer(outlineId)) {
        map.addLayer({
          id: outlineId,
          type: 'line',
          source: SOURCE_ID,
          'source-layer': SOURCE_LAYER,
          filter: ['==', ['get', 'category'], cat.id],
          layout: { visibility: 'none' },
          paint: {
            'line-color': cat.fill,
            'line-width': ['case', ['boolean', ['feature-state', 'highlighted'], false], 2.5, 1],
          },
        });
      }
    }

    let currentSelected: number | null = null;

    async function ensureBoundarylessMarkers() {
      if (markersRef.current.size > 0) return;
      const data = await loadPAData();
      paDataRef.current = data;
      for (const pa of data.protectedAreas) {
        if (pa.has_boundary) continue;
        const el = document.createElement('div');
        el.className = 'pa-marker';
        el.title = pa.name;
        el.addEventListener('click', () => {
          selectPA(pa.id);
          debouncedUpdateUrl({ pa: pa.id });
        });
        const marker = new maplibregl.Marker({ element: el }).setLngLat([pa.centroid_lng, pa.centroid_lat]).addTo(map);
        markersRef.current.set(pa.id, marker);
      }
    }

    function onClick(e: maplibregl.MapMouseEvent) {
      const layers = CATEGORIES.map((c) => `pa-${c.id}-fill`).filter((id) => map.getLayer(id));
      // NP > TR > BR > Ramsar > WLS click priority (§3.1) — query in that order, take first hit.
      const priority = ['pa-np-fill', 'pa-tr-fill', 'pa-br-fill', 'pa-ramsar-fill', 'pa-wls-fill'].filter((id) =>
        layers.includes(id),
      );
      const features = map.queryRenderedFeatures(e.point, { layers: priority });
      if (!features.length) return;
      const winner = priority
        .map((layerId) => features.find((f) => f.layer.id === layerId))
        .find(Boolean) as maplibregl.MapGeoJSONFeature | undefined;
      const id = winner?.properties?.id as string | undefined;
      if (!id) return;
      selectPA(id);
      debouncedUpdateUrl({ pa: id });
    }

    map.on('click', onClick);
    for (const cat of CATEGORIES) {
      map.on('mouseenter', `pa-${cat.id}-fill`, () => (map.getCanvas().style.cursor = 'pointer'));
      map.on('mouseleave', `pa-${cat.id}-fill`, () => (map.getCanvas().style.cursor = ''));
    }

    async function applySelection(paId: string | null) {
      if (currentSelected !== null) {
        map.setFeatureState({ source: SOURCE_ID, sourceLayer: SOURCE_LAYER, id: currentSelected }, { selected: false });
        currentSelected = null;
      }
      for (const marker of markersRef.current.values()) marker.getElement().classList.remove('highlighted');
      if (!paId) return;

      const data = paDataRef.current ?? (await loadPAData());
      paDataRef.current = data;
      const pa = data.protectedAreas.find((p) => p.id === paId);
      if (!pa) return;

      if (pa.has_boundary) {
        const fid = data.paIdMap[paId];
        if (fid !== undefined) {
          map.setFeatureState({ source: SOURCE_ID, sourceLayer: SOURCE_LAYER, id: fid }, { selected: true });
          currentSelected = fid;
        }
        // Ensure its category layer is visible so the selected polygon is actually paintable.
        setLayerVisibility(new Set([...paLayerCategories.get(), pa.category]));
        paLayerCategories.set(new Set([...paLayerCategories.get(), pa.category]));
        paLayerVisible.set(true);
      } else {
        await ensureBoundarylessMarkers();
        markersRef.current.get(paId)?.getElement().classList.add('highlighted');
      }

      if (pa.bounds) map.fitBounds(pa.bounds, { padding: 60, duration: 500 });
      else map.flyTo({ center: [pa.centroid_lng, pa.centroid_lat], zoom: 10 });
    }

    function setLayerVisibility(categories: Set<string>) {
      const filters = paFilters.get();
      const filtered = hasActivePAFilters(filters);
      for (const cat of CATEGORIES) {
        const visible = paLayerVisible.get() && categories.has(cat.id);
        map.setLayoutProperty(`pa-${cat.id}-fill`, 'visibility', visible ? 'visible' : 'none');
        map.setLayoutProperty(`pa-${cat.id}-outline`, 'visibility', visible ? 'visible' : 'none');
      }
      for (const [id, marker] of markersRef.current) {
        const pa = paDataRef.current?.protectedAreas.find((p) => p.id === id);
        const shown =
          paLayerVisible.get() &&
          pa &&
          categories.has(pa.category) &&
          (!filtered || paMatchesFilters(pa, filters));
        marker.getElement().style.display = shown ? '' : 'none';
      }
    }

    // §3.6: PA filter panel (Category + State) narrows via `setFilter`, layered on top of the
    // per-category base filter above — orthogonal to LayerControl's visibility toggle (§3.2)
    // and to `selected`/`highlighted` feature-state, never conflate the three.
    function applyFilters(filters: PAFilters) {
      const data = paDataRef.current;
      const filtered = hasActivePAFilters(filters);
      for (const cat of CATEGORIES) {
        const fillId = `pa-${cat.id}-fill`;
        const outlineId = `pa-${cat.id}-outline`;
        if (!map.getLayer(fillId)) continue;
        const base: maplibregl.FilterSpecification = ['==', ['get', 'category'], cat.id];
        if (!filtered || !data) {
          map.setFilter(fillId, base);
          map.setFilter(outlineId, base);
          continue;
        }
        const matchingIds = data.protectedAreas.filter((pa) => paMatchesFilters(pa, filters)).map((pa) => pa.id);
        const combined: maplibregl.FilterSpecification = ['all', base, ['in', ['get', 'id'], ['literal', matchingIds]]];
        map.setFilter(fillId, combined);
        map.setFilter(outlineId, combined);
      }
      setLayerVisibility(paLayerCategories.get());
    }

    const unsubVisible = paLayerVisible.subscribe(async (visible) => {
      if (visible && !paDataRef.current) {
        paDataRef.current = await loadPAData();
        await ensureBoundarylessMarkers();
        applyFilters(paFilters.get());
      }
      setLayerVisibility(paLayerCategories.get());
    });
    const unsubCategories = paLayerCategories.subscribe((cats) => setLayerVisibility(cats));
    const unsubSelected = selectedPAId.subscribe((id) => applySelection(id));
    const unsubFilters = paFilters.subscribe((filters) => applyFilters(filters));

    return () => {
      map.off('click', onClick);
      unsubVisible();
      unsubCategories();
      unsubSelected();
      unsubFilters();
      for (const marker of markersRef.current.values()) marker.remove();
      markersRef.current.clear();
    };
  }, [map]);

  return null;
}
