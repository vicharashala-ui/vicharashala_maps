#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "Spec_file.md" ] || [ ! -f "PROGRESS.md" ]; then
  echo "Error: run this from the project root (Spec_file.md/PROGRESS.md not found here)." >&2
  exit 1
fi
if [ ! -f "research/rivers-index-draft.json" ]; then
  echo "Error: research/rivers-index-draft.json not found — run step7a/7b/7c-patch.sh first." >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "Error: node not found on PATH." >&2
  exit 1
fi

mkdir -p .tmp-patch
cat > .tmp-patch/brahmaputra-batch.json << 'JSON_EOF'
[
  {
    "id": "brahmaputra", "name": "Brahmaputra", "local_name_hi": "ब्रह्मपुत्र",
    "basin": "brahmaputra-basin", "length_km_india": 916, "basin_area_india_km2": 194413,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": true, "transnational": true,
    "states": ["arunachal-pradesh", "assam"],
    "aliases": ["Tsangpo", "Yarlung Tsangpo", "Siang", "Dihang"],
    "_needs_verification": [],
    "_source": "India-WRIS wiki: source Kailash ranges (Konggyu Tsho, Tibet), 2900km total, 916km in India, basin 194,413 km2 in India (5.9% of country); navigable as National Waterway 2"
  },
  {
    "id": "dibang", "name": "Dibang", "local_name_hi": "दिबांग",
    "basin": "brahmaputra-basin", "length_km_india": 324, "basin_area_india_km2": 13933,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": false,
    "states": ["arunachal-pradesh"], "aliases": ["Talon"],
    "_needs_verification": [],
    "_source": "Wikipedia: source Dri/Tangon confluence, 324km, basin 13,933 km2, wholly Arunachal Pradesh, joins Lohit near Sadiya"
  },
  {
    "id": "lohit", "name": "Lohit", "local_name_hi": "लोहित",
    "basin": "brahmaputra-basin", "length_km_india": 200, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["arunachal-pradesh", "assam"], "aliases": ["Zayul Chu"],
    "_needs_verification": ["length_km_india: rough estimate — total length 560km (Wikipedia) spans Tibet + Arunachal Pradesh + Assam, no direct India-only figure found", "basin_area_india_km2: not found (total basin 41,499 km2 spans China/India)"],
    "_source": "Wikipedia: source Kangri Karpo (Zayul County, Tibet), joins Siang near Sadiya, Assam to form Brahmaputra"
  },
  {
    "id": "subansiri", "name": "Subansiri", "local_name_hi": "सुबानसिरी",
    "basin": "brahmaputra-basin", "length_km_india": 382, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["arunachal-pradesh", "assam"], "aliases": ["Gold River"],
    "_needs_verification": ["basin_area_india_km2: not found"],
    "_source": "byjus.com: total 442km (192km Arunachal Pradesh + 190km Assam + rest Tibet); largest Brahmaputra tributary"
  },
  {
    "id": "kameng", "name": "Kameng", "local_name_hi": "कामेंग",
    "basin": "brahmaputra-basin", "length_km_india": 150, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["arunachal-pradesh", "assam"], "aliases": ["Jia Bharali", "Bhareli"],
    "_needs_verification": ["origin/transnational: source described only as \"unsurveyed hills, presumably Tibet\" — not independently confirmed", "basin_area_india_km2: not found"],
    "_source": "byjus.com: ~250km total, 90km Arunachal Pradesh + 60km Assam"
  },
  {
    "id": "dhansiri", "name": "Dhansiri", "local_name_hi": "धनसिरी",
    "basin": "brahmaputra-basin", "length_km_india": 352, "basin_area_india_km2": 1220,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["nagaland", "assam"], "aliases": [],
    "_needs_verification": ["basin_area_india_km2: 1,220 km2 (Wikipedia) seems small relative to a 352km-long river — flagging for a sanity-check re-source"],
    "_source": "Wikipedia: source Laisang Peak (Nagaland), 352km, wholly India, joins Brahmaputra on south bank"
  },
  {
    "id": "manas", "name": "Manas", "local_name_hi": "मानस",
    "basin": "brahmaputra-basin", "length_km_india": 104, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["assam"], "aliases": ["Drangme Chhu"],
    "_needs_verification": ["basin_area_india_km2: not found (total system large, India-only portion unclear)"],
    "_source": "Wikipedia: total 400km (24km Tibet + 272km Bhutan + 104km Assam), joins Brahmaputra at Jogighopa"
  },
  {
    "id": "sankosh", "name": "Sankosh", "local_name_hi": "संकोश",
    "basin": "brahmaputra-basin", "length_km_india": 85, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["assam", "west-bengal"], "aliases": ["Puna Tsang Chu"],
    "_needs_verification": ["length_km_india: LOW CONFIDENCE placeholder — no length figure found at all this session, not even a total length", "basin_area_india_km2: not found"],
    "_source": "Wikipedia: rises northern Bhutan, forms part of Assam-West Bengal border before joining Brahmaputra — no length data in the article"
  },
  {
    "id": "teesta", "name": "Teesta", "local_name_hi": "तीस्ता",
    "basin": "brahmaputra-basin", "length_km_india": 414, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["sikkim", "west-bengal"], "aliases": ["Tista"],
    "_needs_verification": ["length_km_india: single source gave 414km total; commonly-cited alternate figures (~309km) exist elsewhere and weren't reconciled this session", "basin_area_india_km2: not found"],
    "_source": "Osmanian river-list (414km, low-to-medium authority): source Pahunri Glacier (Sikkim), flows through Sikkim/West Bengal into Bangladesh to join Brahmaputra"
  },
  {
    "id": "rangeet", "name": "Rangeet", "local_name_hi": "रंगीत",
    "basin": "brahmaputra-basin", "length_km_india": 65, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": false,
    "states": ["sikkim"], "aliases": ["Rangit", "Ranjit"],
    "_needs_verification": ["length_km_india: LOW CONFIDENCE placeholder — no length figure found this session", "basin_area_india_km2: not found"],
    "_source": "waterwaymap.org confirms Rangeet as a Sikkim waterway and Teesta tributary — no length data found"
  },
  {
    "id": "torsa", "name": "Torsa", "local_name_hi": "तोर्षा",
    "basin": "brahmaputra-basin", "length_km_india": 100, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["west-bengal"], "aliases": ["Amo Chhu", "Machu"],
    "_needs_verification": ["length_km_india: DERIVED (total 358km minus 113km Tibet minus 145km Bhutan = ~100km), not a direct source", "basin_area_india_km2: not found"],
    "_source": "Wikipedia: source Chumbi Valley (Tibet), flows through Bhutan then India then Bangladesh to join Brahmaputra"
  },
  {
    "id": "jaldhaka", "name": "Jaldhaka", "local_name_hi": "जलढाका",
    "basin": "brahmaputra-basin", "length_km_india": 193, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "spring-fed",
    "navigable": false, "transnational": true,
    "states": ["sikkim", "west-bengal"], "aliases": ["Dichu"],
    "_needs_verification": ["length_km_india: DERIVED (total 233km minus ~40km Bhutan stretch = ~193km) and doesn't separately account for a Bangladesh portion — treat as rough", "basin_area_india_km2: not found"],
    "_source": "Wikipedia: source Bitang Lake (Kupup, Sikkim), flows Sikkim → Bhutan (~40km) → re-enters India at Bindu, Kalimpong → eventually Bangladesh"
  },
  {
    "id": "barak", "name": "Barak", "local_name_hi": "बराक",
    "basin": "brahmaputra-basin", "length_km_india": 524, "basin_area_india_km2": 41723,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": true, "transnational": true,
    "states": ["manipur", "mizoram", "assam"], "aliases": [],
    "_needs_verification": [],
    "_source": "Wikipedia: source Liyai Khullen village (Manipur), 524km of 900km total in India, basin 41,723 km2 of 52,000 km2 total in India; navigable — National Waterway 16 (Lakhipur-Bhanga, 121km)"
  },
  {
    "id": "kopili", "name": "Kopili", "local_name_hi": "कोपिली",
    "basin": "brahmaputra-basin", "length_km_india": 290, "basin_area_india_km2": 16420,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["meghalaya", "assam"], "aliases": ["Kapili"],
    "_needs_verification": ["ALIAS FLAG: Wikipedia treats 'Kapili' as an alternate name for this same Kopili river, but spec §4.9 lists Kopili and Kapili as two separate entries. Recommend clarifying with the user whether Kapili should be (a) merged into this entry, (b) a genuinely distinct river, or (c) dropped as a duplicate before final validation."],
    "_source": "Wikipedia: source Meghalaya plateau, 290km, basin 16,420 km2, wholly India (Meghalaya + Assam), largest south-bank Brahmaputra tributary"
  },
  {
    "id": "kapili", "name": "Kapili", "local_name_hi": "कापिली",
    "basin": "brahmaputra-basin", "length_km_india": null, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["assam"], "aliases": [],
    "_needs_verification": ["ENTIRE ENTRY IS A PLACEHOLDER pending clarification — Wikipedia's Kopili River article states 'Kapili' is simply an alternate name for the Kopili river (previous entry), not a separate river. No independent Kapili data was found this session. All fields here (states, drainage/origin/seasonal type) are copied from the Kopili entry as a best guess only — do not treat as sourced."],
    "_source": "None found independently — see needs_verification"
  }
]
JSON_EOF

node << 'NODE_EOF'
const fs = require('fs');
const existing = JSON.parse(fs.readFileSync('research/rivers-index-draft.json', 'utf8'));
const batch = JSON.parse(fs.readFileSync('.tmp-patch/brahmaputra-batch.json', 'utf8'));

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
## Current status: Step 7 in progress — rivers-index.json metadata research, Ganga system complete (35/105 rivers total)

### rivers-index.json research progress (`research/rivers-index-draft.json`)
Built via web research (batched by river system per spec §4.9), NOT the shapefile's `build/rivers-govt-metadata.json` seed from Step 5c — that file lives in your gitignored `build/` dir from a prior session and wasn't available to cross-check here. **Action needed**: if you still have that file, share it so the overlapping fields (basin/origin text for the 61 matched rivers) can be reconciled against this research — government-sourced beats web-sourced where they conflict.

Spec §4.9 defines 7 river-system groups: Indus, Ganga, Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage.

- **Indus system** (9/9 done)
- **Ganga system** (26/26 done): full list — Ganga, Bhagirathi, Alaknanda, Yamuna, Chambal, Banas, Kali Sindh, Parbati, Betwa, Ken, Son, Gomti, Ghaghra/Karnali, Sarda/Sharda, Gandak, Burhi Gandak, Kosi, Mahananda, Mechi, Kamla, Bagmati, Damodar, Hooghly, Barakar, Ajay, Rupnarayan
- Each entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)
- **Weakest entries in the Ganga system batch** (flag before relying on these): **Rupnarayan** — `length_km_india` is an unverified placeholder, no source found this session; **Ghaghra**, **Sarda**, **Gandak**, **Kosi** — `length_km_india`/`basin_area_india_km2` are derived estimates (India-only split not directly sourced, total lengths span Tibet/Nepal/China); **Bagmati** — length sourced from a single low-authority trivia site, conflicts with Wikipedia's own infobox; **Mechi** — length is a rough placeholder for a small border river
- `_source` field on each entry records what was used (CWC preferred, then India-WRIS wiki / state government sources, then Wikipedia/secondary) — strip before final schema validation
- 5 river-system groups remaining: Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage (70 rivers)

### Not started yet
- 5 remaining river-system groups for rivers-index.json (70 rivers, see above)
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
1. Continue rivers-index.json research: **Brahmaputra system** next (15 rivers), or reorder if you'd rather
2. In parallel/after: rescoped Overpass for the 44 unmatched rivers' geometry
3. Once both are further along: reconcile `research/rivers-index-draft.json` against Step 5c's `build/rivers-govt-metadata.json` seed (send it over if you have it), and specifically re-verify the weakest entries flagged above, before running `prepareRivers.js`
OLD_EOF

cat > .tmp-patch/new_status.txt << 'NEW_EOF'
## Current status: Step 7 in progress — rivers-index.json metadata research, Brahmaputra system complete (50/105 rivers total)

### rivers-index.json research progress (`research/rivers-index-draft.json`)
Built via web research (batched by river system per spec §4.9), NOT the shapefile's `build/rivers-govt-metadata.json` seed from Step 5c — that file lives in your gitignored `build/` dir from a prior session and wasn't available to cross-check here. **Action needed**: if you still have that file, share it so the overlapping fields (basin/origin text for the 61 matched rivers) can be reconciled against this research — government-sourced beats web-sourced where they conflict.

Spec §4.9 defines 7 river-system groups: Indus, Ganga, Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage.

- **Indus system** (9/9 done)
- **Ganga system** (26/26 done)
- **Brahmaputra system** (15/15 done): Brahmaputra, Dibang, Lohit, Subansiri, Kameng, Dhansiri, Manas, Sankosh, Teesta, Rangeet, Torsa, Jaldhaka, Barak, Kopili, Kapili
- Each entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)
- **ACTION NEEDED — Kopili/Kapili naming conflict**: Wikipedia treats "Kapili" as just an alternate name for the Kopili river, not a separate river, but spec §4.9 lists them as two distinct entries. The `kapili` draft entry is a placeholder with all fields copied from `kopili` and no independent source — needs your call on whether to merge, treat as genuinely distinct, or drop before final validation.
- **Weakest entries in the Brahmaputra batch**: **Sankosh**, **Rangeet** — length placeholders with literally no source found (not even a total length); **Teesta** — single source (414km) conflicts with a commonly-cited alternate figure (~309km) elsewhere, not reconciled; **Torsa**, **Jaldhaka** — lengths are derived (total minus known non-India segments), not directly sourced; **Lohit**, **Kameng**, **Manas**, **Sankosh** — `basin_area_india_km2` not found
- Weakest entries in the Ganga system batch (previous update, still unresolved): Rupnarayan, Ghaghra, Sarda, Gandak, Kosi, Bagmati, Mechi
- `_source` field on each entry records what was used — strip before final schema validation
- 4 river-system groups remaining: Peninsular-East (29 rivers), Peninsular-West (14 rivers), Coastal (11 rivers), Inland Drainage (2 rivers) — 56 rivers total

### Not started yet
- 4 remaining river-system groups for rivers-index.json (56 rivers, see above)
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
1. Continue rivers-index.json research: **Peninsular-East system** next (29 rivers — largest remaining group, will likely need 2+ sub-batches), or reorder if you'd rather
2. Resolve the Kopili/Kapili naming question above
3. In parallel/after: rescoped Overpass for the 44 unmatched rivers' geometry
4. Once both are further along: reconcile `research/rivers-index-draft.json` against Step 5c's `build/rivers-govt-metadata.json` seed (send it over if you have it), and re-verify all flagged weak entries, before running `prepareRivers.js`
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
git commit -q -m "Step 7 (in progress): rivers-index.json research — Brahmaputra system (15 rivers, 50/105 total)" \
  || echo "Commit skipped (configure 'git config user.name/user.email' then commit manually)."

echo "==> Done."
