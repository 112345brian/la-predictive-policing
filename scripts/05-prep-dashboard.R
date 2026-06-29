lapd_spatial <- readRDS(here::here("data", "processed", "lapd-spatial.rds"))
tracts <- readRDS(here::here("data", "cache", "tracts-post.rds"))

crime_counts <- lapd_spatial |>
  sf::st_drop_geometry() |>
  dplyr::filter(type == "crime") |>
  dplyr::count(GEOID)

dashboard_data <- tracts |>
  dplyr::left_join(crime_counts, by = "GEOID")

saveRDS(dashboard_data, here::here("data", "processed", "dashboard-data.rds"))
