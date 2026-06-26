# Fetches raw LAPD crime incident data
# from the LA Open Data Portal (SODA 2.1)
# and combines pre-PredPol (2015-2019)
# and post-PredPol (2022-2024) periods.

source(here::here("scripts", "_pipeline-helpers.R"))
source(here::here("scripts", "_lapd-api.R"))

lapd_crimes <- fetch_lapd_periods(
  "63jg-8b9z",
  "2nrs-mtv8",
  "date_occ",
  "lapd-crimes-pre-raw.rds",
  "lapd-crimes-post-raw.rds"
)

write_processed_dataset(lapd_crimes, "lapd-crimes.rds")
