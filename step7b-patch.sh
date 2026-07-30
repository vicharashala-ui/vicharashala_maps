#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "Spec_file.md" ] || [ ! -f "PROGRESS.md" ]; then
  echo "Error: run this from the project root (Spec_file.md/PROGRESS.md not found here)." >&2
  exit 1
fi
if [ ! -f "research/rivers-index-draft.json" ]; then
  echo "Error: research/rivers-index-draft.json not found — run step7a-patch.sh first." >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "Error: node not found on PATH." >&2
  exit 1
fi

mkdir -p .tmp-patch
cat > .tmp-patch/ganga-batch2a.json << 'JSON_EOF'
[
  {
    "id": "ganga", "name": "Ganga", "local_name_hi": "गंगा",
    "basin": "ganga-basin", "length_km_india": 2525, "basin_area_india_km2": 861452,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": true, "transnational": true,
    "states": ["uttarakhand", "uttar-pradesh", "bihar", "jharkhand", "west-bengal"],
    "aliases": ["Ganges", "Ganga Mata"],
    "_needs_verification": [],
    "_source": "India-WRIS wiki (indiawris.gov.in/wiki/doku.php?id=ganga): length 2525km source-to-Bay of Bengal via Bhagirathi-Hooghly, India basin area 861,452 km2 (26% of country)"
  },
  {
    "id": "bhagirathi", "name": "Bhagirathi", "local_name_hi": "भागीरथी",
    "basin": "ganga-basin", "length_km_india": 205, "basin_area_india_km2": 6921,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": false,
    "states": ["uttarakhand"], "aliases": [],
    "_needs_verification": [],
    "_source": "CWC Upper Ganga Basin Organisation (cwc.gov.in/ugbo/gangabasin/bhagirathi): 205km, source Gaumukh Glacier, basin 6,921 km2"
  },
  {
    "id": "alaknanda", "name": "Alaknanda", "local_name_hi": "अलकनंदा",
    "basin": "ganga-basin", "length_km_india": 195, "basin_area_india_km2": 10882,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": false,
    "states": ["uttarakhand"], "aliases": [],
    "_needs_verification": [],
    "_source": "Wikipedia: source Satopanth/Bhagirathi Kharak glaciers, 195km, basin 10,882 km2"
  },
  {
    "id": "yamuna", "name": "Yamuna", "local_name_hi": "यमुना",
    "basin": "ganga-basin", "length_km_india": 1376, "basin_area_india_km2": 366223,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": false,
    "states": ["uttarakhand", "himachal-pradesh", "haryana", "delhi", "uttar-pradesh"],
    "aliases": ["Jamuna", "Jumna"],
    "_needs_verification": ["basin_area_india_km2: 366,223 km2 is the commonly-cited textbook figure but wasn't directly confirmed in searched sources this session — one low-quality source gave an implausible 69,000 km2 (likely confusing a sub-basin), discarded"],
    "_source": "Multiple secondary sources (adda247, class24, kvguruji) agree on 1,376km from Yamunotri Glacier; entirely within India"
  },
  {
    "id": "chambal", "name": "Chambal", "local_name_hi": "चंबल",
    "basin": "ganga-basin", "length_km_india": 960, "basin_area_india_km2": 144591,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["madhya-pradesh", "rajasthan", "uttar-pradesh"],
    "aliases": ["Charmanyavati"],
    "_needs_verification": [],
    "_source": "Wikipedia: 960km, basin 144,591 km2 up to Yamuna confluence; source-derived RAS Rajasthan exam notes independently confirm one of only two perennial rivers in Rajasthan"
  },
  {
    "id": "banas", "name": "Banas", "local_name_hi": "बनास",
    "basin": "ganga-basin", "length_km_india": 512, "basin_area_india_km2": null,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["rajasthan"], "aliases": [],
    "_needs_verification": ["basin_area_india_km2: not found in searched sources"],
    "_source": "RAS exam notes (justprepraj.com): 512km, source near Kumbhalgarh (Aravallis), entirely Rajasthan, joins Chambal at Rameshwaram (Sawai Madhopur); non-perennial per same source (\"only two perennial rivers in Rajasthan: Chambal and Mahi\")"
  },
  {
    "id": "kali-sindh", "name": "Kali Sindh", "local_name_hi": "काली सिंध",
    "basin": "ganga-basin", "length_km_india": 550, "basin_area_india_km2": 48492,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["madhya-pradesh", "rajasthan"], "aliases": ["Kali Sindhu"],
    "_needs_verification": ["seasonal_type: inferred (not perennial per Rajasthan-rivers source), not independently confirmed"],
    "_source": "Wikipedia: 550km (405km MP + 145km Rajasthan), basin 48,492 km2, tributary of Chambal"
  },
  {
    "id": "parbati", "name": "Parbati", "local_name_hi": "पार्वती",
    "basin": "ganga-basin", "length_km_india": 385, "basin_area_india_km2": null,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["madhya-pradesh", "rajasthan"], "aliases": [],
    "_needs_verification": ["length_km_india: single secondary source (waterwaymap.org), not cross-checked", "basin_area_india_km2: not found", "seasonal_type: inferred, not independently confirmed"],
    "_source": "waterwaymap.org river-length list: 385km; jatland wiki confirms Parbati as Chambal tributary via Madhya Pradesh/Rajasthan"
  },
  {
    "id": "betwa", "name": "Betwa", "local_name_hi": "बेतवा",
    "basin": "ganga-basin", "length_km_india": 590, "basin_area_india_km2": 46580,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["madhya-pradesh", "uttar-pradesh"], "aliases": ["Vetravati"],
    "_needs_verification": ["seasonal_type: inferred from general Bundelkhand-region drought/low-flow characteristics, not independently confirmed for this specific river"],
    "_source": "India-WRIS Yamuna River System wiki: source Bhopal district MP, 590km, basin 46,580 km2 (31,971 MP + 14,609 UP)"
  },
  {
    "id": "ken", "name": "Ken", "local_name_hi": "केन",
    "basin": "ganga-basin", "length_km_india": 427, "basin_area_india_km2": 28058,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["madhya-pradesh", "uttar-pradesh"], "aliases": ["Karnavati"],
    "_needs_verification": ["seasonal_type: inferred from general Bundelkhand-region drought/low-flow characteristics, not independently confirmed for this specific river"],
    "_source": "Wikipedia: 427km (292km MP + 84km UP + 51km boundary), source Barner Range Katni district MP; India-WRIS: basin 28,058 km2 (24,472 MP + 3,386 UP)"
  },
  {
    "id": "son", "name": "Son", "local_name_hi": "सोन",
    "basin": "ganga-basin", "length_km_india": 784, "basin_area_india_km2": null,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["madhya-pradesh", "chhattisgarh", "uttar-pradesh", "jharkhand", "bihar"],
    "aliases": ["Sone", "Sonbhadra"],
    "_needs_verification": ["basin_area_india_km2: not found in searched sources", "seasonal_type: marked perennial as largest southern Ganga tributary with substantial baseflow, not independently confirmed against a govt source"],
    "_source": "Wikipedia: 784km, source near Amarkantak MP, joins Ganga at Maner (Patna district, Bihar)"
  }
]
JSON_EOF

node << 'NODE_EOF'
const fs = require('fs');
const existing = JSON.parse(fs.readFileSync('research/rivers-index-draft.json', 'utf8'));
const batch = JSON.parse(fs.readFileSync('.tmp-patch/ganga-batch2a.json', 'utf8'));

const existingIds = new Set(existing.map(r => r.id));
const dupes = batch.filter(r => existingIds.has(r.id));
if (dupes.length) {
  console.error('ERROR: duplicate river id(s) already in draft:', dupes.map(r => r.id).join(', '));
  process.exit(1);
}

const merged = existing.concat(batch);
fs.writeFileSync('research/rivers-index-draft.json', JSON.stringify(merged, null, 2) + '\n');
console.log('==> research/rivers-index-draft.json now has ' + merged.length + ' entries (+' + batch.length + ')');
NODE_EOF

mkdir -p .tmp-patch
cat > .tmp-patch/old_status.txt << 'OLD_EOF'
## Current status: Step 7 in progress — rivers-index.json metadata research, batch 1/9 (Indus system) done

### rivers-index.json research progress (`research/rivers-index-draft.json`)
Built via web research (batched by river system per spec §4.9), NOT the shapefile's `build/rivers-govt-metadata.json` seed from Step 5c — that file lives in your gitignored `build/` dir from a prior session and wasn't available to cross-check here. **Action needed**: if you still have that file, share it so the overlapping fields (basin/origin text for the 61 matched rivers) can be reconciled against this research — government-sourced beats web-sourced where they conflict.
- Batch 1/9 done: **Indus system** (9 rivers) — Indus, Jhelum, Chenab, Ravi, Beas, Sutlej, Spiti, Zanskar, Shyok
- Each entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)
- Fields with genuine sourcing gaps are flagged in each entry's `_needs_verification` array with the specific gap — not silently guessed. Worst offender: **Chenab** (conflicting length-in-India figures across sources, 960-1180km, no authoritative India-only figure found; `basin_area_india_km2` left `null`)
- `_source` field on each entry records what was used (CWC "About Basins" preferred where available, Wikipedia/WRIS wiki otherwise) — strip before final schema validation
- 8/9 systems remaining: Ganga, Yamuna & tributaries, Brahmaputra, Peninsular East-flowing (Godavari/Krishna/Kaveri/etc.), Peninsular West-flowing (Narmada/Tapi/etc.), Northeast tributaries, Coastal/minor, Himalayan-other — batching order not yet fixed, doing them roughly in spec §4.9 list order unless told otherwise

### Not started yet
- **8 remaining river-system batches** for rivers-index.json (see above)
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
1. Continue rivers-index.json research, next batch: **Ganga system** (or reorder if you'd rather prioritize differently)
2. In parallel/after: rescoped Overpass for the 44 unmatched rivers' geometry
3. Once both are further along: reconcile `research/rivers-index-draft.json` against Step 5c's `build/rivers-govt-metadata.json` seed (send it over if you have it) before running `prepareRivers.js`
OLD_EOF

cat > .tmp-patch/new_status.txt << 'NEW_EOF'
## Current status: Step 7 in progress — rivers-index.json metadata research, 20/105 rivers done

### rivers-index.json research progress (`research/rivers-index-draft.json`)
Built via web research (batched by river system per spec §4.9), NOT the shapefile's `build/rivers-govt-metadata.json` seed from Step 5c — that file lives in your gitignored `build/` dir from a prior session and wasn't available to cross-check here. **Action needed**: if you still have that file, share it so the overlapping fields (basin/origin text for the 61 matched rivers) can be reconciled against this research — government-sourced beats web-sourced where they conflict.

**Correction**: spec §4.9 actually defines 7 river-system groups, not 9 — Indus, Ganga, Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage. Fixing the miscount from the last update.

- **Indus system** (9/9 done): Indus, Jhelum, Chenab, Ravi, Beas, Sutlej, Spiti, Zanskar, Shyok
- **Ganga system** (11/26 done): Ganga, Bhagirathi, Alaknanda, Yamuna, Chambal, Banas, Kali Sindh, Parbati, Betwa, Ken, Son — remaining 15: Gomti, Ghaghra/Karnali, Sarda/Sharda, Gandak, Burhi Gandak, Kosi, Mahananda, Mechi, Kamla, Bagmati, Damodar, Hooghly, Barakar, Ajay, Rupnarayan
- Each entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)
- Fields with genuine sourcing gaps are flagged in each entry's `_needs_verification` array with the specific gap — not silently guessed. Worst offenders so far: **Chenab** (conflicting India-length figures, 960-1180km); **Yamuna** `basin_area_india_km2` (366,223km2 is the standard textbook figure, not independently re-confirmed this session); several MP/Rajasthan Chambal tributaries have inferred (not sourced) `seasonal_type`
- `_source` field on each entry records what was used (CWC preferred where available, then India-WRIS wiki, then Wikipedia/secondary) — strip before final schema validation
- 5 river-system groups remaining after Ganga: Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage

### Not started yet
- Rest of Ganga system (15 rivers) + 5 remaining river-system groups for rivers-index.json (see above)
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
1. Continue rivers-index.json research: rest of Ganga system (Gomti/Ghaghra/Gandak/Kosi group next, or reorder if you'd rather)
2. In parallel/after: rescoped Overpass for the 44 unmatched rivers' geometry
3. Once both are further along: reconcile `research/rivers-index-draft.json` against Step 5c's `build/rivers-govt-metadata.json` seed (send it over if you have it) before running `prepareRivers.js`
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
git commit -q -m "Step 7 (in progress): rivers-index.json research — Ganga mainstem + Yamuna/Chambal group (11 rivers, 20/105 total)" \
  || echo "Commit skipped (configure 'git config user.name/user.email' then commit manually)."

echo "==> Done."
