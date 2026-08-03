#!/usr/bin/env bash
# step23-patch.sh — real protected_area_ids for the 7 Step 21 river files, from your
# Step 20/22 spatialIntersect.js run. chenab.json unchanged (its protected_area_ids is
# genuinely [] — no PA intersects Chenab in the current data).
# Run from project root in Git Bash. Idempotent.
set -euo pipefail

mkdir -p public/data/rivers

cat > public/data/rivers/indus.json << 'PATCH_EOF'
{
  "id": "indus",
  "name": "Indus",
  "aliases": ["Sindhu", "Singi Khamban"],
  "local_names": { "hi": "सिन्धु" },
  "basin": "indus-basin",
  "type": "main",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 8,
  "wikimedia_image_id": null,
  "source": {
    "name": "Sengge Zangbo (Senge Khabab, near Mount Kailash)",
    "state": "tibet",
    "altitude_m": 5469,
    "coordinates": [81.8117, 31.3122]
  },
  "sink": {
    "name": "Indus River Delta",
    "type": "sea",
    "location": "Arabian Sea, Sindh, Pakistan",
    "coordinates": [67.435, 23.995]
  },
  "length_km_india": 709,
  "length_km_total": 2880,
  "basin_area_total_km2": 1120000,
  "basin_area_india_km2": 321289,
  "states_flows_through": ["ladakh"],
  "basin_states": ["ladakh"],
  "tributaries": { "left": ["zanskar"], "right": ["shyok"] },
  "distributaries": [],
  "protected_area_ids": ["changthang-wls"],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["china", "pakistan"],
  "significance": ["irrigation", "strategic", "cultural"],
  "notable_city_ids": ["leh"],
  "upsc_relevant": true,
  "did_you_know": [
    "India's name is derived from the Sanskrit Sindhu, the ancient name of the Indus.",
    "In India the Indus flows only through Ladakh, entering near Demchok and exiting near Domkhar."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/ravi.json << 'PATCH_EOF'
{
  "id": "ravi",
  "name": "Ravi",
  "aliases": ["Iravati", "Purushni"],
  "local_names": { "hi": "रावी" },
  "basin": "indus-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Bara Bhangal (confluence of the Budhil and Tantgari streams)",
    "state": "himachal-pradesh",
    "altitude_m": 4000,
    "coordinates": [77.05, 32.25]
  },
  "sink": {
    "name": "Confluence with the Chenab",
    "type": "river",
    "location": "Near Ahmadpur Sial, Jhang district, Punjab, Pakistan",
    "coordinates": [72.25, 30.75]
  },
  "length_km_india": 320,
  "length_km_total": 725,
  "basin_area_total_km2": null,
  "basin_area_india_km2": 14442,
  "states_flows_through": ["himachal-pradesh", "punjab"],
  "basin_states": ["himachal-pradesh", "punjab"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": ["kathlaur-kushlian-wls"],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["pakistan"],
  "significance": ["irrigation", "hydropower", "historical"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Ravi is the smallest of the five rivers that give Punjab its name (panj-ab, 'five waters').",
    "Known as Iravati in the Rigveda, the Ravi is traditionally associated with the site of the Battle of the Ten Kings."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/beas.json << 'PATCH_EOF'
{
  "id": "beas",
  "name": "Beas",
  "aliases": ["Vipasha", "Vipas", "Hyphasis"],
  "local_names": { "hi": "ब्यास" },
  "basin": "indus-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 6,
  "wikimedia_image_id": null,
  "source": {
    "name": "Beas Kund, near Rohtang Pass",
    "state": "himachal-pradesh",
    "altitude_m": 4361,
    "coordinates": [77.25, 32.37]
  },
  "sink": {
    "name": "Confluence with the Sutlej",
    "type": "river",
    "location": "Harike Wetland, Punjab, India",
    "coordinates": [74.95, 31.17]
  },
  "length_km_india": 470,
  "length_km_total": 470,
  "basin_area_total_km2": 20303,
  "basin_area_india_km2": 20303,
  "states_flows_through": ["himachal-pradesh", "punjab"],
  "basin_states": ["himachal-pradesh", "punjab"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [
    "beas-conservation-reserve-ramsar",
    "harike-lake-ramsar",
    "harike-lake-wls",
    "pong-dam-lake-ramsar",
    "pong-dam-lake-wls"
  ],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["irrigation", "hydropower"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Beas is the only major Himalayan tributary of the Indus system that flows entirely within India.",
    "Alexander the Great's army turned back at the Beas (the ancient Hyphasis) in 326 BCE, marking the easternmost limit of his campaign in South Asia."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/sutlej.json << 'PATCH_EOF'
{
  "id": "sutlej",
  "name": "Sutlej",
  "aliases": ["Satluj", "Satadru", "Zungbal"],
  "local_names": { "hi": "सतलुज" },
  "basin": "indus-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 6,
  "wikimedia_image_id": null,
  "source": {
    "name": "Manasarovar-Rakshastal lakes area",
    "state": "tibet",
    "altitude_m": 4575,
    "coordinates": [81.9944, 30.3645]
  },
  "sink": {
    "name": "Confluence with Chenab, forming the Panjnad",
    "type": "river",
    "location": "Near Khairpur, Bahawalpur district, Punjab, Pakistan",
    "coordinates": [71.0617, 29.3897]
  },
  "length_km_india": 1050,
  "length_km_total": 1450,
  "basin_area_total_km2": 395000,
  "basin_area_india_km2": null,
  "states_flows_through": ["himachal-pradesh", "punjab"],
  "basin_states": ["himachal-pradesh", "punjab"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [
    "govind-sagar-wls",
    "harike-lake-ramsar",
    "harike-lake-wls",
    "lippa-asrang-wls",
    "majathal-wls",
    "nangal-wildlife-sanctuary-ramsar",
    "nangal-wls",
    "ropar-lake-ramsar",
    "rupi-bhaba-wls"
  ],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["china", "pakistan"],
  "significance": ["irrigation", "hydropower", "strategic"],
  "notable_city_ids": ["ludhiana"],
  "upsc_relevant": true,
  "did_you_know": [
    "The Sutlej is the longest of the five rivers of Punjab and the easternmost tributary of the Indus.",
    "The Bhakra Dam on the Sutlej impounds Gobind Sagar, one of India's largest reservoirs."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/zanskar.json << 'PATCH_EOF'
{
  "id": "zanskar",
  "name": "Zanskar",
  "aliases": [],
  "local_names": { "hi": "जांस्कर" },
  "basin": "indus-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Confluence of the Doda and Tsarap (Lungnak) rivers, near Padum",
    "state": "ladakh",
    "altitude_m": 3657,
    "coordinates": [76.87, 33.47]
  },
  "sink": {
    "name": "Confluence with the Indus",
    "type": "river",
    "location": "Nimmu, Ladakh",
    "coordinates": [77.25, 34.15]
  },
  "length_km_india": 134,
  "length_km_total": 134,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["ladakh"],
  "basin_states": ["ladakh"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": ["hemis-np"],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["tourism", "adventure sports"],
  "notable_city_ids": [],
  "upsc_relevant": false,
  "did_you_know": [
    "The Zanskar freezes solid enough in winter to form the 'Chadar' trek, once the region's only reliable winter route.",
    "The Zanskar–Indus confluence at Nimmu is a popular viewpoint: muddy Zanskar water visibly meeting the clearer Indus."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/shyok.json << 'PATCH_EOF'
{
  "id": "shyok",
  "name": "Shyok",
  "aliases": ["Shayok"],
  "local_names": { "hi": "श्योक" },
  "basin": "indus-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 7,
  "wikimedia_image_id": null,
  "source": {
    "name": "Rimo Glacier",
    "state": "ladakh",
    "altitude_m": 5000,
    "coordinates": [77.5, 35.3]
  },
  "sink": {
    "name": "Confluence with the Indus",
    "type": "river",
    "location": "Near Skardu, Gilgit-Baltistan",
    "coordinates": [75.67, 35.3]
  },
  "length_km_india": 400,
  "length_km_total": 550,
  "basin_area_total_km2": 33465,
  "basin_area_india_km2": null,
  "states_flows_through": ["ladakh"],
  "basin_states": ["ladakh"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": ["changthang-wls", "karakoram-nubra-shyok-wls"],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["pakistan"],
  "significance": ["strategic", "glacial hydrology"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Shyok rises near the Siachen Glacier, in one of the highest and most militarized terrains on Earth.",
    "The Shyok is prone to glacial lake outburst floods (GLOFs), historically some of the most destructive flash floods in the western Himalaya."
  ]
}
PATCH_EOF
echo

echo "Patch applied: protected_area_ids updated in indus, ravi, beas, sutlej, zanskar, shyok"
