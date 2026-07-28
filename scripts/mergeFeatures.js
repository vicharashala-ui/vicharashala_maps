// scripts/mergeFeatures.js
// Input:  src/boundaries/*.geojson (canonicalized), build/protected-areas.canonical.json
// Output: build/pa-merged.geojson, public/data/pa-id-map.json, public/data/protected-areas.json
//
// Run AFTER ensureProperties.js.

import fs from 'node:fs';
import path from 'node:path';
import * as turf from '@turf/turf';
import { ProtectedArea } from './schemas.js';

const BOUNDARIES_DIR = 'src/boundaries';
const BUILD_OUT = 'build';
const DATA_OUT = 'public/data';

function run() {
  fs.mkdirSync(DATA_OUT, { recursive: true });

  const metadata = JSON.parse(
    fs.readFileSync(path.join(BUILD_OUT, 'protected-areas.canonical.json'), 'utf-8')
  );
  const metaById = new Map(metadata.map((m) => [m.id, m]));

  const files = fs.readdirSync(BOUNDARIES_DIR).filter((f) => f.endsWith('.geojson'));

  const merged = { type: 'FeatureCollection', features: [] };
  const idMap = {};
  let nextId = 1;

  for (const file of files) {
    const geojson = JSON.parse(fs.readFileSync(path.join(BOUNDARIES_DIR, file), 'utf-8'));
    const canonId = geojson.features[0].properties.id;

    const bounds = turf.bbox(geojson);
    const meta = metaById.get(canonId);
    if (meta) meta.bounds = bounds;

    for (const feature of geojson.features) {
      feature.id = nextId;
      merged.features.push(feature);
    }
    idMap[canonId] = nextId;
    nextId++;
  }

  fs.writeFileSync(path.join(BUILD_OUT, 'pa-merged.geojson'), JSON.stringify(merged));
  fs.writeFileSync(path.join(DATA_OUT, 'pa-id-map.json'), JSON.stringify(idMap, null, 2));

  const validated = metadata.map((m) => ProtectedArea.parse(m));
  fs.writeFileSync(path.join(DATA_OUT, 'protected-areas.json'), JSON.stringify(validated));

  console.log(`Merged features: ${merged.features.length}`);
  console.log(`pa-id-map.json entries: ${Object.keys(idMap).length}`);
  console.log(`protected-areas.json records (validated): ${validated.length}`);
  const withBounds = validated.filter((m) => m.bounds !== null).length;
  console.log(`Records with bounds: ${withBounds} (expect total - boundary-less sites)`);
}

run();
