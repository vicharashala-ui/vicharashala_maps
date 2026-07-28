// scripts/enrichStates.js
// Input:  build/raw/india-states.raw.geojson (already Visvalingam/200m-simplified upstream —
//         see PROGRESS.md Step 4 notes; no re-simplification done here)
// Output: public/geojson/india-states.geojson (geometry + enriched properties)
//         public/data/states.json (metadata only, mirrors protected-areas.json's split)
//
// rivers_flowing_through / basin_rivers / notable_city_ids / protected_area_ids are left
// empty here — they depend on the rivers pipeline (steps ⑥⑦⑧) and spatialIntersect.js
// (step ⑪), neither of which exist yet. Filled in a later step.

import fs from 'node:fs';
import path from 'node:path';
import { State } from './schemas.js';

const RAW_FILE = 'build/raw/india-states.raw.geojson';
const GEOJSON_OUT = 'public/geojson/india-states.geojson';
const DATA_OUT = 'public/data/states.json';

const UT_NAMES = new Set([
  'Andaman & Nicobar Islands',
  'Chandigarh',
  'Dadra & Nagar Haveli and Daman & Diu',
  'Delhi',
  'Jammu & Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
]);

const CAPITALS = {
  'Andaman & Nicobar Islands': 'Port Blair',
  'Andhra Pradesh': 'Amaravati',
  'Arunachal Pradesh': 'Itanagar',
  Assam: 'Dispur',
  Bihar: 'Patna',
  Chandigarh: 'Chandigarh',
  Chhattisgarh: 'Raipur',
  'Dadra & Nagar Haveli and Daman & Diu': 'Daman',
  Delhi: 'New Delhi',
  Goa: 'Panaji',
  Gujarat: 'Gandhinagar',
  Haryana: 'Chandigarh',
  'Himachal Pradesh': 'Shimla',
  'Jammu & Kashmir': 'Srinagar',
  Jharkhand: 'Ranchi',
  Karnataka: 'Bengaluru',
  Kerala: 'Thiruvananthapuram',
  Ladakh: 'Leh',
  Lakshadweep: 'Kavaratti',
  'Madhya Pradesh': 'Bhopal',
  Maharashtra: 'Mumbai',
  Manipur: 'Imphal',
  Meghalaya: 'Shillong',
  Mizoram: 'Aizawl',
  Nagaland: 'Kohima',
  Odisha: 'Bhubaneswar',
  Puducherry: 'Puducherry',
  Punjab: 'Chandigarh',
  Rajasthan: 'Jaipur',
  Sikkim: 'Gangtok',
  'Tamil Nadu': 'Chennai',
  Telangana: 'Hyderabad',
  Tripura: 'Agartala',
  'Uttar Pradesh': 'Lucknow',
  Uttarakhand: 'Dehradun',
  'West Bengal': 'Kolkata',
};

function displayName(rawName) {
  return rawName.replace(/ & /g, ' and ');
}

function slugify(name) {
  return name
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function run() {
  const raw = JSON.parse(fs.readFileSync(RAW_FILE, 'utf-8'));

  fs.mkdirSync(path.dirname(GEOJSON_OUT), { recursive: true });
  fs.mkdirSync(path.dirname(DATA_OUT), { recursive: true });

  const metadata = [];
  const seenIds = new Set();

  for (const feature of raw.features) {
    const rawName = feature.properties.st_nm;
    if (!(rawName in CAPITALS)) {
      throw new Error(`No capital/admin_type entry for "${rawName}" — add it to CAPITALS.`);
    }
    const name = displayName(rawName);
    const id = slugify(name);
    if (seenIds.has(id)) throw new Error(`Duplicate state id "${id}"`);
    seenIds.add(id);

    const record = {
      id,
      name,
      admin_type: UT_NAMES.has(rawName) ? 'ut' : 'state',
      capital: CAPITALS[rawName],
      rivers_flowing_through: [],
      basin_rivers: [],
      notable_city_ids: [],
      protected_area_ids: [],
    };

    State.parse(record);
    metadata.push(record);
    feature.properties = { id, name, admin_type: record.admin_type };
  }

  fs.writeFileSync(GEOJSON_OUT, JSON.stringify(raw));
  fs.writeFileSync(DATA_OUT, JSON.stringify(metadata, null, 2));

  console.log(`States/UTs processed: ${metadata.length}`);
  console.log(`  states: ${metadata.filter((m) => m.admin_type === 'state').length}`);
  console.log(`  UTs:    ${metadata.filter((m) => m.admin_type === 'ut').length}`);
}

run();
