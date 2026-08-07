import { atom, computed } from 'nanostores';
import { riversIndex } from './dataStore';
import type { RiverIndexEntry, ProtectedArea } from './types';

export interface RiverFilters {
  states: string[];
  basins: string[];
  drainageType: RiverIndexEntry['drainage_type'] | null;
  transnational: boolean;
}

const EMPTY_RIVER_FILTERS: RiverFilters = { states: [], basins: [], drainageType: null, transnational: false };
export const riverFilters = atom<RiverFilters>(EMPTY_RIVER_FILTERS);

export function hasActiveRiverFilters(f: RiverFilters): boolean {
  return f.states.length > 0 || f.basins.length > 0 || f.drainageType !== null || f.transnational;
}

export function riverFilterCount(f: RiverFilters): number {
  return f.states.length + f.basins.length + (f.drainageType ? 1 : 0) + (f.transnational ? 1 : 0);
}

export function resetRiverFilters(): void {
  riverFilters.set(EMPTY_RIVER_FILTERS);
}

function riverMatches(r: RiverIndexEntry, f: RiverFilters): boolean {
  if (f.states.length && !f.states.some((s) => r.states.includes(s))) return false;
  if (f.basins.length && !f.basins.includes(r.basin)) return false;
  if (f.drainageType && r.drainage_type !== f.drainageType) return false;
  if (f.transnational && !r.transnational) return false;
  return true;
}

// `null` = no filters active = show everything. `riversIndex` is static core data (§5.3), so
// this only needs to recompute when `riverFilters` itself changes. Consumed by RiversLayer
// (map `setFilter`), RiverBrowseList (list filtering), and each filter panel's live count.
export const matchingRiverIds = computed(riverFilters, (f) =>
  hasActiveRiverFilters(f) ? new Set(riversIndex.filter((r) => riverMatches(r, f)).map((r) => r.id)) : null,
);

export interface PAFilters {
  categories: ProtectedArea['category'][];
  states: string[]; // matches `ProtectedArea.state` — Title Case display names, not id slugs
}

const EMPTY_PA_FILTERS: PAFilters = { categories: [], states: [] };
export const paFilters = atom<PAFilters>(EMPTY_PA_FILTERS);

export function hasActivePAFilters(f: PAFilters): boolean {
  return f.categories.length > 0 || f.states.length > 0;
}

export function paFilterCount(f: PAFilters): number {
  return f.categories.length + f.states.length;
}

export function resetPAFilters(): void {
  paFilters.set(EMPTY_PA_FILTERS);
}

// PA data is a lazy fetch (§5.3), not static like riversIndex, so this can't be a `computed`
// off filters alone — callers already hold the loaded `protectedAreas` array and filter inline.
export function paMatchesFilters(pa: ProtectedArea, f: PAFilters): boolean {
  if (f.categories.length && !f.categories.includes(pa.category)) return false;
  if (f.states.length && !f.states.some((s) => pa.state.includes(s))) return false;
  return true;
}
