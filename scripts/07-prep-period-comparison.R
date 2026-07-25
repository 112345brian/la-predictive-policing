# Builds a tract/period arrest-to-crime comparison table.
# Requires 05-build-spatial.R to have run first.

source(here::here("scripts", "_pipeline-helpers.R"))

lapd_spatial <- readRDS(processed_path("lapd-spatial.rds")) |>
  sf::st_drop_geometry() |>
  dplyr::mutate(incident_date = dplyr::coalesce(date_occ, arst_date))

year_span <- function(dates) {
  as.integer(format(max(dates, na.rm = TRUE), "%Y")) -
    as.integer(format(min(dates, na.rm = TRUE), "%Y")) + 1
}

n_years <- c(
  pre = year_span(lapd_spatial$incident_date[lapd_spatial$period == "pre"]),
  post = year_span(lapd_spatial$incident_date[lapd_spatial$period == "post"])
)

arrest_over_crime <- lapd_spatial |>
  dplyr::filter(!is.na(GEOID)) |>
  dplyr::count(GEOID, period, type) |>
  tidyr::pivot_wider(names_from = type, values_from = n, values_fill = 0) |>
  dplyr::mutate(
    period = factor(period, levels = c("pre", "post")),
    arrest_crime_ratio = arrest / crime
  )

write_processed_dataset(
  list(arrest_over_crime = arrest_over_crime, n_years = n_years),
  "period-comparison.rds"
)
