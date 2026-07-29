// scripts/processRiversShapefile.js
// Input:  build/raw/rivers-shp/Rivers.{shp,dbf,shx,prj,cpg,sbn,sbx}
//         (data.gov.in "Rivers" shapefile — place the downloaded files there)
// Output: build/rivers-govt-matched.geojson (matched geometry, WGS84, canonical names)
//         build/rivers-govt-metadata.json (partial rivers-index.json seed: basin/origin/length)
//         build/rivers-govt-report.json (match/no-match/needs-verification summary)
//
// IMPORTANT CAVEAT (also in the report): 38 of 110 source features are MultiLineString —
// the govt shapefile digitizes delta/braided channels as separate line parts under one
// river name, and its `shape_Leng` field sums ALL parts. For those rivers this inflates
// length well past the commonly-cited figure (e.g. this file's Ganga = 3096 km vs the
// ~2525 km usually cited — the difference is delta distributary channels, not mainstem
// length). length_km_india is only auto-filled for single-part (LineString) rivers; the
// MultiLineString ones are left null with needs_verification: true — do not fill these from
// shape_Leng without cross-checking a real source (CWC/India-WRIS).

import fs from 'node:fs';
import { execSync } from 'node:child_process';

const SHP_DIR = 'build/raw/rivers-shp';
const GEOJSON_TMP = 'build/rivers-govt-raw.geojson';

const RIVER_NAMES = [
  'Indus', 'Jhelum', 'Chenab', 'Ravi', 'Beas', 'Sutlej', 'Spiti', 'Zanskar', 'Shyok',
  'Ganga', 'Bhagirathi', 'Alaknanda', 'Yamuna', 'Chambal', 'Betwa', 'Ken', 'Son', 'Gomti',
  'Ghaghra', 'Sarda', 'Gandak', 'Burhi Gandak', 'Kosi', 'Mahananda', 'Mechi', 'Kamla',
  'Bagmati', 'Damodar', 'Hooghly', 'Barakar', 'Ajay', 'Rupnarayan',
  'Brahmaputra', 'Dibang', 'Lohit', 'Subansiri', 'Kameng', 'Dhansiri', 'Manas', 'Sankosh',
  'Teesta', 'Rangeet', 'Torsa', 'Jaldhaka', 'Barak', 'Kopili', 'Kapili',
  'Mahanadi', 'Brahmani', 'Baitarani', 'Subarnarekha', 'Rushikulya', 'Vamsadhara', 'Nagavali',
  'Godavari', 'Krishna', 'Tungabhadra', 'Bhima', 'Musi', 'Manjira', 'Indravati', 'Pranhita',
  'Wainganga', 'Wardha', 'Kaveri', 'Amaravathi', 'Kabini', 'Hemavathi', 'Shimsha', 'Arkavathi',
  'Bhavani', 'Palar', 'Ponnaiyar', 'Vellar', 'Vaigai', 'Tamiraparani',
  'Narmada', 'Tapi', 'Mahi', 'Sabarmati', 'Periyar', 'Chaliyar', 'Bharathapuzha', 'Pamba',
  'Kallada', 'Sharavati', 'Zuari', 'Mandovi', 'Purna', 'Girna',
  'Ulhas', 'Vaitarna', 'Savitri', 'Vashisthi', 'Kali', 'Netravati', 'Gurupur', 'Aghanashini',
  'Damanganga', 'Swarnamukhi', 'Manimuktha', 'Vaippar',
  'Luni', 'Ghaggar', 'Hakra',
];

// canonical spec spelling -> spelling used in the govt shapefile's `rivname` field
const VARIANT_MAP = {
  Sutlej: 'Satluj', Gomti: 'Gomati', Ghaghra: 'Ghaghara', Son: 'Sone',
  Pranhita: 'Pranhitha', Kaveri: 'Cauvery', Kali: 'Kalinadi', Ghaggar: 'Ghagghar',
  Bharathapuzha: 'Bharathapuzha/Ponnani', Lohit: 'Lohit/ Tellu',
};

function run() {
  console.log('==> Converting shapefile to WGS84 GeoJSON via mapshaper');
  execSync(
    `pnpm exec mapshaper "${SHP_DIR}/Rivers.shp" -proj wgs84 -o "${GEOJSON_TMP}" format=geojson`,
    { stdio: 'inherit' }
  );

  const raw = JSON.parse(fs.readFileSync(GEOJSON_TMP, 'utf-8'));
  const byShapefileName = new Map();
  for (const f of raw.features) {
    byShapefileName.set(f.properties.rivname, f);
  }

  const matchedFeatures = [];
  const metadata = [];
  const report = { matched: [], unmatched: [], needsVerification: [] };

  for (const canonicalName of RIVER_NAMES) {
    const shpName = VARIANT_MAP[canonicalName] ?? canonicalName;
    const feature = byShapefileName.get(shpName);
    if (!feature) {
      report.unmatched.push(canonicalName);
      continue;
    }

    const p = feature.properties;
    const isMultiPart = feature.geometry.type === 'MultiLineString';
    const lengthKm = Math.round((p.shape_Leng / 1000) * 10) / 10;

    feature.properties = { id: null, name: canonicalName }; // id assigned in a later step
    matchedFeatures.push(feature);

    metadata.push({
      name: canonicalName,
      basin: p.ba_name || null,
      sub_basin: p.sub_basin || null,
      origin_description: p.origin || null,
      length_km_india: isMultiPart ? null : lengthKm,
      length_source: 'data.gov.in Rivers shapefile',
      needs_verification: isMultiPart,
    });

    report.matched.push(canonicalName);
    if (isMultiPart) report.needsVerification.push({ name: canonicalName, summedLengthKm: lengthKm });
  }

  fs.writeFileSync(
    'build/rivers-govt-matched.geojson',
    JSON.stringify({ type: 'FeatureCollection', features: matchedFeatures })
  );
  fs.writeFileSync('build/rivers-govt-metadata.json', JSON.stringify(metadata, null, 2));
  fs.writeFileSync('build/rivers-govt-report.json', JSON.stringify(report, null, 2));

  console.log(`\nMatched: ${report.matched.length}/${RIVER_NAMES.length}`);
  console.log(`Unmatched (still need Overpass + research): ${report.unmatched.length}`);
  console.log(`Matched but length needs verification (multi-part delta/braid sum): ${report.needsVerification.length}`);
}

run();
