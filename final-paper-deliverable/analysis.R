# Headline model: arrest ~ period * pct_black_latino + offset(log(crime)),
# negative binomial GEE clustered on tract. Crime as offset makes the
# coefficients rate ratios; the interaction is the test.

library(MASS)
library(geeM)

panel_path <- file.path("data", "arrest-crime-panel.csv")
if (!file.exists(panel_path)) {
  stop("run from the folder containing data/; no ", panel_path)
}

panel <- read.csv(panel_path, colClasses = c(GEOID = "character"))

# CSV drops factor order, and alphabetical puts post first.
panel$period <- factor(panel$period, levels = c("pre", "post"))

# Zero crime leaves the rate undefined; no composition, nothing to interact.
model_data <- panel[panel$crime > 0 & !is.na(panel$pct_black_latino), ]
model_data <- model_data[order(model_data$GEOID), ]

cat("Tract-periods in the exported panel: ", nrow(panel), "\n", sep = "")
cat("Tract-periods in the estimation sample: ", nrow(model_data), "\n", sep = "")
cat("Distinct tracts (GEE clusters): ", length(unique(model_data$GEOID)), "\n\n", sep = "")

formula <- arrest ~ period * pct_black_latino + offset(log(crime))

# geem() wants theta supplied.
nb_fit <- glm.nb(formula, data = model_data)
cat("Negative binomial theta: ", format(nb_fit$theta, digits = 4), "\n\n", sep = "")

gee_fit <- geem(
  formula,
  id = GEOID,
  family = negative.binomial(nb_fit$theta),
  corstr = "exchangeable",
  data = model_data
)

gee <- summary(gee_fit)

results <- data.frame(
  term = gee$coefnames,
  estimate = round(gee$beta, 3),
  robust_se = round(gee$se.robust, 3),
  irr = round(exp(gee$beta), 3),
  p = round(gee$p, 3),
  row.names = NULL
)

cat("Negative binomial GEE, exchangeable correlation, clustered by tract\n")
cat("arrest ~ period * pct_black_latino + offset(log(crime))\n\n")
print(results)
