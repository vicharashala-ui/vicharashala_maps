// Fixed-radius bbox around a point, for PAs missing a real `bounds` (boundary-less TRs, §4.2/§4.6).
const FALLBACK_RADIUS_DEG = 0.15;

export type Bounds = [number, number, number, number]; // [west, south, east, north]

export function centroidFallbackBounds(pa: { centroid_lng: number; centroid_lat: number }): Bounds {
  const { centroid_lng: lng, centroid_lat: lat } = pa;
  return [lng - FALLBACK_RADIUS_DEG, lat - FALLBACK_RADIUS_DEG, lng + FALLBACK_RADIUS_DEG, lat + FALLBACK_RADIUS_DEG];
}

// Bbox over a Polygon/MultiPolygon geometry's raw coordinates — used for state fitBounds
// (states.json has no bounds field; india-states.geojson is already loaded on the map, so this
// avoids pulling in Turf just for one client-side reduction).
export type GeoJSONCoords = [number, number] | GeoJSONCoords[];

export function geometryBounds(geometry: { type: string; coordinates: GeoJSONCoords }): Bounds {
  let west = Infinity;
  let south = Infinity;
  let east = -Infinity;
  let north = -Infinity;

  // GeoJSON coordinate arrays nest to different depths per geometry type (Polygon vs
  // MultiPolygon); recursing until we hit a [lng, lat] pair is simpler than switching on type.
  function visit(coords: GeoJSONCoords): void {
    if (typeof coords[0] === 'number') {
      const [lng, lat] = coords as [number, number];
      if (lng < west) west = lng;
      if (lng > east) east = lng;
      if (lat < south) south = lat;
      if (lat > north) north = lat;
    } else {
      for (const c of coords as GeoJSONCoords[]) visit(c);
    }
  }
  visit(geometry.coordinates);

  return [west, south, east, north];
}
