# Fetches LAPD's historical PredPol prediction records from The Markup's
# public investigation dataset and aggregates them to census tract level.
# Source: https://github.com/the-markup/investigation-prediction-bias
#
# Coverage note: This only spans 2018-02-15 through 2020-04-03, not the
# full 2015-2019 "pre" period used elsewhere in this pipeline. Any comparison
# against current enforcement is really "2018-2020 PredPol targeting" vs.
# "2022-2024 DICFP-era enforcement," not the full PredPol era.

source(here::here("scripts", "_pipeline-helpers.R"))

markup_predictions_url <- paste0(
  "https://raw.githubusercontent.com/the-markup/",
  "investigation-prediction-bias/master/in.tar.xz"
)

fetch_la_predictions <- function() {
  tar_dest <- tempfile(fileext = ".tar.xz")
  extract_dir <- tempfile()
  dir.create(extract_dir)
  on.exit(unlink(c(tar_dest, extract_dir), recursive = TRUE))

  utils::download.file(
    markup_predictions_url,
    tar_dest,
    mode = "wb",
    quiet = TRUE
  )
  utils::untar(tar_dest, files = "in/all_predictions.csv", exdir = extract_dir)

  readr::read_csv(
    file.path(extract_dir, "in", "all_predictions.csv"),
    col_types = readr::cols(
      state = readr::col_integer(),
      county = readr::col_integer(),
      tract = readr::col_integer(),
      date = readr::col_date()
    )
  ) |>
    dplyr::filter(department == "la") |>
    dplyr::mutate(
      GEOID = sprintf("%02d%03d%06d", state, county, tract)
    ) |>
    dplyr::select(report_id, date, GEOID)
}

la_predictions <- with_cache(
  "predpol-la-predictions-raw.rds",
  fetch_la_predictions
)

predpol_predictions <- la_predictions |>
  dplyr::summarise(
    n_predictions = dplyr::n(),
    n_days_targeted = dplyr::n_distinct(date),
    date_min = min(date),
    date_max = max(date),
    .by = GEOID
  )

write_processed_dataset(predpol_predictions, "predpol-predictions.rds")
