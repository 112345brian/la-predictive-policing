# Fetches LA Times neighborhood boundaries from the LA City GeoHub
# and caches them for use in downstream spatial joins.

source(here::here("scripts", "_pipeline-helpers.R"))

neighborhoods <- with_cache("la-neighborhoods.rds", function() {
  sf::st_read(
    "https://services5.arcgis.com/7nsPwEMP38bSkCjy/arcgis/rest/services/LA_Times_Neighborhood_Boundaries/FeatureServer/0/query?where=1%3D1&outFields=name&f=geojson",
    quiet = TRUE
  ) |>
    dplyr::select(neighborhood = name)
})

write_processed_dataset(neighborhoods, "neighborhoods.rds")
