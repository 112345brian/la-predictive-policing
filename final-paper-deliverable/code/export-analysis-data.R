# Exports the analysis datasets from the pipeline's .rds outputs to CSV,
# so they can be opened without R.
#
# Run from the repo root, so .Rprofile activates renv:
#   Rscript final-paper-deliverable/code/export-analysis-data.R
#
# Writes canonical copies to data/export/ (via the pipeline's own
# write_export_csv helper) and mirrors them into the submission bundle at
# final-paper-deliverable/data/.

source(here::here("scripts", "_pipeline-helpers.R"))

period_comparison <- readRDS(processed_path("period-comparison.rds"))
yearly_counts <- readRDS(processed_path("yearly-counts.rds"))
crime_backfill <- readRDS(processed_path("crime-backfill-stats.rds"))

exports <- list(
  "arrest-crime-panel.csv" = period_comparison$arrest_over_crime,
  "arrest-crime-panel-all-years.csv" = period_comparison$arrest_over_crime_all_years,
  "yearly-counts.csv" = yearly_counts,
  # n_years is two scalars, needed to turn era totals into per-year figures.
  "period-years.csv" = tibble::tibble(
    period = names(period_comparison$n_years),
    n_years = as.integer(period_comparison$n_years)
  ),
  "crime-backfill-stats.csv" = tibble::as_tibble(crime_backfill)
)

bundle_dir <- here::here("final-paper-deliverable", "data")
dir.create(bundle_dir, recursive = TRUE, showWarnings = FALSE)

for (csv_name in names(exports)) {
  write_export_csv(exports[[csv_name]], csv_name)
  file.copy(export_path(csv_name), file.path(bundle_dir, csv_name), overwrite = TRUE)
  message("wrote ", csv_name, " (", nrow(exports[[csv_name]]), " rows)")
}
