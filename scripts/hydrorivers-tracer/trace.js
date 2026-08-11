// Traces one named river through HydroRIVERS by walking NEXT_DOWN from the reach
// nearest a known source point to the reach nearest a known mouth/confluence point.
// HydroRIVERS carries no river names, so this is the only way to isolate a single
// river's course from the reach network without OSM/govt-shapefile coverage.
import fs from 'node:fs';

const network = JSON.parse(fs.readFileSync('build/hydrorivers-network.json', 'utf8'));

const GRID_DEG = 0.05; // ~5.5km cells — coarser than joinHydroRivers.js's 0.02, this is a point-nearest search not a broad-phase filter
const startGrid = new Map(); // keyed by reach START coord (headwater/waypoint candidates)

function key(lng, lat) {
  return `${Math.floor(lng / GRID_DEG)}_${Math.floor(lat / GRID_DEG)}`;
}
function addToGrid(grid, lng, lat, id) {
  const k = key(lng, lat);
  if (!grid.has(k)) grid.set(k, []);
  grid.get(k).push(id);
}

for (const id in network) {
  const r = network[id];
  const [slng, slat] = r.coords[0];
  addToGrid(startGrid, slng, slat, id);
}

function haversineKm(lng1, lat1, lng2, lat2) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

// Waypoint anchoring needs a different heuristic than pure nearest-vertex: in flat floodplain
// terrain especially, a tiny disconnected field-drain fragment (upland ~10 km²) is very often
// closer to a query point than the actual named river's own channel passing nearby. Since a
// waypoint is always a place known to sit ON a real, substantial named river, among all
// candidates within radiusKm we pick the one with the largest upstream catchment (upland) —
// not the closest one — which reliably rejects these tiny false-positive fragments.
function nearestOnSubstantialChannel(grid, lng, lat, coordPicker, radiusKm = 15) {
  const cellRadius = Math.ceil(radiusKm / (GRID_DEG * 111)) + 1;
  const cx = Math.floor(lng / GRID_DEG);
  const cy = Math.floor(lat / GRID_DEG);
  let best = null;
  let bestUpland = -1;
  let bestDist = null;
  for (let dx = -cellRadius; dx <= cellRadius; dx++) {
    for (let dy = -cellRadius; dy <= cellRadius; dy++) {
      const ids = grid.get(`${cx + dx}_${cy + dy}`);
      if (!ids) continue;
      for (const id of ids) {
        const [clng, clat] = coordPicker(network[id]);
        const dist = haversineKm(lng, lat, clng, clat);
        if (dist > radiusKm) continue;
        const upland = network[id].upland ?? 0;
        if (upland > bestUpland) {
          bestUpland = upland;
          best = id;
          bestDist = dist;
        }
      }
    }
  }
  return best ? { id: best, distKm: bestDist, upland: bestUpland } : null;
}

// Reverse adjacency (nextDown -> incoming reach ids), built once, needed for upstream walk.
const upstreamOf = new Map();
for (const id in network) {
  const nx = network[id].next;
  if (nx && nx !== 0) {
    const key = String(nx); // NEXT_DOWN parses as a number; object keys from `for..in` are strings — normalize both sides
    if (!upstreamOf.has(key)) upstreamOf.set(key, []);
    upstreamOf.get(key).push(id);
  }
}

function stitch(path) {
  const coords = [];
  for (const id of path) {
    const c = network[id].coords;
    if (coords.length && coords[coords.length - 1][0] === c[0][0] && coords[coords.length - 1][1] === c[0][1]) {
      coords.push(...c.slice(1));
    } else {
      coords.push(...c);
    }
  }
  return coords;
}

/**
 * Anchors on a single unambiguous MID-RIVER waypoint — a town/village clearly on the named
 * river's own channel, away from both headwater divides (ambiguous — two valleys can share a
 * pass) and confluences (ambiguous for a tributary — the larger river being joined always has
 * more upstream catchment area, so a naive max-upland branch choice AT the confluence would
 * incorrectly follow the bigger river, not climb the tributary itself). Starting mid-channel
 * needs no branch decision at the confluence (we walk TO it downstream, already knowing which
 * reach we're on) and no branch decision at the source divide either, since forks encountered
 * while climbing are between the target river's own sub-tributaries, where max-upland (largest
 * contributing catchment = conventional main stem) is the correct rule.
 *
 * @param {[number,number]} waypointPt [lng, lat] — any unambiguous point clearly on the river's own channel
 * @param {[number,number]} mouthPt [lng, lat] — confluence with a larger river, or sea mouth
 * @param {object} opts
 * @param {number} opts.mouthToleranceKm - how close a reach END must be to mouthPt to count as arrival
 * @param {number} opts.minUpstreamAreaSkm - stop climbing once the best branch's catchment drops below this
 */
export function traceRiver(waypointPt, mouthPt, opts = {}) {
  const mouthToleranceKm = opts.mouthToleranceKm ?? 6;
  const minUpstreamAreaSkm = opts.minUpstreamAreaSkm ?? 0;

  const anchor = nearestOnSubstantialChannel(startGrid, waypointPt[0], waypointPt[1], (r) => r.coords[0]);
  if (!anchor) return { ok: false, reason: 'no reach found near waypoint' };

  // downstream walk from waypoint to mouth
  const downPath = [];
  let current = anchor.id;
  let downStop = null;
  for (let i = 0; i < 2000; i++) {
    const r = network[current];
    if (!r) {
      downStop = 'next_down reach missing from clipped network (crosses India border)';
      break;
    }
    downPath.push(current);
    // Primary stop condition: a confluence with a much larger river shows up as a huge single-step
    // jump in upstream catchment area — far sharper and more reliable than distance-to-mouth-point,
    // which can overshoot by exactly one reach onto the larger river's own channel (that reach's
    // end coordinate often still lands within tolerance of the named confluence point, since it's
    // the same location — silently inflating length/order with a foreign river's downstream reach).
    const nextReach = r.next && r.next !== 0 ? network[r.next] : null;
    if (nextReach && (nextReach.upland ?? 0) > (r.upland ?? 0) * 3 && (nextReach.upland ?? 0) - (r.upland ?? 0) > 500) {
      downStop = 'next reach belongs to a much larger river (confluence) — stopped before crossing onto it';
      break;
    }
    const [elng, elat] = r.coords[r.coords.length - 1];
    if (haversineKm(elng, elat, mouthPt[0], mouthPt[1]) <= mouthToleranceKm) {
      downStop = 'reached mouth point';
      break;
    }
    if (!r.next || r.next === 0) {
      downStop = 'next_down = 0 (terminal reach — sea or endorheic sink)';
      break;
    }
    current = r.next;
  }

  // upstream main-stem climb from the waypoint anchor
  const upPath = [];
  let node = anchor.id;
  let climbSteps = 0;
  while (climbSteps < 5000) {
    const incoming = upstreamOf.get(String(node));
    if (!incoming || incoming.length === 0) break;
    let best = incoming[0];
    for (const cand of incoming) {
      if ((network[cand].upland ?? 0) > (network[best].upland ?? 0)) best = cand;
    }
    if ((network[best].upland ?? 0) < minUpstreamAreaSkm) break;
    upPath.push(best);
    node = best;
    climbSteps++;
  }
  upPath.reverse();

  const fullPath = [...upPath, ...downPath];
  const coords = stitch(fullPath);
  const totalLenKm = fullPath.reduce((sum, id) => sum + network[id].len, 0);
  const maxOrd = fullPath.reduce((m, id) => Math.max(m, network[id].ord), 0);
  const headReach = fullPath[0];
  const [hLng, hLat] = network[headReach].coords[0];
  const tailReach = fullPath[fullPath.length - 1];
  const tailCoords = network[tailReach].coords;
  const [tLng, tLat] = tailCoords[tailCoords.length - 1];

  return {
    ok: true,
    anchorWaypointDistKm: Math.round(anchor.distKm * 10) / 10,
    downstreamStopReason: downStop,
    finalMouthDistKm: Math.round(haversineKm(tLng, tLat, mouthPt[0], mouthPt[1]) * 10) / 10,
    upstreamReachCount: upPath.length,
    downstreamReachCount: downPath.length,
    totalLenKm: Math.round(totalLenKm * 10) / 10,
    strahlerOrder: maxOrd,
    headwaterPt: [hLng, hLat],
    coords,
    reachIds: fullPath,
  };
}
