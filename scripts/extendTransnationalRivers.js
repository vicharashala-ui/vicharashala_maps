// scripts/extendTransnationalRivers.js
// Input:  build/raw/hydrorivers/HydroRIVERS_v10_as.shp (Asia extract, already downloaded
//         for joinHydroRivers.js — reused here, no new fetch)
//         public/data/rivers-index.json  (source of truth for which rivers are transnational)
//         build/rivers-by-id/{id}.geojson (India-portion geometry, from prepareRivers.js)
//
// Output: public/data/rivers-context.geojson (extension geometry for transnational rivers,
//         outside the India bbox only — a separate, non-interactive contextual layer)
//         build/rivers-context-report.json
//
// WHY TOPOLOGY, NOT NAMES: the India-portion pipeline matches named rivers to OSM/Overpass by
// name. Extending past the border would mean matching against Urdu/Dari/Chinese/Burmese/
// Bengali names — brittle and easy to mismatch (see fetchRivers.js's own multi-candidate
// warnings, which is with English/Hindi names only). HydroRIVERS reaches are unnamed but carry
// real network topology (HYRIV_ID, NEXT_DOWN) — so instead of matching names, we anchor on the
// reach nearest the river's own India-portion endpoint and walk the graph from there. Zero
// naming ambiguity, same free dataset already in the pipeline.
//
// SCOPE: follows the single highest-stream-order (ORD_STRA) continuation at each branch, not
// every tributary — we want the river's own path, not its entire foreign sub-basin. Tracing
// stops at MAX_HOPS or once it leaves CORRIDOR_BBOX.

import fs from 'node:fs';
import { execSync } from 'node:child_process';
import * as turf from '@turf/turf';

const HYDRORIVERS_SHP = 'build/raw/hydrorivers/HydroRIVERS_v10_as.shp';
const CORRIDOR_CLIP = 'build/hydrorivers-corridor-clip.geojson';
const RIVERS_INDEX = 'public/data/rivers-index.json';
const RIVERS_BY_ID_DIR = 'build/rivers-by-id';
const INDIA_STATES_GEOJSON = 'public/geojson/india-states.geojson';
const OUT_CONTEXT = 'public/data/rivers-context.geojson';
const OUT_REPORT = 'build/rivers-context-report.json';

// west, south, east, north — Afghanistan through Myanmar, wide enough to catch every
// transnational river's upstream/downstream reach without pulling in unrelated basins.
const CORRIDOR_BBOX = [60, 5, 100, 38];
// A generous rectangle around India — NOT India's actual shape. Bangladesh, Nepal, Bhutan and
// most of Pakistan sit inside this same rectangle, so it's only a cheap fast-reject before the
// real point-in-polygon check against india-states.geojson (see insideIndia below). An earlier
// version used this rectangle AS the India/not-India test when trimming traced chains — since
// neighbouring countries are inside the rectangle too, every real cross-border reach still
// tested "inside India" and got trimmed away, which is why every river came back empty.
const COARSE_INDIA_BBOX = [66, 5, 99, 38];
const MATCH_TOLERANCE_KM = 3; // looser than joinHydroRivers.js's 1km — border reaches are sparser
const MAX_HOPS = 400; // generous ceiling; real chains stop far earlier when they leave CORRIDOR_BBOX

function clipToCorridor() {
  console.log('==> Clipping HydroRIVERS Asia extract to corridor bbox via mapshaper');
  execSync(
    `pnpm exec mapshaper "${HYDRORIVERS_SHP}" -proj wgs84 ` +
      `-clip bbox=${CORRIDOR_BBOX.join(',')} ` +
      `-o "${CORRIDOR_CLIP}" format=geojson`,
    { stdio: 'inherit' }
  );
}

function endpoints(geometry) {
  const lines = geometry.type === 'MultiLineString' ? geometry.coordinates : [geometry.coordinates];
  return [lines[0][0], lines.at(-1).at(-1)];
}

function gridKey(lng, lat, cellDeg) {
  return `${Math.floor(lng / cellDeg)}_${Math.floor(lat / cellDeg)}`;
}

function buildReachGraph(hydroData) {
  const CELL_DEG = 0.05; // ~5.5km — corridor is sparser than the India-only match, coarser cell is fine
  const byHyrivId = new Map();
  const grid = new Map();

  for (const f of hydroData.features) {
    const coords = f.geometry.type === 'MultiLineString' ? f.geometry.coordinates[0] : f.geometry.coordinates;
    const reach = {
      hyrivId: f.properties.HYRIV_ID,
      nextDown: f.properties.NEXT_DOWN,
      ordStra: f.properties.ORD_STRA,
      coords,
      midpoint: turf.along(turf.lineString(coords), turf.length(turf.lineString(coords)) / 2, {
        units: 'kilometers',
      }).geometry.coordinates,
    };
    byHyrivId.set(reach.hyrivId, reach);
    for (const key of new Set([gridKey(coords[0][0], coords[0][1], CELL_DEG), gridKey(...reach.midpoint, CELL_DEG)])) {
      if (!grid.has(key)) grid.set(key, []);
      grid.get(key).push(reach);
    }
  }

  // reverse adjacency: nextDown -> upstream reaches, so we can walk toward the source too
  const upstreamOf = new Map();
  for (const reach of byHyrivId.values()) {
    if (!reach.nextDown || reach.nextDown === 0) continue;
    if (!upstreamOf.has(reach.nextDown)) upstreamOf.set(reach.nextDown, []);
    upstreamOf.get(reach.nextDown).push(reach);
  }

  return { byHyrivId, grid, upstreamOf, cellDeg: CELL_DEG };
}

// Widens search rings outward until it finds candidates, rather than a fixed 3x3 — sparse
// corridor areas (e.g. high Tibetan plateau) can have empty neighbouring cells even when a
// reach is nearby. Always returns the closest reach found plus its distance, so callers can
// log *why* a match failed instead of just getting null.
function nearestReach(graph, [lng, lat]) {
  const cellX = Math.floor(lng / graph.cellDeg);
  const cellY = Math.floor(lat / graph.cellDeg);
  let best = null;
  let bestDist = Infinity;
  for (let ring = 1; ring <= 4; ring++) {
    for (let dx = -ring; dx <= ring; dx++) {
      for (let dy = -ring; dy <= ring; dy++) {
        if (ring > 1 && Math.abs(dx) < ring && Math.abs(dy) < ring) continue; // already scanned
        for (const reach of graph.grid.get(`${cellX + dx}_${cellY + dy}`) ?? []) {
          const d = turf.distance([lng, lat], reach.midpoint, { units: 'kilometers' });
          if (d < bestDist) {
            bestDist = d;
            best = reach;
          }
        }
      }
    }
    if (best && bestDist <= MATCH_TOLERANCE_KM) break;
  }
  return { reach: bestDist <= MATCH_TOLERANCE_KM ? best : null, closest: best, closestDistKm: bestDist };
}

function insideCorridor([lng, lat]) {
  const [w, s, e, n] = CORRIDOR_BBOX;
  return lng >= w && lng <= e && lat >= s && lat <= n;
}

function insideCoarseIndiaBbox([lng, lat]) {
  const [w, s, e, n] = COARSE_INDIA_BBOX;
  return lng >= w && lng <= e && lat >= s && lat <= n;
}

// India's actual shape (state polygons), not a bounding rectangle — see COARSE_INDIA_BBOX
// comment for why the rectangle alone isn't good enough. The bbox check first is a cheap
// reject; booleanPointInPolygon only runs for points already in the ambiguous rectangle zone.
function loadIndiaStates() {
  const gj = JSON.parse(fs.readFileSync(INDIA_STATES_GEOJSON, 'utf-8'));
  return gj.features.map((f) => ({ geometry: f.geometry, bbox: turf.bbox(f) }));
}

function insideIndia(point, states) {
  if (!insideCoarseIndiaBbox(point)) return false;
  const [lng, lat] = point;
  for (const { geometry, bbox } of states) {
    if (lng < bbox[0] || lng > bbox[2] || lat < bbox[1] || lat > bbox[3]) continue;
    if (turf.booleanPointInPolygon(point, geometry)) return true;
  }
  return false;
}

// Walks the reach graph from `start` in one direction (downstream via nextDown, or upstream
// via reverse adjacency), following the highest-ORD_STRA branch at forks. The anchor itself
// always starts *inside* India (it's matched to our own river's endpoint) — so this does NOT
// stop on "still inside India"; it walks the whole path out to MAX_HOPS/corridor edge, and the
// caller trims to the outside-India portion. (An earlier version broke as soon as a hop was
// still inside India, which — since the anchor and its first few neighbours are almost always
// still inside India near the border — killed every trace after one hop, before it ever
// actually reached the crossing. That's why every river came back empty.)
function traceChain(graph, start, direction) {
  const chain = [];
  const visited = new Set();
  let current = start;

  for (let hop = 0; hop < MAX_HOPS && current; hop++) {
    if (visited.has(current.hyrivId)) break; // guards against any cyclic NEXT_DOWN data
    visited.add(current.hyrivId);
    if (!insideCorridor(current.midpoint)) break;

    chain.push(current);

    if (direction === 'down') {
      current = current.nextDown ? graph.byHyrivId.get(current.nextDown) : null;
    } else {
      const candidates = graph.upstreamOf.get(current.hyrivId) ?? [];
      current = candidates.length ? candidates.reduce((a, b) => (b.ordStra > a.ordStra ? b : a)) : null;
    }
  }
  return chain;
}

function run() {
  if (!fs.existsSync(HYDRORIVERS_SHP)) {
    console.error(`Missing ${HYDRORIVERS_SHP} — same file joinHydroRivers.js needs. Place it first.`);
    process.exit(1);
  }
  if (!fs.existsSync(RIVERS_BY_ID_DIR)) {
    console.error(
      `Missing ${RIVERS_BY_ID_DIR}/ — this is written by scripts/prepareRivers.js. Run that first ` +
        `(build/ is gitignored, so it won't exist unless you've run the pipeline in this checkout).`
    );
    process.exit(1);
  }
  if (!fs.existsSync(CORRIDOR_CLIP)) {
    clipToCorridor();
  } else {
    console.log(`==> Reusing existing ${CORRIDOR_CLIP} (delete it to force re-clip)`);
  }

  const hydroData = JSON.parse(fs.readFileSync(CORRIDOR_CLIP, 'utf-8'));
  console.log(`HydroRIVERS reaches in corridor: ${hydroData.features.length}`);
  const sampleProps = hydroData.features[0]?.properties ?? {};
  if (!('HYRIV_ID' in sampleProps) || !('NEXT_DOWN' in sampleProps)) {
    console.error('HYRIV_ID/NEXT_DOWN not found on features. Available fields:', Object.keys(sampleProps));
    process.exit(1);
  }
  const graph = buildReachGraph(hydroData);
  const indiaStates = loadIndiaStates();

  const riversIndex = JSON.parse(fs.readFileSync(RIVERS_INDEX, 'utf-8'));
  const transnational = riversIndex.filter((r) => r.transnational);

  const contextFeatures = [];
  const report = [];

  for (const river of transnational) {
    const byIdPath = `${RIVERS_BY_ID_DIR}/${river.id}.geojson`;
    if (!fs.existsSync(byIdPath)) {
      report.push({ id: river.id, status: 'no india geometry — skipped' });
      continue;
    }
    const indiaFeature = JSON.parse(fs.readFileSync(byIdPath, 'utf-8')).features[0];
    const candidatePoints = endpoints(indiaFeature.geometry);

    const chains = [];
    const misses = [];
    for (const point of candidatePoints) {
      const { reach, closestDistKm } = nearestReach(graph, point);
      if (!reach) {
        misses.push(Math.round(closestDistKm * 10) / 10);
        continue;
      }
      const traced = [...traceChain(graph, reach, 'down'), ...traceChain(graph, reach, 'up')];
      // Trim to the reaches actually outside India — the walk includes the interior stretch
      // between the anchor and the border, which is redundant with the existing India-portion
      // geometry (already rendered by the interactive rivers-line pmtiles layer).
      const outside = traced.filter((r) => !insideIndia(r.midpoint, indiaStates));
      if (outside.length) chains.push(...outside.map((r) => r.coords));
    }

    if (!chains.length) {
      report.push({
        id: river.id,
        status: 'no cross-border chain found',
        closestMissesKm: misses.length ? misses : undefined,
      });
      continue;
    }

    contextFeatures.push({
      type: 'Feature',
      properties: { river_id: river.id, countries: river.transnational_countries ?? [] },
      geometry: { type: 'MultiLineString', coordinates: chains },
    });
    report.push({ id: river.id, status: 'ok', segments: chains.length });
  }

  fs.writeFileSync(OUT_CONTEXT, JSON.stringify({ type: 'FeatureCollection', features: contextFeatures }));
  fs.writeFileSync(OUT_REPORT, JSON.stringify(report, null, 2));

  const counts = new Map();
  for (const r of report) counts.set(r.status, (counts.get(r.status) ?? 0) + 1);
  console.log('\nBreakdown:');
  for (const [status, n] of counts) console.log(`  ${n}x ${status}`);
  if (counts.has('no cross-border chain found')) {
    const misses = report.filter((r) => r.status === 'no cross-border chain found' && r.closestMissesKm);
    if (misses.length) {
      console.log('\nClosest-miss distances (km) for rivers with no match — if these are all just');
      console.log('over 3km, raise MATCH_TOLERANCE_KM; if they\'re huge (100+), the grid/graph itself');
      console.log('isn\'t finding real nearby reaches and needs a closer look:');
      misses.forEach((m) => console.log(`  ${m.id}: ${m.closestMissesKm.join(', ')}`));
    }
  }

  const ok = report.filter((r) => r.status === 'ok').length;
  console.log(`\n${ok}/${transnational.length} transnational rivers extended — see ${OUT_REPORT} for the rest.`);
}

run();
