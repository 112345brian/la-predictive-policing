# Shared era styling for yearly-trend figures.
# The middle era is DICFP's first two years, shown but not analyzed,
# so it is styled to recede against the two eras being compared.
era_colors <- c(pre = "#2c3e50", covid = "#8a8f99", post = "#c98a2c")
era_text_labels <- c(
  pre = "PredPol Era",
  covid = "Early DICFP\n(COVID, excluded)",
  post = "DICFP Era"
)

# Formatted era spans, for labelling tables and figures.
# The underlying years come from _pipeline-helpers.R,
# where excluding a year narrows the analysis window
# and therefore these labels too.
span_of <- function(years) paste0(min(years), "-", max(years))

era_span <- c(
  pre = span_of(PREDPOL_ANALYSIS_YEARS),
  post = span_of(DICFP_ANALYSIS_YEARS)
)

# The tract-periods the analysis is actually fit on.
# A rate needs a non-zero denominator,
# and the interaction needs a composition value to interact with.
# Shared so that counts quoted in the text describe the sample modeled,
# rather than the table it was drawn from.
analysis_sample <- function(data) {
  dplyr::filter(data, crime > 0, !is.na(pct_black_latino))
}

# Fits the headline period x racial composition model:
# a negative binomial GEE clustered by tract,
# with reported crime as an offset so arrest counts are modeled as a rate.
# Tracts with zero recorded crime or missing demographics are dropped.
# The dispersion parameter has to be estimated by a plain negative binomial
# fit first, since geem() needs it supplied.
# Used for both the headline model and the sensitivity check.
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

# Pulls one term out of a fit_interaction_gee() summary as formatted strings,
# for quoting a coefficient inline in prose.
# Returns estimate, p, and IRR.
gee_term <- function(gee_summary, term) {
  i <- which(gee_summary$coefnames == term)
  list(
    estimate = scales::number(gee_summary$beta[i], accuracy = 0.001),
    p = scales::number(gee_summary$p[i], accuracy = 0.001),
    irr = scales::number(exp(gee_summary$beta[i]), accuracy = 0.01)
  )
}

# Formats a period x stat summary table given a spec tibble
# (stat, label, accuracy, and optionally percent).
# Stats with percent = TRUE are formatted as e.g. "58.6%" instead of "0.586".
# Returns the kable-ready wide table plus a flat named list
# (e.g. display$median_ratio_pre)
# for referencing individual values inline in prose.

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
