#!/usr/bin/env bash
# step24-patch.sh — rivers/{id}.json batch 2 (Ganga system, 21 rivers) + Ravi length fix
# (per Ashwin's decision to keep rivers-index.json's 725km figure, ravi.json's
# length_km_india/length_km_total are both reverted to 725 to stay consistent).
# Run from project root in Git Bash. Idempotent.
set -euo pipefail

mkdir -p public/data/rivers

cat > public/data/rivers/ganga.json << 'PATCH_EOF'
{
  "id": "ganga",
  "name": "Ganga",
  "aliases": ["Ganges", "Ganga Mata"],
  "local_names": { "hi": "गंगा" },
  "basin": "ganga-basin",
  "type": "main",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 8,
  "wikimedia_image_id": null,
  "source": {
    "name": "Gaumukh (Gangotri Glacier), traditionally regarded as the Ganga's source",
    "state": "uttarakhand",
    "altitude_m": 3892,
    "coordinates": [79.0819, 30.9928]
  },
  "sink": {
    "name": "Ganges Delta",
    "type": "sea",
    "location": "Bay of Bengal, near Sagar Island, West Bengal / Bangladesh",
    "coordinates": [88.03, 21.65]
  },
  "length_km_india": 2525,
  "length_km_total": 2704,
  "basin_area_total_km2": 1080000,
  "basin_area_india_km2": 861452,
  "states_flows_through": ["uttarakhand", "uttar-pradesh", "bihar", "jharkhand", "west-bengal"],
  "basin_states": ["uttarakhand", "uttar-pradesh", "bihar", "jharkhand", "west-bengal"],
  "tributaries": { "left": ["gomti", "ghaghra", "gandak", "kosi", "mahananda"], "right": ["yamuna", "son"] },
  "distributaries": ["hooghly"],
  "protected_area_ids": [],
  "navigable": true,
  "transnational": true,
  "transnational_countries": ["bangladesh"],
  "significance": ["religious", "cultural", "irrigation", "navigation"],
  "notable_city_ids": ["haridwar", "rishikesh", "varanasi", "prayagraj", "patna"],
  "upsc_relevant": true,
  "did_you_know": [
    "The Ganga's source is officially reckoned at Gaumukh, the terminus of the Gangotri Glacier — though the river only takes the name 'Ganga' after the Bhagirathi and Alaknanda meet at Devprayag.",
    "The Ganga basin, covering about a quarter of India's land area, supports more than 40% of India's population."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/bhagirathi.json << 'PATCH_EOF'
{
  "id": "bhagirathi",
  "name": "Bhagirathi",
  "aliases": [],
  "local_names": { "hi": "भागीरथी" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Gaumukh, Gangotri Glacier",
    "state": "uttarakhand",
    "altitude_m": 3892,
    "coordinates": [79.0819, 30.9928]
  },
  "sink": {
    "name": "Confluence with the Alaknanda, forming the Ganga",
    "type": "river",
    "location": "Devprayag, Uttarakhand",
    "coordinates": [78.598, 30.1461]
  },
  "length_km_india": 229.1,
  "length_km_total": 229.1,
  "basin_area_total_km2": 6921,
  "basin_area_india_km2": 6921,
  "states_flows_through": ["uttarakhand"],
  "basin_states": ["uttarakhand"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["religious", "glacial hydrology"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "Hindu tradition regards the Bhagirathi, not the higher-discharge Alaknanda, as the true source stream of the Ganga.",
    "The Gangotri Glacier feeding it is retreating by tens of metres a year, a frequently cited case study in Himalayan glacial melt."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/alaknanda.json << 'PATCH_EOF'
{
  "id": "alaknanda",
  "name": "Alaknanda",
  "aliases": [],
  "local_names": { "hi": "अलकनंदा" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 6,
  "wikimedia_image_id": null,
  "source": {
    "name": "Satopanth and Bhagirath Kharak glaciers, near Badrinath",
    "state": "uttarakhand",
    "altitude_m": 4600,
    "coordinates": [79.4, 30.75]
  },
  "sink": {
    "name": "Confluence with the Bhagirathi, forming the Ganga",
    "type": "river",
    "location": "Devprayag, Uttarakhand",
    "coordinates": [78.598, 30.1461]
  },
  "length_km_india": 206.4,
  "length_km_total": 206.4,
  "basin_area_total_km2": 10882,
  "basin_area_india_km2": 10882,
  "states_flows_through": ["uttarakhand"],
  "basin_states": ["uttarakhand"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["religious", "hydropower", "tourism"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "By volume the Alaknanda carries more water than the Bhagirathi at their Devprayag confluence, even though the Bhagirathi is conventionally treated as the Ganga's source stream.",
    "The 2013 Uttarakhand floods, one of India's worst Himalayan disasters, were driven largely by extreme rainfall and glacial-lake outburst flooding in the Alaknanda basin."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/yamuna.json << 'PATCH_EOF'
{
  "id": "yamuna",
  "name": "Yamuna",
  "aliases": ["Jamuna", "Jumna"],
  "local_names": { "hi": "यमुना" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 8,
  "wikimedia_image_id": null,
  "source": {
    "name": "Champasar Glacier (Yamunotri), Bandarpoonch massif",
    "state": "uttarakhand",
    "altitude_m": 6387,
    "coordinates": [78.45, 31.02]
  },
  "sink": {
    "name": "Confluence with the Ganga (Triveni Sangam)",
    "type": "river",
    "location": "Prayagraj, Uttar Pradesh",
    "coordinates": [81.8463, 25.4358]
  },
  "length_km_india": 1376,
  "length_km_total": 1376,
  "basin_area_total_km2": 366223,
  "basin_area_india_km2": 366223,
  "states_flows_through": ["uttarakhand", "himachal-pradesh", "haryana", "delhi", "uttar-pradesh"],
  "basin_states": ["uttarakhand", "himachal-pradesh", "haryana", "delhi", "uttar-pradesh", "madhya-pradesh", "rajasthan"],
  "tributaries": { "left": [], "right": ["chambal", "betwa", "ken"] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["religious", "irrigation", "cultural"],
  "notable_city_ids": ["delhi", "agra"],
  "upsc_relevant": true,
  "did_you_know": [
    "The Yamuna is the Ganga's largest tributary by volume, though the Yamuna itself never touches the sea directly — it merges into the Ganga at Prayagraj.",
    "The Taj Mahal was built on the Yamuna's bank at Agra specifically so its reflection would appear in the river."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/chambal.json << 'PATCH_EOF'
{
  "id": "chambal",
  "name": "Chambal",
  "aliases": ["Charmanyavati"],
  "local_names": { "hi": "चंबल" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "perennial",
  "origin_type": "rain-fed",
  "stream_order": 7,
  "wikimedia_image_id": null,
  "source": {
    "name": "Janapav Hill, Vindhya Range escarpment",
    "state": "madhya-pradesh",
    "altitude_m": 854,
    "coordinates": [75.6, 22.5]
  },
  "sink": {
    "name": "Confluence with the Yamuna near Pachnada",
    "type": "river",
    "location": "Etawah/Bhind border, Uttar Pradesh / Madhya Pradesh",
    "coordinates": [79.1, 26.5]
  },
  "length_km_india": 988.5,
  "length_km_total": 988.5,
  "basin_area_total_km2": 144591,
  "basin_area_india_km2": 144591,
  "states_flows_through": ["madhya-pradesh", "rajasthan", "uttar-pradesh"],
  "basin_states": ["madhya-pradesh", "rajasthan", "uttar-pradesh"],
  "tributaries": { "left": [], "right": ["banas", "kali-sindh", "parbati"] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["ravine topography", "wildlife conservation", "hydropower"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Chambal's deeply eroded ravine badlands, once notorious as a refuge for dacoits, are now a protected sanctuary for gharials and the endangered Ganges river dolphin.",
    "Unlike most Ganga tributaries, the Chambal is one of the least polluted major rivers in India, largely because industrial development along its banks stayed limited."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/banas.json << 'PATCH_EOF'
{
  "id": "banas",
  "name": "Banas",
  "aliases": [],
  "local_names": { "hi": "बनास" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "seasonal",
  "origin_type": "rain-fed",
  "stream_order": 7,
  "wikimedia_image_id": null,
  "source": {
    "name": "Khamnor Hills, Aravalli Range, near Kumbhalgarh",
    "state": "rajasthan",
    "altitude_m": 700,
    "coordinates": [73.6, 25.1]
  },
  "sink": {
    "name": "Confluence with the Chambal",
    "type": "river",
    "location": "Sawai Madhopur district, Rajasthan",
    "coordinates": [76.8, 25.9]
  },
  "length_km_india": 550,
  "length_km_total": 550,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["rajasthan"],
  "basin_states": ["rajasthan"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["irrigation", "Aravalli drainage"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Banas is the largest river to rise, flow, and stay entirely within Rajasthan before joining the Chambal.",
    "It is one of the few significant rivers of the Aravalli Range's eastern slope, in contrast to the range's largely seasonal, short westward-draining streams."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/kali-sindh.json << 'PATCH_EOF'
{
  "id": "kali-sindh",
  "name": "Kali Sindh",
  "aliases": ["Kali Sindhu"],
  "local_names": { "hi": "काली सिंध" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "seasonal",
  "origin_type": "rain-fed",
  "stream_order": 6,
  "wikimedia_image_id": null,
  "source": {
    "name": "Vindhya Range, near Bhanpura",
    "state": "madhya-pradesh",
    "altitude_m": 550,
    "coordinates": [75.2, 24.0]
  },
  "sink": {
    "name": "Confluence with the Chambal",
    "type": "river",
    "location": "Baran district, Rajasthan",
    "coordinates": [76.4, 25.3]
  },
  "length_km_india": 550,
  "length_km_total": 550,
  "basin_area_total_km2": 48492,
  "basin_area_india_km2": 48492,
  "states_flows_through": ["madhya-pradesh", "rajasthan"],
  "basin_states": ["madhya-pradesh", "rajasthan"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["irrigation"],
  "notable_city_ids": [],
  "upsc_relevant": false,
  "did_you_know": [
    "The Kali Sindh drains a large stretch of the Malwa Plateau before joining the Chambal, one of that river's principal right-bank tributaries."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/parbati.json << 'PATCH_EOF'
{
  "id": "parbati",
  "name": "Parbati",
  "aliases": [],
  "local_names": { "hi": "पार्वती" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "seasonal",
  "origin_type": "rain-fed",
  "stream_order": 6,
  "wikimedia_image_id": null,
  "source": {
    "name": "Vindhya Range, near Sehore",
    "state": "madhya-pradesh",
    "altitude_m": 500,
    "coordinates": [77.2, 23.2]
  },
  "sink": {
    "name": "Confluence with the Chambal",
    "type": "river",
    "location": "Sheopur district, Madhya Pradesh",
    "coordinates": [77.0, 25.9]
  },
  "length_km_india": 444.2,
  "length_km_total": 444.2,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["madhya-pradesh", "rajasthan"],
  "basin_states": ["madhya-pradesh", "rajasthan"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["irrigation"],
  "notable_city_ids": [],
  "upsc_relevant": false,
  "did_you_know": [
    "The Parbati is one of three Malwa Plateau rivers — alongside the Banas and Kali Sindh — that all feed the Chambal from its right bank."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/betwa.json << 'PATCH_EOF'
{
  "id": "betwa",
  "name": "Betwa",
  "aliases": ["Vetravati"],
  "local_names": { "hi": "बेतवा" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "perennial",
  "origin_type": "rain-fed",
  "stream_order": 6,
  "wikimedia_image_id": null,
  "source": {
    "name": "Kumra village, Vindhya Range",
    "state": "madhya-pradesh",
    "altitude_m": 550,
    "coordinates": [77.6, 23.1]
  },
  "sink": {
    "name": "Confluence with the Yamuna",
    "type": "river",
    "location": "Hamirpur, Uttar Pradesh",
    "coordinates": [80.15, 25.95]
  },
  "length_km_india": 590,
  "length_km_total": 590,
  "basin_area_total_km2": 46580,
  "basin_area_india_km2": 46580,
  "states_flows_through": ["madhya-pradesh", "uttar-pradesh"],
  "basin_states": ["madhya-pradesh", "uttar-pradesh"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["irrigation", "historical", "heritage sites"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The cenotaphs (chhatris) of Orchha's former rulers stand directly on the Betwa's banks, one of Madhya Pradesh's best-known heritage riverfronts.",
    "Known as Vetravati in ancient texts, the Betwa is mentioned in Kalidasa's Raghuvamsha."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/ken.json << 'PATCH_EOF'
{
  "id": "ken",
  "name": "Ken",
  "aliases": ["Karnavati"],
  "local_names": { "hi": "केन" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "perennial",
  "origin_type": "rain-fed",
  "stream_order": 8,
  "wikimedia_image_id": null,
  "source": {
    "name": "Ahirgawan village, Kaimur Range",
    "state": "madhya-pradesh",
    "altitude_m": 550,
    "coordinates": [80.3, 23.4]
  },
  "sink": {
    "name": "Confluence with the Yamuna",
    "type": "river",
    "location": "Banda district, Uttar Pradesh",
    "coordinates": [80.4, 25.75]
  },
  "length_km_india": 427,
  "length_km_total": 427,
  "basin_area_total_km2": 28058,
  "basin_area_india_km2": 28058,
  "states_flows_through": ["madhya-pradesh", "uttar-pradesh"],
  "basin_states": ["madhya-pradesh", "uttar-pradesh"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["irrigation", "river-interlinking project", "tiger reserve"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Ken flows through Panna Tiger Reserve, one of Madhya Pradesh's premier tiger habitats.",
    "The Ken-Betwa Link is India's first river-interlinking project under the National Perspective Plan, meant to transfer 'surplus' Ken water to the water-stressed Betwa basin."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/son.json << 'PATCH_EOF'
{
  "id": "son",
  "name": "Son",
  "aliases": ["Sone", "Sonbhadra"],
  "local_names": { "hi": "सोन" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "perennial",
  "origin_type": "rain-fed",
  "stream_order": 6,
  "wikimedia_image_id": null,
  "source": {
    "name": "Amarkantak Plateau",
    "state": "madhya-pradesh",
    "altitude_m": 1057,
    "coordinates": [81.7546, 22.6725]
  },
  "sink": {
    "name": "Confluence with the Ganga",
    "type": "river",
    "location": "Near Danapur, west of Patna, Bihar",
    "coordinates": [85.05, 25.65]
  },
  "length_km_india": 784,
  "length_km_total": 784,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["madhya-pradesh", "chhattisgarh", "uttar-pradesh", "jharkhand", "bihar"],
  "basin_states": ["madhya-pradesh", "chhattisgarh", "uttar-pradesh", "jharkhand", "bihar"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["irrigation", "one of the Ganga's largest south-bank tributaries"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Son and the Narmada both rise on the same Amarkantak Plateau but flow in almost opposite directions — the Son east to the Bay of Bengal via the Ganga, the Narmada west to the Arabian Sea.",
    "The Son is the Ganga's largest south-bank (right-bank) tributary."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/gomti.json << 'PATCH_EOF'
{
  "id": "gomti",
  "name": "Gomti",
  "aliases": ["Gumti", "Gomati"],
  "local_names": { "hi": "गोमती" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "spring-fed",
  "stream_order": 8,
  "wikimedia_image_id": null,
  "source": {
    "name": "Gomat Taal (Fulhar Jheel), near Madhotanda",
    "state": "uttar-pradesh",
    "altitude_m": 200,
    "coordinates": [80.1, 28.7]
  },
  "sink": {
    "name": "Confluence with the Ganga",
    "type": "river",
    "location": "Near Ghazipur, Uttar Pradesh",
    "coordinates": [83.2, 25.5]
  },
  "length_km_india": 960,
  "length_km_total": 960,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["uttar-pradesh"],
  "basin_states": ["uttar-pradesh"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["flows through Lucknow", "historic navigation route"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "Unlike most Himalayan-belt tributaries of the Ganga, the Gomti doesn't rise from a glacier — it begins at Gomat Taal, a terai swamp near Pilibhit.",
    "The Gomti flows through the heart of Lucknow, Uttar Pradesh's capital, and was historically navigable up to the city."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/ghaghra.json << 'PATCH_EOF'
{
  "id": "ghaghra",
  "name": "Ghaghra",
  "aliases": ["Karnali", "Manchu"],
  "local_names": { "hi": "घाघरा" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 8,
  "wikimedia_image_id": null,
  "source": {
    "name": "Mapchachungo Glacier, near Lake Manasarovar",
    "state": "tibet",
    "altitude_m": 5000,
    "coordinates": [81.5, 30.5]
  },
  "sink": {
    "name": "Confluence with the Ganga",
    "type": "river",
    "location": "Near Chhapra (Revelganj), Bihar",
    "coordinates": [84.75, 25.78]
  },
  "length_km_india": 503,
  "length_km_total": 503,
  "basin_area_total_km2": 57578,
  "basin_area_india_km2": 57578,
  "states_flows_through": ["uttar-pradesh", "bihar"],
  "basin_states": ["uttar-pradesh", "bihar"],
  "tributaries": { "left": [], "right": ["sarda"] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["china", "nepal"],
  "significance": ["frequent flooding", "irrigation"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "Known as the Karnali in Nepal, the Ghaghra is one of the longest rivers in Nepal before it crosses into India.",
    "It is among the most flood-prone rivers of the Indo-Gangetic plain, regularly shifting course across the Terai lowlands."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/sarda.json << 'PATCH_EOF'
{
  "id": "sarda",
  "name": "Sarda",
  "aliases": ["Kali", "Mahakali"],
  "local_names": { "hi": "शारदा" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 7,
  "wikimedia_image_id": null,
  "source": {
    "name": "Limpiyadhura, near the India-Nepal-China tri-junction",
    "state": "uttarakhand",
    "altitude_m": 3600,
    "coordinates": [80.44, 30.2]
  },
  "sink": {
    "name": "Confluence with the Ghaghra",
    "type": "river",
    "location": "Bahramghat, Uttar Pradesh",
    "coordinates": [81.2, 27.3]
  },
  "length_km_india": 350,
  "length_km_total": 350,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["uttarakhand", "uttar-pradesh"],
  "basin_states": ["uttarakhand", "uttar-pradesh"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["nepal"],
  "significance": ["India-Nepal border river", "major irrigation canal (Sarda Canal)", "territorial dispute"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "Known as the Mahakali or Kali in Nepal, the Sarda forms part of the India-Nepal border and is at the centre of the long-running Kalapani-Limpiyadhura territorial dispute.",
    "The Sarda Canal, built in the 1920s off the Sarda Barrage, was one of the earliest large-scale irrigation projects in colonial India."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/gandak.json << 'PATCH_EOF'
{
  "id": "gandak",
  "name": "Gandak",
  "aliases": ["Gandaki", "Narayani", "Sapt Gandaki"],
  "local_names": { "hi": "गंडक" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 7,
  "wikimedia_image_id": null,
  "source": {
    "name": "Nhubine Himal Glacier (Kali Gandaki headwaters), Mustang district",
    "state": "nepal",
    "altitude_m": 6268,
    "coordinates": [83.6, 29.3]
  },
  "sink": {
    "name": "Confluence with the Ganga",
    "type": "river",
    "location": "Near Sonpur/Hajipur, Bihar",
    "coordinates": [85.13, 25.72]
  },
  "length_km_india": 260,
  "length_km_total": 630,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["uttar-pradesh", "bihar"],
  "basin_states": ["uttar-pradesh", "bihar"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["nepal"],
  "significance": ["irrigation (Gandak Barrage)", "India-Nepal treaty river"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "Called the Narayani in Nepal and Sapt Gandaki for its seven Himalayan headstreams, the Gandak is one of the Ganga's largest north-bank tributaries.",
    "The 1959 Gandak Treaty between India and Nepal governs irrigation and hydropower sharing on the river."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/kosi.json << 'PATCH_EOF'
{
  "id": "kosi",
  "name": "Kosi",
  "aliases": ["Koshi", "Saptakoshi", "Sorrow of Bihar"],
  "local_names": { "hi": "कोसी" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 7,
  "wikimedia_image_id": null,
  "source": {
    "name": "Arun River headwaters, eastern Nepal/Tibet Himalaya",
    "state": "nepal",
    "altitude_m": 5000,
    "coordinates": [87.0, 28.0]
  },
  "sink": {
    "name": "Confluence with the Ganga",
    "type": "river",
    "location": "Near Kursela, Bihar",
    "coordinates": [87.35, 25.75]
  },
  "length_km_india": 260,
  "length_km_total": 720,
  "basin_area_total_km2": null,
  "basin_area_india_km2": 11410,
  "states_flows_through": ["bihar"],
  "basin_states": ["bihar"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["nepal", "china"],
  "significance": ["frequent, severe flooding", "embankment/barrage engineering"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "Nicknamed the 'Sorrow of Bihar,' the Kosi has a long history of catastrophic floods and dramatic channel shifts across the plains — it has moved over 100km westward over the past two centuries.",
    "The 2008 Kosi flood, triggered by an embankment breach, was one of independent India's worst river disasters."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/mahananda.json << 'PATCH_EOF'
{
  "id": "mahananda",
  "name": "Mahananda",
  "aliases": [],
  "local_names": { "hi": "महानंदा" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "rain-fed",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Himalayan foothills near Kurseong",
    "state": "west-bengal",
    "altitude_m": 2000,
    "coordinates": [88.28, 26.88]
  },
  "sink": {
    "name": "Confluence with the Ganga",
    "type": "river",
    "location": "Near the India-Bangladesh border, West Bengal",
    "coordinates": [88.15, 24.85]
  },
  "length_km_india": 324,
  "length_km_total": 360,
  "basin_area_total_km2": null,
  "basin_area_india_km2": 11530,
  "states_flows_through": ["west-bengal", "bihar"],
  "basin_states": ["west-bengal", "bihar"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["bangladesh"],
  "significance": ["Siliguri Corridor drainage", "India-Bangladesh border river"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Mahananda drains the Siliguri Corridor — India's narrow 'Chicken's Neck' — the strip of land connecting the northeastern states to the rest of the country.",
    "A stretch of the Mahananda forms part of the India-Bangladesh international border before it joins the Ganga."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/damodar.json << 'PATCH_EOF'
{
  "id": "damodar",
  "name": "Damodar",
  "aliases": ["River of Sorrows", "Damuda"],
  "local_names": { "hi": "दामोदर" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "perennial",
  "origin_type": "rain-fed",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Chota Nagpur Plateau, near Tori village",
    "state": "jharkhand",
    "altitude_m": 600,
    "coordinates": [84.2, 23.75]
  },
  "sink": {
    "name": "Confluence with the Hooghly",
    "type": "river",
    "location": "Near Falta, South 24 Parganas district, West Bengal",
    "coordinates": [88.15, 22.3]
  },
  "length_km_india": 592,
  "length_km_total": 592,
  "basin_area_total_km2": 25820,
  "basin_area_india_km2": 25820,
  "states_flows_through": ["jharkhand", "west-bengal"],
  "basin_states": ["jharkhand", "west-bengal"],
  "tributaries": { "left": [], "right": ["barakar"] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["coalfields", "Damodar Valley Corporation multipurpose project", "historically severe flooding"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Damodar Valley Corporation (1948), India's first multipurpose river valley project, was explicitly modeled on the United States' Tennessee Valley Authority.",
    "The Damodar valley holds some of India's richest coalfields, historically earning the river the nickname 'River of Sorrow' for its pre-dam flooding."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/hooghly.json << 'PATCH_EOF'
{
  "id": "hooghly",
  "name": "Hooghly",
  "aliases": ["Bhagirathi-Hooghly"],
  "local_names": { "hi": "हुगली" },
  "basin": "ganga-basin",
  "type": "distributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "mixed",
  "stream_order": 6,
  "wikimedia_image_id": null,
  "source": {
    "name": "Bifurcation from the Ganga at the Farakka Barrage",
    "state": "west-bengal",
    "altitude_m": 15,
    "coordinates": [87.93, 24.8]
  },
  "sink": {
    "name": "Hooghly estuary",
    "type": "sea",
    "location": "Bay of Bengal, near Sagar Island, West Bengal",
    "coordinates": [88.03, 21.65]
  },
  "length_km_india": 260,
  "length_km_total": 260,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["west-bengal"],
  "basin_states": ["west-bengal"],
  "tributaries": { "left": [], "right": ["damodar", "ajay"] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": true,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["Kolkata Port navigation channel", "colonial-era trade route", "Ganga's principal India-only distributary"],
  "notable_city_ids": ["kolkata"],
  "upsc_relevant": true,
  "did_you_know": [
    "Called the Bhagirathi from Farakka to Nabadwip and the Hooghly from Nabadwip to the sea, this channel is the Ganga's main distributary that stays entirely within India.",
    "The Farakka Barrage (1975) regulates how much Ganga water is diverted into the Hooghly versus continuing into Bangladesh as the Padma — a long-running point of India-Bangladesh water-sharing negotiation."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/barakar.json << 'PATCH_EOF'
{
  "id": "barakar",
  "name": "Barakar",
  "aliases": [],
  "local_names": { "hi": "बराकर" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "perennial",
  "origin_type": "rain-fed",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Chota Nagpur Plateau, near Padma/Chandwa",
    "state": "jharkhand",
    "altitude_m": 600,
    "coordinates": [85.3, 23.9]
  },
  "sink": {
    "name": "Confluence with the Damodar",
    "type": "river",
    "location": "Near Dishergarh, Paschim Bardhaman district, West Bengal",
    "coordinates": [86.85, 23.65]
  },
  "length_km_india": 291.3,
  "length_km_total": 291.3,
  "basin_area_total_km2": 6159,
  "basin_area_india_km2": 6159,
  "states_flows_through": ["jharkhand", "west-bengal"],
  "basin_states": ["jharkhand", "west-bengal"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["Maithon Dam (Damodar Valley Corporation)", "coal belt tributary"],
  "notable_city_ids": [],
  "upsc_relevant": false,
  "did_you_know": [
    "The Maithon Dam on the Barakar, part of the Damodar Valley Corporation scheme, was one of the highest earthen dams in India at the time of its construction."
  ]
}
PATCH_EOF
echo

cat > public/data/rivers/ajay.json << 'PATCH_EOF'
{
  "id": "ajay",
  "name": "Ajay",
  "aliases": [],
  "local_names": { "hi": "अजय" },
  "basin": "ganga-basin",
  "type": "tributary",
  "drainage_type": "peninsular",
  "seasonal_type": "seasonal",
  "origin_type": "rain-fed",
  "stream_order": 5,
  "wikimedia_image_id": null,
  "source": {
    "name": "Chota Nagpur Plateau, near the Jharkhand-Bihar border",
    "state": "jharkhand",
    "altitude_m": 400,
    "coordinates": [86.5, 24.5]
  },
  "sink": {
    "name": "Confluence with the Hooghly (Bhagirathi)",
    "type": "river",
    "location": "Near Katwa, Purba Bardhaman district, West Bengal",
    "coordinates": [88.13, 23.65]
  },
  "length_km_india": 308.4,
  "length_km_total": 308.4,
  "basin_area_total_km2": 6000,
  "basin_area_india_km2": 6000,
  "states_flows_through": ["bihar", "jharkhand", "west-bengal"],
  "basin_states": ["bihar", "jharkhand", "west-bengal"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": false,
  "transnational_countries": [],
  "significance": ["district boundary river", "cultural/heritage association"],
  "notable_city_ids": [],
  "upsc_relevant": false,
  "did_you_know": [
    "The Ajay flows past Santiniketan, the university town founded by Rabindranath Tagore, on the Birbhum-Bardhaman border in West Bengal."
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
  "length_km_india": 725,
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

echo "Patch applied: 21 Ganga-system rivers/{id}.json + ravi.json length fix"
echo "Total rivers/{id}.json files now: 28 (7 Indus + 21 Ganga)"
