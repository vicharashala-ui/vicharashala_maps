import { atom } from 'nanostores';
import type { RiverIndexEntry, StateEntry, ProtectedArea } from './types';

// index.astro embeds these as inert JSON in a <script type="application/json"> tag (§5.3) —
// read synchronously at module load, no fetch, no await.
// DEVIATION: falls back to an empty array outside a browser/Astro context (e.g. unit tests)
// instead of throwing, since this module is also imported by non-page tooling.
function readInlineJSON<T>(elementId: string, fallback: T): T {
  if (typeof document === 'undefined') return fallback;
  const el = document.getElementById(elementId);
  if (!el?.textContent) return fallback;
  return JSON.parse(el.textContent) as T;
}

export const riversIndex: RiverIndexEntry[] = readInlineJSON('core-data-rivers', []);
export const states: StateEntry[] = readInlineJSON('core-data-states', []);

// DEVIATION FROM SPEC §5.3: search-index-pa.json (pipeline step ⑬) doesn't exist yet, so
// loadPAData() fetches only protected-areas.json + pa-id-map.json. Add the search index fetch
// back once buildSearchIndex.js ships.
export interface PAData {
  protectedAreas: ProtectedArea[];
  paIdMap: Record<string, number>;
}

export const paDataLoaded = atom<boolean>(false);

let paDataPromise: Promise<PAData> | null = null;
export function loadPAData(): Promise<PAData> {
  paDataPromise ??= Promise.all([
    fetch('/data/protected-areas.json').then((r) => r.json()),
    fetch('/data/pa-id-map.json').then((r) => r.json()),
  ]).then(([protectedAreas, paIdMap]) => {
    paDataLoaded.set(true);
    return { protectedAreas, paIdMap };
  });
  return paDataPromise;
}

// river ID -> segment Feature IDs in rivers.pmtiles (§4.6). Lazy — only needed post-selection
// for tributary/segment highlighting (§3.3), not first paint.
let riversIdMapPromise: Promise<Record<string, number[]>> | null = null;
export function loadRiversIdMap(): Promise<Record<string, number[]>> {
  riversIdMapPromise ??= fetch('/data/rivers-id-map.json').then((r) => r.json());
  return riversIdMapPromise;
}
