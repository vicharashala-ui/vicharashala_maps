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
