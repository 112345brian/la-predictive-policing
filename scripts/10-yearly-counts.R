# Citywide crime and arrest counts by year, for the trend figure.
# Includes 2020-2021, which the era comparison excludes.
# Same "post" datasets,
# just outside the windows they are normally queried with.
# Requires: 02-build-arrests.R, 05-backfill-crime-nibrs.R

source(here::here("scripts", "_pipeline-helpers.R"))
source(here::here("scripts", "_lapd-api.R"))

yearly_counts_for <- function(type, raw_data, date_field, covid_resource_id) {
  pre_post <- raw_data |>
    dplyr::mutate(year = as.integer(format(.data[[date_field]], "%Y"))) |>
    dplyr::count(year, period, name = "n")

  covid <- fetch_lapd_dataset(
    covid_resource_id,
    paste0(
      date_field,
      " >= '",
      COVID_START,
      "T00:00:00' AND ",
      date_field,
      " < '",
      COVID_END,
      "T00:00:00'"
    ),
    paste0("yearly-", type, "s-covid-2020-2021.rds")
  ) |>
    dplyr::mutate(
      year = as.integer(
        format(as.POSIXct(.data[[date_field]], tz = LAPD_TZ), "%Y")
      )
    ) |>
    dplyr::count(year, name = "n") |>
    dplyr::mutate(period = "covid")

  dplyr::bind_rows(pre_post, covid) |>
    dplyr::mutate(
      type = type,
      period = factor(period, levels = c("pre", "covid", "post"))
    )
}

lapd_crimes <- readRDS(processed_path("lapd-crimes-completed.rds"))
lapd_arrests <- readRDS(processed_path("lapd-arrests.rds"))

yearly_counts <- dplyr::bind_rows(
  yearly_counts_for("arrest", lapd_arrests, "arst_date", "amvf-fr72"),
  yearly_counts_for("crime", lapd_crimes, "date_occ", "2nrs-mtv8")
)

write_processed_dataset(yearly_counts, "yearly-counts.rds")
