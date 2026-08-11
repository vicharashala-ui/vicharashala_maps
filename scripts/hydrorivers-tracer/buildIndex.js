// One-off: parse the clipped HydroRIVERS geojson into a compact network index
// held in memory for scripts_wip/trace.js to require() via a shared cache file.
import fs from 'node:fs';

const SRC = 'build/hydrorivers-india-clip.geojson';
const OUT = 'build/hydrorivers-network.json';

console.log('Reading', SRC);
const raw = fs.readFileSync(SRC, 'utf8');
console.log('Parsing JSON (', (raw.length / 1e6).toFixed(0), 'MB )');
const d = JSON.parse(raw);

const reaches = {};
for (const f of d.features) {
  const p = f.properties;
  const g = f.geometry;
  const coords = g.type === 'MultiLineString' ? g.coordinates[0] : g.coordinates;
  reaches[p.HYRIV_ID] = {
    next: p.NEXT_DOWN,
    len: p.LENGTH_KM,
    ord: p.ORD_STRA,
    main: p.MAIN_RIV,
    upland: p.UPLAND_SKM, // upstream catchment area — used to pick the main-stem branch at forks
    coords: coords.map(([lng, lat]) => [Math.round(lng * 1e5) / 1e5, Math.round(lat * 1e5) / 1e5]),
  };
}

console.log('Reaches:', Object.keys(reaches).length);
fs.writeFileSync(OUT, JSON.stringify(reaches));
console.log('Wrote', OUT, (fs.statSync(OUT).size / 1e6).toFixed(0), 'MB');
