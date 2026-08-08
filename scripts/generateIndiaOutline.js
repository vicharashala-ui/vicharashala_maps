// scripts/generateIndiaOutline.js
// Input:  public/geojson/india-states.geojson (per-state polygons)
// Output: public/geojson/india-outline.geojson (single dissolved national outline —
//         internal state-to-state edges removed, only the true external border remains)
//
// Why: MapView's state-borders layer draws every state polygon's own edges, so the outer
// national border and internal state boundaries render identically. Rerun this whenever
// india-states.geojson's geometry changes (state boundary corrections, resimplification).

import fs from 'node:fs';
import * as turf from '@turf/turf';

const IN = 'public/geojson/india-states.geojson';
const OUT = 'public/geojson/india-outline.geojson';

const states = JSON.parse(fs.readFileSync(IN, 'utf-8'));
const dissolved = turf.union(turf.featureCollection(states.features));

if (!dissolved) {
  console.error('turf.union returned null — check india-states.geojson for invalid/self-intersecting geometry.');
  process.exit(1);
}

fs.writeFileSync(OUT, JSON.stringify(turf.featureCollection([dissolved])));
console.log(`Wrote ${OUT} (${dissolved.geometry.type}, ${JSON.stringify(dissolved.geometry).length} bytes)`);
