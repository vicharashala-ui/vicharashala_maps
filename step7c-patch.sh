#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "Spec_file.md" ] || [ ! -f "PROGRESS.md" ]; then
  echo "Error: run this from the project root (Spec_file.md/PROGRESS.md not found here)." >&2
  exit 1
fi
if [ ! -f "research/rivers-index-draft.json" ]; then
  echo "Error: research/rivers-index-draft.json not found — run step7a-patch.sh and step7b-patch.sh first." >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "Error: node not found on PATH." >&2
  exit 1
fi

mkdir -p .tmp-patch
cat > .tmp-patch/ganga-batch2b.json << 'JSON_EOF'
[
  {
    "id": "gomti", "name": "Gomti", "local_name_hi": "गोमती",
    "basin": "ganga-basin", "length_km_india": 960, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["uttar-pradesh"], "aliases": ["Gumti", "Gomati"],
    "_needs_verification": ["basin_area_india_km2: not found", "length: sources split 900-960km (used Wikipedia infobox 960km); navigable historically per one colonial-era source, marked false for current-day pending confirmation"],
    "_source": "Wikipedia: entirely UP, source Gomat Taal (Pilibhit), 960km to confluence at Kaithi/Varanasi"
  },
  {
    "id": "ghaghra", "name": "Ghaghra (Karnali)", "local_name_hi": "घाघरा",
    "basin": "ganga-basin", "length_km_india": 503, "basin_area_india_km2": 57578,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["uttar-pradesh", "bihar"], "aliases": ["Karnali", "Manchu"],
    "_needs_verification": ["length_km_india and basin_area_india_km2 are DERIVED, not directly sourced: total length 1080km (CWC) minus Nepal's 507km (largest river in Nepal, per Wikipedia) minus ~70km Tibet stretch = ~503km estimate; basin_area = 45% of CWC's 127,000 km2 total catchment figure. Needs a direct India-only source.", "navigable: historically used for steamer navigation per one source, not confirmed current-day"],
    "_source": "CWC Upper Ganga Basin Organisation (cwc.gov.in/ugbo/gangabasin/ghaghra): total length 1080km to Ganga confluence at Doriganj Bihar, catchment 127,000 km2 (45% India); Wikipedia for Nepal-portion length"
  },
  {
    "id": "sarda", "name": "Sarda (Sharda)", "local_name_hi": "शारदा",
    "basin": "ganga-basin", "length_km_india": 350, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["uttarakhand", "uttar-pradesh"], "aliases": ["Kali", "Mahakali"],
    "_needs_verification": ["length_km_india: rough estimate, no precise figure found (Wikipedia confirms only a ~100km fully-in-UP segment near the end)", "basin_area_india_km2: not found"],
    "_source": "Wikipedia (Sarda River): downstream name of Kali/Mahakali below Brahmadev Mandi barrage in Nepal; forms India-Nepal border, source Nanda Devi massif glaciers (Pithoragarh)"
  },
  {
    "id": "gandak", "name": "Gandak", "local_name_hi": "गंडक",
    "basin": "ganga-basin", "length_km_india": 260, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["uttar-pradesh", "bihar"], "aliases": ["Gandaki", "Narayani", "Sapt Gandaki"],
    "_needs_verification": ["length_km_india: rough estimate (total 814km, mostly Nepal per Wikipedia — India/Bihar-only portion not directly confirmed)", "basin_area_india_km2: a Bihar-government-context source gave 40,553 km2 which is implausible (exceeds Wikipedia's total basin of 46,300 km2 'most of it in Nepal') — discarded as likely erroneous, left null pending a reliable figure"],
    "_source": "Wikipedia (Gandaki River): source Nhubine Himal Glacier (Mustang, Nepal), total 814km, total basin 46,300 km2"
  },
  {
    "id": "burhi-gandak", "name": "Burhi Gandak", "local_name_hi": "बूढ़ी गंडक",
    "basin": "ganga-basin", "length_km_india": 320, "basin_area_india_km2": 10150,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": true,
    "states": ["bihar"], "aliases": ["Sikrahna"],
    "_needs_verification": ["transnational: marked true because a Bihar-government source cites 2,420 km2 of hilly catchment in Nepal, though the main channel and length figure (320km) are wholly within Bihar per Wikipedia"],
    "_source": "Wikipedia: source Chautarwa Chaur (West Champaran), 320km, basin 10,150 km2, wholly Bihar; Bihar govt source (studyiq) for Nepal catchment portion"
  },
  {
    "id": "kosi", "name": "Kosi", "local_name_hi": "कोसी",
    "basin": "ganga-basin", "length_km_india": 260, "basin_area_india_km2": 11410,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["bihar"], "aliases": ["Koshi", "Saptakoshi", "Sorrow of Bihar"],
    "_needs_verification": ["length_km_india: rough estimate — total length 729km (Wikipedia) spans Tibet+Nepal+Bihar, no direct India-only figure found"],
    "_source": "Bihar govt source (FMISC/studyiq): India catchment 11,410 km2 of 74,030 km2 total (rest in Tibet/Nepal); Wikipedia for total length"
  },
  {
    "id": "mahananda", "name": "Mahananda", "local_name_hi": "महानंदा",
    "basin": "ganga-basin", "length_km_india": 324, "basin_area_india_km2": 11530,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": true,
    "states": ["west-bengal", "bihar"], "aliases": [],
    "_needs_verification": [],
    "_source": "Wikipedia: source Paglajhora Falls (Darjeeling hills), 324km of 360km total in India, 11,530 km2 of 20,600 km2 total basin in India"
  },
  {
    "id": "mechi", "name": "Mechi", "local_name_hi": "मेची",
    "basin": "ganga-basin", "length_km_india": 20, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": true,
    "states": ["bihar"], "aliases": [],
    "_needs_verification": ["length_km_india: rough placeholder only — small border river, mostly forms the India-Nepal boundary before a short stretch into Kishanganj district (Bihar) to its Mahananda confluence; no direct figure found", "basin_area_india_km2: not found for Mechi specifically (only the combined Mahananda-system India catchment of 11,520 km2 was found, which overlaps with the Mahananda entry above and shouldn't be double-counted)"],
    "_source": "Wikipedia: source Mahabharat Range (Nepal), forms India-Nepal border, joins Mahananda at Kishanganj district, Bihar"
  },
  {
    "id": "kamla", "name": "Kamla", "local_name_hi": "कमला",
    "basin": "ganga-basin", "length_km_india": null, "basin_area_india_km2": 4488,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": true,
    "states": ["bihar"], "aliases": ["Kamla Balan", "Balan"],
    "_needs_verification": ["length_km_india: no figure found in searched sources, left null"],
    "_source": "Bihar govt source (beams.fmiscwrdbihar.gov.in): India (Bihar) catchment 4,488 km2 of 7,232 km2 total (rest Nepal); enters India at Jaynagar, Madhubani district"
  },
  {
    "id": "bagmati", "name": "Bagmati", "local_name_hi": "बागमती",
    "basin": "ganga-basin", "length_km_india": 394, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": true,
    "states": ["bihar"], "aliases": [],
    "_needs_verification": ["length_km_india: single low-authority source (testbook trivia Q&A, 394km); Wikipedia's own infobox (586.3km total) and a secondary source (360km total) disagree — not reconciled", "basin_area_india_km2: not found"],
    "_source": "testbook.com trivia Q&A (394km India portion, low confidence); Wikipedia: source Baghdwar Falls (Shivapuri, Kathmandu), joins Kamla in Bihar"
  },
  {
    "id": "damodar", "name": "Damodar", "local_name_hi": "दामोदर",
    "basin": "ganga-basin", "length_km_india": 592, "basin_area_india_km2": 25820,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["jharkhand", "west-bengal"], "aliases": ["River of Sorrows", "Damuda"],
    "_needs_verification": [],
    "_source": "Wikipedia + multiple corroborating sources: source Khamarpat Hill (Chota Nagpur Plateau, Palamau), 592km, basin 25,820 km2, wholly Jharkhand/West Bengal"
  },
  {
    "id": "hooghly", "name": "Hooghly", "local_name_hi": "हुगली",
    "basin": "ganga-basin", "length_km_india": 260, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "mixed",
    "navigable": true, "transnational": false,
    "states": ["west-bengal"], "aliases": ["Bhagirathi-Hooghly"],
    "_needs_verification": ["basin_area_india_km2: not applicable in the usual sense — Hooghly is a Ganga distributary, not an independently-basined river; left null rather than force a number"],
    "_source": "Wikipedia: westernmost Ganga distributary, 260km, splits off at Giria and flows to Bay of Bengal via Kolkata; major shipping channel to Kolkata Port"
  },
  {
    "id": "barakar", "name": "Barakar", "local_name_hi": "बराकर",
    "basin": "ganga-basin", "length_km_india": 256, "basin_area_india_km2": 6159,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["jharkhand", "west-bengal"], "aliases": [],
    "_needs_verification": ["seasonal_type: inferred (smaller Chota Nagpur tributary), not independently confirmed"],
    "_source": "Wikipedia: source near Padma (Hazaribagh district), 256km, catchment 6,159 km2, wholly India, main tributary of Damodar"
  },
  {
    "id": "ajay", "name": "Ajay", "local_name_hi": "अजय",
    "basin": "ganga-basin", "length_km_india": 288, "basin_area_india_km2": 6000,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["bihar", "jharkhand", "west-bengal"], "aliases": [],
    "_needs_verification": [],
    "_source": "Wikipedia (288km, cross-checked riversinsight): source Jamui Hills (Bihar), joins Bhagirathi-Hooghly at Katwa, catchment ~6,000 km2, explicitly described as seasonal by riversinsight"
  },
  {
    "id": "rupnarayan", "name": "Rupnarayan", "local_name_hi": "रूपनारायण",
    "basin": "ganga-basin", "length_km_india": 176, "basin_area_india_km2": null,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["west-bengal"], "aliases": ["Dwarakeswar-Shilabati"],
    "_needs_verification": ["length_km_india: LOW CONFIDENCE placeholder (~176km) — not found/confirmed in this session's searches, needs a direct source", "basin_area_india_km2: not found", "seasonal_type: inferred, not independently confirmed"],
    "_source": "General knowledge only (not verified this session) — formed by confluence of Dwarakeswar and Shilabati rivers, joins Hooghly near Geonkhali; flagged as the weakest-sourced entry in this batch, recommend priority re-check"
  }
]
JSON_EOF

node << 'NODE_EOF'
const fs = require('fs');
const existing = JSON.parse(fs.readFileSync('research/rivers-index-draft.json', 'utf8'));
const batch = JSON.parse(fs.readFileSync('.tmp-patch/ganga-batch2b.json', 'utf8'));

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
OLD_EOF

cat > .tmp-patch/new_status.txt << 'NEW_EOF'
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
git commit -q -m "Step 7 (in progress): rivers-index.json research — rest of Ganga system (15 rivers, Ganga system complete, 35/105 total)" \
  || echo "Commit skipped (configure 'git config user.name/user.email' then commit manually)."

echo "==> Done."
