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

# 2016 ships 57,809 records twice, identical across every column.
# This is the source of the apparent 2016 spike.
# I whole-row dedup rather than dr_no.
# A refresh with genuinely differing same-dr_no rows trips the guard below
# instead of silently keeping whichever the API returned first.

lapd_crimes <- dplyr::distinct(lapd_crimes)
stopifnot(!anyDuplicated(lapd_crimes$dr_no))

write_processed_dataset(lapd_crimes, "lapd-crimes.rds")
