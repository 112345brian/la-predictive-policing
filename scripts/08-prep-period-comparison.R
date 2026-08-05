# Builds a tract/period arrest-to-crime comparison table.
# Requires: 06-build-spatial.R

source(here::here("scripts", "_pipeline-helpers.R"))

lapd_spatial_all <- readRDS(processed_path("lapd-spatial.rds")) |>
  sf::st_drop_geometry() |>
  dplyr::mutate(
    incident_date = dplyr::coalesce(date_occ, arst_date),
    year = as.integer(format(incident_date, "%Y"))
  )

# Dropped from both crime and arrests, so each era spans the same years.
lapd_spatial <- lapd_spatial_all |>
  dplyr::filter(!year %in% INCOMPLETE_CRIME_YEARS)

year_span <- function(dates) {
  as.integer(format(max(dates, na.rm = TRUE), "%Y")) -
    as.integer(format(min(dates, na.rm = TRUE), "%Y")) + 1
}

n_years <- c(
  pre = year_span(lapd_spatial$incident_date[lapd_spatial$period == "pre"]),
  post = year_span(lapd_spatial$incident_date[lapd_spatial$period == "post"])
)

build_comparison <- function(data) {
  data |>
    dplyr::filter(!is.na(GEOID), !is_special_use_tract(GEOID)) |>
    dplyr::count(GEOID, period, type) |>
    tidyr::pivot_wider(names_from = type, values_from = n, values_fill = 0) |>
    dplyr::mutate(
      period = factor(period, levels = c("pre", "post")),
      arrest_crime_ratio = arrest / crime
    )
}

arrest_over_crime <- build_comparison(lapd_spatial)

# Uncorrected variant retaining the incomplete years,
# reported inline in Results to show what the exclusion changes.
arrest_over_crime_all_years <- build_comparison(lapd_spatial_all)

write_processed_dataset(
  list(
    arrest_over_crime = arrest_over_crime,
    arrest_over_crime_all_years = arrest_over_crime_all_years,
    n_years = n_years
  ),
  "period-comparison.rds"
)
