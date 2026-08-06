import { useEffect, useRef } from 'preact/hooks';
import maplibregl from 'maplibre-gl';
import { selectedStateId } from '../../utils/mapStore';
import { geometryBounds } from '../../utils/geoUtils';
import type { GeoJSONCoords } from '../../utils/geoUtils';

const SOURCE_ID = 'india-states';
const OUTLINE_LAYER = 'state-selected-outline';

interface StateFeature {
  properties: { id: string };
  geometry: { type: string; coordinates: GeoJSONCoords };
}

export default function StateHighlightLayer({ map }: { map: maplibregl.Map }) {
  const geojsonRef = useRef<{ features: StateFeature[] } | null>(null);

  useEffect(() => {
    if (!map.getLayer(OUTLINE_LAYER)) {
      const accentWarm = getComputedStyle(document.documentElement).getPropertyValue('--color-accent-warm').trim();
      map.addLayer({
        id: OUTLINE_LAYER,
        type: 'line',
        source: SOURCE_ID,
        filter: ['==', ['get', 'id'], ''],
        paint: { 'line-color': accentWarm, 'line-width': 2.5 },
      });
    }

    async function applySelection(stateId: string | null) {
      map.setFilter(OUTLINE_LAYER, ['==', ['get', 'id'], stateId ?? '']);
      if (!stateId) return;

      geojsonRef.current ??= await fetch('/geojson/india-states.geojson').then((r) => r.json());
      const feature = geojsonRef.current?.features.find((f) => f.properties.id === stateId);
      if (feature) map.fitBounds(geometryBounds(feature.geometry), { padding: 40, duration: 500 });
    }

    const unsubscribe = selectedStateId.subscribe((id) => {
      applySelection(id);
    });

    return () => unsubscribe();
  }, [map]);

  return null;
}
