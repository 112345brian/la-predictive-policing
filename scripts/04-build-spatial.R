# Spatial join of LAPD incidents to census tracts and ACS demographics.

source(here::here("scripts", "_pipeline-helpers.R"))

lapd_crimes <- readRDS(processed_path("lapd-crimes.rds"))
lapd_arrests <- readRDS(processed_path("lapd-arrests.rds"))
acs_race <- readRDS(processed_path("acs-race.rds"))

lapd <- dplyr::bind_rows(
  dplyr::mutate(lapd_crimes, type = "crime"),
  dplyr::mutate(lapd_arrests, type = "arrest")
)

tracts_pre <- with_cache("tracts-pre.rds", function() {
  tigris::tracts(state = "CA", county = "Los Angeles", year = 2019) |>
    sf::st_transform(crs = 4326)
})

tracts_post <- with_cache("tracts-post.rds", function() {
  tigris::tracts(state = "CA", county = "Los Angeles", year = 2023) |>
    sf::st_transform(crs = 4326)
})

join_to_tracts <- function(data, tracts) {
  data |>
    dplyr::filter(!is.na(lat), !is.na(lon)) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
    sf::st_join(tracts["GEOID"])
}

lapd_spatial <- dplyr::bind_rows(
  join_to_tracts(dplyr::filter(lapd, period == "pre"), tracts_pre),
  join_to_tracts(dplyr::filter(lapd, period == "post"), tracts_post)
) |>
  dplyr::left_join(acs_race, by = c("GEOID", "period"))

write_processed_dataset(lapd_spatial, "lapd-spatial.rds")
