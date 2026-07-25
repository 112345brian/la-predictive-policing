# Fetches LAPD crime and arrest data for the same window covered by The
# Markup's recovered PredPol predictions (2018-02-15 to 2020-04-03, see
# scripts/08-build-predpol-predictions.R) and computes a tract-level
# arrest-to-crime ratio for that window.
#
# This lets predpol_targeting be checked against contemporaneous enforcement
# intensity directly. This is something The Markup's own disparate-impact analysis
# never did, which only benchmarked predictions against demographics only, never
# against reported crime; see private/research-design.md.

source(here::here("scripts", "_pipeline-helpers.R"))
source(here::here("scripts", "_lapd-api.R"))

window_start <- "2018-02-15"
window_end <- "2020-04-03"
window_split <- "2020-01-01" # boundary between LA's 2010-2019 and 2020-present open data resources

concurrent_crimes <- fetch_lapd_window(
  "63jg-8b9z",
  "2nrs-mtv8",
  "date_occ",
  window_start,
  window_end,
  window_split,
  "predpol-window-crimes-raw.rds"
)

concurrent_arrests <- fetch_lapd_window(
  "yru6-6re4",
  "amvf-fr72",
  "arst_date",
  window_start,
  window_end,
  window_split,
  "predpol-window-arrests-raw.rds"
)

tracts_pre <- with_cache("tracts-pre.rds", function() {
  tigris::tracts(state = "CA", county = "Los Angeles", year = 2019) |>
    sf::st_transform(crs = 3310)
})

join_to_tracts <- function(data) {
  data |>
    dplyr::filter(!is.na(lat), !is.na(lon)) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
    sf::st_transform(3310) |>
    sf::st_join(tracts_pre["GEOID"]) |>
    sf::st_drop_geometry()
}

concurrent_ratio <- dplyr::full_join(
  join_to_tracts(concurrent_crimes) |> dplyr::count(GEOID, name = "crime"),
  join_to_tracts(concurrent_arrests) |> dplyr::count(GEOID, name = "arrest"),
  by = "GEOID"
) |>
  tidyr::replace_na(list(crime = 0, arrest = 0)) |>
  dplyr::mutate(arrest_crime_ratio = arrest / crime)

predpol_predictions <- readRDS(processed_path("predpol-predictions.rds"))

predpol_concurrent_window <- dplyr::left_join(
  predpol_predictions,
  concurrent_ratio,
  by = "GEOID"
)

write_processed_dataset(
  predpol_concurrent_window,
  "predpol-concurrent-window.rds"
)
