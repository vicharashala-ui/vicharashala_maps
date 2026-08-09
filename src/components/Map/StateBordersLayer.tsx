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
