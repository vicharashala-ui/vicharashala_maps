#!/usr/bin/env bash
# step21-patch.sh — cities.json + rivers/{id}.json batch 1 (Indus system, 7 rivers) + schema additions
# Run from project root in Git Bash. Idempotent (overwrites).
set -euo pipefail

mkdir -p scripts public/data/rivers

cat > scripts/schemas.js << 'PATCH_EOF'
// scripts/schemas.js
// Mirrors spec §4.1-4.4. Build-only — never shipped to the client bundle.
//
// DEVIATION FROM SPEC: `biome_type`, `iucn_status`, `endemic_species`, `wikipedia_url`,
// `year_established` are curated/enrichment fields the spec calls "sparse" or "Phase 2".
// Our real source data (ecoguesser repo) doesn't carry them yet, so ProtectedArea allows
// null/empty defaults here rather than failing validation. Tighten once enrichment lands.

import { z } from 'zod';

// DEVIATION FROM SPEC: `basin_area_india_km2` is nullable. 33 of the 85 V1-scope rivers never
// got a reliable figure during Step 7's web research (left null rather than invented) — this
// wasn't caught until Step 17b ran full schema validation against the complete geometry-backed
// set for the first time. HydroRIVERS' UPLAND_SKM is a possible backfill source but overstates
// India-only area for transnational rivers (includes upstream basin outside India), so it's not
// auto-substituted here. Tighten once real research backfills these.
export const RiverIndexEntry = z.object({
  id: z.string(),
  name: z.string(),
  local_name_hi: z.string(),
  basin: z.string(),
  length_km_india: z.number().positive(),
  basin_area_india_km2: z.number().positive().nullable(),
  drainage_type: z.enum(['himalayan', 'peninsular', 'coastal', 'inland']),
  stream_order: z.number().int().positive(),
  seasonal_type: z.enum(['perennial', 'seasonal', 'ephemeral']),
  origin_type: z.enum(['glacial', 'rain-fed', 'spring-fed', 'mixed']),
  navigable: z.boolean(),
  transnational: z.boolean(),
  states: z.array(z.string()),
  aliases: z.array(z.string()),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]),
});

export const ProtectedArea = z.object({
  id: z.string(),
  name: z.string(),
  category: z.enum(['np', 'wls', 'tr', 'br', 'ramsar']),
  state: z.array(z.string()),
  area_km2: z.number().nonnegative(), // 10 sites (small islands/urban WLS) have unrecorded area = 0
  centroid_lat: z.number(),
  centroid_lng: z.number(),
  has_boundary: z.boolean(),
  river_ids: z.array(z.string()),
  year_established: z.number().int().nullable(),
  wikipedia_url: z.string().url().nullable(),
  upsc_relevant: z.boolean(),
  aliases: z.array(z.string()),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]).nullable(),
  iucn_status: z.enum(['Ia', 'Ib', 'II', 'III', 'IV', 'V', 'VI']).nullable(),
  biome_type: z.string().nullable(),
  endemic_species: z.array(z.string()).max(3),
});

// rivers/{id}.json — spec §4.1. Manually authored; validated by authorRiverDetails.js
// before writing, same fail-loud pattern as the generated pipeline files.
export const RiverDetail = z.object({
  id: z.string(),
  name: z.string(),
  aliases: z.array(z.string()),
  local_names: z.record(z.string(), z.string()),
  basin: z.string(),
  type: z.enum(['main', 'tributary', 'distributary']),
  drainage_type: z.enum(['himalayan', 'peninsular', 'coastal', 'inland']),
  seasonal_type: z.enum(['perennial', 'seasonal', 'ephemeral']),
  origin_type: z.enum(['glacial', 'rain-fed', 'spring-fed', 'mixed']),
  stream_order: z.number().int().positive(),
  wikimedia_image_id: z.string().nullable(),
  source: z.object({
    name: z.string(),
    state: z.string(),
    altitude_m: z.number(),
    coordinates: z.tuple([z.number(), z.number()]),
  }),
  sink: z.object({
    name: z.string(),
    type: z.enum(['sea', 'river', 'lake']),
    location: z.string(),
    coordinates: z.tuple([z.number(), z.number()]),
  }),
  length_km_india: z.number().positive(),
  length_km_total: z.number().positive(),
  basin_area_total_km2: z.number().positive().nullable(),
  basin_area_india_km2: z.number().positive().nullable(),
  states_flows_through: z.array(z.string()),
  basin_states: z.array(z.string()),
  tributaries: z.object({ left: z.array(z.string()), right: z.array(z.string()) }),
  distributaries: z.array(z.string()),
  protected_area_ids: z.array(z.string()),
  navigable: z.boolean(),
  transnational: z.boolean(),
  transnational_countries: z.array(z.string()),
  significance: z.array(z.string()),
  notable_city_ids: z.array(z.string()),
  upsc_relevant: z.boolean(),
  did_you_know: z.array(z.string()),
});

// cities.json — spec §4.5. Manually authored, no generation script.
export const City = z.object({
  id: z.string(),
  name: z.string(),
  state: z.string(),
  river: z.string(),
  river_bank: z.enum(['left', 'right']),
  coordinates: z.tuple([z.number(), z.number()]),
  significance: z.array(z.string()),
  ghats: z.array(
    z.object({
      id: z.string(),
      name: z.string(),
      significance: z.string(),
    })
  ),
});

export const State = z.object({
  id: z.string(),
  name: z.string(),
  admin_type: z.enum(['state', 'ut']),
  capital: z.string(),
  rivers_flowing_through: z.array(z.string()),
  basin_rivers: z.array(z.string()),
  notable_city_ids: z.array(z.string()),
  protected_area_ids: z.array(z.string()),
});

function contrastRatio(hexA, hexB) {
  const luminance = (hex) => {
    const [r, g, b] = hex.match(/\w\w/g).map((c) => {
      const v = parseInt(c, 16) / 255;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const [l1, l2] = [luminance(hexA), luminance(hexB)].sort((a, b) => b - a);
  return (l1 + 0.05) / (l2 + 0.05);
}

const LAND_LIGHT = '#D4E6C3';
const LAND_DARK = '#1E3A2F';

export const Basin = z
  .object({
    id: z.string(),
    name: z.string(),
    color_light: z.string(),
    color_dark: z.string(),
    area_km2: z.number().positive(),
    states: z.array(z.string()),
    main_river: z.string(),
    rivers: z.array(z.string()),
    area_rank: z.number().int(),
  })
  .refine((b) => contrastRatio(b.color_light, LAND_LIGHT) >= 3.0, {
    message: 'color_light fails 3:1 non-text contrast against --color-land (light)',
  })
  .refine((b) => contrastRatio(b.color_dark, LAND_DARK) >= 3.0, {
    message: 'color_dark fails 3:1 non-text contrast against --color-land (dark)',
  });
PATCH_EOF
echo

cat > public/data/cities.json << 'PATCH_EOF'
[
  {
    "id": "leh",
    "name": "Leh",
    "state": "ladakh",
    "river": "indus",
    "river_bank": "left",
    "coordinates": [77.5771, 34.1526],
    "significance": ["tourism", "trade", "religious"],
    "ghats": []
  },
  {
    "id": "haridwar",
    "name": "Haridwar",
    "state": "uttarakhand",
    "river": "ganga",
    "river_bank": "left",
    "coordinates": [78.1642, 29.9457],
    "significance": ["religious", "tourism"],
    "ghats": [
      { "id": "har-ki-pauri", "name": "Har Ki Pauri", "significance": "religious" }
    ]
  },
  {
    "id": "rishikesh",
    "name": "Rishikesh",
    "state": "uttarakhand",
    "river": "ganga",
    "river_bank": "left",
    "coordinates": [78.2676, 30.0869],
    "significance": ["religious", "tourism"],
    "ghats": [
      { "id": "triveni-ghat", "name": "Triveni Ghat", "significance": "religious" }
    ]
  },
  {
    "id": "varanasi",
    "name": "Varanasi",
    "state": "uttar-pradesh",
    "river": "ganga",
    "river_bank": "left",
    "coordinates": [83.0047, 25.3176],
    "significance": ["religious", "tourism"],
    "ghats": [
      { "id": "dashashwamedh-ghat", "name": "Dashashwamedh Ghat", "significance": "religious" },
      { "id": "manikarnika-ghat", "name": "Manikarnika Ghat", "significance": "religious" }
    ]
  },
  {
    "id": "prayagraj",
    "name": "Prayagraj",
    "state": "uttar-pradesh",
    "river": "ganga",
    "river_bank": "left",
    "coordinates": [81.8463, 25.4358],
    "significance": ["religious", "tourism"],
    "ghats": [
      { "id": "sangam", "name": "Triveni Sangam", "significance": "religious" }
    ]
  },
  {
    "id": "patna",
    "name": "Patna",
    "state": "bihar",
    "river": "ganga",
    "river_bank": "right",
    "coordinates": [85.1376, 25.5941],
    "significance": ["administrative", "religious"],
    "ghats": [
      { "id": "gandhi-ghat", "name": "Gandhi Ghat", "significance": "civic" }
    ]
  },
  {
    "id": "kolkata",
    "name": "Kolkata",
    "state": "west-bengal",
    "river": "hooghly",
    "river_bank": "left",
    "coordinates": [88.3639, 22.5726],
    "significance": ["administrative", "religious", "tourism"],
    "ghats": [
      { "id": "babughat", "name": "Babughat", "significance": "religious" }
    ]
  },
  {
    "id": "delhi",
    "name": "Delhi",
    "state": "delhi",
    "river": "yamuna",
    "river_bank": "right",
    "coordinates": [77.209, 28.6139],
    "significance": ["administrative", "religious"],
    "ghats": []
  },
  {
    "id": "agra",
    "name": "Agra",
    "state": "uttar-pradesh",
    "river": "yamuna",
    "river_bank": "right",
    "coordinates": [78.0081, 27.1767],
    "significance": ["tourism", "historical"],
    "ghats": []
  },
  {
    "id": "guwahati",
    "name": "Guwahati",
    "state": "assam",
    "river": "brahmaputra",
    "river_bank": "left",
    "coordinates": [91.7362, 26.1445],
    "significance": ["religious", "tourism"],
    "ghats": [
      { "id": "umananda-ghat", "name": "Umananda Ghat", "significance": "religious" }
    ]
  },
  {
    "id": "ahmedabad",
    "name": "Ahmedabad",
    "state": "gujarat",
    "river": "sabarmati",
    "river_bank": "right",
    "coordinates": [72.5714, 23.0225],
    "significance": ["commercial", "tourism"],
    "ghats": []
  },
  {
    "id": "nashik",
    "name": "Nashik",
    "state": "maharashtra",
    "river": "godavari",
    "river_bank": "right",
    "coordinates": [73.7898, 19.9975],
    "significance": ["religious", "tourism"],
    "ghats": [
      { "id": "ramkund", "name": "Ramkund", "significance": "religious" }
    ]
  },
  {
    "id": "hyderabad",
    "name": "Hyderabad",
    "state": "telangana",
    "river": "musi",
    "river_bank": "right",
    "coordinates": [78.4867, 17.385],
    "significance": ["administrative", "commercial"],
    "ghats": []
  },
  {
    "id": "ludhiana",
    "name": "Ludhiana",
    "state": "punjab",
    "river": "sutlej",
    "river_bank": "left",
    "coordinates": [75.8573, 30.901],
    "significance": ["commercial"],
    "ghats": []
  }
]
PATCH_EOF
echo

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
  "protected_area_ids": [],
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

cat > public/data/rivers/chenab.json << 'PATCH_EOF'
{
  "id": "chenab",
  "name": "Chenab",
  "aliases": ["Chandrabhaga", "Asikni"],
  "local_names": { "hi": "चिनाब" },
  "basin": "indus-basin",
  "type": "tributary",
  "drainage_type": "himalayan",
  "seasonal_type": "perennial",
  "origin_type": "glacial",
  "stream_order": 6,
  "wikimedia_image_id": null,
  "source": {
    "name": "Confluence of Chandra and Bhaga rivers, Tandi",
    "state": "himachal-pradesh",
    "altitude_m": 4890,
    "coordinates": [77.4808, 32.6358]
  },
  "sink": {
    "name": "Confluence with Sutlej, forming the Panjnad",
    "type": "river",
    "location": "Bahawalpur district, Punjab, Pakistan",
    "coordinates": [71.0281, 29.3492]
  },
  "length_km_india": 431.4,
  "length_km_total": 974,
  "basin_area_total_km2": null,
  "basin_area_india_km2": null,
  "states_flows_through": ["himachal-pradesh", "jammu-and-kashmir"],
  "basin_states": ["himachal-pradesh", "jammu-and-kashmir"],
  "tributaries": { "left": [], "right": [] },
  "distributaries": [],
  "protected_area_ids": [],
  "navigable": false,
  "transnational": true,
  "transnational_countries": ["pakistan"],
  "significance": ["irrigation", "hydropower"],
  "notable_city_ids": [],
  "upsc_relevant": true,
  "did_you_know": [
    "The Chenab is formed by the union of the Chandra and Bhaga rivers at Tandi in Himachal Pradesh's Lahaul valley.",
    "Under the Indus Waters Treaty, the Chenab's waters are allocated mainly to Pakistan, with India permitted only limited, non-consumptive uses."
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
  "protected_area_ids": [],
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
  "protected_area_ids": [],
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
  "protected_area_ids": [],
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
  "protected_area_ids": [],
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
  "protected_area_ids": [],
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

pnpm install
echo "Patch applied: schemas.js (+RiverDetail, +City), public/data/cities.json (14 cities),"
echo "public/data/rivers/{indus,chenab,ravi,beas,sutlej,zanskar,shyok}.json"
