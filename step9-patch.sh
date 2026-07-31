#!/usr/bin/env bash
set -euo pipefail

# Step 9 — fix a duplicate-rivname matching bug + recover 3 more govt-matched rivers
# (Banas, Parbati, Manjira), re-run the full reconciliation with corrected data.
# Self-contained — writes both scripts fresh, does not depend on step8-patch.sh
# having been run first. Run from the project root in Git Bash. Idempotent.
#
# Needs build/raw/rivers-shp/Rivers.shp (Step 5c's source shapefile) OR
# build/rivers-govt-raw.geojson (the already-converted intermediate) present
# locally — this patch does not re-supply either, both are gitignored and you
# already have them from the Step 5c session.

if [ ! -f build/raw/rivers-shp/Rivers.shp ] && [ ! -f build/rivers-govt-raw.geojson ]; then
  echo "ERROR: need build/raw/rivers-shp/Rivers.shp or build/rivers-govt-raw.geojson — neither found." >&2
  exit 1
fi

cat > scripts/processRiversShapefile.js << 'PROC_EOF'
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
//
// DUPLICATE rivname BUG (fixed): the shapefile has 3 names shared by two unrelated/mismatched
// features — Banas (Ganga-basin Chambal tributary vs. an unrelated Kutch/Saurashtra river),
// Wainganga (real 630km mainstem vs. a 6.5km fragment), Sharavati (real 134km river vs. a
// 38km fragment misclassified under Netravati's sub_basin). The old Map.set() silently kept
// whichever feature came last in iteration order — Wainganga happened to land on the correct
// one, Sharavati did not (shipped as 38.2km instead of ~134km; already in build/rivers-govt-metadata.json
// from a prior run — re-running this script corrects it). DISAMBIGUATE below picks explicitly
// instead of relying on iteration order; an unlisted duplicate throws rather than guessing.

import fs from 'node:fs';
import { execSync } from 'node:child_process';

const SHP_DIR = 'build/raw/rivers-shp';
const GEOJSON_TMP = 'build/rivers-govt-raw.geojson';

const RIVER_NAMES = [
  'Indus', 'Jhelum', 'Chenab', 'Ravi', 'Beas', 'Sutlej', 'Spiti', 'Zanskar', 'Shyok',
  'Ganga', 'Bhagirathi', 'Alaknanda', 'Yamuna', 'Chambal', 'Banas', 'Kali Sindh', 'Parbati',
  'Betwa', 'Ken', 'Son', 'Gomti',
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
  Bharathapuzha: 'Bharathapuzha/Ponnani', Lohit: 'Lohit/ Tellu', Manjira: 'Manjra',
};

// shapefile name -> which duplicate to keep, when more than one feature shares that name
const DISAMBIGUATE = {
  Banas: (p) => p.ba_name === 'Ganga', // not the unrelated Kutch/Saurashtra "Banas"
  Wainganga: (p) => p.sub_basin === '', // not the 6.5km fragment (sub_basin "Pranhita and others")
  Sharavati: (p) => p.sub_basin === '', // not the 38km fragment misclassified under Netravati
};

function run() {
  if (!fs.existsSync(GEOJSON_TMP)) {
    console.log('==> Converting shapefile to WGS84 GeoJSON via mapshaper');
    execSync(
      `pnpm exec mapshaper "${SHP_DIR}/Rivers.shp" -proj wgs84 -o "${GEOJSON_TMP}" format=geojson`,
      { stdio: 'inherit' }
    );
  } else {
    console.log(`==> Reusing existing ${GEOJSON_TMP}`);
  }

  const raw = JSON.parse(fs.readFileSync(GEOJSON_TMP, 'utf-8'));
  const byShapefileName = new Map(); // name -> feature[]
  for (const f of raw.features) {
    const name = f.properties.rivname;
    if (!byShapefileName.has(name)) byShapefileName.set(name, []);
    byShapefileName.get(name).push(f);
  }

  const matchedFeatures = [];
  const metadata = [];
  const report = { matched: [], unmatched: [], needsVerification: [] };

  for (const canonicalName of RIVER_NAMES) {
    const shpName = VARIANT_MAP[canonicalName] ?? canonicalName;
    const candidates = byShapefileName.get(shpName);
    if (!candidates) {
      report.unmatched.push(canonicalName);
      continue;
    }

    let feature = candidates[0];
    if (candidates.length > 1) {
      const pick = DISAMBIGUATE[canonicalName];
      if (!pick) {
        throw new Error(
          `"${shpName}" has ${candidates.length} shapefile features and no DISAMBIGUATE rule for "${canonicalName}" — add one, don't guess.`
        );
      }
      const matches = candidates.filter((f) => pick(f.properties));
      if (matches.length !== 1) {
        throw new Error(`DISAMBIGUATE for "${canonicalName}" matched ${matches.length} features, expected exactly 1.`);
      }
      feature = matches[0];
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
PROC_EOF

cat > scripts/reconcileGovtMetadata.js << 'RECONCILE_EOF'
// scripts/reconcileGovtMetadata.js
// Input:  research/rivers-index-draft.json (107 web-research entries, Step 7)
//         build/rivers-govt-metadata.json (61 govt-shapefile/HydroRIVERS entries, Step 5c+6)
// Output: research/rivers-index-reconciled.json (106 entries)
//
// Overrides length_km_india (only when the govt entry isn't a multi-part/braided-channel
// sum, needs_verification:false) and stream_order with govt/HydroRIVERS data — both are
// more authoritative than web research per §4.8. basin/sub_basin/origin_description aren't
// applied: they don't map onto RiverIndexEntry (§4.1) fields, only onto the manually-authored
// rivers/{id}.json detail files, which are out of scope here.

import fs from 'node:fs';

const DRAFT_PATH = 'research/rivers-index-draft.json';
const GOVT_PATH = 'build/rivers-govt-metadata.json';
const OUT_PATH = 'research/rivers-index-reconciled.json';
const LENGTH_DISCREPANCY_THRESHOLD = 0.2; // 20% — flag for a manual look; govt value still wins

// The shapefile's `rivname` spelling doesn't always match the spec-derived name the draft
// uses. Resolved by checking each mismatch's govt `basin` field against the draft entry it
// should logically match:
const GOVT_NAME_TO_DRAFT_NAME = {
  Ghaghra: 'Ghaghra (Karnali)',
  // govt basin "West flowing rivers from Tapi to Tadri" = Western Ghats coastal drainage,
  // confirms this is the Karnataka coastal Kali, not the Sharda/Kali of the Ghaghra system.
  Kali: 'Kali (Karnataka)',
  // govt basin "Indus (Up to border)" matches the Ghaggar-Hakra system's classification;
  // the shapefile's separate "Hakra" feature stays unmatched (spec treats this as one entry).
  Ghaggar: 'Ghaggar-Hakra',
};

// The shapefile has one feature named "Purna" — basin "Godavari", origin "Ajanta Range".
// That's the Godavari-tributary Purna, not the Tapi-tributary one spec §4.9 groups under
// Peninsular-West (with Narmada/Tapi/Mahi/Sabarmati/.../Girna, all west-flowing to the
// Arabian Sea). Exact-name matching produced a false positive: discard the govt data,
// keep the draft's web-research values, and treat it as still needing its own geometry.
const GOVT_FALSE_POSITIVES = new Set(['Purna']);

// Wikipedia + the govt shapefile (one feature, matched under "Kopili") agree Kapili is an
// alternate spelling, not a distinct river. Kopili's draft entry already lists "Kapili" in
// aliases. Drop the placeholder duplicate entry (107 -> 106 total).
const DUPLICATE_IDS_TO_DROP = new Set(['kapili']);

function reconcile() {
  const draft = JSON.parse(fs.readFileSync(DRAFT_PATH, 'utf-8'));
  const govtEntries = JSON.parse(fs.readFileSync(GOVT_PATH, 'utf-8'));
  const govtByDraftName = new Map(
    govtEntries.map((e) => [GOVT_NAME_TO_DRAFT_NAME[e.name] ?? e.name, e])
  );

  const report = { overridden: [], discrepancies: [], dropped: [], excludedGovtMatch: [] };

  const reconciled = draft
    .filter((river) => !DUPLICATE_IDS_TO_DROP.has(river.id))
    .map((river) => {
      const govt = govtByDraftName.get(river.name);
      if (!govt || GOVT_FALSE_POSITIVES.has(govt.name)) {
        if (govt) report.excludedGovtMatch.push(river.name);
        return river;
      }

      const changes = [];
      const next = { ...river };

      if (!govt.needs_verification && govt.length_km_india !== null) {
        if (river.length_km_india !== null) {
          const diff = Math.abs(govt.length_km_india - river.length_km_india) / river.length_km_india;
          if (diff > LENGTH_DISCREPANCY_THRESHOLD) {
            report.discrepancies.push({ name: river.name, webResearch: river.length_km_india, govt: govt.length_km_india });
          }
        }
        next.length_km_india = govt.length_km_india;
        changes.push('length_km_india');
      }

      if (govt.stream_order !== null) {
        next.stream_order = govt.stream_order;
        changes.push('stream_order');
      }

      if (changes.length) {
        next._source = `${river._source} | ${changes.join(', ')} from data.gov.in Rivers shapefile / HydroRIVERS (govt-authoritative, overrides web research)`;
        report.overridden.push({ name: river.name, fields: changes });
      }
      return next;
    });

  for (const id of DUPLICATE_IDS_TO_DROP) {
    const dropped = draft.find((r) => r.id === id);
    if (dropped) report.dropped.push(dropped.name);
  }

  fs.writeFileSync(OUT_PATH, JSON.stringify(reconciled, null, 2));

  console.log(`Reconciled: ${reconciled.length} rivers (was ${draft.length})`);
  console.log(`Overridden with govt/HydroRIVERS data: ${report.overridden.length}`);
  report.overridden.forEach((o) => console.log(`  ${o.name}: ${o.fields.join(', ')}`));
  console.log(`\nDropped as duplicates: ${report.dropped.join(', ') || 'none'}`);
  console.log(`Govt match excluded (wrong river, needs its own geometry): ${report.excludedGovtMatch.join(', ') || 'none'}`);

  if (report.discrepancies.length) {
    console.log(`\nLength discrepancies >20% (govt value used, worth a manual look):`);
    report.discrepancies.forEach((d) => console.log(`  ${d.name}: web=${d.webResearch}km govt=${d.govt}km`));
  }

  const stillNeedGeometry = reconciled.filter(
    (r) => !govtByDraftName.has(r.name) || GOVT_FALSE_POSITIVES.has(govtByDraftName.get(r.name)?.name)
  );
  console.log(`\nStill need geometry (${stillNeedGeometry.length}):`);
  console.log(stillNeedGeometry.map((r) => r.name).join(', '));
}

reconcile();
RECONCILE_EOF

node scripts/processRiversShapefile.js
node scripts/reconcileGovtMetadata.js

echo
echo "Done. research/rivers-index-reconciled.json updated (63 govt-matched, 43 still need geometry)."
