plot_racial_distribution <- function(data, tier = "High") {
  bar_data <- data |>
    sf::st_drop_geometry() |>
    dplyr::filter(!is.na(n)) |>
    dplyr::mutate(
      crime_tier = dplyr::case_when(
        n >= quantile(n, 0.67, na.rm = TRUE) ~ "High",
        n >= quantile(n, 0.33, na.rm = TRUE) ~ "Mid",
        TRUE ~ "Low"
      )
    ) |>
    dplyr::filter(crime_tier == tier) |>
    dplyr::summarise(
      White = sum(non_hispanic_whiteE, na.rm = TRUE),
      Black = sum(non_hispanic_blackE, na.rm = TRUE),
      Hispanic = sum(hispanic_or_latinoE, na.rm = TRUE),
      Total = sum(totalE, na.rm = TRUE)
    ) |>
    dplyr::mutate(Other = Total - White - Black - Hispanic) |>
    tidyr::pivot_longer(c(White, Black, Hispanic, Other), names_to = "group", values_to = "pop") |>
    dplyr::mutate(
      pct = pop / sum(pop),
      group = factor(group, levels = c("White", "Hispanic", "Black", "Other"))
    )

  ggplot2::ggplot(bar_data, ggplot2::aes(x = group, y = pct, fill = group)) +
    ggplot2::geom_col(width = 0.6, show.legend = FALSE) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
    ggplot2::scale_fill_manual(values = c(
      White = "#4E79A7", Black = "#F28E2B", Hispanic = "#59A14F", Other = "#BAB0AC"
    )) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank()
    )
}

plot_crime_by_race <- function(data) {
  scatter_data <- data |>
    sf::st_drop_geometry() |>
    dplyr::filter(!is.na(crimes_per_year), !is.na(totalE), totalE > 0) |>
    dplyr::mutate(pct_black_hispanic = (non_hispanic_blackE + hispanic_or_latinoE) / totalE)

  ggplot2::ggplot(scatter_data, ggplot2::aes(x = pct_black_hispanic, y = crimes_per_year)) +
    ggplot2::geom_point(alpha = 0.3, size = 1.5, color = "#2E5E8E") +
    ggplot2::geom_smooth(method = "lm", se = TRUE, color = "#C95C3A", linewidth = 1) +
    ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::labs(x = "% Black + Hispanic", y = "Crimes per Year") +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank()
    )
}

plot_crime_counts <- function(data) {
  pal <- leaflet::colorNumeric("viridis", domain = data$crimes_per_year, na.color = "#E0E0E0")

  leaflet::leaflet(data) |>
    leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron) |>
    leaflet::addPolygons(
      fillColor = pal(data$crimes_per_year),
      fillOpacity = 0.7,
      color = NA,
      label = ~ paste0(
        "Tract ", substr(GEOID, 6, 11), ": ",
        ifelse(is.na(crimes_per_year), "no data", round(crimes_per_year, 1)),
        " crimes/yr"
      )
    ) |>
    leaflet::addLegend(
      pal = pal,
      values = data$crimes_per_year,
      title = "Crimes/Year",
      position = "bottomright",
      na.label = ""
    )
}
