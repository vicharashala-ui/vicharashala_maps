// scripts/buildPaMerged.js
// Input:  src/boundaries/*.geojson (canonicalized, feature.properties.id set)
// Output: build/pa-merged.geojson
//
// Rebuilds spatialIntersect.js's PA-geometry input directly from src/boundaries. Unlike
// mergeFeatures.js, this doesn't touch public/data/protected-areas.json or pa-id-map.json —
// those are already built and correct; this only reconstructs the build/ intermediate needed
// to re-run the river/PA intersection.

import fs from 'node:fs';
import path from 'node:path';

const BOUNDARIES_DIR = 'src/boundaries';
const OUT = 'build/pa-merged.geojson';

function run() {
  fs.mkdirSync('build', { recursive: true });
  const files = fs.readdirSync(BOUNDARIES_DIR).filter((f) => f.endsWith('.geojson'));

  const merged = { type: 'FeatureCollection', features: [] };
  let nextId = 1;
  for (const file of files) {
    const geojson = JSON.parse(fs.readFileSync(path.join(BOUNDARIES_DIR, file), 'utf-8'));
    for (const feature of geojson.features) {
      feature.id = nextId;
      merged.features.push(feature);
    }
    nextId++;
  }

  fs.writeFileSync(OUT, JSON.stringify(merged));
  console.log(`Wrote ${OUT}: ${merged.features.length} features from ${files.length} files`);
}

run();
