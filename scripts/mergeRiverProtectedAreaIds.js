// scripts/mergeRiverProtectedAreaIds.js
// Input:  build/river-protected-area-ids.json (spatialIntersect.js output, { river_id: [pa_id,...] })
//         public/data/rivers/{id}.json         (manually-authored detail files)
// Output: public/data/rivers/{id}.json          (protected_area_ids field updated in place)
//
// Does a targeted text replace of just the protected_area_ids field so unrelated formatting
// in each hand-authored file is left untouched (no full JSON.stringify re-serialization).

import fs from 'node:fs';
import path from 'node:path';

const RIVER_PA_IDS = 'build/river-protected-area-ids.json';
const RIVERS_DIR = 'public/data/rivers';
const FIELD_RE = /"protected_area_ids":\s*\[[^\]]*\]/;

function run() {
  const riverPA = JSON.parse(fs.readFileSync(RIVER_PA_IDS, 'utf-8'));
  const files = fs.readdirSync(RIVERS_DIR).filter((f) => f.endsWith('.json'));

  let updated = 0;
  let unchanged = 0;
  for (const file of files) {
    const filePath = path.join(RIVERS_DIR, file);
    const text = fs.readFileSync(filePath, 'utf-8');
    const river = JSON.parse(text);
    const computed = (riverPA[river.id] || []).slice().sort();

    if (JSON.stringify(river.protected_area_ids) === JSON.stringify(computed)) {
      unchanged++;
      continue;
    }

    const newField = computed.length === 0
      ? '"protected_area_ids": []'
      : `"protected_area_ids": [\n${computed.map((id) => `    "${id}"`).join(',\n')}\n  ]`;

    if (!FIELD_RE.test(text)) throw new Error(`${file}: protected_area_ids field not found`);
    const newText = text.replace(FIELD_RE, newField);

    // fail loudly if the replace didn't produce the intended value
    const check = JSON.parse(newText);
    if (JSON.stringify(check.protected_area_ids) !== JSON.stringify(computed)) {
      throw new Error(`${file}: replacement mismatch`);
    }

    fs.writeFileSync(filePath, newText);
    updated++;
  }

  console.log(`${updated} river file(s) updated, ${unchanged} already correct`);
}

run();
