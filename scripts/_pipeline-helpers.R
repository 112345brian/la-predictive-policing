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

write_processed_dataset <- function(data, rds_name) {
  ensure_processed_dir()
  saveRDS(data, processed_path(rds_name))

  invisible(data)
}

write_export_csv <- function(data, csv_name) {
  ensure_export_dir()
  readr::write_csv(data, export_path(csv_name))
  invisible(data)
}

write_cache <- function(data, cache_name) {
  ensure_cache_dir()
  saveRDS(data, cache_path(cache_name))
  invisible(data)
}

acs_year <- function() {
  as.integer(getOption("pipeline.acs_year", 2024))
}

acs_cache_name <- function(name) {
  paste0(name, "-", acs_year(), ".rds")
}
