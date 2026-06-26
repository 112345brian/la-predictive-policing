# Builds ACS race/ethnicity data to census tract level for LA County.

source(here::here("scripts", "_pipeline-helpers.R"))

race_raw <- with_cache(acs_cache_name("acs-race-raw"), function() {
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
    year = acs_year(),
    survey = "acs5",
    cache_table = TRUE,
    output = "wide"
  )
})

acs_race <- race_raw |>
  dplyr::mutate(
    pct_black_latino = (non_hispanic_blackE + hispanic_or_latinoE) / totalE
  )

write_processed_dataset(acs_race, "acs-race.rds")
