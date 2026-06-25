# Runs the full data pipeline from raw inputs to analysis outputs.

import_raw <- getOption("pipeline.import_raw", FALSE)
acs_year <- getOption("pipeline.acs_year", 2024)

source(here::here("scripts", "01-build-crime-incidents.R"))

# Fetch pre-period (2015-2019)

cache_pre <- cache_path("lapd-arrests-raw-pre.rds")

if (!file.exists(cache_pre) || should_import_raw) {
  lapd_crimes_pre <- httr2::request(
    "https://data.lacity.org/resource/yru6-6re4.json"
  ) |>
    httr2::req_url_query(
      `$limit` = 2000000,
      `$where` = "date_occ >= '2015-01-01T00:00:00' AND date_occ < '2020-01-01T00:00:00'"
    ) |>
    httr2::req_headers(`X-App-Token` = Sys.getenv("LA_CITY_APP_TOKEN")) |>
    httr2::req_auth_basic(
      Sys.getenv("LA_CITY_EMAIL"),
      Sys.getenv("LA_CITY_PASSWORD")
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE)

  write_cache(lapd_crimes_pre, "lapd-crimes-pre-raw.rds")
} else {
  lapd_crimes_pre <- readRDS(cache_pre)
}
