// Rebuilds public/tiles/rivers.pmtiles with new rivers appended, at full maxzoom (z14) fidelity.
// Re-extracts the 88 EXISTING rivers losslessly from the current pmtiles by scanning each river's
// own bbox (from rivers-index.json) at z14 — not the whole-India grid, which would be ~1.4M tiles
// to probe at z14; per-river bbox scoping keeps each scan small while still hitting full maxzoom.
// Preserves the existing numeric vector-tile feature ids (rivers-id-map.json) byte-for-byte; new
// rivers get fresh sequential ids appended after the current max.
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import { PMTiles } from 'pmtiles';
import { VectorTile } from '@mapbox/vector-tile';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { PbfReader: Protobuf } = require('pbf');

class NodeFileSource {
  constructor(path) {
    this.path = path;
    this.fd = fs.openSync(path, 'r');
  }
  getKey() {
    return this.path;
  }
  async getBytes(offset, length) {
    const buf = Buffer.alloc(length);
    fs.readSync(this.fd, buf, 0, length, offset);
    return { data: buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) };
  }
}

const EXTRACT_ZOOM = 14;

function lonToTileX(lon, z) {
  return Math.floor(((lon + 180) / 360) * 2 ** z);
}
function latToTileY(lat, z) {
  const rad = (lat * Math.PI) / 180;
  return Math.floor(((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) * 2 ** z);
}

async function extractRiverAtBbox(p, z, [minLon, minLat, maxLon, maxLat]) {
  // pad by 1 tile so a river's line isn't clipped right at its own bbox edge
  const xMin = lonToTileX(minLon, z) - 1;
  const xMax = lonToTileX(maxLon, z) + 1;
  const yMin = latToTileY(maxLat, z) - 1;
  const yMax = latToTileY(minLat, z) + 1;

  const segmentsById = new Map();
  for (let x = xMin; x <= xMax; x++) {
    for (let y = yMin; y <= yMax; y++) {
      const tile = await p.getZxy(z, x, y);
      if (!tile) continue;
      const vt = new VectorTile(new Protobuf(tile.data));
      const layer = vt.layers['rivers'];
      if (!layer) continue;
      for (let i = 0; i < layer.length; i++) {
        const feat = layer.feature(i);
        const strId = feat.properties.id;
        const numId = feat.id;
        if (strId === undefined || numId === undefined) continue;
        const geo = feat.toGeoJSON(x, y, z);
        const coordsList =
          geo.geometry.type === 'LineString'
            ? [geo.geometry.coordinates]
            : geo.geometry.type === 'MultiLineString'
              ? geo.geometry.coordinates
              : [];
        for (const c of coordsList) {
          if (!segmentsById.has(strId)) segmentsById.set(strId, { numId, strOrder: feat.properties.stream_order, segments: [] });
          segmentsById.get(strId).segments.push(c);
        }
      }
    }
  }
  return segmentsById;
}

async function run() {
  const source = new NodeFileSource('public/tiles/rivers.pmtiles');
  const p = new PMTiles(source);
  const header = await p.getHeader();
  const z = Math.min(EXTRACT_ZOOM, header.maxZoom);

  const riversIndex = JSON.parse(fs.readFileSync('public/data/rivers-index.json', 'utf-8'));
  const idMap = JSON.parse(fs.readFileSync('public/data/rivers-id-map.json', 'utf-8'));
  const existingIds = new Set(Object.keys(idMap));

  const NEW_RIVER_IDS = ['bagmati', 'tamiraparani', 'vaitarna'];
  const existingRivers = riversIndex.filter((r) => !NEW_RIVER_IDS.includes(r.id));
  const newRivers = riversIndex.filter((r) => NEW_RIVER_IDS.includes(r.id));

  if (existingRivers.length !== existingIds.size) {
    throw new Error(`existing river count mismatch: index has ${existingRivers.length}, id-map has ${existingIds.size}`);
  }

  const features = [];
  const finalIdMap = {};

  console.log(`Re-extracting ${existingRivers.length} existing rivers at z${z} (per-river bbox)...`);
  let done = 0;
  for (const river of existingRivers) {
    const found = await extractRiverAtBbox(p, z, river.bounds);
    const entry = found.get(river.id);
    if (!entry) throw new Error(`river "${river.id}" not found in re-extraction — bbox or id mismatch`);
    const expectedNumId = idMap[river.id][0];
    if (entry.numId !== expectedNumId) {
      throw new Error(`river "${river.id}" numeric id mismatch: expected ${expectedNumId}, got ${entry.numId}`);
    }
    features.push({
      type: 'Feature',
      id: entry.numId,
      properties: { id: river.id, stream_order: entry.strOrder },
      geometry:
        entry.segments.length === 1
          ? { type: 'LineString', coordinates: entry.segments[0] }
          : { type: 'MultiLineString', coordinates: entry.segments },
    });
    finalIdMap[river.id] = [entry.numId];
    done++;
    if (done % 20 === 0) console.log(`  ${done}/${existingRivers.length}`);
  }

  let nextId = Math.max(...Object.values(idMap).flat()) + 1;
  console.log(`Appending ${newRivers.length} new rivers starting at id ${nextId}...`);
  for (const river of newRivers) {
    // shipped geometry = India-portion trace coords, produced during tracing (scripts_tmp/*.json)
    const traceOut = JSON.parse(fs.readFileSync(`/tmp/${river.id}.json`, 'utf-8'));
    const numId = nextId++;
    features.push({
      type: 'Feature',
      id: numId,
      properties: { id: river.id, stream_order: river.stream_order },
      geometry: { type: 'LineString', coordinates: traceOut.indiaCoords },
    });
    finalIdMap[river.id] = [numId];
  }

  fs.mkdirSync('build', { recursive: true });
  fs.writeFileSync('build/rivers-prepared-v4.geojson', features.map((f) => JSON.stringify(f)).join('\n'));
  fs.writeFileSync('public/data/rivers-id-map.json', JSON.stringify(finalIdMap, null, 2) + '\n');

  console.log('Running tippecanoe...');
  execSync(
    `tippecanoe --output=build/rivers-v4.pmtiles --layer=rivers --minimum-zoom=4 --maximum-zoom=14 --drop-smallest-as-needed --include=id --include=stream_order --name="India Rivers" --attribution="OpenStreetMap contributors" --force build/rivers-prepared-v4.geojson`,
    { stdio: 'inherit' }
  );
  fs.copyFileSync('build/rivers-v4.pmtiles', 'public/tiles/rivers.pmtiles');
  console.log('Wrote public/tiles/rivers.pmtiles');
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
