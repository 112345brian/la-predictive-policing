# Builds ACS race/ethnicity data to census tract level for LA County.
# Pulls two snapshots aligned with the pre- (2019) and post- (2023) periods.

source(here::here("scripts", "_pipeline-helpers.R"))

tidycensus::census_api_key(Sys.getenv("CENSUS_API_KEY"))

fetch_acs_race <- function(year) {
  with_cache(paste0("acs-race-", year, "-raw.rds"), function() {
    tidycensus::get_acs(
      geography = "tract",
      state = "CA",
      county = "Los Angeles",
      variables = c(
        total = "B03002_001",
        non_hispanic_white = "B03002_003",
        non_hispanic_black = "B03002_004",
        hispanic_or_latino = "B03002_012"
      ),
      year = year,
      survey = "acs5",
      cache_table = TRUE,
      output = "wide"
    )
  })
}

acs_race <- bind_periods(fetch_acs_race(2019), fetch_acs_race(2023)) |>
  dplyr::mutate(
    pct_black_latino = (non_hispanic_blackE + hispanic_or_latinoE) / totalE
  )

write_processed_dataset(acs_race, "acs-race.rds")
