# Spatial join of LAPD incidents to census tracts,
# ACS demographics, and neighborhoods.
# Requires:
# 02-build-arrests.R,
# 03-build-census.R,
# 04-build-neighborhoods.R,
# 05-backfill-crime-nibrs.R

source(here::here("scripts", "_pipeline-helpers.R"))

# Use California Albers since the area is not big enough to have
# to calculate the curves of the Earth.

join_crs <- 3310

lapd_crimes <- readRDS(processed_path("lapd-crimes-completed.rds"))
lapd_arrests <- readRDS(processed_path("lapd-arrests.rds"))
acs_race <- readRDS(processed_path("acs-race.rds"))

lapd <- dplyr::bind_rows(
  dplyr::mutate(lapd_crimes, type = "crime"),
  dplyr::mutate(lapd_arrests, type = "arrest")
) |>
  # dr_no only identifies crime rows (arrests use rpt_id instead),
  # so it can't serve as a row key across both types once bound together.
  # Give every row its own id for the neighborhood-overlap dedup below.
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

# A point on the boundary of overlapping neighborhoods matches more than one,
# so keep the largest-area match per incident.
# Pick the winning row by position.
# Do not use row_id.
# Filtering on distinct() dedupes nothing.
# The dedup runs on the geometry-dropped frame because
# dplyr's sf methods carry the geometry list-column through every arrange,
# which is expensive at 2M rows and
# pointless when only position and area decide the winner.
keep_positions <- lapd_joined |>
  sf::st_drop_geometry() |>
  dplyr::select(row_id, neighborhood_area) |>
  dplyr::mutate(position = dplyr::row_number()) |>
  dplyr::arrange(row_id, dplyr::desc(neighborhood_area)) |>
  dplyr::distinct(row_id, .keep_all = TRUE) |>
  dplyr::pull(position)

lapd_spatial <- lapd_joined[sort(keep_positions), ] |>
  dplyr::select(-row_id, -neighborhood_area) |>
  sf::st_transform(4326)

# This makes sure that we don't add rows.
stopifnot(nrow(lapd_spatial) == dplyr::n_distinct(lapd_joined$row_id))

# At least 95% of incidents got a tract, and
# at least 90% got a composition value.
match_rate <- function(x) mean(!is.na(x))
stopifnot(
  match_rate(lapd_spatial$GEOID) > 0.95,
  match_rate(lapd_spatial$pct_black_latino) > 0.90
)

write_processed_dataset(lapd_spatial, "lapd-spatial.rds")
