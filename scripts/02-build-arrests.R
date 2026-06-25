# Fetches raw LAPD arrest data
# from the LA Open Data Portal (SODA 2.1)
# and combines pre-PredPol (2015-2019)
# and post-PredPol (2022-2024) periods.

source(here::here("scripts", "_pipeline-helpers.R"))
readRenviron(here::here("private", ".Renviron"))

lapd_arrests <- fetch_lapd_periods(
  "yru6-6re4",
  "amvf-fr72",
  "arst_date",
  "lapd-arrests-pre-raw.rds",
  "lapd-arrests-post-raw.rds"
)

write_processed_dataset(lapd_arrests, "lapd-arrests.rds")
