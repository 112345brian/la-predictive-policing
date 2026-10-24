# Completes 2024 crime by adding NIBRS Offenses to the legacy dataset.
# Requires: 01-build-crime-incidents.R
#
# LAPD migrated division by division, March-May 2024,
# so neither dataset covers the year alone.
# See "Data" for an explanation of why I add rather than splice.

source(here::here("scripts", "_pipeline-helpers.R"))
source(here::here("scripts", "_lapd-api.R"))

lapd_crimes <- readRDS(processed_path("lapd-crimes.rds"))

# time_occ is essential as a key.
# 16% of post-migration legacy rows share date+location+division
# with a different dr_no,
# so a timeless key drops real incidents.
# This is worst in the densest tracts.

overlap_key <- function(data) {
  paste(
    as.Date(data$date_occ, tz = LAPD_TZ),
    data$time_occ,
    data$lat,
    data$lon,
    data$area_name
  )
}

nibrs_crimes <- fetch_lapd_dataset(
  "y8y3-fqfu",
  paste0(
    "date_occ >= '",
    NIBRS_TRANSITION,
    "T00:00:00' AND ",
    "date_occ < '",
    DICFP_END,
    "T00:00:00'"
  ),
  "crime-nibrs-backfill.rds"
) |>
  dplyr::distinct(caseno, .keep_all = TRUE) |>
  dplyr::mutate(date_occ = as.POSIXct(date_occ, tz = LAPD_TZ))

legacy_post_migration <- dplyr::filter(
  lapd_crimes,
  date_occ >= as.POSIXct(NIBRS_TRANSITION, tz = LAPD_TZ)
)
legacy_keys <- overlap_key(legacy_post_migration)

nibrs_new <- dplyr::filter(
  nibrs_crimes,
  !overlap_key(nibrs_crimes) %in% legacy_keys
)

lapd_crimes_completed <- nibrs_new |>
  dplyr::transmute(
    date_occ,
    time_occ,
    lat,
    lon,
    area_name,
    period = "post",
    is_post = TRUE
  ) |>
  dplyr::bind_rows(lapd_crimes)

# Both directions fail silently otherwise. An empty NIBRS fetch would leave
# 2024 incomplete and every downstream figure would quietly regress; a
# time_occ format change on either side would match nothing and let the
# duplicates through. Overlap sits near 0.4%, so anything at 0 or above a
# tenth means the key stopped identifying incidents.
overlap_share <- (nrow(nibrs_crimes) - nrow(nibrs_new)) / nrow(nibrs_crimes)
stopifnot(
  nrow(nibrs_new) > 0,
  overlap_share > 0,
  overlap_share < 0.1
)

write_processed_dataset(lapd_crimes_completed, "lapd-crimes-completed.rds")

# Counts behind the figures quoted in the Data section.

crime_2024 <- lapd_crimes_completed |>
  dplyr::filter(format(date_occ, "%Y") == "2024") |>
  dplyr::count(month = format(date_occ, "%m"))

post_migration_months <- crime_2024$n[crime_2024$month >= "03"]
legacy_2024 <- sum(format(lapd_crimes$date_occ, "%Y") == "2024")

write_processed_dataset(
  list(
    n_nibrs_cases = nrow(nibrs_crimes),
    n_legacy_post_migration = nrow(legacy_post_migration),
    n_overlap_removed = nrow(nibrs_crimes) - nrow(nibrs_new),
    n_added = nrow(nibrs_new),
    jan_2024 = crime_2024$n[crime_2024$month == "01"],
    feb_2024 = crime_2024$n[crime_2024$month == "02"],
    post_migration_month_min = min(post_migration_months),
    post_migration_month_max = max(post_migration_months),
    total_2024 = sum(crime_2024$n),
    total_2024_legacy_only = legacy_2024
  ),
  "crime-backfill-stats.rds"
)
