#!/usr/bin/env bash
# Step 5b: fixes scripts/fetchRivers.js — overpass-api.de's Apache front-end returns 406
# without an Accept header (Node's fetch sends none by default). Also adds an automatic
# fallback to a mirror endpoint if the primary is down/rate-limited.
# Run from the project root, then: node scripts/fetchRivers.js
set -euo pipefail

if [ ! -f package.json ] || ! grep -q '"name": "vicharashala-maps"' package.json; then
  echo "Run this from the vicharashala-maps project root." >&2
  exit 1
fi

echo "==> Writing scripts/fetchRivers.js (fixed)"
mkdir -p scripts
cat > scripts/fetchRivers.js << 'EOF'
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

// overpass-api.de's Apache front-end 406s requests with no Accept header (Node's fetch
// sends none by default). Fixed below. Mirror kept as an automatic fallback in case the
// primary is rate-limiting or down (Overpass has no SLA on public instances).
const OVERPASS_ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];
const TIMEOUT_S = 180;

// spec §4.9 — ~104 named rivers, grouped by system (grouping is just for readability here,
// not written to output). Parenthetical tributaries in the spec's Chambal entry (Banas, Kali
// Sindh, Parbati) are NOT separate entries — the spec groups them under Chambal.
const RIVER_NAMES = [
  // Indus system
  'Indus', 'Jhelum', 'Chenab', 'Ravi', 'Beas', 'Sutlej', 'Spiti', 'Zanskar', 'Shyok',
  // Ganga system
  'Ganga', 'Bhagirathi', 'Alaknanda', 'Yamuna', 'Chambal', 'Betwa', 'Ken', 'Son', 'Gomti',
  'Ghaghra', 'Sarda', 'Gandak', 'Burhi Gandak', 'Kosi', 'Mahananda', 'Mechi', 'Kamla',
  'Bagmati', 'Damodar', 'Hooghly', 'Barakar', 'Ajay', 'Rupnarayan',
  // Brahmaputra system
  'Brahmaputra', 'Dibang', 'Lohit', 'Subansiri', 'Kameng', 'Dhansiri', 'Manas', 'Sankosh',
  'Teesta', 'Rangeet', 'Torsa', 'Jaldhaka', 'Barak', 'Kopili', 'Kapili',
  // Peninsular — east flowing
  'Mahanadi', 'Brahmani', 'Baitarani', 'Subarnarekha', 'Rushikulya', 'Vamsadhara', 'Nagavali',
  'Godavari', 'Krishna', 'Tungabhadra', 'Bhima', 'Musi', 'Manjira', 'Indravati', 'Pranhita',
  'Wainganga', 'Wardha', 'Kaveri', 'Amaravathi', 'Kabini', 'Hemavathi', 'Shimsha', 'Arkavathi',
  'Bhavani', 'Palar', 'Ponnaiyar', 'Vellar', 'Vaigai', 'Tamiraparani',
  // Peninsular — west flowing
  'Narmada', 'Tapi', 'Mahi', 'Sabarmati', 'Periyar', 'Chaliyar', 'Bharathapuzha', 'Pamba',
  'Kallada', 'Sharavati', 'Zuari', 'Mandovi', 'Purna', 'Girna',
  // Coastal
  'Ulhas', 'Vaitarna', 'Savitri', 'Vashisthi', 'Kali', 'Netravati', 'Gurupur', 'Aghanashini',
  'Damanganga', 'Swarnamukhi', 'Manimuktha', 'Vaippar',
  // Inland drainage
  'Luni', 'Ghaggar', 'Hakra',
];

// OSM tags some of these under an alternate/regional spelling. Extend as fetch results reveal gaps.
const NAME_VARIANTS = {
  Ganga: ['Ganga', 'Ganges'],
  Ghaghra: ['Ghaghra', 'Karnali', 'Ghagra'],
  Sarda: ['Sarda', 'Sharda', 'Kali'], // NOTE: "Kali" also appears as its own coastal-list entry
  // (Kali River, Karnataka) — expect overlap here; reconcile by location after fetch, not by name.
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
  // Escape regex metacharacters, anchor each alternative.
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

async function queryOverpass(query) {
  let lastError;
  for (const endpoint of OVERPASS_ENDPOINTS) {
    try {
      console.log(`Trying ${endpoint} ...`);
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain',
          Accept: '*/*',
          'User-Agent': 'vicharashala-maps-fetchRivers/1.0',
        },
        body: query,
      });
      if (!res.ok) {
        throw new Error(`${res.status} ${res.statusText}\n${await res.text()}`);
      }
      return await res.json();
    } catch (err) {
      console.log(`  failed: ${err.message.split('\n')[0]}`);
      lastError = err;
    }
  }
  throw new Error(`All Overpass endpoints failed. Last error: ${lastError.message}`);
}

async function run() {
  const query = buildQuery();
  console.log(`Querying Overpass for ${RIVER_NAMES.length} river names...`);

  const osmData = await queryOverpass(query);
  console.log(`Ways returned: ${osmData.elements.length}`);

  const { default: osmtogeojson } = await import('osmtogeojson');
  const geojson = osmtogeojson(osmData);

  fs.mkdirSync('build', { recursive: true });
  fs.writeFileSync('build/rivers-raw.geojson', JSON.stringify(geojson));

  // Reconciliation report: which of our ~104 names got zero matches.
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
EOF

echo "==> Committing"
git add -A
git commit -q -m "Step 5b: fix fetchRivers.js 406 (Accept header) + mirror fallback" \
  || echo "Commit skipped (configure 'git config user.name/user.email' then commit manually)."

echo ""
echo "==> Now run: node scripts/fetchRivers.js"
