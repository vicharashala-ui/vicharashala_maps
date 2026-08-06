import { atom } from 'nanostores';
import type maplibregl from 'maplibre-gl';

// Set once by MapView.tsx after `load`; consumed by LayerControl/panels (separate islands)
// to call MapLibre methods (setLayoutProperty, flyTo, setFeatureState) without prop drilling.
export const mapInstance = atom<maplibregl.Map | null>(null);

export const selectedRiverId = atom<string | null>(null);
export const selectedPAId = atom<string | null>(null);
// State selection is map-only (highlight + fitBounds, §3.8) — no state info panel exists yet
// (tracked separately in PROGRESS.md), so this doesn't participate in `activePanel`.
export const selectedStateId = atom<string | null>(null);
export const activePanel = atom<'river' | 'pa' | null>(null);

export const paLayerVisible = atom<boolean>(false);
export const paLayerCategories = atom<Set<string>>(new Set(['np', 'wls', 'tr', 'br', 'ramsar']));

export { paDataLoaded } from './dataStore';

export function selectRiver(id: string | null): void {
  selectedPAId.set(null);
  selectedStateId.set(null);
  selectedRiverId.set(id);
  activePanel.set(id ? 'river' : null);
}

export function selectPA(id: string | null): void {
  selectedRiverId.set(null);
  selectedStateId.set(null);
  selectedPAId.set(id);
  activePanel.set(id ? 'pa' : null);
}

export function selectState(id: string | null): void {
  selectedRiverId.set(null);
  selectedPAId.set(null);
  activePanel.set(null);
  selectedStateId.set(id);
}

export function closePanel(): void {
  selectedRiverId.set(null);
  selectedPAId.set(null);
  selectedStateId.set(null);
  activePanel.set(null);
}
