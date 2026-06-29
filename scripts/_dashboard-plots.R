plot_crime_counts <- function(data) {
  pal <- leaflet::colorNumeric("viridis", domain = data$n, na.color = "#E0E0E0")

  leaflet::leaflet(data) |>
    leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron) |>
    leaflet::addPolygons(
      fillColor = ~ pal(n),
      fillOpacity = 0.7,
      color = NA,
      label = ~ paste0(
        "Tract ",
        substr(GEOID, 6, 11),
        ": ",
        ifelse(is.na(n), "no data", n),
        " crimes"
      )
    ) |>
    leaflet::addLegend(
      pal = pal,
      values = ~n,
      title = "Crime Count",
      position = "bottomright"
    )
}
