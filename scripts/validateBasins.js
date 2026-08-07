// scripts/validateBasins.js
// basins.json is hand-edited (§4.7), so unlike the generated data files there's no pipeline
// step to validate it inline. Wired as package.json's "prebuild" so a bad edit (contrast
// failure, unknown river/state id, wrong type) is caught before every `pnpm build`, not just
// at authoring time.

import { readFileSync } from 'node:fs';
import { Basin } from './schemas.js';

const basins = JSON.parse(readFileSync('public/data/basins.json', 'utf-8'));
const riverIds = new Set(
  JSON.parse(readFileSync('public/data/rivers-index.json', 'utf-8')).map((r) => r.id)
);
const stateIds = new Set(
  JSON.parse(readFileSync('public/data/states.json', 'utf-8')).map((s) => s.id)
);

let errors = 0;

for (const basin of basins) {
  const result = Basin.safeParse(basin);
  if (!result.success) {
    errors++;
    console.error(`${basin.id ?? '(no id)'}: ${result.error.issues.map((i) => i.message).join('; ')}`);
    continue;
  }
  if (!basin.rivers.includes(basin.main_river)) {
    errors++;
    console.error(`${basin.id}: main_river "${basin.main_river}" not in rivers[]`);
  }
  for (const riverId of basin.rivers) {
    if (!riverIds.has(riverId)) {
      errors++;
      console.error(`${basin.id}: unknown river id "${riverId}"`);
    }
  }
  for (const stateId of basin.states) {
    if (!stateIds.has(stateId)) {
      errors++;
      console.error(`${basin.id}: unknown state id "${stateId}"`);
    }
  }
}

const rankSet = new Set(basins.map((b) => b.area_rank));
if (rankSet.size !== basins.length) {
  errors++;
  console.error(`area_rank is not unique across ${basins.length} basins`);
}

if (errors > 0) {
  console.error(`\nvalidateBasins.js: ${errors} error(s) in basins.json`);
  process.exit(1);
}

console.log(`validateBasins.js: ${basins.length} basins valid`);
