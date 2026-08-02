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
