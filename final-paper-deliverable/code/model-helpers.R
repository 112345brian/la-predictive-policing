# Middle era is DICFP's first two years, shown but excluded from analysis.
era_colors <- c(pre = "#2c3e50", covid = "#8a8f99", post = "#c98a2c")
era_text_labels <- c(
  pre = "PredPol Era",
  covid = "Early DICFP\n(COVID, excluded)",
  post = "DICFP Era"
)

# Years come from _pipeline-helpers.R, so excluding a year narrows these too.
span_of <- function(years) paste0(min(years), "-", max(years))

era_span <- c(
  pre = span_of(PREDPOL_ANALYSIS_YEARS),
  post = span_of(DICFP_ANALYSIS_YEARS)
)

# Drops tract-periods with a zero-crime denominator or missing composition.
analysis_sample <- function(data) {
  dplyr::filter(data, crime > 0, !is.na(pct_black_latino))
}

# Headline period x racial composition model:
# NB GEE clustered by tract, crime as offset.
# geem() needs dispersion pre-estimated via glm.nb().
fit_interaction_gee <- function(data) {
  model_data <- data |>
    analysis_sample() |>
    dplyr::arrange(GEOID) |>
    as.data.frame()

  formula <- arrest ~ period * pct_black_latino + offset(log(crime))
  nb_fit <- MASS::glm.nb(formula, data = model_data)

  fit <- geeM::geem(
    formula,
    id = GEOID,
    family = MASS::negative.binomial(nb_fit$theta),
    corstr = "exchangeable",
    data = model_data
  )

  summary(fit)
}

# Formats one term from a fit_interaction_gee() summary for inline prose.
gee_term <- function(gee_summary, term) {
  i <- which(gee_summary$coefnames == term)
  list(
    estimate = scales::number(gee_summary$beta[i], accuracy = 0.001),
    p = scales::number(gee_summary$p[i], accuracy = 0.001),
    irr = scales::number(exp(gee_summary$beta[i]), accuracy = 0.01)
  )
}

# Formats a period x stat table from spec
# (stat, label, accuracy, percent?).
# Returns a kable-ready wide table plus a flat list
# (display$median_ratio_pre) for inline prose.
stat_table <- function(stats, spec) {
  if (!"percent" %in% names(spec)) {
    spec$percent <- FALSE
  }

  long <- stats |>
    tidyr::pivot_longer(-period, names_to = "stat", values_to = "value") |>
    dplyr::left_join(spec, by = "stat") |>
    dplyr::mutate(
      fmt = purrr::pmap_chr(
        list(value, accuracy, percent),
        function(value, accuracy, percent) {
          if (percent) {
            scales::percent(value, accuracy = accuracy)
          } else {
            scales::number(value, accuracy = accuracy, big.mark = ",")
          }
        }
      )
    )

  display <- long |>
    dplyr::mutate(key = paste(stat, period, sep = "_")) |>
    dplyr::select(key, fmt) |>
    tibble::deframe() |>
    as.list()

  table <- long |>
    dplyr::select(period, label, fmt) |>
    tidyr::pivot_wider(names_from = period, values_from = fmt) |>
    dplyr::rename(Statistic = label)

  list(table = table, display = display)
}
