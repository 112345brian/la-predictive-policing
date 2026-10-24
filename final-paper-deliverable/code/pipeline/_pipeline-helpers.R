# Shared helpers for the reproducible data pipeline.

extract_cbsa <- function(x) {
  stringr::str_extract(x, "\\d{5}$")
}

processed_path <- function(...) {
  here::here("data", "processed", ...)
}

export_path <- function(...) {
  here::here("data", "export", ...)
}

raw_path <- function(...) {
  here::here("data", "raw", ...)
}

cache_path <- function(...) {
  here::here("data", "cache", ...)
}

ensure_processed_dir <- function() {
  dir.create(processed_path(), recursive = TRUE, showWarnings = FALSE)
}

ensure_export_dir <- function() {
  dir.create(export_path(), recursive = TRUE, showWarnings = FALSE)
}

ensure_cache_dir <- function() {
  dir.create(cache_path(), recursive = TRUE, showWarnings = FALSE)
}

# Write to a temp file, then rename: renaming is atomic within a filesystem,
# so a concurrent Quarto render reads the old version or the new one, never a
# partial write. saveRDS() in place turns that overlap into a hard error.
write_atomic <- function(path, write_fn) {
  tmp <- paste0(path, ".tmp-", Sys.getpid())
  on.exit(unlink(tmp), add = TRUE)

  write_fn(tmp)
  if (!file.rename(tmp, path)) {
    stop("could not move ", tmp, " into place at ", path)
  }

  invisible(NULL)
}

write_processed_dataset <- function(data, rds_name) {
  ensure_processed_dir()
  write_atomic(processed_path(rds_name), function(path) saveRDS(data, path))

  invisible(data)
}

write_export_csv <- function(data, csv_name) {
  ensure_export_dir()
  write_atomic(export_path(csv_name), function(path) readr::write_csv(data, path))

  invisible(data)
}

write_cache <- function(data, cache_name) {
  ensure_cache_dir()
  write_atomic(cache_path(cache_name), function(path) saveRDS(data, path))

  invisible(data)
}

with_cache <- function(cache_name, fn) {
  cache <- cache_path(cache_name)
  if (!file.exists(cache) || getOption("pipeline.import_raw", FALSE)) {
    data <- fn()
    write_cache(data, cache_name)
    data
  } else {
    readRDS(cache)
  }
}

# Three eras, not two with a gap: DICFP replaced PredPol in April 2020,
# so 2020-2021 are its first years. Fetched for the trend figure, excluded
# from the comparison -- COVID is not separable from the program change there.
PREDPOL_FIRST_YEAR <- 2015
PREDPOL_LAST_YEAR <- 2019
COVID_FIRST_YEAR <- 2020
COVID_LAST_YEAR <- 2021
DICFP_FIRST_YEAR <- 2022
DICFP_LAST_YEAR <- 2024

# SODA upper bounds are exclusive, so an era ending in Y runs to Jan 1 of Y+1.
year_boundary <- function(year) paste0(year, "-01-01")

PREDPOL_START <- year_boundary(PREDPOL_FIRST_YEAR)
PREDPOL_END <- year_boundary(PREDPOL_LAST_YEAR + 1)
COVID_START <- year_boundary(COVID_FIRST_YEAR)
COVID_END <- year_boundary(COVID_LAST_YEAR + 1)
DICFP_START <- year_boundary(DICFP_FIRST_YEAR)
DICFP_END <- year_boundary(DICFP_LAST_YEAR + 1)

# LAPD timestamps are naive wall-clock, no offset. Parse every date_occ and
# arst_date with this or the pipeline's date arithmetic is machine-dependent.
LAPD_TZ <- "America/Los_Angeles"

# The legacy crime dataset (2nrs-mtv8) stops updating here; records on or
# after are incomplete and get supplemented from NIBRS Offenses (y8y3-fqfu).
NIBRS_TRANSITION <- "2024-03-07"

# 2015 crime is missing four divisions (Topanga 0, Mission 1, Olympic 3,
# Southeast 871) while their arrests are complete, which would give those
# tracts five years of arrests over four of crime. Excluded, not corrected.
INCOMPLETE_CRIME_YEARS <- c(2015)

# Excluding a year above updates these and every label derived from them.
PREDPOL_ANALYSIS_YEARS <- setdiff(
  PREDPOL_FIRST_YEAR:PREDPOL_LAST_YEAR, INCOMPLETE_CRIME_YEARS
)
DICFP_ANALYSIS_YEARS <- setdiff(
  DICFP_FIRST_YEAR:DICFP_LAST_YEAR, INCOMPLETE_CRIME_YEARS
)

# 9800-series tracts are special land use (airports, ports, parks): incidents
# but almost no residents, so a composition share over them is noise.
is_special_use_tract <- function(geoid) {
  grepl("^[0-9]{5}98", geoid)
}

bind_periods <- function(pre, post) {
  dplyr::bind_rows(
    dplyr::mutate(pre, period = "pre", is_post = FALSE),
    dplyr::mutate(post, period = "post", is_post = TRUE)
  )
}

acs_year <- function() {
  as.integer(getOption("pipeline.acs_year", 2024))
}

acs_cache_name <- function(name) {
  paste0(name, "-", acs_year(), ".rds")
}
