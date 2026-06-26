# Runs the full data pipeline from raw inputs to analysis outputs.

import_raw <- getOption("pipeline.import_raw", FALSE)
acs_year <- getOption("pipeline.acs_year", 2024)

source(here::here("scripts", "01-build-crime-incidents.R"))
source(here::here("scripts", "02-build-arrests.R"))
source(here::here("scripts", "03-build-census.R"))
