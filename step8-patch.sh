#!/usr/bin/env bash
set -euo pipefail

# Step 8 — reconcile govt shapefile/HydroRIVERS metadata into the rivers-index research draft.
# Run from the project root in Git Bash. Idempotent — safe to re-run.

mkdir -p build scripts

cat > build/rivers-govt-metadata.json << 'GOVTMETA_EOF'
[{"name":"Indus","basin":"Indus (Up to border)","sub_basin":null,"origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":976},{"name":"Chenab","basin":"Indus (Up to border)","sub_basin":"Chenab","origin_description":null,"length_km_india":431.4,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":563},{"name":"Beas","basin":"Indus (Up to border)","sub_basin":null,"origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":565},{"name":"Sutlej","basin":"Indus (Up to border)","sub_basin":null,"origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":724.1},{"name":"Ganga","basin":"Ganga","sub_basin":null,"origin_description":"Gangotri Glaciers, After Confluence Of Bhagirathi And Alaknanda","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":2459.9},{"name":"Bhagirathi","basin":"Ganga","sub_basin":"Above Ramganga Confluence","origin_description":"Gangotri Glaciers In Himalayas","length_km_india":229.1,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":265.1},{"name":"Alaknanda","basin":"Ganga","sub_basin":"Above Ramganga Confluence","origin_description":"Garhwal Himalayas","length_km_india":206.4,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":237},{"name":"Yamuna","basin":"Ganga","sub_basin":null,"origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":1647.7},{"name":"Chambal","basin":"Ganga","sub_basin":null,"origin_description":"Vindhyaangeear Mhow In The Indore District Of Madhya Pradesh","length_km_india":988.5,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":7,"hydrorivers_length_km_crosscheck":1101.1},{"name":"Betwa","basin":"Ganga","sub_basin":"Yamuna Lower","origin_description":"Near Khumra Village In Bhopal District Of Madhya Pradesh","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":704.7},{"name":"Son","basin":"Ganga","sub_basin":null,"origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":953.8},{"name":"Gomti","basin":"Ganga","sub_basin":null,"origin_description":"Near Manikot east of Pillibhit district of Uttar Pradesh","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":781},{"name":"Ghaghra","basin":"Ganga","sub_basin":null,"origin_description":"Combined Water Of Sarda And Kauriala","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":791.3},{"name":"Gandak","basin":"Ganga","sub_basin":"Gandak and others","origin_description":"North-East Of Dhaulagiri In Nepal","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":7,"hydrorivers_length_km_crosscheck":405.7},{"name":"Damodar","basin":"Ganga","sub_basin":null,"origin_description":"Hills Of The Chottanagpur Plateau, Bihar","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":5,"hydrorivers_length_km_crosscheck":701.6},{"name":"Hooghly","basin":"Ganga","sub_basin":"Bhagirathi and others (Ganga Lower)","origin_description":"Splits From Ganga At Farakka Barrage","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":249.3},{"name":"Barakar","basin":"Ganga","sub_basin":null,"origin_description":null,"length_km_india":291.3,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":302.3},{"name":"Ajay","basin":"Ganga","sub_basin":"Bhagirathi and others (Ganga Lower)","origin_description":"Near Deoghar In The Santhal Parganas District Of Jharkhand","length_km_india":308.4,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":355.5},{"name":"Brahmaputra","basin":"Brahamaputra","sub_basin":null,"origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":2109.6},{"name":"Lohit","basin":"Brahamaputra","sub_basin":"Brahmaputra Upper","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":652},{"name":"Subansiri","basin":"Brahamaputra","sub_basin":"Brahmaputra Upper","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":7,"hydrorivers_length_km_crosscheck":647},{"name":"Kameng","basin":"Brahamaputra","sub_basin":"Brahmaputra Lower","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":330.8},{"name":"Teesta","basin":"Brahamaputra","sub_basin":"Brahmaputra Lower","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":401.4},{"name":"Torsa","basin":"Brahamaputra","sub_basin":"Brahmaputra Lower","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":5,"hydrorivers_length_km_crosscheck":131},{"name":"Jaldhaka","basin":"Brahamaputra","sub_basin":"Brahmaputra Lower","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":5,"hydrorivers_length_km_crosscheck":281.4},{"name":"Barak","basin":"Barak and Others","sub_basin":"Barak","origin_description":null,"length_km_india":100.3,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":135.1},{"name":"Kopili","basin":"Brahamaputra","sub_basin":"Brahmaputra Lower","origin_description":null,"length_km_india":333,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":7,"hydrorivers_length_km_crosscheck":409.1},{"name":"Mahanadi","basin":"Mahanadi","sub_basin":null,"origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":7,"hydrorivers_length_km_crosscheck":1128.4},{"name":"Brahmani","basin":"Brahmani and Baitarni","sub_basin":"Brahmani","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":607},{"name":"Baitarani","basin":"Brahmani and Baitarni","sub_basin":"Baitarni","origin_description":null,"length_km_india":414.3,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":472.2},{"name":"Subarnarekha","basin":"Subernarekha","sub_basin":"Subernarekha","origin_description":null,"length_km_india":479.5,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":612.5},{"name":"Vamsadhara","basin":"East flowing rivers between Mahanadi and Pennar","sub_basin":"Vamsadhara and other","origin_description":null,"length_km_india":287,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":289.7},{"name":"Nagavali","basin":"East flowing rivers between Mahanadi and Pennar","sub_basin":"Nagvati and other","origin_description":"Near Lakhbahal village in Thuamul Rampur block of Kalahandi District","length_km_india":250.4,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":252.2},{"name":"Godavari","basin":"Godavari","sub_basin":null,"origin_description":"Trambakeshwar, Nashik District In Maharashtra","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":1808.5},{"name":"Krishna","basin":"Krishna","sub_basin":null,"origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":8,"hydrorivers_length_km_crosscheck":1621.9},{"name":"Tungabhadra","basin":"Krishna","sub_basin":null,"origin_description":null,"length_km_india":552.5,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":7,"hydrorivers_length_km_crosscheck":638.4},{"name":"Bhima","basin":"Krishna","sub_basin":null,"origin_description":"Bhimashankar, Pune district in Maharashtra","length_km_india":864.5,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":986.7},{"name":"Musi","basin":"Krishna","sub_basin":"Krishna Lower","origin_description":null,"length_km_india":296.2,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":324.8},{"name":"Indravati","basin":"Godavari","sub_basin":null,"origin_description":"Rises On The Western Slopes Of Eastern Ghats In The Kalahandi District","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":620.1},{"name":"Pranhita","basin":"Godavari","sub_basin":"Pranhita and others","origin_description":"After Confluence Of Wardha And Wainganga","length_km_india":115.5,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":7,"hydrorivers_length_km_crosscheck":132.8},{"name":"Wainganga","basin":"Godavari","sub_basin":null,"origin_description":"Origin In Baitul District In Madhya Pradesh","length_km_india":629.8,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":7,"hydrorivers_length_km_crosscheck":752.2},{"name":"Wardha","basin":"Godavari","sub_basin":null,"origin_description":"Origin In Baitul District In Madhya Pradesh","length_km_india":533.6,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":584},{"name":"Kaveri","basin":"Cauvery","sub_basin":null,"origin_description":"Originate at Talakaveri in Coorg District of Karnataka in Brahmagiri Range of Western Ghats","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":814.5},{"name":"Palar","basin":"East flowing rivers between Pennar and Kanyakumari","sub_basin":"Palar and other","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":5,"hydrorivers_length_km_crosscheck":464.5},{"name":"Ponnaiyar","basin":"East flowing rivers between Pennar and Kanyakumari","sub_basin":"Ponnaiyar and other","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":5,"hydrorivers_length_km_crosscheck":483.5},{"name":"Vaigai","basin":"East flowing rivers between Pennar and Kanyakumari","sub_basin":"Pamba and others","origin_description":null,"length_km_india":312.2,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":4,"hydrorivers_length_km_crosscheck":304.1},{"name":"Narmada","basin":"Narmada","sub_basin":null,"origin_description":"Amarkantak, Satpuda Range","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":7,"hydrorivers_length_km_crosscheck":1581.9},{"name":"Tapi","basin":"Tapi","sub_basin":null,"origin_description":null,"length_km_india":779,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":934.8},{"name":"Mahi","basin":"Mahi","sub_basin":null,"origin_description":null,"length_km_india":553.5,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":625.9},{"name":"Sabarmati","basin":"Sabarmati","sub_basin":null,"origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":385.5},{"name":"Periyar","basin":"West flowing rivers from Tadri to Kanyakumari","sub_basin":"Periyar and others","origin_description":"Originate from Sivagiri peak","length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":5,"hydrorivers_length_km_crosscheck":340.9},{"name":"Bharathapuzha","basin":"West flowing rivers from Tadri to Kanyakumari","sub_basin":"Varrar and others","origin_description":null,"length_km_india":99.9,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":124.9},{"name":"Kallada","basin":"West flowing rivers from Tadri to Kanyakumari","sub_basin":"Periyar and others","origin_description":null,"length_km_india":126.1,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":4,"hydrorivers_length_km_crosscheck":144.8},{"name":"Sharavati","basin":"West flowing rivers from Tadri to Kanyakumari","sub_basin":"Netravati and others","origin_description":null,"length_km_india":38.2,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":4,"hydrorivers_length_km_crosscheck":39.4},{"name":"Purna","basin":"Godavari","sub_basin":"Godavari Middle","origin_description":"Rises In The Ajanta Range","length_km_india":382.2,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":420.9},{"name":"Ulhas","basin":"West flowing rivers from Tapi to Tadri","sub_basin":"Bhatsol and others","origin_description":null,"length_km_india":146,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":6,"hydrorivers_length_km_crosscheck":209.4},{"name":"Kali","basin":"West flowing rivers from Tapi to Tadri","sub_basin":"Vasishti and others","origin_description":null,"length_km_india":178.7,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":247.6},{"name":"Netravati","basin":"West flowing rivers from Tadri to Kanyakumari","sub_basin":"Netravati and others","origin_description":null,"length_km_india":115.7,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":173.8},{"name":"Vaippar","basin":"East flowing rivers between Pennar and Kanyakumari","sub_basin":"Vaippar and others","origin_description":null,"length_km_india":86.5,"length_source":"data.gov.in Rivers shapefile","needs_verification":false,"stream_order":5,"hydrorivers_length_km_crosscheck":101.5},{"name":"Luni","basin":"West flowing rivers of Kutch and Saurashtra including Luni","sub_basin":"Luni Upper","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":6,"hydrorivers_length_km_crosscheck":614.9},{"name":"Ghaggar","basin":"Indus (Up to border)","sub_basin":"Ghaghar and others","origin_description":null,"length_km_india":null,"length_source":"data.gov.in Rivers shapefile","needs_verification":true,"stream_order":5,"hydrorivers_length_km_crosscheck":374.9}]
GOVTMETA_EOF

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

node scripts/reconcileGovtMetadata.js

echo
echo "Done. research/rivers-index-reconciled.json written (106 entries)."
echo "research/rivers-index-draft.json is untouched — kept as a historical record."
