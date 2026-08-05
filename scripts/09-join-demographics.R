# Joins tract-level Black/Latino population share
# onto the arrest/crime comparison table, keyed by GEOID and period
# (ACS vintage tracks the same pre/post split as the crime and arrest data).
# Requires: 03-build-census.R, 08-prep-period-comparison.R

source(here::here("scripts", "_pipeline-helpers.R"))

acs_race <- readRDS(processed_path("acs-race.rds")) |>
  dplyr::mutate(period = factor(period, levels = c("pre", "post"))) |>
  dplyr::select(GEOID, period, pct_black_latino)

period_comparison <- readRDS(processed_path("period-comparison.rds"))

join_race <- function(data) {
  dplyr::left_join(data, acs_race, by = c("GEOID", "period"))
}

write_processed_dataset(
  list(
    arrest_over_crime = join_race(period_comparison$arrest_over_crime),
    arrest_over_crime_all_years = join_race(
      period_comparison$arrest_over_crime_all_years
    ),
    n_years = period_comparison$n_years
  ),
  "period-comparison.rds"
)
