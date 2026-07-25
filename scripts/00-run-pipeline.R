# Runs the full data pipeline from raw inputs to analysis outputs.

import_raw <- getOption("pipeline.import_raw", FALSE) # If TRUE, pulls from API instead of cache
acs_year <- getOption("pipeline.acs_year", 2024)

source(here::here("scripts", "01-build-crime-incidents.R"))
source(here::here("scripts", "02-build-arrests.R"))
source(here::here("scripts", "03-build-census.R"))
source(here::here("scripts", "04-build-neighborhoods.R"))
source(here::here("scripts", "05-build-spatial.R"))
source(here::here("scripts", "06-prep-dashboard.R"))
source(here::here("scripts", "07-prep-period-comparison.R"))

# See the private directory for Markup/motivation scripts
