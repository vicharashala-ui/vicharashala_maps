#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "Spec_file.md" ] || [ ! -f "PROGRESS.md" ]; then
  echo "Error: run this from the project root (Spec_file.md/PROGRESS.md not found here)." >&2
  exit 1
fi
if [ ! -f "research/rivers-index-draft.json" ]; then
  echo "Error: research/rivers-index-draft.json not found — run step7a through step7g first." >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "Error: node not found on PATH." >&2
  exit 1
fi

mkdir -p .tmp-patch
cat > .tmp-patch/coastal-inland-batch.json << 'JSON_EOF'
[
  {
    "id": "ulhas", "name": "Ulhas", "local_name_hi": "उल्हास",
    "basin": "ulhas-basin", "length_km_india": 122, "basin_area_india_km2": 4637,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["maharashtra"], "aliases": [],
    "_needs_verification": [],
    "_source": "India-WRIS wiki + vajiramandravi (cross-confirmed): source Sahyadri hills near Tungarli Lake (Lonavala, Raigad district), 122km, catchment 4,637 km2, wholly Maharashtra, longest river in the Konkan"
  },
  {
    "id": "vaitarna", "name": "Vaitarna", "local_name_hi": "वैतरणा",
    "basin": "vaitarna-basin", "length_km_india": 154, "basin_area_india_km2": 3795,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["maharashtra"], "aliases": [],
    "_needs_verification": [],
    "_source": "Wikipedia (154km) + Springer academic morphometric study (catchment 3,795 km2, 6th-order basin): source Trimbakeshwar (Nashik district), wholly Maharashtra, longest river in Konkan per some sources (conflicts with Ulhas claim above — not reconciled)"
  },
  {
    "id": "savitri", "name": "Savitri", "local_name_hi": "सावित्री",
    "basin": "savitri-basin", "length_km_india": 110, "basin_area_india_km2": null,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["maharashtra"], "aliases": [],
    "_needs_verification": ["length_km_india: Wikipedia gives an approximate \"around 110km\"", "basin_area_india_km2: not found"],
    "_source": "Wikipedia: source Savitri Point (Mahabaleshwar), ~110km, wholly Maharashtra, meets Arabian Sea near Harihareshwar"
  },
  {
    "id": "vashisthi", "name": "Vashisthi", "local_name_hi": "वशिष्ठी",
    "basin": "vashisthi-basin", "length_km_india": null, "basin_area_india_km2": null,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["maharashtra"], "aliases": [],
    "_needs_verification": ["length_km_india: NOT FOUND — Wikipedia's own Vashishti River article gives no length figure at all", "basin_area_india_km2: not found"],
    "_source": "Wikipedia: source Western Ghats, wholly Maharashtra, flows past Chiplun, no length/basin data available in the article — weakest-sourced entry in this batch"
  },
  {
    "id": "kali-karnataka", "name": "Kali (Karnataka)", "local_name_hi": "काली नदी",
    "basin": "kali-karnataka-basin", "length_km_india": 265, "basin_area_india_km2": null,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka"], "aliases": ["Kali Nadi", "Kalinadi"],
    "_needs_verification": ["length_km_india: Wikipedia infobox gives 265km but the article's own body text later says \"184 kilometers\" — internally inconsistent, used the infobox figure", "basin_area_india_km2: not found"],
    "_source": "Wikipedia: source Diggi village (Uttara Kannada district), wholly Karnataka, joins Arabian Sea at Karwar; multiple dams including Supa Dam"
  },
  {
    "id": "netravati", "name": "Netravati", "local_name_hi": "नेत्रावती",
    "basin": "netravati-basin", "length_km_india": 106, "basin_area_india_km2": 3502,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka"], "aliases": [],
    "_needs_verification": ["length_km_india: sources range 84-106km across different pages — used Wikipedia's 106km", "basin_area_india_km2: converted from a secondary source's 1,352 sq mi figure, not independently confirmed in km2"],
    "_source": "Wikipedia: source Kudremukha (Chikkamagaluru district), wholly Karnataka, joins Arabian Sea south of Mangalore; known as 'Dakshina Kannada Jeeva Nadi' (lifeline river)"
  },
  {
    "id": "gurupur", "name": "Gurupur", "local_name_hi": "गुरुपुर",
    "basin": "gurupur-basin", "length_km_india": 48, "basin_area_india_km2": null,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka"], "aliases": [],
    "_needs_verification": ["ENTIRE ENTRY IS A LOW-CONFIDENCE PLACEHOLDER — no reliable source found this session beyond confirming the river exists and flows through Mangalore/Ullal, joining the Arabian Sea near Netravati's mouth. Length is an unsourced estimate."],
    "_source": "None found independently this session — see needs_verification"
  },
  {
    "id": "aghanashini", "name": "Aghanashini", "local_name_hi": "अघनाशिनी",
    "basin": "aghanashini-basin", "length_km_india": 117, "basin_area_india_km2": null,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka"], "aliases": ["Tadadi Hole"],
    "_needs_verification": ["basin_area_india_km2: not found (one source gave 1,350 km2 but that figure appears to actually describe Netravati, contaminated in the same source paragraph — discarded)", "seasonal_type: notable as one of the few undammed rivers in the Western Ghats, assumed perennial but not independently confirmed"],
    "_source": "Wikipedia + IISc Centre for Ecological Sciences (cross-confirmed): source Gadihalli village near Sirsi (Uttara Kannada district), 117km, wholly Karnataka, joins Arabian Sea near Gokarna"
  },
  {
    "id": "damanganga", "name": "Damanganga", "local_name_hi": "दमणगंगा",
    "basin": "damanganga-basin", "length_km_india": 131, "basin_area_india_km2": null,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["maharashtra", "gujarat", "dadra-and-nagar-haveli-and-daman-and-diu"],
    "aliases": ["Dawan River"],
    "_needs_verification": ["basin_area_india_km2: not found", "seasonal_type: assumed, not independently confirmed"],
    "_source": "Wikipedia: source Ambegaon (Dindori taluka, Nashik district, Maharashtra), 131.3km, wholly India, forms Daman Ganga Reservoir Project shared between Gujarat and DNHDD"
  },
  {
    "id": "swarnamukhi", "name": "Swarnamukhi", "local_name_hi": "स्वर्णमुखी",
    "basin": "swarnamukhi-basin", "length_km_india": null, "basin_area_india_km2": 3225,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["andhra-pradesh"], "aliases": [],
    "_needs_verification": ["length_km_india: not found — only catchment area was sourced", "seasonal_type: assumed, not independently confirmed"],
    "_source": "vajiramandravi.com: small east-flowing river basin, catchment 3,225 km2, wholly Andhra Pradesh"
  },
  {
    "id": "manimuktha", "name": "Manimuktha", "local_name_hi": "मणिमुक्ता",
    "basin": "manimuktha-basin", "length_km_india": null, "basin_area_india_km2": null,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["tamil-nadu"], "aliases": [],
    "_needs_verification": ["ENTIRE ENTRY IS UNSOURCED THIS SESSION — no reliable length, basin, or detailed origin data found for a Tamil Nadu river by this name. Recommend dedicated re-research before relying on this entry at all."],
    "_source": "None found this session — see needs_verification"
  },
  {
    "id": "vaippar", "name": "Vaippar", "local_name_hi": "वैप्पार",
    "basin": "vaippar-basin", "length_km_india": 130, "basin_area_india_km2": 5288,
    "drainage_type": "coastal", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["tamil-nadu"], "aliases": [],
    "_needs_verification": ["seasonal_type: assumed (all Tamil Nadu rivers except Tamiraparani are non-perennial per earlier-batch sourcing), not independently re-confirmed for this specific river"],
    "_source": "Wikipedia: source Varusanadu hills (Tenkasi district), 130km, catchment 5,288 km2, wholly Tamil Nadu, joins Gulf of Mannar near Sippikulam"
  },
  {
    "id": "luni", "name": "Luni", "local_name_hi": "लूनी",
    "basin": "luni-basin", "length_km_india": 495, "basin_area_india_km2": 37363,
    "drainage_type": "inland", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["rajasthan", "gujarat"], "aliases": ["Sagarmati"],
    "_needs_verification": [],
    "_source": "Wikipedia: source Pushkar valley (Aravalli Range, near Ajmer), 495km, basin 37,363 km2, wholly India, terminates in the marshes of the Rann of Kutch — largest river of the Thar Desert, does not reach the sea"
  },
  {
    "id": "ghaggar-hakra", "name": "Ghaggar-Hakra", "local_name_hi": "घग्गर-हकरा",
    "basin": "ghaggar-basin", "length_km_india": 320, "basin_area_india_km2": 42200,
    "drainage_type": "inland", "stream_order": null,
    "seasonal_type": "ephemeral", "origin_type": "rain-fed",
    "navigable": false, "transnational": true,
    "states": ["himachal-pradesh", "punjab", "haryana", "rajasthan"], "aliases": ["Hakra", "Sarasvati"],
    "_needs_verification": ["length_km_india: sources range widely (320-560km depending on whether the Pakistan Hakra segment and full historical channel are counted) — used the commonly-cited 320km 'present-day channel, majority in India' figure from two independent sources", "basin_area_india_km2: an academic source (CSIR-NGRI) gives 42,200 km2 for the full basin across 5 states/UTs (used here); a secondary source gives a smaller 29,524 km2 — not reconciled", "transnational: marked true since the river continues into Pakistan as the Hakra before drying out, though the bulk of flow and the segment India considers 'Ghaggar' stays domestic"],
    "_source": "CSIR-National Geophysical Research Institute (basin area) + riversinsight.com/indiamapped.com (length, cross-confirmed): source Shivalik Hills (Himachal Pradesh), ephemeral/seasonal — explicitly described as carrying baseflow only in its upper reaches, dry Oct-Mar; possibly the historical Vedic Sarasvati river"
  }
]
JSON_EOF

node << 'NODE_EOF'
const fs = require('fs');
const existing = JSON.parse(fs.readFileSync('research/rivers-index-draft.json', 'utf8'));
const batch = JSON.parse(fs.readFileSync('.tmp-patch/coastal-inland-batch.json', 'utf8'));

const existingIds = new Set(existing.map(r => r.id));
const dupes = batch.filter(r => existingIds.has(r.id));
if (dupes.length) {
  console.error('ERROR: duplicate river id(s) already in draft:', dupes.map(r => r.id).join(', '));
  process.exit(1);
}

const merged = existing.concat(batch);
fs.writeFileSync('research/rivers-index-draft.json', JSON.stringify(merged, null, 2) + '\n');
console.log('==> research/rivers-index-draft.json now has ' + merged.length + ' entries (+' + batch.length + ') — ALL spec §4.9 rivers now have draft entries');
NODE_EOF

mkdir -p .tmp-patch
cat > .tmp-patch/old_status.txt << 'OLD_EOF'
## Current status: Step 7 in progress — rivers-index.json metadata research, Peninsular-West complete (93/105 rivers total)

### rivers-index.json research progress (`research/rivers-index-draft.json`)
Built via web research (batched by river system per spec §4.9), NOT the shapefile's `build/rivers-govt-metadata.json` seed from Step 5c — that file lives in your gitignored `build/` dir from a prior session and wasn't available to cross-check here. **Action needed**: if you still have that file, share it so the overlapping fields (basin/origin text for the 61 matched rivers) can be reconciled against this research — government-sourced beats web-sourced where they conflict.

Spec §4.9 defines 7 river-system groups: Indus, Ganga, Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage.

- **Indus system** (9/9 done)
- **Ganga system** (26/26 done)
- **Brahmaputra system** (15/15 done)
- **Peninsular-East system** (29/29 done)
- **Peninsular-West system** (14/14 done): Narmada, Tapi, Mahi, Sabarmati, Periyar, Chaliyar, Bharathapuzha, Pamba, Kallada, Sharavati, Zuari, Mandovi, Purna, Girna
- Each entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)
- **Strongest data this batch**: Narmada, Tapi, Mahi, Periyar, Purna all cross-confirmed 2+ sources. **ACTION NEEDED — "Purna" disambiguation**: India has 3 distinct rivers named Purna (a Tapi tributary via Khandesh, an independent South Gujarat coastal river, and a separate Godavari tributary in Marathwada). Used the Tapi tributary since spec pairs Purna with Girna (both Tapi tributaries) — worth a sanity-check.
- Other flagged weak entries this batch: Zuari and Sabarmati both have Wikipedia-internal length/basin conflicts (infobox vs. body text disagree); Sharavati/Zuari/Mandovi/Kallada have no basin area found
- **ACTION NEEDED — "Vellar" naming ambiguity** (from Peninsular-East, still unresolved): Tamil Nadu has two Vellar rivers; used the Southern one.
- **ACTION NEEDED — Kopili/Kapili naming conflict** (from Brahmaputra batch, still unresolved): likely the same river listed twice in spec.
- Other flagged weak entries from earlier batches (Ganga: Rupnarayan, Ghaghra, Sarda, Gandak, Kosi, Bagmati, Mechi; Brahmaputra: Sankosh, Rangeet, Teesta, Torsa, Jaldhaka; Peninsular-East pt.1: Musi, Indravati, Pranhita, Wainganga, Wardha) still unresolved
- `_source` field on each entry records what was used — strip before final schema validation
- 2 river-system groups remaining: Coastal (11 rivers), Inland Drainage (2 rivers) — 12 rivers total left

### Not started yet
- 2 remaining river-system groups for rivers-index.json (12 rivers, see above)
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
1. Continue rivers-index.json research: **Coastal + Inland Drainage systems** next (12 rivers — the final two groups, likely can finish rivers-index.json research entirely in the next session), or reorder if you'd rather
2. Resolve the "Purna", "Vellar", and Kopili/Kapili naming questions above
3. In parallel/after: rescoped Overpass for the 44 unmatched rivers' geometry
4. Once both are further along: reconcile `research/rivers-index-draft.json` against Step 5c's `build/rivers-govt-metadata.json` seed (send it over if you have it), and re-verify all flagged weak entries, before running `prepareRivers.js`
OLD_EOF

cat > .tmp-patch/new_status.txt << 'NEW_EOF'
## Current status: Step 7 research pass COMPLETE — all 107 rivers in `research/rivers-index-draft.json` (spec §4.9's list totals 107, not 105 — see note below)

### rivers-index.json research: all batches done
Built via web research (batched by river system per spec §4.9), NOT the shapefile's `build/rivers-govt-metadata.json` seed from Step 5c — that file lives in your gitignored `build/` dir from a prior session and wasn't available to cross-check here. **Action needed**: if you still have that file, share it so the overlapping fields (basin/origin text for the 61 matched rivers) can be reconciled against this research — government-sourced beats web-sourced where they conflict.

**Count correction**: spec §4.9's river lists actually total 107 named rivers (9 Indus + 26 Ganga + 15 Brahmaputra + 29 Peninsular-East + 14 Peninsular-West + 12 Coastal + 2 Inland Drainage), not the ~105 figure used throughout this project so far. Every named entry in §4.9 has a draft record now.

- **Indus** (9/9), **Ganga** (26/26), **Brahmaputra** (15/15), **Peninsular-East** (29/29), **Peninsular-West** (14/14) — all done in prior updates
- **Coastal** (12/12 done): Ulhas, Vaitarna, Savitri, Vashisthi, Kali (Karnataka), Netravati, Gurupur, Aghanashini, Damanganga, Swarnamukhi, Manimuktha, Vaippar
- **Inland Drainage** (2/2 done): Luni, Ghaggar-Hakra
- Every entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)

### Before running `prepareRivers.js`, this needs a verification pass — full list of open items:
1. **Reconcile against Step 5c's `build/rivers-govt-metadata.json`** (send it over) — government data should override web research on any overlapping field
2. **Naming/identity questions requiring your input** (not resolved by more research, need a decision):
   - **Kopili vs Kapili** (Brahmaputra) — likely the same river listed twice in spec; `kapili` entry is an unsourced placeholder
   - **Vellar** (Peninsular-East) — Tamil Nadu has two rivers by this name; used the Southern one
   - **Purna** (Peninsular-West) — India has 3 rivers by this name; used the Tapi tributary
3. **Entries with essentially no data found** (weakest of the weak — worth dedicated re-research before trusting): **Vashisthi** (no length at all), **Manimuktha** (nothing found), **Gurupur** (length is an unsourced guess), **Sankosh**/**Rangeet** (Brahmaputra, no length found), **Kamla** (Ganga, no length found)
4. **Everything else flagged `_needs_verification`** across all 7 batches — mostly derived/estimated lengths for transboundary rivers (India-only portion of a longer river) and unconfirmed `basin_area_india_km2`/`seasonal_type` values. Strip all `_source`/`_needs_verification` fields before final schema validation regardless.

### Not started yet
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry (separate from the metadata research just finished)
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
Metadata research is done — the two remaining workstreams are independent of each other now:
1. **Verification pass** on the open items above (naming decisions + weak entries), ideally with the Step 5c govt data reconciled in
2. **Geometry**: rescoped Overpass for the 44 unmatched rivers (separate task, blocked on nothing above)
Both need to land before `prepareRivers.js` can run and produce the final `public/data/rivers-index.json` + `rivers.pmtiles`.
NEW_EOF

node << 'NODE_EOF'
const fs = require('fs');
const content = fs.readFileSync('PROGRESS.md', 'utf8');
const oldStatus = fs.readFileSync('.tmp-patch/old_status.txt', 'utf8').replace(/\n$/, '');
const newStatus = fs.readFileSync('.tmp-patch/new_status.txt', 'utf8').replace(/\n$/, '');

if (!content.includes(oldStatus)) {
  console.error('ERROR: expected PROGRESS.md status block not found verbatim — aborting to avoid corrupting the file.');
  process.exit(1);
}

fs.writeFileSync('PROGRESS.md', content.replace(oldStatus, newStatus));
console.log('==> PROGRESS.md updated');
NODE_EOF

rm -rf .tmp-patch

git add research/rivers-index-draft.json PROGRESS.md
git commit -q -m "Step 7 COMPLETE: rivers-index.json research — Coastal + Inland Drainage (14 rivers, all 107 spec rivers now drafted)" \
  || echo "Commit skipped (configure 'git config user.name/user.email' then commit manually)."

echo "==> Done."
