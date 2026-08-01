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
// everything.
//
// v3 — v2 tracked a separate `completedBatches` flag instead of deriving "is this region
// done" from the data itself. A region whose query succeeded but whose run ended before that
// flag got persisted (crash, interrupted run, or a run of an older script version) wasn't
// recognized as done next time, got re-queried, and had its matches pushed into the same flat
// arrays again — silently doubling them. Confirmed in the wild: Zanskar/Pamba/Burhi Gandak's
// merged lengths were ~2x their researched length purely from this, not real OSM contamination.
// Fix: never trust a separately-tracked flag. `loadAndMigrate()` below reconstructs, per
// region, whether every one of its configured rivers is already accounted for (matched or
// recorded unmatched) directly from the existing files, deduping any doubled features by
// osm_id along the way. Only regions that are provably incomplete get re-fetched — for the
// data this was built against, that turned out to be zero regions; everything was already
// on disk, just mis-tracked.
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
    rivers: {
      Jhelum: ['Jhelum', 'Vyeth', 'Vitasta', 'Hydaspes'], Ravi: ['Ravi', 'Iravati', 'Purushni'],
      Spiti: ['Spiti'], Zanskar: ['Zanskar'], Shyok: ['Shyok'],
    },
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
      'Burhi Gandak': ['Burhi Gandak', 'Budhi Gandak', 'Sikrahna'], Kosi: ['Kosi', 'Koshi'],
      Mahananda: ['Mahananda'], Mechi: ['Mechi'], Kamla: ['Kamla', 'Kamla Balan', 'Balan'],
      Bagmati: ['Bagmati'], Rupnarayan: ['Rupnarayan', 'Rupnarayana', 'Dwarakeswar', 'Shilabati'],
    },
  },
  {
    region: 'brahmaputra_ne',
    bbox: [24, 88, 29.5, 98], // Arunachal, Nagaland, Assam, Sikkim, north WB
    rivers: {
      Dibang: ['Dibang', 'Talon'], Dhansiri: ['Dhansiri'], Manas: ['Manas', 'Drangme Chhu'],
      Sankosh: ['Sankosh', 'Puna Tsang Chu'], Rangeet: ['Rangeet', 'Rangit'],
    },
  },
  {
    region: 'kaveri_south_tn',
    bbox: [8, 76, 20, 87], // Odisha, Karnataka, Kerala, Tamil Nadu
    rivers: {
      Rushikulya: ['Rushikulya'], Amaravathi: ['Amaravathi', 'Amaravati'], Kabini: ['Kabini', 'Kabbani'],
      Hemavathi: ['Hemavathi', 'Hemavati'], Shimsha: ['Shimsha'], Arkavathi: ['Arkavathi', 'Arkavati'],
      Bhavani: ['Bhavani'], 'Vellar (Southern)': ['Vellar'],
      Tamiraparani: ['Tamiraparani', 'Thamirabarani', 'Tambraparni', 'Porunai'],
      Manimuktha: ['Manimuktha', 'Manimuktha Nadhi'],
    },
  },
  {
    region: 'kerala_west',
    bbox: [8, 75, 12, 78], // Kerala
    rivers: { Chaliyar: ['Chaliyar', 'Beypore River'], Pamba: ['Pamba', 'Pampa'] },
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

const NAME_TO_REGION = new Map(BATCHES.flatMap((b) => Object.keys(b.rivers).map((name) => [name, b.region])));

// Reconstruct featuresByRegion from whatever's already on disk. A region is only kept if
// EVERY one of its configured rivers is accounted for (a deduped matched feature, or a name
// present in the old report's `unmatched` list) — anything less means we can't prove that
// region's fetch actually completed, so it's dropped and re-fetched below rather than trusted.
function regionSignature(batch) {
  return JSON.stringify(batch.rivers);
}

function loadAndMigrate() {
  if (!fs.existsSync(OUT_GEOJSON)) return {};

  const prevGeojson = JSON.parse(fs.readFileSync(OUT_GEOJSON, 'utf-8'));
  const prevReport = fs.existsSync(OUT_REPORT) ? JSON.parse(fs.readFileSync(OUT_REPORT, 'utf-8')) : {};
  const prevUnmatched = new Set(prevReport.unmatched ?? []);
  const prevSignatures = prevReport.variantsSignature ?? {};

  const seenOsmIds = new Set();
  const byRegion = {};
  for (const f of prevGeojson.features) {
    const region = NAME_TO_REGION.get(f.properties?.name);
    if (!region) continue; // river no longer in BATCHES config — drop
    const dedupeKey = `${region}:${f.properties.osm_id}`;
    if (seenOsmIds.has(dedupeKey)) continue; // duplicate from the old double-push bug — drop
    seenOsmIds.add(dedupeKey);
    (byRegion[region] ??= []).push(f);
  }

  const featuresByRegion = {};
  for (const batch of BATCHES) {
    if (prevSignatures[batch.region] !== regionSignature(batch)) continue; // rivers/variants changed — force re-fetch
    const feats = byRegion[batch.region] ?? [];
    const matchedNames = new Set(feats.map((f) => f.properties.name));
    const complete = Object.keys(batch.rivers).every((name) => matchedNames.has(name) || prevUnmatched.has(name));
    if (complete) featuresByRegion[batch.region] = feats;
  }
  return featuresByRegion;
}

// Always derived fresh from featuresByRegion — never manually accumulated — so it can't drift
// out of sync with the actual feature data the way the old flat push-arrays did.
function deriveReport(featuresByRegion) {
  const report = { matched: [], unmatched: [], multiCandidate: [] };
  for (const batch of BATCHES) {
    if (!(batch.region in featuresByRegion)) continue;
    const feats = featuresByRegion[batch.region];
    for (const canonicalName of Object.keys(batch.rivers)) {
      const count = feats.filter((f) => f.properties.name === canonicalName).length;
      if (count === 0) report.unmatched.push(canonicalName);
      else {
        report.matched.push(canonicalName);
        if (count > 1) report.multiCandidate.push({ name: canonicalName, count });
      }
    }
  }
  return report;
}

function writeOutput(featuresByRegion) {
  const allFeatures = Object.values(featuresByRegion).flat();
  const report = deriveReport(featuresByRegion);
  report.variantsSignature = Object.fromEntries(BATCHES.map((b) => [b.region, regionSignature(b)]));
  fs.mkdirSync('build', { recursive: true });
  fs.writeFileSync(OUT_GEOJSON, JSON.stringify({ type: 'FeatureCollection', features: allFeatures }));
  fs.writeFileSync(OUT_REPORT, JSON.stringify(report, null, 2));
}

async function run() {
  const featuresByRegion = loadAndMigrate();
  const salvaged = Object.keys(featuresByRegion).length;
  if (salvaged > 0) console.log(`${salvaged}/${BATCHES.length} batches already complete on disk.`);

  for (const batch of BATCHES) {
    if (batch.region in featuresByRegion) {
      console.log(`\n==> ${batch.region} — already complete, skipping`);
      continue;
    }
    console.log(`\n==> ${batch.region} (${Object.keys(batch.rivers).length} rivers)`);
    let osmData;
    try {
      osmData = await queryOverpass(buildQuery(batch.bbox, batch.rivers));
    } catch (err) {
      console.log(`  BATCH FAILED: ${err.message}`);
      continue; // region stays absent from featuresByRegion -> retried next run
    }

    const { default: osmtogeojson } = await import('osmtogeojson');
    const geojson = osmtogeojson(osmData);
    console.log(`  ways returned: ${geojson.features.length}`);

    const regionFeatures = [];
    for (const [canonicalName, variants] of Object.entries(batch.rivers)) {
      const matches = geojson.features.filter((f) => variants.includes(f.properties?.tags?.name));
      for (const f of matches) {
        regionFeatures.push({ ...f, properties: { id: null, name: canonicalName, osm_id: f.id } });
      }
    }
    featuresByRegion[batch.region] = regionFeatures; // overwrite this region's slice — safe to retry
    writeOutput(featuresByRegion); // write after every batch — a later failure doesn't lose earlier progress
  }

  // Always write, even if every region was salvaged and no batch was fetched this run — a
  // salvage can shrink the on-disk feature set (deduping) and that needs to be persisted too,
  // not just reflected in this run's printed report.
  writeOutput(featuresByRegion);

  const report = deriveReport(featuresByRegion);
  const total = BATCHES.reduce((n, b) => n + Object.keys(b.rivers).length, 0);
  console.log(`\nMatched: ${report.matched.length}/${total}`);
  console.log(`Unmatched: ${report.unmatched.join(', ') || 'none'}`);
  if (report.multiCandidate.length) {
    console.log(`\nMulti-candidate (resolve manually by checking coordinates before merging):`);
    report.multiCandidate.forEach((m) => console.log(`  ${m.name}: ${m.count} candidates`));
  }
  const failedRegions = BATCHES.filter((b) => !(b.region in featuresByRegion)).map((b) => b.region);
  if (failedRegions.length) {
    console.log(`\nBATCHES THAT FAILED (nothing lost elsewhere, just re-run this script):`);
    failedRegions.forEach((r) => console.log(`  ${r}`));
  } else {
    console.log(`\nAll batches complete.`);
  }
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});

