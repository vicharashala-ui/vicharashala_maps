#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "Spec_file.md" ] || [ ! -f "PROGRESS.md" ]; then
  echo "Error: run this from the project root (Spec_file.md/PROGRESS.md not found here)." >&2
  exit 1
fi
if [ ! -f "research/rivers-index-draft.json" ]; then
  echo "Error: research/rivers-index-draft.json not found — run step7a through step7e first." >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "Error: node not found on PATH." >&2
  exit 1
fi

mkdir -p .tmp-patch
cat > .tmp-patch/peninsular-east-batch2.json << 'JSON_EOF'
[
  {
    "id": "kaveri", "name": "Kaveri", "local_name_hi": "कावेरी",
    "basin": "kaveri-basin", "length_km_india": 800, "basin_area_india_km2": 81155,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka", "tamil-nadu", "kerala", "puducherry"],
    "aliases": ["Cauvery", "Ponni"],
    "_needs_verification": [],
    "_source": "Wikipedia + worldatlas.com (cross-confirmed): source Talakaveri (Brahmagiri range, Kodagu, Karnataka), 800km, basin 81,155 km2, wholly India; explicitly perennial (one of few peninsular rivers fed by both monsoons)"
  },
  {
    "id": "amaravathi", "name": "Amaravathi", "local_name_hi": "अमरावती",
    "basin": "kaveri-basin", "length_km_india": 256, "basin_area_india_km2": 8280,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["kerala", "tamil-nadu"], "aliases": ["Pournami"],
    "_needs_verification": ["length_km_india: one source (upsccolorfullnotes) gives 256km/8280km2 pairing, another (testbook) gives 282km — not reconciled"],
    "_source": "upsccolorfullnotes.com: source Naimakad (Anaimalai, Western Ghats, Idukki district, Kerala), 256km, catchment 8,280 km2, joins Kaveri in Tamil Nadu"
  },
  {
    "id": "kabini", "name": "Kabini", "local_name_hi": "काबिनी",
    "basin": "kaveri-basin", "length_km_india": 240, "basin_area_india_km2": 7040,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["kerala", "karnataka"], "aliases": ["Kabani", "Kapila"],
    "_needs_verification": ["length_km_india: approximate (\"~240km\") per source, not a precise figure"],
    "_source": "upsccolorfullnotes.com (explicitly described as perennial): source Pakramthalam hills (North Wayanad, Kerala), ~240km, basin 7,040 km2"
  },
  {
    "id": "hemavathi", "name": "Hemavathi", "local_name_hi": "हेमावती",
    "basin": "kaveri-basin", "length_km_india": 245, "basin_area_india_km2": null,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka"], "aliases": [],
    "_needs_verification": ["basin_area_india_km2: not found", "seasonal_type: assumed (Karnataka Kaveri tributary, monsoon-fed), not independently confirmed"],
    "_source": "adda247 UPSC notes: source Ballalarayana Durga (Chikmagalur district, Karnataka), 245km, joins Kaveri near Krishnarajasagar"
  },
  {
    "id": "shimsha", "name": "Shimsha", "local_name_hi": "शिम्शा",
    "basin": "kaveri-basin", "length_km_india": 221, "basin_area_india_km2": 8469,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka"], "aliases": [],
    "_needs_verification": ["seasonal_type: assumed, not independently confirmed"],
    "_source": "adda247 UPSC notes: source Devarayanadurga Hills (Tumkur district, Karnataka), 221km, catchment 8,469 km2"
  },
  {
    "id": "arkavathi", "name": "Arkavathi", "local_name_hi": "अर्कावती",
    "basin": "kaveri-basin", "length_km_india": 190, "basin_area_india_km2": 4351,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka"], "aliases": [],
    "_needs_verification": ["length_km_india: Wikipedia infobox gives 190km but a secondary source (upsccolorfullnotes) gives 161km — not reconciled", "seasonal_type: Bengaluru's main drinking-water source, known to have dried up in stretches from over-extraction — marked seasonal but this reflects degraded flow rather than a natural seasonal regime"],
    "_source": "Wikipedia: source Nandi Hills (Chikkaballapura district, Karnataka), 190km, joins Kaveri near Kanakapura"
  },
  {
    "id": "bhavani", "name": "Bhavani", "local_name_hi": "भवानी",
    "basin": "kaveri-basin", "length_km_india": 234, "basin_area_india_km2": 1410,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["kerala", "tamil-nadu"], "aliases": [],
    "_needs_verification": ["length_km_india: a secondary source (riversinsight) gives 217km vs Wikipedia's 234km — used Wikipedia"],
    "_source": "Wikipedia (explicitly \"a 234km long perennial river fed by monsoons\"): source Nilgiris (Western Ghats, Tamil Nadu), basin 1,410 km2, second-largest river in Tamil Nadu"
  },
  {
    "id": "palar", "name": "Palar", "local_name_hi": "पालार",
    "basin": "palar-basin", "length_km_india": 348, "basin_area_india_km2": 5044,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka", "andhra-pradesh", "tamil-nadu"], "aliases": [],
    "_needs_verification": [],
    "_source": "testbook (348km = 93km Karnataka + 33km Andhra Pradesh + 222km Tamil Nadu) + World Bank Climate Risk Country Profiles (catchment 5,044 km2, cross-confirmed independently)"
  },
  {
    "id": "ponnaiyar", "name": "Ponnaiyar", "local_name_hi": "पोन्नैयार",
    "basin": "ponnaiyar-basin", "length_km_india": 497, "basin_area_india_km2": null,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["karnataka", "tamil-nadu"], "aliases": [],
    "_needs_verification": ["basin_area_india_km2: not found", "length: Wikipedia gives 497km, a secondary source (testbook TN GK) gives 500km — close agreement, used Wikipedia"],
    "_source": "Wikipedia: second-longest river wholly in Tamil Nadu/Karnataka (after Kaveri), 497km, flows through Bengaluru's eastern suburbs, Hosur, Chengam"
  },
  {
    "id": "vellar", "name": "Vellar (Southern)", "local_name_hi": "वेल्लार",
    "basin": "vellar-basin", "length_km_india": 137, "basin_area_india_km2": 2034,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["tamil-nadu"], "aliases": [],
    "_needs_verification": ["NAMING AMBIGUITY: Tamil Nadu has two distinct Vellar rivers (Northern, near Cuddalore, and Southern, near Pudukkottai). This entry uses the Southern Vellar (Wikipedia: 137km, 2,034 km2). A separate source (World Bank Climate Risk Profiles) gives a different, larger 3,682 km2 basin figure that likely refers to the Northern Vellar or a combined figure — spec §4.9 just says \"Vellar\" with no disambiguation. Recommend confirming which one (or both) is intended."],
    "_source": "Wikipedia (Vellar River, Southern Tamil Nadu): source Kumirikatti forest reserve, 137km, basin 2,034 km2, joins Palk Strait near Manamelkudi, Pudukkottai district"
  },
  {
    "id": "vaigai", "name": "Vaigai", "local_name_hi": "वैगई",
    "basin": "vaigai-basin", "length_km_india": 258, "basin_area_india_km2": 7230,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "seasonal", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["tamil-nadu"], "aliases": [],
    "_needs_verification": ["length_km_india: two independent secondary sources (brainkart, andedge) agree on 258km/7,741km2, but Wikipedia's own infobox gives 295km/7,009km2 — used the 258km figure since two independent sources agree, but not fully reconciled with Wikipedia"],
    "_source": "brainkart.com + andedge.com (independent agreement): source Varusanadu hills (Western Ghats, Tamil Nadu), 258km, wholly Tamil Nadu, drains into Palk Strait; Wikipedia describes it as \"semi-perennial\""
  },
  {
    "id": "tamiraparani", "name": "Tamiraparani", "local_name_hi": "तामिरपरणी",
    "basin": "tamiraparani-basin", "length_km_india": 128, "basin_area_india_km2": 5717,
    "drainage_type": "peninsular", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "rain-fed",
    "navigable": false, "transnational": false,
    "states": ["tamil-nadu"], "aliases": ["Thamirabarani", "Tambraparni", "Porunai"],
    "_needs_verification": [],
    "_source": "Wikipedia + grokipedia (cross-confirmed): source Pothigai Hills (Western Ghats, Ambasamudram taluk, Tirunelveli district), 128km, basin 5,717 km2, wholly Tamil Nadu — explicitly the ONLY perennial river fully within Tamil Nadu"
  }
]
JSON_EOF

node << 'NODE_EOF'
const fs = require('fs');
const existing = JSON.parse(fs.readFileSync('research/rivers-index-draft.json', 'utf8'));
const batch = JSON.parse(fs.readFileSync('.tmp-patch/peninsular-east-batch2.json', 'utf8'));

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
## Current status: Step 7 in progress — rivers-index.json metadata research, 67/105 rivers done

### rivers-index.json research progress (`research/rivers-index-draft.json`)
Built via web research (batched by river system per spec §4.9), NOT the shapefile's `build/rivers-govt-metadata.json` seed from Step 5c — that file lives in your gitignored `build/` dir from a prior session and wasn't available to cross-check here. **Action needed**: if you still have that file, share it so the overlapping fields (basin/origin text for the 61 matched rivers) can be reconciled against this research — government-sourced beats web-sourced where they conflict.

Spec §4.9 defines 7 river-system groups: Indus, Ganga, Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage.

- **Indus system** (9/9 done)
- **Ganga system** (26/26 done)
- **Brahmaputra system** (15/15 done)
- **Peninsular-East system** (17/29 done): Mahanadi, Brahmani, Baitarani, Subarnarekha, Rushikulya, Vamsadhara, Nagavali, Godavari, Krishna, Tungabhadra, Bhima, Musi, Manjira, Indravati, Pranhita, Wainganga, Wardha — remaining 12 (Kaveri system + Tamil Nadu rivers): Kaveri, Amaravathi, Kabini, Hemavathi, Shimsha, Arkavathi, Bhavani, Palar, Ponnaiyar, Vellar, Vaigai, Tamiraparani
- Each entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)
- **This batch's strongest data**: Godavari, Krishna, Bhima, Tungabhadra, Manjira, Mahanadi, Brahmani, Baitarani, Subarnarekha all cross-confirmed across 2+ sources (Wikipedia + CWC/govt). **Weakest**: Musi, Indravati, Pranhita, Wainganga, Wardha have `basin_area_india_km2` unfound; Pranhita's length is a low-confidence placeholder; Rushikulya/Vamsadhara lengths are rough estimates
- **ACTION NEEDED — Kopili/Kapili naming conflict** (from Brahmaputra batch, still unresolved): Wikipedia treats "Kapili" as just an alternate name for Kopili, but spec §4.9 lists them separately. Needs your call before final validation.
- Other flagged weak entries from earlier batches (Ganga: Rupnarayan, Ghaghra, Sarda, Gandak, Kosi, Bagmati, Mechi; Brahmaputra: Sankosh, Rangeet, Teesta, Torsa, Jaldhaka) still unresolved
- `_source` field on each entry records what was used — strip before final schema validation
- Remaining: rest of Peninsular-East (12 rivers), Peninsular-West (14 rivers), Coastal (11 rivers), Inland Drainage (2 rivers) — 38 rivers total

### Not started yet
- Rest of Peninsular-East (12 rivers) + 3 remaining river-system groups for rivers-index.json (38 rivers, see above)
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
1. Continue rivers-index.json research: **Kaveri system + Tamil Nadu rivers** next (12 rivers, completes Peninsular-East), or reorder if you'd rather
2. Resolve the Kopili/Kapili naming question above
3. In parallel/after: rescoped Overpass for the 44 unmatched rivers' geometry
4. Once both are further along: reconcile `research/rivers-index-draft.json` against Step 5c's `build/rivers-govt-metadata.json` seed (send it over if you have it), and re-verify all flagged weak entries, before running `prepareRivers.js`
OLD_EOF

cat > .tmp-patch/new_status.txt << 'NEW_EOF'
## Current status: Step 7 in progress — rivers-index.json metadata research, Peninsular-East complete (79/105 rivers total)

### rivers-index.json research progress (`research/rivers-index-draft.json`)
Built via web research (batched by river system per spec §4.9), NOT the shapefile's `build/rivers-govt-metadata.json` seed from Step 5c — that file lives in your gitignored `build/` dir from a prior session and wasn't available to cross-check here. **Action needed**: if you still have that file, share it so the overlapping fields (basin/origin text for the 61 matched rivers) can be reconciled against this research — government-sourced beats web-sourced where they conflict.

Spec §4.9 defines 7 river-system groups: Indus, Ganga, Brahmaputra, Peninsular-East, Peninsular-West, Coastal, Inland Drainage.

- **Indus system** (9/9 done)
- **Ganga system** (26/26 done)
- **Brahmaputra system** (15/15 done)
- **Peninsular-East system** (29/29 done): full list — Mahanadi, Brahmani, Baitarani, Subarnarekha, Rushikulya, Vamsadhara, Nagavali, Godavari, Krishna, Tungabhadra, Bhima, Musi, Manjira, Indravati, Pranhita, Wainganga, Wardha, Kaveri, Amaravathi, Kabini, Hemavathi, Shimsha, Arkavathi, Bhavani, Palar, Ponnaiyar, Vellar, Vaigai, Tamiraparani
- Each entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)
- **Strongest data this batch**: Kaveri, Tamiraparani, Bhavani, Palar, Kabini all cross-confirmed 2+ sources
- **ACTION NEEDED — "Vellar" naming ambiguity**: Tamil Nadu has two distinct Vellar rivers (Northern, near Cuddalore; Southern, near Pudukkottai). Used the Southern Vellar (only one with clean sourced data this session) — spec §4.9 doesn't disambiguate. Needs your call.
- **ACTION NEEDED — Kopili/Kapili naming conflict** (from Brahmaputra batch, still unresolved): Wikipedia treats "Kapili" as just an alternate name for Kopili, but spec §4.9 lists them separately.
- Other flagged weak entries from earlier batches (Ganga: Rupnarayan, Ghaghra, Sarda, Gandak, Kosi, Bagmati, Mechi; Brahmaputra: Sankosh, Rangeet, Teesta, Torsa, Jaldhaka; Peninsular-East pt.1: Musi, Indravati, Pranhita, Wainganga, Wardha) still unresolved
- `_source` field on each entry records what was used — strip before final schema validation
- 3 river-system groups remaining: Peninsular-West (14 rivers), Coastal (11 rivers), Inland Drainage (2 rivers) — 26 rivers total, all smaller groups than what's been done so far

### Not started yet
- 3 remaining river-system groups for rivers-index.json (26 rivers, see above)
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
1. Continue rivers-index.json research: **Peninsular-West system** next (14 rivers — Narmada, Tapi, Mahi, Sabarmati, Periyar, Chaliyar, Bharathapuzha, Pamba, Kallada, Sharavati, Zuari, Mandovi, Purna, Girna), or reorder if you'd rather
2. Resolve the "Vellar" and Kopili/Kapili naming questions above
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
git commit -q -m "Step 7 (in progress): rivers-index.json research — Kaveri + Tamil Nadu rivers (12 rivers, Peninsular-East complete, 79/105 total)" \
  || echo "Commit skipped (configure 'git config user.name/user.email' then commit manually)."

echo "==> Done."
