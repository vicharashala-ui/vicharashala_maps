// scripts/schemas.js
// Mirrors spec §4.1-4.4. Build-only — never shipped to the client bundle.
//
// DEVIATION FROM SPEC: `biome_type`, `iucn_status`, `endemic_species`, `wikipedia_url`,
// `year_established` are curated/enrichment fields the spec calls "sparse" or "Phase 2".
// Our real source data (ecoguesser repo) doesn't carry them yet, so ProtectedArea allows
// null/empty defaults here rather than failing validation. Tighten once enrichment lands.

import { z } from 'zod';

// DEVIATION FROM SPEC: `basin_area_india_km2` is nullable. 33 of the 85 V1-scope rivers never
// got a reliable figure during Step 7's web research (left null rather than invented) — this
// wasn't caught until Step 17b ran full schema validation against the complete geometry-backed
// set for the first time. HydroRIVERS' UPLAND_SKM is a possible backfill source but overstates
// India-only area for transnational rivers (includes upstream basin outside India), so it's not
// auto-substituted here. Tighten once real research backfills these.
export const RiverIndexEntry = z.object({
  id: z.string(),
  name: z.string(),
  local_name_hi: z.string(),
  basin: z.string(),
  length_km_india: z.number().positive(),
  basin_area_india_km2: z.number().positive().nullable(),
  drainage_type: z.enum(['himalayan', 'peninsular', 'coastal', 'inland']),
  stream_order: z.number().int().positive(),
  seasonal_type: z.enum(['perennial', 'seasonal', 'ephemeral']),
  origin_type: z.enum(['glacial', 'rain-fed', 'spring-fed', 'mixed']),
  navigable: z.boolean(),
  transnational: z.boolean(),
  states: z.array(z.string()),
  aliases: z.array(z.string()),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]),
});

export const ProtectedArea = z.object({
  id: z.string(),
  name: z.string(),
  category: z.enum(['np', 'wls', 'tr', 'br', 'ramsar']),
  state: z.array(z.string()),
  area_km2: z.number().nonnegative(), // 10 sites (small islands/urban WLS) have unrecorded area = 0
  centroid_lat: z.number(),
  centroid_lng: z.number(),
  has_boundary: z.boolean(),
  river_ids: z.array(z.string()),
  year_established: z.number().int().nullable(),
  wikipedia_url: z.string().url().nullable(),
  upsc_relevant: z.boolean(),
  aliases: z.array(z.string()),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]).nullable(),
  iucn_status: z.enum(['Ia', 'Ib', 'II', 'III', 'IV', 'V', 'VI']).nullable(),
  biome_type: z.string().nullable(),
  endemic_species: z.array(z.string()).max(3),
});

// rivers/{id}.json — spec §4.1. Manually authored; validated by authorRiverDetails.js
// before writing, same fail-loud pattern as the generated pipeline files.
export const RiverDetail = z.object({
  id: z.string(),
  name: z.string(),
  aliases: z.array(z.string()),
  local_names: z.record(z.string(), z.string()),
  basin: z.string(),
  type: z.enum(['main', 'tributary', 'distributary']),
  drainage_type: z.enum(['himalayan', 'peninsular', 'coastal', 'inland']),
  seasonal_type: z.enum(['perennial', 'seasonal', 'ephemeral']),
  origin_type: z.enum(['glacial', 'rain-fed', 'spring-fed', 'mixed']),
  stream_order: z.number().int().positive(),
  wikimedia_image_id: z.string().nullable(),
  source: z.object({
    name: z.string(),
    state: z.string(),
    altitude_m: z.number(),
    coordinates: z.tuple([z.number(), z.number()]),
  }),
  sink: z.object({
    name: z.string(),
    type: z.enum(['sea', 'river', 'lake']),
    location: z.string(),
    coordinates: z.tuple([z.number(), z.number()]),
  }),
  length_km_india: z.number().positive(),
  length_km_total: z.number().positive(),
  basin_area_total_km2: z.number().positive().nullable(),
  basin_area_india_km2: z.number().positive().nullable(),
  states_flows_through: z.array(z.string()),
  basin_states: z.array(z.string()),
  tributaries: z.object({ left: z.array(z.string()), right: z.array(z.string()) }),
  distributaries: z.array(z.string()),
  protected_area_ids: z.array(z.string()),
  navigable: z.boolean(),
  transnational: z.boolean(),
  transnational_countries: z.array(z.string()),
  significance: z.array(z.string()),
  notable_city_ids: z.array(z.string()),
  upsc_relevant: z.boolean(),
  did_you_know: z.array(z.string()),
});

// cities.json — spec §4.5. Manually authored, no generation script.
export const City = z.object({
  id: z.string(),
  name: z.string(),
  state: z.string(),
  river: z.string(),
  river_bank: z.enum(['left', 'right']),
  coordinates: z.tuple([z.number(), z.number()]),
  significance: z.array(z.string()),
  ghats: z.array(
    z.object({
      id: z.string(),
      name: z.string(),
      significance: z.string(),
    })
  ),
});

export const State = z.object({
  id: z.string(),
  name: z.string(),
  admin_type: z.enum(['state', 'ut']),
  capital: z.string(),
  rivers_flowing_through: z.array(z.string()),
  basin_rivers: z.array(z.string()),
  notable_city_ids: z.array(z.string()),
  protected_area_ids: z.array(z.string()),
});

function contrastRatio(hexA, hexB) {
  const luminance = (hex) => {
    const [r, g, b] = hex.match(/\w\w/g).map((c) => {
      const v = parseInt(c, 16) / 255;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const [l1, l2] = [luminance(hexA), luminance(hexB)].sort((a, b) => b - a);
  return (l1 + 0.05) / (l2 + 0.05);
}

const LAND_LIGHT = '#D4E6C3';
const LAND_DARK = '#1E3A2F';

export const Basin = z
  .object({
    id: z.string(),
    name: z.string(),
    color_light: z.string(),
    color_dark: z.string(),
    area_km2: z.number().positive(),
    states: z.array(z.string()),
    main_river: z.string(),
    rivers: z.array(z.string()),
    area_rank: z.number().int(),
  })
  .refine((b) => contrastRatio(b.color_light, LAND_LIGHT) >= 3.0, {
    message: 'color_light fails 3:1 non-text contrast against --color-land (light)',
  })
  .refine((b) => contrastRatio(b.color_dark, LAND_DARK) >= 3.0, {
    message: 'color_dark fails 3:1 non-text contrast against --color-land (dark)',
  });
