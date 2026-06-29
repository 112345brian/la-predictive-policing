lapd_spatial <- readRDS(here::here("data", "processed", "lapd-spatial.rds"))
tracts <- readRDS(here::here("data", "cache", "tracts-post.rds"))

crime_incidents <- lapd_spatial |>
  sf::st_drop_geometry() |>
  dplyr::filter(type == "crime")

year_min <- min(crime_incidents$date_occ, na.rm = TRUE) |>
  format("%Y") |>
  as.integer()
year_max <- max(crime_incidents$date_occ, na.rm = TRUE) |>
  format("%Y") |>
  as.integer()
n_years <- year_max - year_min + 1

crime_counts <- crime_incidents |>
  dplyr::count(GEOID)

acs_race <- readRDS(here::here("data", "processed", "acs-race.rds")) |>
  dplyr::filter(is_post) |>
  dplyr::select(
    GEOID,
    totalE,
    non_hispanic_whiteE,
    non_hispanic_blackE,
    hispanic_or_latinoE
  )

dashboard_data <- tracts |>
  dplyr::filter(!grepl("^\\d{5}98", GEOID)) |>
  dplyr::left_join(crime_counts, by = "GEOID") |>
  dplyr::left_join(acs_race, by = "GEOID") |>
  dplyr::filter(is.na(n) | is.na(totalE) | totalE == 0 | (n / totalE) < 1) |> # Keep this filter to take out non-residential or institutional tracts.
  dplyr::mutate(crimes_per_year = n / n_years) |>
  sf::st_transform(4326)

saveRDS(
  list(
    dashboard_data = dashboard_data,
    year_min = year_min,
    year_max = year_max,
    n_years = n_years
  ),
  here::here("data", "processed", "dashboard-data.rds")
)
