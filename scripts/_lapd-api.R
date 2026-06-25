# LAPD Open Data Portal fetch functions.

fetch_lapd_dataset <- function(resource_id, where_clause, cache_name) {
  cache <- cache_path(cache_name)
  if (!file.exists(cache) || getOption("pipeline.import_raw", FALSE)) {
    data <- httr2::request(
      paste0("https://data.lacity.org/resource/", resource_id, ".json")
    ) |>
      httr2::req_url_query(`$limit` = 2000000, `$where` = where_clause) |>
      httr2::req_headers(`X-App-Token` = Sys.getenv("LA_CITY_APP_TOKEN")) |>
      httr2::req_auth_basic(
        Sys.getenv("LA_CITY_EMAIL"),
        Sys.getenv("LA_CITY_PASSWORD")
      ) |>
      httr2::req_perform() |>
      httr2::resp_body_json(simplifyVector = TRUE)
    write_cache(data, cache_name)
  } else {
    data <- readRDS(cache)
  }
  data
}

fetch_lapd_periods <- function(
  pre_id,
  post_id,
  date_field,
  pre_cache,
  post_cache
) {
  pre_where <- paste0(
    date_field,
    " >= '2015-01-01T00:00:00' AND ",
    date_field,
    " < '2020-01-01T00:00:00'"
  )
  post_where <- paste0(
    date_field,
    " >= '2022-01-01T00:00:00' AND ",
    date_field,
    " < '2025-01-01T00:00:00'"
  )

  pre <- fetch_lapd_dataset(pre_id, pre_where, pre_cache)
  post <- fetch_lapd_dataset(post_id, post_where, post_cache)

  dplyr::bind_rows(pre, post) |>
    dplyr::mutate(
      !!date_field := as.POSIXct(.data[[date_field]]),
      period = dplyr::case_when(
        .data[[date_field]] < as.POSIXct("2020-01-01") ~ "pre",
        .data[[date_field]] >= as.POSIXct("2022-01-01") ~ "post"
      ),
      is_post = period == "post"
    )
}
