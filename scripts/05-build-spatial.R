# Spatial join of LAPD incidents to census tracts, ACS demographics, and neighborhoods.
# Requires 04-build-neighborhoods.R to have run first.

source(here::here("scripts", "_pipeline-helpers.R"))

# California Albers (equal-area, meters). Point-in-polygon joins run in this
# planar CRS instead of geographic (4326) coordinates, since sf routes 4326
# predicates through S2 spherical geometry, which is much slower than GEOS
# on a projected CRS at millions of rows. Output is transformed back to 4326
# at the end for downstream mapping.
join_crs <- 3310

lapd_crimes <- readRDS(processed_path("lapd-crimes.rds"))
lapd_arrests <- readRDS(processed_path("lapd-arrests.rds"))
acs_race <- readRDS(processed_path("acs-race.rds"))

lapd <- dplyr::bind_rows(
  dplyr::mutate(lapd_crimes, type = "crime"),
  dplyr::mutate(lapd_arrests, type = "arrest")
) |>
  # dr_no only identifies crime rows (arrests use rpt_id instead), so it
  # can't serve as a row key across both types once bound together. Give
  # every row its own id for the neighborhood-overlap dedup below.
  dplyr::mutate(row_id = dplyr::row_number())

neighborhoods <- readRDS(processed_path("neighborhoods.rds")) |>
  sf::st_transform(join_crs) |>
  dplyr::mutate(neighborhood_area = sf::st_area(geometry))

tracts_pre <- with_cache("tracts-pre.rds", function() {
  tigris::tracts(state = "CA", county = "Los Angeles", year = 2019) |>
    sf::st_transform(crs = join_crs)
})

tracts_post <- with_cache("tracts-post.rds", function() {
  tigris::tracts(state = "CA", county = "Los Angeles", year = 2023) |>
    sf::st_transform(crs = join_crs)
})

join_to_tracts <- function(data, tracts) {
  data |>
    dplyr::filter(!is.na(lat), !is.na(lon)) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
    sf::st_transform(join_crs) |>
    sf::st_join(tracts["GEOID"])
}

lapd_joined <- dplyr::bind_rows(
  join_to_tracts(dplyr::filter(lapd, period == "pre"), tracts_pre),
  join_to_tracts(dplyr::filter(lapd, period == "post"), tracts_post)
) |>
  dplyr::left_join(acs_race, by = c("GEOID", "period")) |>
  sf::st_join(neighborhoods, join = sf::st_intersects, left = TRUE)

# A point on the boundary of overlapping neighborhoods can match more than
# one; keep the largest-area match per row. Do the arrange+distinct dedup on
# a plain (geometry-dropped) key frame instead of the full sf object -
# dplyr's sf methods keep the geometry list-column consistent through every
# arrange/distinct call, which is expensive at ~2M rows for no benefit here,
# since only row_id/neighborhood_area matter for picking which row survives.
keep_row_ids <- lapd_joined |>
  sf::st_drop_geometry() |>
  dplyr::select(row_id, neighborhood_area) |>
  dplyr::arrange(row_id, dplyr::desc(neighborhood_area)) |>
  dplyr::distinct(row_id, .keep_all = TRUE) |>
  dplyr::pull(row_id)

lapd_spatial <- lapd_joined |>
  dplyr::filter(row_id %in% keep_row_ids) |>
  dplyr::select(-row_id, -neighborhood_area) |>
  sf::st_transform(4326)

write_processed_dataset(lapd_spatial, "lapd-spatial.rds")
