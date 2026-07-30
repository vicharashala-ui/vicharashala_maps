#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "Spec_file.md" ] || [ ! -f "PROGRESS.md" ]; then
  echo "Error: run this from the project root (Spec_file.md/PROGRESS.md not found here)." >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "Error: node not found on PATH." >&2
  exit 1
fi

mkdir -p research

cat > research/rivers-index-draft.json << 'JSON_EOF'
[
  {
    "id": "indus", "name": "Indus", "local_name_hi": "सिन्धु",
    "basin": "indus-basin", "length_km_india": 709, "basin_area_india_km2": 321289,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["ladakh"], "aliases": ["Sindhu", "Singi Khamban"],
    "_needs_verification": [],
    "_source": "CWC Indus Basin Organisation (cwc.gov.in/ibo/about-basins): total 2880km/709km in India, catchment 321,289 km2 in India"
  },
  {
    "id": "jhelum", "name": "Jhelum", "local_name_hi": "झेलम",
    "basin": "indus-basin", "length_km_india": 165, "basin_area_india_km2": 17622,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "spring-fed",
    "navigable": true, "transnational": true,
    "states": ["jammu-and-kashmir"], "aliases": ["Vyeth", "Vitasta", "Hydaspes"],
    "_needs_verification": [],
    "_source": "India-WRIS wiki: length 402km to border, 165km in India (Kashmir Valley), catchment 17,622 km2. Navigable: traditional shikara/boat traffic in Srinagar/Wular reaches."
  },
  {
    "id": "chenab", "name": "Chenab", "local_name_hi": "चिनाब",
    "basin": "indus-basin", "length_km_india": 700, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["himachal-pradesh", "jammu-and-kashmir"], "aliases": ["Chandrabhaga", "Asikni"],
    "_needs_verification": ["length_km_india: estimated from CWC segment data (Chandra 125km + confluence-to-Akhnoor 504km + onward J&K stretch) — sources conflict (960-1180km claimed for total/India length across different pages), no single authoritative India-only figure found", "basin_area_india_km2: not found in searched sources, left null"],
    "_source": "India-WRIS chenab wiki (segment lengths); Wikipedia/Britannica (total length 974km); conflicting secondary sources"
  },
  {
    "id": "ravi", "name": "Ravi", "local_name_hi": "रावी",
    "basin": "indus-basin", "length_km_india": 725, "basin_area_india_km2": 14442,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["himachal-pradesh", "punjab"], "aliases": ["Iravati", "Purushni"],
    "_needs_verification": [],
    "_source": "CWC Indus Basin Organisation: 725km, 14,442 km2 catchment in India"
  },
  {
    "id": "beas", "name": "Beas", "local_name_hi": "ब्यास",
    "basin": "indus-basin", "length_km_india": 470, "basin_area_india_km2": 20303,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": false,
    "states": ["himachal-pradesh", "punjab"], "aliases": ["Vipasha", "Vipas", "Hyphasis"],
    "_needs_verification": [],
    "_source": "Wikipedia: entirely within India, 470km, basin 20,303 km2"
  },
  {
    "id": "sutlej", "name": "Sutlej", "local_name_hi": "सतलुज",
    "basin": "indus-basin", "length_km_india": 1050, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["himachal-pradesh", "punjab"], "aliases": ["Satluj", "Satadru", "Zungbal"],
    "_needs_verification": ["length_km_india: single secondary source only (vajiramandravi.com, 1450km total/1050km India) — not cross-checked against CWC", "basin_area_india_km2: not found"],
    "_source": "Vajiram & Ravi UPSC notes (secondary, not govt-sourced) — flagged, recommend CWC cross-check"
  },
  {
    "id": "spiti", "name": "Spiti", "local_name_hi": "स्पीति",
    "basin": "indus-basin", "length_km_india": 200, "basin_area_india_km2": 6300,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": false,
    "states": ["himachal-pradesh"], "aliases": [],
    "_needs_verification": ["length_km_india: approximate, no exact figure found in searched sources (only catchment area was confirmed)"],
    "_source": "Wikipedia (Spiti river/valley): catchment 6,300 km2, entirely Himachal Pradesh, tributary of Sutlej at Khab"
  },
  {
    "id": "zanskar", "name": "Zanskar", "local_name_hi": "जांस्कर",
    "basin": "indus-basin", "length_km_india": 134, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": false,
    "states": ["ladakh"], "aliases": [],
    "_needs_verification": ["basin_area_india_km2: not found"],
    "_source": "Wikidata: 134km; Wikipedia: entirely within Ladakh, joins Indus near Nimmu"
  },
  {
    "id": "shyok", "name": "Shyok", "local_name_hi": "श्योक",
    "basin": "indus-basin", "length_km_india": 400, "basin_area_india_km2": null,
    "drainage_type": "himalayan", "stream_order": null,
    "seasonal_type": "perennial", "origin_type": "glacial",
    "navigable": false, "transnational": true,
    "states": ["ladakh"], "aliases": ["Shayok"],
    "_needs_verification": ["length_km_india: rough estimate — total length 550km (Wikipedia) but river crosses into Pakistan-administered Gilgit-Baltistan before joining Indus near Skardu; India-only portion not found in sources", "basin_area_india_km2: not found (total basin 33,465 km2 spans India/Pakistan/China)"],
    "_source": "Wikipedia: source Rimo Glacier (Ladakh), total length 550km, basin 33,465 km2"
  }
]
JSON_EOF

node -e "const d=JSON.parse(require('fs').readFileSync('research/rivers-index-draft.json','utf8')); console.log('==> research/rivers-index-draft.json written and validated as JSON (' + d.length + ' entries)');"

mkdir -p .tmp-patch
cat > .tmp-patch/old_status.txt << 'OLD_EOF'
## Current status: Step 6 complete — HydroRIVERS join CONFIRMED on real data (24.5s, 61/61 matched)

### Not started yet
- **Running `joinHydroRivers.js` (v2) itself** — send me the console output when done
- **44 unmatched rivers** — still need Overpass (rescoped) or manual research for geometry
- **Full `rivers-index.json`** — still missing `local_name_hi`, `drainage_type`, `seasonal_type`, `origin_type`, `navigable`, `transnational`, `states`, `aliases` for all 105. Open question, still unresolved.
- `scripts/prepareRivers.js` (step ⑦), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
Two open workstreams, priority not yet chosen for the next session:
1. **Rescoped Overpass** for the 44 unmatched rivers' geometry (bbox-based, not the slow area-polygon query that 504'd before; also needs the Windows `process.exit()` crash fix)
2. **Full `rivers-index.json` research** — still unanswered: does the user have a source, or should this be built via web research from scratch (batched by river system, not all 105 at once)
OLD_EOF

cat > .tmp-patch/new_status.txt << 'NEW_EOF'
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
git commit -q -m "Step 7 (in progress): rivers-index.json research, batch 1/9 — Indus system" \
  || echo "Commit skipped (configure 'git config user.name/user.email' then commit manually)."

echo "==> Done."
