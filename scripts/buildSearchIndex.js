// scripts/buildSearchIndex.js — spec §4.7 step ⑬ (run last)
// Input:  public/data/rivers-index.json, public/data/states.json, public/data/protected-areas.json
// Output: public/data/search-index-primary.json (rivers + states)
//         public/data/search-index-pa.json       (protected areas)
//
// Docs are trimmed to just what SearchBar.tsx's result rows need (§3.7/§3.8) — not full record
// duplication; full records are already loaded separately (inlined core-data / loadPAData()).
// `name` outweighs `aliases` so e.g. "Ganges" matches "Ganga" without outranking an exact hit.

import fs from 'node:fs';
import path from 'node:path';
import Fuse from 'fuse.js';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
// fuse.js's package.json doesn't expose a "./package.json" subpath export, so resolve the
// module's dist entry (.../fuse.js/dist/fuse.cjs) and walk up two dirs to its package.json.
// Uses node:path throughout (not string slicing on '/') so it works on Windows too.
const fuseEntry = require.resolve('fuse.js');
const fusePkgPath = path.join(path.dirname(fuseEntry), '..', 'package.json');
const fuseVersion = JSON.parse(fs.readFileSync(fusePkgPath, 'utf-8')).version;

const KEYS = [
  { name: 'name', weight: 2 },
  { name: 'aliases', weight: 1 },
];

function assertNoVersionDrift(outPath) {
  if (!fs.existsSync(outPath)) return;
  const committed = JSON.parse(fs.readFileSync(outPath, 'utf-8'));
  if (committed.fuseVersion !== fuseVersion) {
    throw new Error(
      `${outPath}: committed index was built with fuse.js ${committed.fuseVersion}, ` +
      `but installed version is ${fuseVersion}. Re-run this script to rebuild the index.`
    );
  }
}

function writeIndex(outPath, docs) {
  assertNoVersionDrift(outPath);
  const index = Fuse.createIndex(KEYS, docs);
  fs.writeFileSync(outPath, JSON.stringify({ fuseVersion, keys: KEYS, docs, index: index.toJSON() }));
  console.log(`Wrote ${outPath}: ${docs.length} docs`);
}

function run() {
  const riversIndex = JSON.parse(fs.readFileSync('public/data/rivers-index.json', 'utf-8'));
  const states = JSON.parse(fs.readFileSync('public/data/states.json', 'utf-8'));
  const pas = JSON.parse(fs.readFileSync('public/data/protected-areas.json', 'utf-8'));

  const riverDocs = riversIndex.map((r) => ({
    type: 'river',
    id: r.id,
    name: r.name,
    aliases: r.aliases,
    length_km_india: r.length_km_india,
    drainage_type: r.drainage_type,
    transnational: r.transnational,
  }));

  const stateDocs = states.map((s) => ({
    type: 'state',
    id: s.id,
    name: s.name,
    capital: s.capital,
    admin_type: s.admin_type,
  }));

  writeIndex('public/data/search-index-primary.json', [...riverDocs, ...stateDocs]);

  const paDocs = pas.map((p) => ({
    type: 'pa',
    id: p.id,
    name: p.name,
    aliases: p.aliases,
    category: p.category,
    state: p.state,
    area_km2: p.area_km2,
  }));

  writeIndex('public/data/search-index-pa.json', paDocs);
}

run();
