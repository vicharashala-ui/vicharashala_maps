// Fixed-radius bbox around a point, for PAs missing a real `bounds` (boundary-less TRs, §4.2/§4.6).
const FALLBACK_RADIUS_DEG = 0.15;

export type Bounds = [number, number, number, number]; // [west, south, east, north]

export function centroidFallbackBounds(pa: { centroid_lng: number; centroid_lat: number }): Bounds {
  const { centroid_lng: lng, centroid_lat: lat } = pa;
  return [lng - FALLBACK_RADIUS_DEG, lat - FALLBACK_RADIUS_DEG, lng + FALLBACK_RADIUS_DEG, lat + FALLBACK_RADIUS_DEG];
}
