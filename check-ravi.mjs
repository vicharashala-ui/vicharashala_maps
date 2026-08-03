import * as turf from '@turf/turf';
import fs from 'node:fs';

const f = JSON.parse(fs.readFileSync('build/rivers-by-id/ravi.geojson', 'utf-8')).features[0];
console.log('geometry type:', f.geometry.type);

let badCount = 0;
for (const c of turf.coordAll(f)) {
  const isBad =
    Array.isArray(c) === false ||
    c.length < 2 ||
    c.length > 3 ||
    c.some((n) => typeof n !== 'number' || Number.isFinite(n) === false);
  if (isBad) {
    badCount++;
    console.log('BAD COORD:', JSON.stringify(c));
  }
}
console.log('Total bad coords:', badCount);
console.log('Total coords checked:', turf.coordAll(f).length);
