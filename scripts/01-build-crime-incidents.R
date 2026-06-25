# Fetches raw LAPD crime incident data
# from the LA Open Data Portal (SODA 2.1)
# and combines pre-PredPol (2015-2019)
# and post-PredPol (2022-2024) periods.

source(here::here("scripts", "_pipeline-helpers.R"))
readRenviron(here::here("private", ".Renviron"))

should_import_raw <- getOption("pipeline.import_raw", FALSE)

# Fetch pre-period (2015-2019)

cache_pre <- cache_path("lapd-crimes-pre-raw.rds")

if (!file.exists(cache_pre) || should_import_raw) {
  lapd_crimes_pre <- httr2::request(
    "https://data.lacity.org/resource/63jg-8b9z.json"
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

# Fetch post-period (2022-2024)

cache_post <- cache_path("lapd-crimes-post-raw.rds")

if (!file.exists(cache_post) || should_import_raw) {
  lapd_crimes_post <- httr2::request(
    "https://data.lacity.org/resource/2nrs-mtv8.json"
  ) |>
    httr2::req_url_query(
      `$limit` = 2000000,
      `$where` = "date_occ >= '2022-01-01T00:00:00' AND date_occ < '2025-01-01T00:00:00'"
    ) |>
    httr2::req_headers(`X-App-Token` = Sys.getenv("LA_CITY_APP_TOKEN")) |>
    httr2::req_auth_basic(
      Sys.getenv("LA_CITY_EMAIL"),
      Sys.getenv("LA_CITY_PASSWORD")
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE)

  write_cache(lapd_crimes_post, "lapd-crimes-post-raw.rds")
} else {
  lapd_crimes_post <- readRDS(cache_post)
}

# Combine and label

lapd_crimes_raw <- dplyr::bind_rows(lapd_crimes_pre, lapd_crimes_post) |>
  dplyr::mutate(
    date_occ = as.POSIXct(date_occ),
    period = dplyr::case_when(
      date_occ < as.POSIXct("2020-01-01") ~ "pre",
      date_occ >= as.POSIXct("2022-01-01") ~ "post"
    ),
    is_post = period == "post"
  )

write_processed_dataset(lapd_crimes_raw, "lapd-crimes.rds")
