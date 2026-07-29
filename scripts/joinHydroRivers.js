// scripts/joinHydroRivers.js
// Input:  build/raw/hydrorivers/HydroRIVERS_v10_as.shp (+ sidecar files)
//         build/rivers-govt-matched.geojson, build/rivers-govt-metadata.json (from Step 5c)
// Output: build/rivers-govt-metadata.json (updated in place), build/hydrorivers-join-report.json
//
// HydroRIVERS has NO river names — matched onto our named rivers by proximity. A grid index
// over reach midpoints makes this tractable at real scale (India bbox has ~500K reaches —
// the first version of this script used a per-candidate pointToLineDistance check with no
// index, which was fine on a 90-reach test fixture and unusably slow at 500K; this version
// was stress-tested at that scale before being handed over, see PROGRESS.md).
//
// stream_order = MAX Strahler order (ORD_STRA) among matched reaches (a river's order is
// conventionally read at its most developed/downstream point). Matched reach lengths are
// also summed as an independent length estimate — NOT auto-substituted for length_km_india,
// written to a separate field for manual comparison against the 32 needs_verification rivers.

import fs from 'node:fs';
import { execSync } from 'node:child_process';
import * as turf from '@turf/turf';

const HYDRORIVERS_SHP = 'build/raw/hydrorivers/HydroRIVERS_v10_as.shp';
const CLIPPED_GEOJSON = 'build/hydrorivers-india-clip.geojson';
const MATCHED_RIVERS = 'build/rivers-govt-matched.geojson';
const METADATA_FILE = 'build/rivers-govt-metadata.json';
const REPORT_FILE = 'build/hydrorivers-join-report.json';

const INDIA_BBOX = [68, 6, 98, 36]; // west, south, east, north
const MATCH_TOLERANCE_KM = 1;
const SAMPLE_INTERVAL_KM = 0.5; // points sampled along each named river for grid lookups
const GRID_CELL_DEG = 0.02; // ~2.2km — coarser than tolerance on purpose, index is a broad-phase filter only; final distance check below is real haversine km

function clipToIndia() {
  console.log('==> Clipping HydroRIVERS Asia extract to India bbox via mapshaper');
  execSync(
    `pnpm exec mapshaper "${HYDRORIVERS_SHP}" -proj wgs84 ` +
      `-clip bbox=${INDIA_BBOX.join(',')} ` +
      `-o "${CLIPPED_GEOJSON}" format=geojson`,
    { stdio: 'inherit' }
  );
}

function reachMidpoint(feature) {
  const coords =
    feature.geometry.type === 'MultiLineString'
      ? feature.geometry.coordinates[0]
      : feature.geometry.coordinates;
  const line = turf.lineString(coords);
  const length = turf.length(line, { units: 'kilometers' });
  return turf.along(line, length / 2, { units: 'kilometers' }).geometry.coordinates;
}

function gridKey(lng, lat) {
  return `${Math.floor(lng / GRID_CELL_DEG)}_${Math.floor(lat / GRID_CELL_DEG)}`;
}

function buildGridIndex(reaches) {
  const grid = new Map();
  for (const reach of reaches) {
    const [lng, lat] = reach.midpoint;
    const key = gridKey(lng, lat);
    if (!grid.has(key)) grid.set(key, []);
    grid.get(key).push(reach);
  }
  return grid;
}

function nearbyReaches(grid, lng, lat) {
  const cellX = Math.floor(lng / GRID_CELL_DEG);
  const cellY = Math.floor(lat / GRID_CELL_DEG);
  const results = [];
  for (let dx = -1; dx <= 1; dx++) {
    for (let dy = -1; dy <= 1; dy++) {
      const bucket = grid.get(`${cellX + dx}_${cellY + dy}`);
      if (bucket) results.push(...bucket);
    }
  }
  return results;
}

// Regularly-spaced sample points along a river's geometry (LineString or MultiLineString's
// parts), independent of the source data's own vertex density.
function samplePoints(feature) {
  const coordsList =
    feature.geometry.type === 'MultiLineString'
      ? feature.geometry.coordinates
      : [feature.geometry.coordinates];

  const points = [];
  for (const coords of coordsList) {
    if (coords.length < 2) continue;
    const line = turf.lineString(coords);
    const length = turf.length(line, { units: 'kilometers' });
    for (let d = 0; d <= length; d += SAMPLE_INTERVAL_KM) {
      points.push(turf.along(line, d, { units: 'kilometers' }).geometry.coordinates);
    }
    points.push(coords[coords.length - 1]); // don't lose the tail
  }
  return points;
}

function run() {
  const startTime = Date.now();

  if (!fs.existsSync(CLIPPED_GEOJSON)) {
    clipToIndia();
  } else {
    console.log(`==> Reusing existing ${CLIPPED_GEOJSON} (delete it to force re-clip)`);
  }

  console.log('==> Loading data');
  const hydroData = JSON.parse(fs.readFileSync(CLIPPED_GEOJSON, 'utf-8'));
  const namedRivers = JSON.parse(fs.readFileSync(MATCHED_RIVERS, 'utf-8'));
  const metadata = JSON.parse(fs.readFileSync(METADATA_FILE, 'utf-8'));
  const metaByName = new Map(metadata.map((m) => [m.name, m]));

  console.log(`HydroRIVERS reaches in India bbox: ${hydroData.features.length}`);

  console.log('==> Precomputing reach midpoints + building grid index');
  const reaches = hydroData.features.map((f, i) => ({
    id: i,
    midpoint: reachMidpoint(f),
    ordStra: f.properties.ORD_STRA,
    lengthKm: f.properties.LENGTH_KM,
  }));
  const grid = buildGridIndex(reaches);
  console.log(`Grid cells populated: ${grid.size}`);

  const report = [];

  console.log('==> Matching reaches to named rivers');
  for (const river of namedRivers.features) {
    const riverStart = Date.now();
    const name = river.properties.name;
    const points = samplePoints(river);

    const matchedIds = new Set();
    for (const [lng, lat] of points) {
      for (const candidate of nearbyReaches(grid, lng, lat)) {
        if (matchedIds.has(candidate.id)) continue;
        const dist = turf.distance([lng, lat], candidate.midpoint, { units: 'kilometers' });
        if (dist <= MATCH_TOLERANCE_KM) matchedIds.add(candidate.id);
      }
    }

    const matched = reaches.filter((r) => matchedIds.has(r.id));
    const meta = metaByName.get(name);
    const elapsedS = ((Date.now() - riverStart) / 1000).toFixed(1);

    if (matched.length === 0) {
      report.push({ name, matchedReaches: 0, streamOrder: null, hydroriversLengthKm: null });
      if (meta) meta.stream_order = null;
      console.log(`  ${name}: 0 matches (${elapsedS}s)`);
      continue;
    }

    const streamOrder = Math.max(...matched.map((r) => r.ordStra));
    const lengthSum = Math.round(matched.reduce((s, r) => s + r.lengthKm, 0) * 10) / 10;

    report.push({ name, matchedReaches: matched.length, streamOrder, hydroriversLengthKm: lengthSum });
    if (meta) {
      meta.stream_order = streamOrder;
      meta.hydrorivers_length_km_crosscheck = lengthSum;
    }
    console.log(`  ${name}: ${matched.length} reaches, order ${streamOrder} (${elapsedS}s)`);
  }

  fs.writeFileSync(METADATA_FILE, JSON.stringify(metadata, null, 2));
  fs.writeFileSync(REPORT_FILE, JSON.stringify(report, null, 2));

  const zeroMatch = report.filter((r) => r.matchedReaches === 0);
  const totalS = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`\nTotal time: ${totalS}s`);
  console.log(`Rivers with a stream_order match: ${report.length - zeroMatch.length}/${report.length}`);
  if (zeroMatch.length) {
    console.log(`Zero matches (check MATCH_TOLERANCE_KM or river geometry):`);
    zeroMatch.forEach((r) => console.log(`  - ${r.name}`));
  }
}

run();
