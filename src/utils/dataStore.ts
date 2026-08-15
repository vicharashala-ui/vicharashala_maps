import { atom } from 'nanostores';
import type { RiverIndexEntry, StateEntry, ProtectedArea, BasinEntry, CityEntry, RiverDetail } from './types';

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
export const basins: BasinEntry[] = readInlineJSON('core-data-basins', []);
// Small (14 records), always-needed by StatePanel's "Notable cities" section — same
// zero-fetch inlining rationale as basins.json (§5.3 pattern, Step 37).
export const cities: CityEntry[] = readInlineJSON('core-data-cities', []);

const basinById = new Map(basins.map((b) => [b.id, b]));
export function getBasin(basinId: string): BasinEntry | undefined {
  return basinById.get(basinId);
}

const cityById = new Map(cities.map((c) => [c.id, c]));
export function getCity(cityId: string): CityEntry | undefined {
  return cityById.get(cityId);
}

const stateById = new Map(states.map((s) => [s.id, s]));
export function getState(stateId: string): StateEntry | undefined {
  return stateById.get(stateId);
}

// Genuine network fetch — needed only for search (§3.8), never for map construction or ROTD.
let searchIndexPromise: Promise<SearchIndexFile> | null = null;
export function loadSearchIndex(): Promise<SearchIndexFile> {
  searchIndexPromise ??= fetch('/data/search-index-primary.json').then((r) => r.json());
  return searchIndexPromise;
}

export interface SearchIndexFile {
  fuseVersion: string;
  keys: unknown;
  docs: Record<string, unknown>[];
  index: unknown;
}

export interface PAData {
  protectedAreas: ProtectedArea[];
  paIdMap: Record<string, number>;
  searchIndexPA: SearchIndexFile;
}

export const paDataLoaded = atom<boolean>(false);

let paDataPromise: Promise<PAData> | null = null;
export function loadPAData(): Promise<PAData> {
  paDataPromise ??= Promise.all([
    fetch('/data/protected-areas.json').then((r) => r.json()),
    fetch('/data/pa-id-map.json').then((r) => r.json()),
    fetch('/data/search-index-pa.json').then((r) => r.json()),
  ])
    .then(([protectedAreas, paIdMap, searchIndexPA]) => {
      paDataLoaded.set(true);
      return { protectedAreas, paIdMap, searchIndexPA };
    })
    // Without this, a rejected promise stays cached forever and every future call —
    // including a user-triggered Retry — just replays the same failure.
    .catch((err) => {
      paDataPromise = null;
      throw err;
    });
  return paDataPromise;
}

// Per-river detail (§4.1) — cached individually since only a handful of rivers get fetched in
// a given session (selection, Compare mode), unlike PA data which is one batch fetch of everything.
const riverDetailPromises = new Map<string, Promise<RiverDetail>>();
export function loadRiverDetail(riverId: string): Promise<RiverDetail> {
  let promise = riverDetailPromises.get(riverId);
  if (!promise) {
    promise = fetch(`/data/rivers/${riverId}.json`).then((r) => {
      if (!r.ok) throw new Error(`Failed to load river detail: ${riverId}`);
      return r.json();
    });
    riverDetailPromises.set(riverId, promise);
  }
  return promise;
}

// river ID -> segment Feature IDs in rivers.pmtiles (§4.6). Lazy — only needed post-selection
// for tributary/segment highlighting (§3.3), not first paint.
let riversIdMapPromise: Promise<Record<string, number[]>> | null = null;
export function loadRiversIdMap(): Promise<Record<string, number[]>> {
  riversIdMapPromise ??= fetch('/data/rivers-id-map.json').then((r) => r.json());
  return riversIdMapPromise;
}
