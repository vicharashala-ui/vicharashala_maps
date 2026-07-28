// scripts/fetchRivers.js
// Input:  none (queries OSM Overpass API directly)
// Output: build/rivers-raw.geojson (spec §4.7 step ⑥)
//
// NOT run/tested from the sandbox — Overpass isn't in the allowed network list there.
// This has to run on your machine. If a name below returns zero matches, it usually means
// OSM tags it under a different spelling — check the "ZERO MATCHES" list this script prints
// at the end and add the variant to NAME_VARIANTS, then re-run.
//
// waterway=river only (not =stream) — matches spec's ~105 *named rivers* scope, not every
// tributary. If a smaller river in the list (e.g. Rangeet, Kapili) comes back empty, it may
// be tagged waterway=stream in OSM; add it to STREAM_NAMES below and re-run.

import fs from 'node:fs';

const OVERPASS_ENDPOINT = 'https://overpass-api.de/api/interpreter';
const TIMEOUT_S = 180;

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

const NAME_VARIANTS = {
  Ganga: ['Ganga', 'Ganges'],
  Ghaghra: ['Ghaghra', 'Karnali', 'Ghagra'],
  Sarda: ['Sarda', 'Sharda', 'Kali'],
  Damanganga: ['Damanganga', 'Daman Ganga'],
  Hooghly: ['Hooghly', 'Hugli'],
  'Burhi Gandak': ['Burhi Gandak', 'Budhi Gandak'],
};

function buildNamePattern() {
  const all = new Set();
  for (const name of RIVER_NAMES) {
    const variants = NAME_VARIANTS[name] ?? [name];
    for (const v of variants) all.add(v);
  }
  const escaped = [...all].map((n) => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  return `^(${escaped.join('|')})$`;
}

function buildQuery() {
  const pattern = buildNamePattern();
  return `
[out:json][timeout:${TIMEOUT_S}];
area["ISO3166-1"="IN"][admin_level=2]->.india;
(
  way["waterway"="river"]["name"~"${pattern}"](area.india);
);
out geom;
`.trim();
}

async function run() {
  const query = buildQuery();
  console.log(`Querying Overpass for ${RIVER_NAMES.length} river names...`);

  const res = await fetch(OVERPASS_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain' },
    body: query,
  });

  if (!res.ok) {
    throw new Error(`Overpass request failed: ${res.status} ${res.statusText}\n${await res.text()}`);
  }

  const osmData = await res.json();
  console.log(`Ways returned: ${osmData.elements.length}`);

  const { default: osmtogeojson } = await import('osmtogeojson');
  const geojson = osmtogeojson(osmData);

  fs.mkdirSync('build', { recursive: true });
  fs.writeFileSync('build/rivers-raw.geojson', JSON.stringify(geojson));

  const matchedNames = new Set(
    geojson.features.map((f) => f.properties?.name).filter(Boolean)
  );
  const zeroMatches = RIVER_NAMES.filter((name) => {
    const variants = NAME_VARIANTS[name] ?? [name];
    return !variants.some((v) => matchedNames.has(v));
  });

  console.log(`\nFeatures written: ${geojson.features.length}`);
  console.log(`River names with at least one match: ${RIVER_NAMES.length - zeroMatches.length}/${RIVER_NAMES.length}`);
  if (zeroMatches.length) {
    console.log(`\nZERO MATCHES (check spelling/tagging in OSM, add to NAME_VARIANTS, re-run):`);
    zeroMatches.forEach((n) => console.log(`  - ${n}`));
  }
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
