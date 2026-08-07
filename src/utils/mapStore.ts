import { atom } from 'nanostores';
import type maplibregl from 'maplibre-gl';

// Set once by MapView.tsx after `load`; consumed by LayerControl/panels (separate islands)
// to call MapLibre methods (setLayoutProperty, flyTo, setFeatureState) without prop drilling.
export const mapInstance = atom<maplibregl.Map | null>(null);

export const selectedRiverId = atom<string | null>(null);
export const selectedPAId = atom<string | null>(null);
export const selectedStateId = atom<string | null>(null);
export const activePanel = atom<'river' | 'pa' | 'state' | null>(null);

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
  selectedStateId.set(id);
  activePanel.set(id ? 'state' : null);
}

export function closePanel(): void {
  selectedRiverId.set(null);
  selectedPAId.set(null);
  selectedStateId.set(null);
  activePanel.set(null);
}

// Browse/List mode (§3.7) — the primary keyboard-accessible route to feature selection,
// since MapLibre's KeyboardHandler is pointer-only for selection (§12).
export const browseOpen = atom<boolean>(false);
export const browseTab = atom<'rivers' | 'pa'>('rivers');
