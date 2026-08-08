export type Bounds = [number, number, number, number]; // [west, south, east, north]

export interface RiverIndexEntry {
  id: string;
  name: string;
  local_name_hi: string;
  basin: string;
  length_km_india: number;
  basin_area_india_km2: number | null;
  drainage_type: 'himalayan' | 'peninsular' | 'coastal' | 'inland';
  stream_order: number;
  seasonal_type: 'perennial' | 'seasonal' | 'ephemeral';
  origin_type: 'glacial' | 'rain-fed' | 'spring-fed' | 'mixed';
  navigable: boolean;
  transnational: boolean;
  states: string[];
  aliases: string[];
  bounds: Bounds;
}

export type PACategory = 'np' | 'wls' | 'tr' | 'br' | 'ramsar';

export interface ProtectedArea {
  id: string;
  name: string;
  category: PACategory;
  state: string[];
  area_km2: number;
  centroid_lat: number;
  centroid_lng: number;
  has_boundary: boolean;
  river_ids: string[];
  year_established: number | null;
  wikipedia_url: string | null;
  upsc_relevant: boolean;
  aliases: string[];
  bounds: Bounds | null;
  iucn_status: string | null;
  biome_type: string | null;
  endemic_species: string[];
}

export interface BasinEntry {
  id: string;
  name: string;
  color_light: string;
  color_dark: string;
  area_km2: number;
  states: string[];
  main_river: string;
  rivers: string[];
  area_rank: number;
}

export interface CityEntry {
  id: string;
  name: string;
  state: string;
  river: string;
  river_bank: 'left' | 'right' | string;
  coordinates: [number, number];
  significance: string[];
  ghats: { id: string; name: string }[];
}

export interface StateEntry {
  id: string;
  name: string;
  admin_type: 'state' | 'ut';
  capital: string;
  rivers_flowing_through: string[];
  basin_rivers: string[];
  notable_city_ids: string[];
  protected_area_ids: string[];
}

// /data/rivers/{id}.json — detail, fetched on selection (§4.1). Used by RiverDetailPanel's
// future expansion and Compare mode (§3.10), whose table needs length_km_total/tributaries/sink
// that rivers-index.json doesn't carry.
export interface RiverDetail {
  id: string;
  name: string;
  aliases: string[];
  local_names: Record<string, string>;
  basin: string;
  type: 'main' | 'tributary' | 'distributary';
  drainage_type: RiverIndexEntry['drainage_type'];
  seasonal_type: RiverIndexEntry['seasonal_type'];
  origin_type: RiverIndexEntry['origin_type'];
  stream_order: number;
  wikimedia_image_id: string | null;
  source: { name: string; state: string; altitude_m: number; coordinates: [number, number] };
  sink: { name: string; type: string; location: string; coordinates: [number, number] };
  length_km_india: number;
  length_km_total: number;
  basin_area_total_km2: number | null;
  basin_area_india_km2: number | null;
  states_flows_through: string[];
  basin_states: string[];
  tributaries: { left: string[]; right: string[] };
  distributaries: string[];
  protected_area_ids: string[];
  navigable: boolean;
  transnational: boolean;
  transnational_countries: string[];
  significance: string[];
  notable_city_ids: string[];
  upsc_relevant: boolean;
  did_you_know: string[];
}

// search-index-primary.json / search-index-pa.json docs (scripts/buildSearchIndex.js) — trimmed
// to result-row fields only, not full record duplicates (§4.7 step ⑬).
export interface SearchRiverDoc {
  type: 'river';
  id: string;
  name: string;
  aliases: string[];
  length_km_india: number;
  drainage_type: RiverIndexEntry['drainage_type'];
  transnational: boolean;
}

export interface SearchStateDoc {
  type: 'state';
  id: string;
  name: string;
  capital: string;
  admin_type: StateEntry['admin_type'];
}

export interface SearchPADoc {
  type: 'pa';
  id: string;
  name: string;
  aliases: string[];
  category: PACategory;
  state: string[];
  area_km2: number;
}

export type SearchDoc = SearchRiverDoc | SearchStateDoc | SearchPADoc;
