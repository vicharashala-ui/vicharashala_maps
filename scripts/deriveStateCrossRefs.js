// scripts/deriveStateCrossRefs.js — spec §4.7 step ⑫
// Input:  public/data/states.json (manually-authored id/name/admin_type/capital)
//         public/data/rivers/{id}.json, public/data/protected-areas.json, public/data/cities.json
// Output: public/data/states.json (relational arrays filled in, validated against State)
//
// rivers_flowing_through <- river.states_flows_through
// basin_rivers           <- river.basin_states
// notable_city_ids       <- city.state
// protected_area_ids     <- pa.state (Title Case names; normalized to slugs via states.json name)

import fs from 'node:fs';
import path from 'node:path';
import { State } from './schemas.js';

const STATES_PATH = 'public/data/states.json';
const RIVERS_DIR = 'public/data/rivers';

function slugFromName(name, nameToId) {
  // PA records use "&"; states.json uses "and" — the only mismatch across all sources.
  const normalized = name.replace(/&/g, 'and');
  const id = nameToId.get(normalized);
  if (!id) throw new Error(`Unrecognized state name: "${name}"`);
  return id;
}

function run() {
  const states = JSON.parse(fs.readFileSync(STATES_PATH, 'utf-8'));
  const nameToId = new Map(states.map((s) => [s.name, s.id]));
  const stateIds = new Set(states.map((s) => s.id));

  const riversFlowingThrough = new Map(states.map((s) => [s.id, new Set()]));
  const basinRivers = new Map(states.map((s) => [s.id, new Set()]));
  const notableCityIds = new Map(states.map((s) => [s.id, new Set()]));
  const protectedAreaIds = new Map(states.map((s) => [s.id, new Set()]));

  const riverFiles = fs.readdirSync(RIVERS_DIR).filter((f) => f.endsWith('.json'));
  for (const file of riverFiles) {
    const river = JSON.parse(fs.readFileSync(path.join(RIVERS_DIR, file), 'utf-8'));
    for (const s of river.states_flows_through) {
      if (!stateIds.has(s)) throw new Error(`${file}: unknown state "${s}" in states_flows_through`);
      riversFlowingThrough.get(s).add(river.id);
    }
    for (const s of river.basin_states) {
      if (!stateIds.has(s)) throw new Error(`${file}: unknown state "${s}" in basin_states`);
      basinRivers.get(s).add(river.id);
    }
  }

  const cities = JSON.parse(fs.readFileSync('public/data/cities.json', 'utf-8'));
  for (const city of cities) {
    if (!stateIds.has(city.state)) throw new Error(`city "${city.id}": unknown state "${city.state}"`);
    notableCityIds.get(city.state).add(city.id);
  }

  const pas = JSON.parse(fs.readFileSync('public/data/protected-areas.json', 'utf-8'));
  for (const pa of pas) {
    for (const stateName of pa.state) {
      const id = slugFromName(stateName, nameToId);
      protectedAreaIds.get(id).add(pa.id);
    }
  }

  for (const state of states) {
    state.rivers_flowing_through = [...riversFlowingThrough.get(state.id)].sort();
    state.basin_rivers = [...basinRivers.get(state.id)].sort();
    state.notable_city_ids = [...notableCityIds.get(state.id)].sort();
    state.protected_area_ids = [...protectedAreaIds.get(state.id)].sort();
    State.parse(state);
  }

  fs.writeFileSync(STATES_PATH, JSON.stringify(states, null, 2) + '\n');

  const withRivers = states.filter((s) => s.rivers_flowing_through.length > 0).length;
  const withPAs = states.filter((s) => s.protected_area_ids.length > 0).length;
  const withCities = states.filter((s) => s.notable_city_ids.length > 0).length;
  console.log(`Wrote ${STATES_PATH}: ${states.length} states validated`);
  console.log(`  ${withRivers} with rivers_flowing_through, ${withPAs} with protected_area_ids, ${withCities} with notable_city_ids`);
}

run();
