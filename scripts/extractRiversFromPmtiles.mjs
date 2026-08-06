// One-off: reconstructs build/rivers-by-id/{id}.geojson from public/tiles/rivers.pmtiles,
// since the original build/ intermediates (govt shapefile, Overpass merge, HydroRIVERS clip)
// aren't available in this environment. rivers.pmtiles is the committed, already-built output
// of that pipeline, so decoding it back to GeoJSON is a faithful substitute for spatialIntersect.js's
// geometry input — same coordinates, sourced from the exact file the site ships.
import fs from 'node:fs';
import { PMTiles } from 'pmtiles';

// pmtiles' built-in FileSource expects a browser File; this is a minimal node fd-backed source.
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
import { VectorTile } from '@mapbox/vector-tile';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { PbfReader: Protobuf } = require('pbf');

const OUT_DIR = 'build/rivers-by-id';
// Extraction zoom: full maxzoom (14) means iterating ~2M grid cells over India's bbox, far too
// slow for a one-off reconstruction. z11 keeps river paths detailed enough for PA-intersection
// (tile edge ~19km) while keeping the grid to a tractable ~30k cells.
const EXTRACT_ZOOM = 11;

function lonToTileX(lon, z) {
  return Math.floor(((lon + 180) / 360) * 2 ** z);
}
function latToTileY(lat, z) {
  const rad = (lat * Math.PI) / 180;
  return Math.floor(((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) * 2 ** z);
}

function mergeCoordsById(acc, id, coords) {
  if (!acc.has(id)) acc.set(id, []);
  acc.get(id).push(coords);
}

async function run() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const source = new NodeFileSource('public/tiles/rivers.pmtiles');
  const p = new PMTiles(source);
  const header = await p.getHeader();
  console.log('zoom range', header.minZoom, header.maxZoom);

  const lineStringsById = new Map();

  const z = Math.min(EXTRACT_ZOOM, header.maxZoom);
  const xMin = lonToTileX(header.minLon, z);
  const xMax = lonToTileX(header.maxLon, z);
  const yMin = latToTileY(header.maxLat, z); // max lat -> min y
  const yMax = latToTileY(header.minLat, z); // min lat -> max y
  const total = (xMax - xMin + 1) * (yMax - yMin + 1);
  console.log(`zoom ${z}: x[${xMin},${xMax}] y[${yMin},${yMax}] = ${total} tiles to probe`);

  let probed = 0;
  for (let x = xMin; x <= xMax; x++) {
    for (let y = yMin; y <= yMax; y++) {
      probed++;
      const tile = await p.getZxy(z, x, y);
      if (!tile) continue;
      const vt = new VectorTile(new Protobuf(tile.data));
      const layer = vt.layers['rivers'];
      if (!layer) continue;
      for (let i = 0; i < layer.length; i++) {
        const feat = layer.feature(i);
        const id = feat.properties.id;
        if (id === undefined) continue;
        const geo = feat.toGeoJSON(x, y, z);
        const coordsList = geo.geometry.type === 'LineString'
          ? [geo.geometry.coordinates]
          : geo.geometry.type === 'MultiLineString'
            ? geo.geometry.coordinates
            : [];
        for (const c of coordsList) mergeCoordsById(lineStringsById, id, c);
      }
    }
    if (x % 20 === 0) console.log(`  probed ${probed}/${total}...`);
  }

  let written = 0;
  for (const [id, segments] of lineStringsById) {
    const feature = {
      type: 'Feature',
      properties: { id },
      geometry: segments.length === 1
        ? { type: 'LineString', coordinates: segments[0] }
        : { type: 'MultiLineString', coordinates: segments },
    };
    fs.writeFileSync(`${OUT_DIR}/${id}.geojson`, JSON.stringify({ type: 'FeatureCollection', features: [feature] }));
    written++;
  }
  console.log(`Wrote ${written} river files to ${OUT_DIR}`);
}

run();
