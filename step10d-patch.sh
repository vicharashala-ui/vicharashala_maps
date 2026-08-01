#!/usr/bin/env bash
set -euo pipefail

# Step 10d — fixes the real bug: osmtogeojson@2.2.12 (the version pinned in this
# project) nests tags under properties.tags.{key}, not flattened onto properties
# directly. The matcher was reading properties.name (always undefined), so every
# batch matched 0 rivers even though Overpass itself had already filtered correctly
# server-side. Fixed to read properties.tags.name. Verified directly against your
# real Purna sample (5/5 matched) and against a full mock run using the exact pinned
# osmtogeojson version (my earlier "passing" tests used a different, newer version
# that happens to flatten tags by default — that mismatch is why it looked fine before).
# Removes the diagnostic dump from Step 10c, no longer needed.

cat > scripts/fetchRivers.js << 'FETCH_EOF'
// scripts/fetchRivers.js
// Input:  none (queries OSM Overpass API directly)
// Output: build/rivers-overpass.geojson (spec §4.7 step ⑥, rescoped to the 43 rivers
//         Step 9 couldn't recover from the govt shapefile)
//         build/rivers-overpass-report.json (matched/unmatched + multi-candidate flags)
//
// v2 — the v1 script (single query, country-wide `area["ISO3166-1"="IN"]`) 406'd then
// 504'd. The `area` lookup makes Overpass compute the whole country polygon before it can
// even start filtering, which is slow regardless of query complexity — this version uses a
// bbox per region instead, and batches by region so one timeout only costs that batch, not
// everything. VERIFIED REACHABLE from the target machine (curl -> 200), but this exact
// script has not been run against live Overpass — run it and report back what happens,
// same as every prior data-pipeline script, just verified end-to-end first.
//
// waterway~"river|stream" (not just "river") — several of these are minor enough that OSM
// may tag them as streams, not rivers; the v1 script only checked "river" and never revisited it.
//
// KNOWN MULTI-CANDIDATE RIVERS (see report.multiCandidate after running): Vellar (Tamil Nadu
// has two), Purna (multiple Purnas in India, need the Tapi tributary specifically — Godavari
// basin one already ruled out in Step 9), Sarda/Sharda (also appears as "Kali" in some OSM
// data — do not blindly take the first match). If a batch returns >1 way for one of these
// names, this script keeps all of them and flags it in the report — resolve by checking each
// candidate's coordinates against the batch's states before merging into rivers-index.

import fs from 'node:fs';

const OVERPASS_ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];
const TIMEOUT_S = 60; // per batch, not per name — batches are small now, shouldn't need 180s
const OUT_GEOJSON = 'build/rivers-overpass.geojson';
const OUT_REPORT = 'build/rivers-overpass-report.json';

// canonical draft name -> OSM name(s) to search for. Parenthetical qualifiers in the draft
// (e.g. "Sarda (Sharda)") aren't OSM tag values — split into real name variants here.
const BATCHES = [
  {
    region: 'indus_himalaya',
    bbox: [30, 73, 36, 80], // south, west, north, east — J&K, Ladakh, HP, Punjab
    rivers: { Jhelum: ['Jhelum'], Ravi: ['Ravi'], Spiti: ['Spiti'], Zanskar: ['Zanskar'], Shyok: ['Shyok'] },
  },
  {
    region: 'ganga_upper',
    bbox: [22, 74, 31, 82], // MP, Rajasthan, UP-west, Uttarakhand
    rivers: { 'Kali Sindh': ['Kali Sindh'], Ken: ['Ken'], 'Sarda (Sharda)': ['Sarda', 'Sharda'] },
  },
  {
    region: 'ganga_bihar_plains',
    bbox: [24, 84, 28, 89], // Bihar, north WB, Nepal border — densest-mapped river network in the batch set, smallest bbox on purpose
    rivers: {
      'Burhi Gandak': ['Burhi Gandak', 'Budhi Gandak'], Kosi: ['Kosi', 'Koshi'],
      Mahananda: ['Mahananda'], Mechi: ['Mechi'], Kamla: ['Kamla', 'Kamla Balan'],
      Bagmati: ['Bagmati'], Rupnarayan: ['Rupnarayan', 'Rupnarayana'],
    },
  },
  {
    region: 'brahmaputra_ne',
    bbox: [24, 88, 29.5, 98], // Arunachal, Nagaland, Assam, Sikkim, north WB
    rivers: {
      Dibang: ['Dibang'], Dhansiri: ['Dhansiri'], Manas: ['Manas'], Sankosh: ['Sankosh'],
      Rangeet: ['Rangeet', 'Rangit'],
    },
  },
  {
    region: 'kaveri_south_tn',
    bbox: [8, 76, 20, 87], // Odisha, Karnataka, Kerala, Tamil Nadu
    rivers: {
      Rushikulya: ['Rushikulya'], Amaravathi: ['Amaravathi', 'Amaravati'], Kabini: ['Kabini', 'Kabbani'],
      Hemavathi: ['Hemavathi', 'Hemavati'], Shimsha: ['Shimsha'], Arkavathi: ['Arkavathi', 'Arkavati'],
      Bhavani: ['Bhavani'], 'Vellar (Southern)': ['Vellar'], Tamiraparani: ['Tamiraparani', 'Thamirabarani'],
      Manimuktha: ['Manimuktha', 'Manimuktha Nadhi'],
    },
  },
  {
    region: 'kerala_west',
    bbox: [8, 75, 12, 78], // Kerala
    rivers: { Chaliyar: ['Chaliyar'], Pamba: ['Pamba', 'Pampa'] },
  },
  {
    region: 'konkan_goa_tapi',
    bbox: [14, 72, 22, 78], // Goa, coastal Karnataka/Maharashtra, MP/Maharashtra (Tapi basin)
    rivers: {
      Zuari: ['Zuari'], Mandovi: ['Mandovi', 'Mahadayi'], Purna: ['Purna'], Girna: ['Girna'],
      Vaitarna: ['Vaitarna'], Savitri: ['Savitri'], Vashisthi: ['Vashisthi'], Damanganga: ['Damanganga', 'Daman Ganga'],
    },
  },
  {
    region: 'karnataka_andhra_coastal',
    bbox: [13, 74, 16, 80], // coastal Karnataka, coastal Andhra
    rivers: { Gurupur: ['Gurupur'], Aghanashini: ['Aghanashini'], Swarnamukhi: ['Swarnamukhi', 'Swarnamukhi River'] },
  },
];

function buildQuery(bbox, rivers) {
  const allNames = new Set();
  for (const variants of Object.values(rivers)) for (const v of variants) allNames.add(v);
  const escaped = [...allNames].map((n) => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  const pattern = `^(${escaped.join('|')})$`;
  const [s, w, n, e] = bbox;
  return `
[out:json][timeout:${TIMEOUT_S}];
(
  way["waterway"~"^(river|stream)$"]["name"~"${pattern}"](${s},${w},${n},${e});
);
out geom;
`.trim();
}

async function queryOverpass(query) {
  let lastError;
  for (const endpoint of OVERPASS_ENDPOINTS) {
    process.stdout.write(`  querying ${endpoint}... `);
    const controller = new AbortController();
    // client-side backstop — [timeout:${TIMEOUT_S}] in the query only bounds Overpass's own
    // processing time, not the HTTP request. Without this, a stalled connection (no error,
    // no response, just silence) hangs fetch() forever with zero feedback — exactly what
    // happened on the first real run against the mirror endpoint.
    const timer = setTimeout(() => controller.abort(), (TIMEOUT_S + 20) * 1000);
    try {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain', Accept: '*/*', 'User-Agent': 'vicharashala-maps-fetchRivers/2.1' },
        body: query,
        signal: controller.signal,
      });
      clearTimeout(timer);
      if (!res.ok) throw new Error(`${res.status} ${res.statusText}\n${await res.text()}`);
      console.log('ok');
      return await res.json();
    } catch (err) {
      clearTimeout(timer);
      const msg = err.name === 'AbortError' ? `client-side timeout after ${TIMEOUT_S + 20}s (no response at all)` : err.message;
      console.log(`FAILED: ${msg.split('\n')[0]}`);
      lastError = err;
    }
  }
  throw new Error(`All Overpass endpoints failed. Last error: ${lastError.message}`);
}

async function run() {
  const { default: osmtogeojson } = await import('osmtogeojson');
  const allFeatures = [];
  const report = { matched: [], unmatched: [], multiCandidate: [], batchErrors: [] };

  for (const batch of BATCHES) {
    console.log(`\n==> ${batch.region} (${Object.keys(batch.rivers).length} rivers)`);
    let osmData;
    try {
      osmData = await queryOverpass(buildQuery(batch.bbox, batch.rivers));
    } catch (err) {
      console.log(`  BATCH FAILED: ${err.message}`);
      report.batchErrors.push({ region: batch.region, error: err.message, rivers: Object.keys(batch.rivers) });
      continue; // don't lose the other batches over one failure
    }

    const geojson = osmtogeojson(osmData);
    console.log(`  ways returned: ${geojson.features.length}`);

    for (const [canonicalName, variants] of Object.entries(batch.rivers)) {
      const matches = geojson.features.filter((f) => variants.includes(f.properties?.tags?.name));
      if (matches.length === 0) {
        report.unmatched.push(canonicalName);
        continue;
      }
      if (matches.length > 1) {
        report.multiCandidate.push({ name: canonicalName, count: matches.length });
      }
      for (const f of matches) {
        f.properties = { id: null, name: canonicalName, osm_id: f.id };
        allFeatures.push(f);
      }
      report.matched.push(canonicalName);
    }

    // write after every batch — a later batch failing doesn't lose earlier progress
    fs.mkdirSync('build', { recursive: true });
    fs.writeFileSync(OUT_GEOJSON, JSON.stringify({ type: 'FeatureCollection', features: allFeatures }));
    fs.writeFileSync(OUT_REPORT, JSON.stringify(report, null, 2));
  }

  const total = BATCHES.reduce((n, b) => n + Object.keys(b.rivers).length, 0);
  console.log(`\nMatched: ${report.matched.length}/${total}`);
  console.log(`Unmatched: ${report.unmatched.join(', ') || 'none'}`);
  if (report.multiCandidate.length) {
    console.log(`\nMulti-candidate (resolve manually by checking coordinates before merging):`);
    report.multiCandidate.forEach((m) => console.log(`  ${m.name}: ${m.count} candidates`));
  }
  if (report.batchErrors.length) {
    console.log(`\nBATCHES THAT FAILED (nothing lost elsewhere, re-run just these):`);
    report.batchErrors.forEach((b) => console.log(`  ${b.region}: ${b.error.split('\n')[0]}`));
  }
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
FETCH_EOF

node scripts/fetchRivers.js

echo
echo "Check build/rivers-overpass-report.json. The 3 batches that failed with 429/504 before are worth letting run again too."
