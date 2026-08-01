# Vicharashala Maps — Progress

Spec: `VICHARASHALA_MAPS_SPEC.md` (upload alongside this file if starting a new session).
Package manager: **pnpm**. Environment: **native Windows** (Git Bash, no WSL).

## How to resume in a new session
1. Upload this `PROGRESS.md`.
2. **Also re-upload `VICHARASHALA_MAPS_SPEC.md`** if you have it — my sandbox's copy became inaccessible partway through Step 4 (cache expiry, not a data-loss issue on your end), so some Step 4 decisions (see below) were made from memory/inference rather than re-checking exact spec prose. Worth a quick cross-check once the spec is back in context.
3. `pnpm install` — `pnpm-lock.yaml` is committed, restores exact versions, not "latest."
4. `pnpm build` to confirm things still build before adding new code.
5. Continue at "Next step" below.

## Workflow
- Code/config changes ship as a `stepN-patch.sh` script — run from the project root in Git Bash. Each is tested end-to-end against a clean checkout before being handed over, not just "should work." Idempotent, includes `pnpm install`.
- Generated **binary artifacts** (e.g. `.pmtiles`) ship as plain files to drop into place — they're build output, not source, so a patch script doesn't make sense for them.
- Linux-only native tools (tippecanoe) aren't available on native Windows. Sandbox builds them and hands over the finished artifact instead.
- Source data comes from `https://github.com/vicharashala-ui/ecoguesser.git`, a sibling project with already-processed PA data matching this spec almost field-for-field.

## Current status: Step 16 delivered, NOT YET RUN. Instead of continuing to build inspection tooling, actually researched WHY the 9 flagged rivers are wrong. Two concrete, well-evidenced findings:

1. **Ravi's expected length was wrong data, not a fetch problem.** `rivers-index-reconciled.json` had `length_km_india: 725` — that's the river's TOTAL length (India+Pakistan). Britannica, Wikipedia, and Mershon Center (OSU) all independently agree only ~320km is in India. Corrected to 320 — your matched 171km against a correct 320km is 0.53x, clean. Fixes Ravi outright.

2. **A real gap between Step 7's research and Step 12+'s query config.** `rivers-index-reconciled.json` already had an `aliases` field per river (documented during the original research) that `fetchRivers.js`'s `BATCHES` config never actually used — Overpass was only ever queried for each river's primary name. Cross-checked every flagged/unmatched river against its own `aliases` and found 10 with usable aliases sitting unused, including Jhelum ("Vyeth", its Kashmiri name — independently confirmed via web search) and Dibang ("Talon", its Idu-Mishmi name — also confirmed). Wired all 10 into `BATCHES`. This also exposed a resume-logic gap: regions already marked "complete" wouldn't get re-queried just because their variant list changed, so `fetchRivers.js` now persists a signature of each region's config and forces a re-fetch when it changes (tested: only regions with an actual change get re-queried, not all 8 — except this one time, since signature tracking itself is new).

**Not resolved**: Burhi Gandak, Dhansiri, Rushikulya, Purna, Girna, Vaitarna — didn't find an equally solid explanation for these; still need `inspectFlaggedRivers.js`'s output as the starting point for a manual look.

Remaining: 13 unmatched rivers (Spiti, Manas, Sankosh, Tamiraparani, Manimuktha, Chaliyar, Savitri, Vashisthi, Gurupur, Mechi, Kamla, Bagmati, Rupnarayan) — some of these (Manas, Sankosh, Tamiraparani, Chaliyar, Kamla) now have new alias variants in this patch, so may resolve on the next run; the rest still likely a genuine OSM coverage gap.

### rivers-index.json research + reconciliation: done
Built via web research (batched by river system per spec §4.9), then reconciled against Step 5c/6's govt shapefile + HydroRIVERS data in Step 8. `research/rivers-index-reconciled.json` (106 entries) is the current working file — supersedes `rivers-index-draft.json`, which is kept only as a historical record of the pre-reconciliation research.

**Count correction**: spec §4.9's river lists actually total 107 named rivers (9 Indus + 26 Ganga + 15 Brahmaputra + 29 Peninsular-East + 14 Peninsular-West + 12 Coastal + 2 Inland Drainage), not the ~105 figure used throughout this project so far. Every named entry in §4.9 has a draft record now.

- **Indus** (9/9), **Ganga** (26/26), **Brahmaputra** (15/15), **Peninsular-East** (29/29), **Peninsular-West** (14/14) — all done in prior updates
- **Coastal** (12/12 done): Ulhas, Vaitarna, Savitri, Vashisthi, Kali (Karnataka), Netravati, Gurupur, Aghanashini, Damanganga, Swarnamukhi, Manimuktha, Vaippar
- **Inland Drainage** (2/2 done): Luni, Ghaggar-Hakra
- Every entry has all `RiverIndexEntry` fields except `bounds` (added later in step ⑦ from geometry) and `stream_order` (left `null` — needs the real Strahler value from Step 6's HydroRIVERS join output, not invented here)

### Remaining open items before `prepareRivers.js`:
1. ~~Reconcile against Step 5c's govt data~~ — done, Step 8.
2. **Naming/identity questions**:
   - ~~**Kopili vs Kapili**~~ — resolved (Step 8): govt shapefile has one feature, matched under Kopili. `kapili` entry dropped as a duplicate, 107 → 106 total.
   - ~~**Purna**~~ — resolved, but not the way expected: the govt shapefile's one "Purna" feature is the *Godavari*-tributary Purna (basin "Godavari", origin "Ajanta Range"), not the Tapi-tributary one the draft uses (spec groups it with Narmada/Tapi/Mahi/Sabarmati — all west-flowing). Govt data for this entry was discarded as a false-positive match; the draft's Tapi-tributary Purna metadata stands, and it still needs its own geometry (now in the 46-river list).
   - **Vellar** (Peninsular-East) — still open, govt shapefile didn't match it either way, no new evidence. Tamil Nadu has two rivers by this name; draft used the Southern one.
3. **Length discrepancies >20%** between web research and govt data, flagged in Step 8/9's output, govt value used but worth a manual sanity check: Chenab (700→431km), Barak (524→100km), Subarnarekha (395→480km), Vaigai (258→312km), Bharathapuzha (209→100km), Kali/Karnataka (265→179km), Vaippar (130→87km).
4. **Entries with essentially no data found** (weakest of the weak — worth dedicated re-research before trusting): **Vashisthi** (no length at all), **Manimuktha** (nothing found), **Gurupur** (length is an unsourced guess), **Sankosh**/**Rangeet** (Brahmaputra, no length found), **Kamla** (Ganga, no length found)
5. **Everything else flagged `_needs_verification`** across all 7 batches — mostly derived/estimated lengths for transboundary rivers (India-only portion of a longer river) and unconfirmed `basin_area_india_km2`/`seasonal_type` values. Strip all `_source`/`_needs_verification` fields before final schema validation regardless.

### Not started yet
- **43 rivers without geometry** — see "Next step" for the remaining approach (name-matching improvements are exhausted, see Step 9)
- `scripts/prepareRivers.js` (step ⑦ proper — merges `research/rivers-index-draft.json` + geometry bounds + reconciled `stream_order` into the final validated `public/data/rivers-index.json`), `rivers.pmtiles` (step ⑧)
- `spatialIntersect.js` / `deriveStateCrossRefs.js` / `buildSearchIndex.js` (steps ⑪⑫⑬)
- Everything in spec §5 onward

## Next step
Run `step16-patch.sh`. It'll re-fetch all 8 batches once (one-time cost — signature tracking is new), then re-run merge + inspect automatically. Expect Ravi to disappear from flagged entirely, and Jhelum/Dibang/Manas/Sankosh/Tamiraparani/Chaliyar/Kamla to have a real shot at picking up new matches from the added aliases. Send back the console output and I'll help work through whatever's still flagged (Burhi Gandak, Dhansiri, Rushikulya, Purna, Girna, Vaitarna) plus decide on any rivers still genuinely unmatched (manual digitizing vs. accepting the gap for V1).

Once the flagged rivers are resolved and the unmatched-rivers decision is made:
- **`flagged`** entries (contamination — length way off from researched value, like the known Purna collision) need a manual look at `build/rivers-overpass.geojson` before merging into the final geometry.
- **`clean`** entries are ready to merge as-is.
- **Still `unmatched`** after a complete run (currently includes Spiti, Manas, Sankosh, Tamiraparani, Manimuktha — may change once all batches complete) is the genuinely-not-in-OSM-within-this-bbox list — manual research/digitizing territory, not more pipeline engineering.

After that: merge script combining the govt-shapefile geometry (Step 9, 63 rivers) + the Overpass geometry (this step) into one `build/rivers-matched-final.geojson`, then `prepareRivers.js` (spec §4.7 step ⑦ — simplify, compute bounds, produce final `public/data/rivers-index.json` + `rivers.pmtiles`).

---

## Completed steps log

### Step 16 — actually researched the 9 flagged rivers instead of building more tooling (delivered as `step16-patch.sh`)
Two fixes grounded in evidence, not more automation:

**Ravi's expected length was wrong.** `rivers-index-reconciled.json`'s `length_km_india: 725` for Ravi was the river's TOTAL length (India+Pakistan) — Britannica, Wikipedia, and Mershon Center (OSU) all independently give ~320km as the India-only portion (720-725km total, ~80km of that forming the border before entering Pakistan). Catchment area (14,442 km²) was already correctly India-scoped and matched Wikipedia exactly, suggesting the total-length figure got transcribed into the wrong field. Corrected to 320 — Ravi's actual 171km matched is 0.53x against the corrected figure, clean.

**Aliases were researched but never wired into the fetch config.** `rivers-index-reconciled.json` has had an `aliases` field per river since Step 7 — documented alternate/local/historical names — but `fetchRivers.js`'s `BATCHES` config was hand-authored separately and never pulled from it, so Overpass only ever got queried for each river's primary name. Systematically cross-checked every flagged/unmatched river's `aliases` against its current `BATCHES` variant list and found 10 with usable aliases sitting completely unused: Jhelum (Vyeth, Vitasta, Hydaspes), Ravi (Iravati, Purushni), Burhi Gandak (Sikrahna), Dibang (Talon), Manas (Drangme Chhu), Sankosh (Puna Tsang Chu), Tamiraparani (Tambraparni, Porunai), Chaliyar (Beypore River), Kamla (Balan), Rupnarayan (Dwarakeswar, Shilabati — split from the compound alias since OSM wouldn't tag the literal joined string). Independently confirmed Jhelum/Vyeth and Dibang/Talon via web search before trusting the aliases field blindly. Wired all 10 into `BATCHES` — strictly additive (OR-matched regex), so it can only surface more candidates, never fewer; for the already-over-matched rivers (Burhi Gandak, Rupnarayan) it won't fix their flag but doesn't make it worse either.

**This exposed a real gap in Step 13's resume logic**: a region was only re-fetched if its rivers lacked a matched/unmatched verdict — it never checked whether the *query config itself* had changed, so these new aliases would have been silently ignored for any region the old data already "completes". Fixed: `fetchRivers.js` now persists a signature (`JSON.stringify(batch.rivers)`) per region and forces a re-fetch whenever it no longer matches. One-time cost: this run re-fetches all 8 batches (signature tracking is new, so nothing matches yet); after that, only regions with a genuine future config change get re-queried, not all 8.

**Verified**: full regression suite (dedup, degenerate-geometry handling, idempotency) re-run against the updated `BATCHES` — all pass. New signature-invalidation logic tested with a fixture proving only intentionally-stale regions get re-queried while unchanged ones stay skipped. `research/rivers-index-reconciled.json`'s JSON validity re-checked after the edit (caught and fixed a trailing-comma break from the edit itself). Ran the actual `step16-patch.sh` end-to-end in a clean checkout (with Step 15's state simulated first, matching your real machine) — full pipeline (fetch → merge → inspect) runs clean through to completion even in the all-batches-fail edge case. Caught and fixed a heredoc-generation bug during this: `research/rivers-index-reconciled.json` has no trailing newline, which ran its closing `]` into the heredoc delimiter on the same line and would have corrupted the patch — general lesson, now inserting an explicit blank `echo` after every embedded file in patch scripts.

**Not resolved**: Burhi Gandak, Dhansiri, Rushikulya, Purna, Girna, Vaitarna — spent real effort (Dibang's search alone surfaced a length-definition ambiguity, upstream tributaries carry different names before the river is called "Dibang") but didn't reach an equally solid conclusion for these in the time spent. Flagging honestly rather than padding out speculative fixes.

### Step 15 — fixed a real crash in inspectFlaggedRivers.js (delivered as `step15-patch.sh`)
Root cause: `sampleStates()` picked sample indices as `[0, Math.floor((coords.length-1)/2), coords.length-1]` and indexed straight in. For a degenerate segment (0 or 1 coordinates), that math produces negative indices, `coords[-1]` is `undefined`, and `turf.point(undefined)` throws `"coordinates must contain numbers"` — exactly the error hit. `mergeOverpassRivers.js`'s own length loop never surfaced this because a `for` loop over an empty/single-element array just silently contributes 0 — same underlying data quirk, no crash, just no signal either.

Fix: coordinates are filtered to valid `[lon,lat]` pairs before any indexing (`isValidCoord`), a missing `geometry` is treated as no coordinates rather than crashing on `.coordinates` of `null`, and a segment left with nothing usable reports `UNRESOLVED` (same bucket as a genuine open-ocean/border segment) instead of stopping the run. Applied the same coordinate filter in the length calculation for consistency, though that path wasn't actually crashing.

**Verified**: reproduced the exact crash with a fixture mixing empty-coords, single-point, and null-geometry segments alongside a legit one — old code crashed identically, new code ran clean and correctly reported the bad segments as UNRESOLVED. Re-ran the full Step 14 fixture suite (contamination-drop, insufficient-coverage-stays-flagged, ocean-stays-unresolved) — all three verdicts unchanged, confirming the fix didn't regress the actual detection logic. Also ran the real `step15-patch.sh` in a clean checkout against a fixture mixing degenerate segments into two of the real flagged river names (Jhelum, Purna) — clean run.

### Step 14 — automated first pass on flagged rivers (delivered as `step14-patch.sh`, superseded by `step15-patch.sh`)
Adds `scripts/inspectFlaggedRivers.js`. A flagged river (length way outside 0.4x-1.6x expected) is usually a same-named-but-unrelated OSM way pulled in alongside the real one (already confirmed for Purna) — checkable without eyeballing coordinates, since every river has an expected `states` list in `rivers-index-reconciled.json`. Samples each segment's start/mid/end (not just one point, so a segment legitimately straddling a state border isn't misjudged) against `india-states.geojson`; a segment with no state match anywhere in the river's expected list is marked a drop-suspect, recomputes the ratio without it, and reports AUTO_RESOLVED if that brings it into range. Segments with no state match at all (open ocean, or a genuine cross-border stretch for transnational rivers like Jhelum/Ravi) are left UNRESOLVED rather than auto-dropped — can't confirm those are wrong.

This is a heuristic that narrows the manual work, not a replacement for it — a KEEP verdict isn't a correctness guarantee (two rivers can share a state), so AUTO_RESOLVED rivers still deserve a spot-check.

**Verified before shipping**: built synthetic fixtures covering all three verdict paths — real contamination (segment in an unrelated state) correctly dropped with the ratio corrected into range; a river still under-covered after dropping suspects correctly stays flagged; an open-ocean segment correctly left UNRESOLVED instead of being silently dropped. Also ran the actual `step14-patch.sh` in a clean checkout against a fixture built from the real 9 flagged river names + their real `states` metadata from the repo's own `rivers-index-reconciled.json`, to confirm no schema surprises against real data. Not run against the actual `build/rivers-overpass.geojson` on your machine — that's real segment geometry I don't have.

Also researched whether the 13 unmatched rivers might just be under a different OSM name/spelling (checked Spiti via web search) — found no alternate name in use for it at all, so didn't burn further searches chasing the same low-probability lead for the other 12. Recommend treating the 13 as a genuine OSM coverage gap (manual digitizing / Phase 2), not a query problem.

### Step 13 — fixed a real duplication bug in fetchRivers.js's resume logic (delivered as `step13-patch.sh`)
Diagnosed from your actual Step 12 console output, not a hypothesis: Step 12's `completedBatches` array was tracked separately from the `matched`/`unmatched`/`multiCandidate` data arrays. A region whose Overpass query succeeded but whose run ended before `completedBatches.push(region)` got persisted (interrupted run, or a run of an older pre-Step-11 script version) wasn't recognized as "done" on the next run — it got re-queried, and its matched features got pushed into the same flat `allFeatures` array a second time. Cross-checked your pasted unmatched/multi-candidate lists against the `BATCHES` config: every duplicated name (Spiti, Manas, Sankosh, Chaliyar, Jhelum, Ravi, Zanskar, Shyok, Dhansiri, Rangeet, Pamba) belonged to a region that got re-queried that run, and all 8 regions' 43 rivers were *already fully accounted for* in the existing `build/` files — the retries were pure waste, not genuinely-needed re-fetches. The doubling explains the previously-flagged Zanskar (2.01x), Pamba (1.89x), and Burhi Gandak (1.87x) — all ≈2x, not real OSM contamination.

**Fix**: `fetchRivers.js` no longer trusts a separately-tracked flag. `loadAndMigrate()` reconstructs, per region, whether every configured river already has a matched-or-unmatched verdict directly from the existing `build/rivers-overpass.geojson` + `-report.json`, deduping any doubled features by `osm_id` along the way. A region only counts as complete if *every* one of its rivers is accounted for; anything less gets re-fetched, nothing else does. `deriveReport()` is now always computed fresh from the feature data rather than accumulated — it can't drift out of sync the way the old flat push-arrays did. Output is written unconditionally at the end of every run (not just inside the fetch loop) so a fully-salvaged run still persists the deduped file to disk, not just the printed report.

**Verified end-to-end**, not just unit-level: built a fixture reproducing your exact reported bug pattern (4 regions with doubled features, matching your duplicate-name lists exactly), ran the actual `step13-patch.sh` against a clean checkout — result matched the prediction: "8/8 batches already complete on disk", zero Overpass calls, feature count 328→243 after dedup, Zanskar/Pamba/Burhi Gandak flipped from ~2x-flagged to clean (0.6–0.8x on the fixture's dummy geometry — real numbers will differ once run against your actual data, but the *mechanism* is confirmed fixed). Second run of the same patch script is a byte-identical no-op (idempotent). `osmtogeojson` import also made lazy (only loaded if a batch actually needs a live fetch) so the salvage-only path has no dependency on it being installed.

**Not independently verified against live Overpass** — my sandbox has no route to `overpass-api.de`/`overpass.kumi.systems` (`403 host_not_allowed`, confirmed via the egress proxy's deny header), same constraint noted in prior sessions. `queryOverpass`/`buildQuery`/`BATCHES` are untouched from the already-battle-tested Step 12 code; only the state-management layer around them changed, and that's what was tested above.

### Step 11-12 — merge script + made fetchRivers.js resumable (delivered as `step11-patch.sh`, superseded by `step12-patch.sh`)
- **`scripts/mergeOverpassRivers.js`**: real runs showed most "multi-candidate" rivers (Ravi: 11 candidates, Ken: 16, Sarda: 37, etc.) are normal — OSM maps long rivers as many separate way segments, not one line, so many matches per name is expected, not a name collision. Rather than manually eyeball coordinates for ~23 rivers, this merges same-name segments into one feature and sums their length, comparing the total against the web-researched `length_km_india` already in `rivers-index-reconciled.json`. A total far off from the researched figure is the real contamination signal (confirmed against the known Purna case — two unrelated rivers share that name, per Step 9 — synthetic segments summing to 2x the researched length correctly flagged; a normal 3-segment river at 1.0x correctly passed). Thresholds: <0.4x or >1.6x expected flags for manual review.
- **`fetchRivers.js` made resumable**: real runs showed a rotating subset of the 8 batches failing on rate-limits/timeouts on every single run so far — different batches each time, never all 8 in one pass. The script used to overwrite its entire output from scratch every run, so a batch that succeeded once could get lost if a later run of the whole script failed elsewhere before writing. Fixed to load its own previous `build/rivers-overpass.geojson`/`-report.json` on startup and skip any batch already in `completedBatches`, only retrying what previously failed. Verified: a second run against an already-completed batch makes zero network calls for it, and results accumulate correctly across runs (5 matched in run 1 + 3 more in run 2 = 8 total, not overwritten).
- Net effect: this is no longer "run once and report the result" — it's "keep re-running until `BATCHES THAT FAILED` is empty," and each re-run only costs whatever didn't succeed yet.

### Step 10 (in progress) — fetchRivers.js debugged against real Overpass, 2 real bugs found and fixed
Overpass reachability confirmed from your machine: `curl` to `overpass-api.de` returned `200`. Rewrote `scripts/fetchRivers.js`: bbox instead of `area["ISO3166-1"="IN"]` (the country-wide area lookup makes Overpass compute the whole India polygon before it can filter anything — almost certainly the real cause of the original v1 504, not the name regex), batched into 8 regions (indus_himalaya / ganga_upper / ganga_bihar_plains / brahmaputra_ne / kaveri_south_tn / kerala_west / konkan_goa_tapi / karnataka_andhra_coastal — `ganga_plains` was split into two after its first real run 504'd, being the largest bbox over the densest-mapped river network in the set), `waterway~"river|stream"` not just `river`, known name variants baked into each batch's query, multi-candidate rivers (Vellar, etc.) flagged rather than silently resolved.

First real runs against live Overpass surfaced two genuine bugs mocked testing hadn't caught:
1. **No client-side timeout on the HTTP request.** `[timeout:60]` in the query only bounds Overpass's own processing time, not the connection itself — when the mirror endpoint stalled without ever responding, `fetch()` hung forever. Fixed with an `AbortController` (query timeout + 20s) and `querying <endpoint>...` progress logging so a slow response is distinguishable from a dead one. Verified by mocking a `fetch` that truly never resolves — confirmed both endpoints now abort cleanly instead of hanging.
2. **`osmtogeojson@2.2.12` (the version actually pinned in this project) nests tags under `properties.tags.{key}`, not flattened onto `properties` directly.** The matcher read `properties.name` — always `undefined` — so real runs matched 0/43 despite Overpass correctly returning 127 real ways across 5 successful batches (server-side name filtering worked fine; purely a client-side property-path bug). My own earlier "passing" mocked tests used a different, newer `osmtogeojson` version (3.0.0-beta.5, pulled by a bare `npm install osmtogeojson` in my own test sandbox) that happens to flatten tags by default — that version mismatch is exactly why the bug wasn't caught before a real run. Fixed to read `properties.tags.name`, verified directly against a real sample response you sent (5/5 Purna features matched) and against a full mock run redone using the *correctly pinned* 2.2.12.

**Lesson logged**: when mocking a library's output shape for testing, pin the exact version from the project's lockfile, not whatever a fresh install resolves — different versions can have different default behavior and the mock will validate against the wrong one, giving false confidence.

Rate-limiting (429) and transient timeouts on various batches across runs so far look like normal Overpass flakiness, not script bugs — per-batch error isolation makes re-running cheap (small batches, no incremental skip-if-already-matched logic, but that's fine at this scale).

### Step 9 — 3 more rivers recovered + a duplicate-rivname data bug fixed (delivered as `step9-patch.sh`)
You uploaded `rivers-govt-raw.geojson` (the converted, pre-matching intermediate — 110 features). Checked all 43-at-the-time unmatched river names against it with exact/substring/Levenshtein(≤2) fuzzy matching:
- **Recovered 3**: Banas and Parbati (Chambal tributaries — never actually attempted before, `processRiversShapefile.js`'s `RIVER_NAMES` list didn't include them as separate entries at all, only Kali Sindh was in that gap and it's genuinely absent from the shapefile), and Manjira (shapefile spells it "Manjra" — added as a `VARIANT_MAP` entry).
- **Everything else genuinely absent** — this shapefile only has 110 named-river features nationally (a "major rivers" dataset), not partial coverage of the full ~106-river target list. No more recoverable via better matching.
- **Real bug found and fixed**: the shapefile has 3 duplicate `rivname`s (Banas, Wainganga, Sharavati — each has 2 unrelated/mismatched features under the same name). The old matcher's `Map.set()` silently kept whichever came last in iteration order. Wainganga happened to land on the correct feature by luck; **Sharavati did not** — it had already shipped in Step 8's output as 38.2km (a misclassified fragment under Netravati's sub-basin) instead of the real ~134km river, which is exactly why it showed up in Step 8's discrepancy list. Fixed by grouping candidates per name and picking explicitly via a `DISAMBIGUATE` config (keyed on `ba_name`/`sub_basin`); an unhandled duplicate now throws instead of guessing.
- `processRiversShapefile.js` also now skips the mapshaper conversion if `build/rivers-govt-raw.geojson` already exists, so re-running it doesn't require the original `.shp` files to still be present.
- Re-ran `reconcileGovtMetadata.js` with the corrected data: 60 → 63 govt-matched rivers, 46 → 43 still needing geometry, Sharavati's discrepancy resolved.
- Tested end-to-end on a clean checkout (with your uploaded raw geojson dropped into `build/`), twice for idempotency, output validated (106 unique IDs, correct Sharavati/Wainganga/Banas values).

### Step 8 — Govt/HydroRIVERS metadata reconciled into rivers-index research (delivered as `step8-patch.sh`)
- `scripts/reconcileGovtMetadata.js` — merges `build/rivers-govt-metadata.json` (Step 5c/6, 61 entries) into `research/rivers-index-draft.json` (107 entries), overriding `length_km_india` (only when not a multi-part/braided-channel sum, `needs_verification:false`) and `stream_order` (always, when present) — both are govt/HydroRIVERS-authoritative per §4.8. `basin`/`sub_basin`/`origin_description` from the govt file aren't applied — they don't map onto `RiverIndexEntry` schema fields, only onto the manually-authored `rivers/{id}.json` detail files (Phase 2, out of scope here).
- Output: `research/rivers-index-reconciled.json` (106 entries). `rivers-index-draft.json` untouched, kept as historical record.
- **Findings, all applied automatically by the script (see comments in `reconcileGovtMetadata.js` for the reasoning)**:
  - 3 of the govt shapefile's 61 matches used a different name spelling than the draft (`Ghaghra`→`Ghaghra (Karnali)`, `Kali`→`Kali (Karnataka)` — confirmed via govt `basin` field, `Ghaggar`→`Ghaggar-Hakra`) — the original exact-string matcher in `processRiversShapefile.js` doesn't alias these, so these 3 rivers' govt data was sitting unused until this step.
  - **Purna false positive**: the govt shapefile's only "Purna" feature is the Godavari-tributary one, not the Tapi-tributary one the spec's grouping implies. Excluded — see updated open items above.
  - **Kopili/Kapili**: resolved as duplicate, `kapili` dropped. 107 → 106 total rivers.
  - 60 of 106 entries got `stream_order` and/or `length_km_india` overridden with govt data; 8 of those have a >20% length discrepancy vs. web research (govt value used, listed above).
- Tested end-to-end on a clean checkout — idempotent (`git status --short` after 2 runs matches after 1), output validated (106 unique IDs, draft file untouched).

### Step 6 v2 — HydroRIVERS join, performance bug fixed
**v1 bug**: matched HydroRIVERS reaches onto named rivers via a linear per-candidate `pointToLineDistance` check with only a bbox pre-filter. Worked fine on a 90-reach synthetic test. At the real scale of India's bbox — **503,929 reaches**, an order of magnitude more than I'd estimated — this hung for 5+ hours with no progress output and no crash. My synthetic test never exercised anything close to real scale, which is exactly the gap that let this ship broken.

**Fix**: rewrote the matching as (1) a grid spatial index over reach midpoints (~2.2km cells, built once), (2) each named river's geometry resampled into regularly-spaced points (every 0.5km, independent of source vertex density) rather than checking against raw geometry, (3) for each sample point, only the 3×3 nearby grid cells are checked (a handful of candidates) instead of the full bbox-filtered set, with a real haversine distance for the final decision. Also added per-river progress logging with timing, so a genuine hang would be visible immediately instead of silent.

**Verified before shipping**: generated a 503,929-reach synthetic fixture matching HydroRIVERS' real density (uniform random scatter across the India bbox — if anything harder on the grid index than real river-clustered data), ran the actual patch script against it end-to-end on a clean checkout — 28-32 seconds, all 61 rivers matched, correctness re-confirmed against the smaller Chenab-based fixture from v1 (same results: order 13, ~103 reaches matched).

**Confirmed on real HydroRIVERS data**: 24.5s total, 61/61 rivers matched, no zero-match rivers — the stress test predicted real performance accurately.

### Step 5c — Government rivers shapefile processed (delivered as `step5c-patch.sh`)
*(Steps 5a/5b were an Overpass-first attempt — 406 then 504 errors, see git history in this file's earlier revisions if needed. Superseded once you found the data.gov.in shapefile; not worth carrying forward as separate log entries.)*
- Source: `data.gov.in` "Rivers" shapefile (you uploaded it directly — `Rivers.shp/.dbf/.shx/.prj/.cpg/.sbn/.sbx`)
- `scripts/processRiversShapefile.js` — converts via Mapshaper (WGS84 reprojection), matches the shapefile's 110 features against spec's 105-river list (handling spelling variants: Satluj→Sutlej, Gomati→Gomti, Ghaghara→Ghaghra, Sone→Son, Pranhitha→Pranhita, Cauvery→Kaveri, Kalinadi→Kali, Ghagghar→Ghaggar, etc.)
- **61/105 matched** with real geometry + government-sourced `basin`/`sub_basin`/`origin` text; **44 unmatched** (mostly smaller Western Ghats and Northeast tributaries not in this dataset — still need Overpass)
- **Length caveat**: 38 of 110 source features are `MultiLineString` (delta/braided channels digitized as separate parts, e.g. Ganga, Brahmaputra, Godavari, Yamuna, Krishna). The shapefile's `shape_Leng` field sums every part, inflating the figure well past commonly-cited lengths (this file's Ganga = 3096 km vs. the ~2525 km usually cited). `length_km_india` is only auto-filled for single-part rivers (29 of the 61 matched); the other 32 are left `null` with `needs_verification: true` rather than shipping an inflated number as fact.
- Outputs: `build/rivers-govt-matched.geojson` (61 features, canonical names), `build/rivers-govt-metadata.json` (partial rivers-index.json seed), `build/rivers-govt-report.json` (full matched/unmatched/needs-verification breakdown)
- **Gotcha hit and fixed**: `pnpm add -D mapshaper` exits with code 1 on first install (pnpm 11's supply-chain policy blocks native builds for `better-sqlite3`/`msgpackr-extract` by default) — same class of issue as Step 1's esbuild/sharp. Patch script now runs `pnpm approve-builds` right after, non-interactively.
- Verified end-to-end on a clean checkout of your actual repo (via GitHub), not just the dev sandbox
- Not started: full mainstem-length correction for the 32 flagged rivers (would need real longest-path extraction from the multi-part geometry, or a second source)

---

## Completed steps log

### Step 4 — State/UT metadata enrichment (delivered as `step4-patch.sh`)
- `scripts/enrichStates.js` — enriches all 36 features (28 states + 8 UTs) with `id`, `name`, `admin_type`, `capital`; validates each via the `State` zod schema
- Outputs `public/geojson/india-states.geojson` (geometry + minimal properties) and `public/data/states.json` (metadata only — mirrors the PA data's geometry/metadata split)
- Verified on a clean checkout with Steps 1-3 already applied — same 28/8 split both times, `pnpm build` still succeeds

**Source data finding:** `scripts/source-data/india-states.geojson` in ecoguesser is **already simplified** (Visvalingam, 200m interval, keep-shapes, 0.0001° precision — same method/tolerance as the PA boundaries). No Mapshaper invocation was needed for this step at all — it's pure JS, so Windows/Git Bash has zero friction here.

**Deviation from spec**: `rivers_flowing_through`, `basin_rivers`, `notable_city_ids`, `protected_area_ids` are left as empty arrays — these depend on the rivers pipeline and `spatialIntersect.js`/`deriveStateCrossRefs.js` (steps ⑥-⑧, ⑪, ⑫), none of which exist yet. Validated as empty arrays against the `State` schema (which allows this), not skipped.

**Capital list**: used the commonly-accepted single capital per state/UT (e.g. Jammu & Kashmir → Srinagar, its summer/main seat; Uttarakhand → Dehradun, the de facto seat over the designated-but-unused Gairsain). Worth a manual sanity check if precision on any specific one matters for your use case — this table isn't sourced from the ecoguesser repo, it's a static reference table I wrote.

**Note:** ecoguesser also has a documented topojson conversion for this same file (`convertStatesTopo.js`) that roughly halves gzip size (~216KB vs 333KB gzip) by deduplicating shared state borders — with well-documented reasoning for why they explicitly avoid mapshaper's auto-quantization (it silently produced an invalid/self-intersecting Andaman & Nicobar polygon). Not adopted here — spec's folder layout (`public/geojson/`) reads as plain GeoJSON, and adding topojson would mean a new client-side decode dependency not yet confirmed against the actual spec text. Worth revisiting as a size optimization later if needed — the exact reasoning/command is preserved in ecoguesser's script if we do.

### Step 1 — Project scaffold
- Astro v6.4.8 (pinned — spec targets v6, registry default is now v7) initialized manually with `pnpm init`, not `create-astro`, for exact version control
- Runtime deps: preact, @astrojs/preact@**5.1.5** (not 6.0.1 — see Decisions), maplibre-gl, pmtiles, nanostores, @nanostores/preact, fuse.js, virtua, @fontsource/sora, @fontsource/inter, tailwindcss@4 + @tailwindcss/vite@4
- Dev deps: zod@3 (build-time validation)
- `astro.config.mjs` (static output, Preact integration, Tailwind v4 Vite plugin), `tsconfig.json` (strict)
- Full folder skeleton per spec §5.2
- `pnpm build` and `pnpm dev` both verified working
- Git repo initialized

**Decisions/gotchas:**
- `@astrojs/preact@6.0.1` pulls in Vite 8 (rolldown, experimental) via `@preact/preset-vite`, which breaks `@tailwindcss/vite@4.3.3` (`Missing field tsconfigPaths` build error). Downgraded to `@astrojs/preact@5.1.5`, which targets Vite 7 — matches Astro 6's own `vite: ^7.3.2` requirement.
- Also had to add `vite@^7.3.2` as an **explicit devDependency** — without it, pnpm's peer resolution let a second Vite 8 sneak in via `@tailwindcss/vite`'s peer range (`^5||^6||^7||^8`), causing "Found 2 versions of vite." Pinning collapses everything onto one Vite 7 instance.
- zod v3, not v4 — spec's `.refine()` patterns are written against v3.

**Pinned versions:** astro 6.4.8 · @astrojs/preact 5.1.5 · preact 10.29.7 · vite 7.3.6 · maplibre-gl 5.24.0 · pmtiles 4.4.1 · tailwindcss/@tailwindcss/vite 4.3.3 · nanostores 1.4.1 · @nanostores/preact 1.1.0 · fuse.js 7.5.0 · virtua 0.44.3 · zod 3.25.76

### Step 2 — Protected Areas data pipeline (delivered as `step2-patch.sh`)
- `scripts/schemas.js` — Zod schemas per spec §4.1-4.4
- `scripts/ensureProperties.js` — canonicalizes all 837 raw ecoguesser IDs, injects `{name, category, area_km2}` into boundary file properties
- `scripts/mergeFeatures.js` — merges 835 boundary files, assigns sequential numeric Feature IDs, computes `bounds` via Turf `bbox()`, validates, writes `public/data/protected-areas.json` (837 records) + `public/data/pa-id-map.json`
- Verified on a clean checkout, not just the dev sandbox

**Data source findings:**
- ecoguesser's PA data is already at spec step ②'s output stage: 837 metadata records + 835 boundary GeoJSONs (2 fewer — boundary-less TRs, matches spec exactly). Filenames match metadata IDs 1:1, no fuzzy matching needed.
- **Deviation**: canonical IDs keep a `-{category}` suffix (`nameri-np` / `nameri-tr`) instead of spec's bare slug — 3 real sites hold two designations each (Keoladeo Ghana = NP+Ramsar, Nameri = NP+TR, Pilibhit = WLS+TR) and bare slugs collide. Verified unique across all 837.
- **Deviation**: `area_km2` relaxed to `.nonnegative()` — 10 real records (small island/urban sanctuaries) have unrecorded area = 0.
- Fields absent from source, defaulted (spec calls most Phase 2/curated anyway): `year_established`, `iucn_status`, `biome_type` → `null`; `endemic_species`, `aliases` → `[]`; `upsc_relevant` → `false`. `wikipedia_url` auto-derived from name.
- ecoguesser also has `india-boundary.geojson`, `scripts/source-data/india-states.geojson`, working `simplifyBoundaries.js`/`convertStatesTopo.js` — reusable for Step 4 (state boundaries).
- ecoguesser has **no river data** at all.

**Pinned versions:** @turf/turf 7.3.5 (devDependency)

### Step 3 — protected-areas.pmtiles (delivered as a binary file, not a patch script)
- Installed tippecanoe 2.49.0 in sandbox (unavailable on native Windows)
- Built `public/tiles/protected-areas.pmtiles` from `build/pa-merged.geojson` using spec §4.7 step ⑤'s command verbatim
- Verified via the `pmtiles` JS library: minZoom 4 / maxZoom 14, source-layer `protected-areas`, `id`+`category` fields present, bounds match India's extent, **8.68 MB** (well under Cloudflare's 25 MiB limit — no R2 offload needed)
- **Action needed**: place the delivered file at `public/tiles/protected-areas.pmtiles` in your project (overwrites the empty placeholder from Step 1)

