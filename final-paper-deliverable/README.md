# Policing Spatial Concentration Under LAPD's Post-PredPol DICFP Program

Final paper for AS.470.703, Urban Data Analytics. This folder is self-contained:
the paper, the dataset it was built from, and the code that produced the
statistics.

## Contents

| File | What it is |
|---|---|
| `final-paper.pdf` | The paper. |
| `final-paper.qmd` | Its Quarto source. Reads the CSVs in `data/` and generates every table and figure. |
| `references.bib` | Bibliography. |
| `american-political-science-association.csl` | APSA citation style. |
| `analysis.R` | Refits the headline model on its own, in about sixty lines. |
| `data/` | The dataset, as CSV. |
| `code/` | The pipeline that built the dataset from the source APIs. |

## The analysis

The unit of observation is a census tract in one of two policing eras: PredPol
(2016-2019) and DICFP (2022-2024). The model treats arrests as a rate relative
to reported crime and asks whether the change in that rate between eras depends
on the tract's Black/Latino population share.

```
arrest ~ period * pct_black_latino + offset(log(crime))
```

Fit as a negative binomial GEE with an exchangeable working correlation,
clustered on census tract. Crime enters as an offset, so coefficients are rate
ratios on arrests per reported crime, and the interaction term is the hypothesis
test.

`Rscript analysis.R` reproduces it from `data/arrest-crime-panel.csv` using only
`MASS` and `geeM`:

| Term | Estimate | IRR | p |
|---|---:|---:|---:|
| (Intercept) | -1.284 | 0.28 | <.001 |
| Period (DICFP era) | -0.527 | 0.59 | <.001 |
| Black/Latino share | 0.584 | 1.79 | <.001 |
| Period x Black/Latino share | 0.172 | 1.19 | .016 |

Estimation sample: 2,362 tract-periods across 1,406 tracts.

## The data

| File | Contents |
|---|---|
| `arrest-crime-panel.csv` | The modeled dataset. One row per tract per era, 2,384 rows. |
| `arrest-crime-panel-all-years.csv` | Sensitivity variant retaining 2015, which the main panel drops. 2,387 rows. |
| `period-years.csv` | Years each era spans, for converting era totals to per-year figures. |
| `yearly-counts.csv` | Citywide crime and arrest counts by year, including the excluded 2020-2021. |
| `crime-backfill-stats.csv` | Record counts behind the figures on LAPD's March 2024 NIBRS migration. |

Columns in the two panel files:

| Column | Meaning |
|---|---|
| `GEOID` | 11-digit census tract identifier. Text, with a leading zero. |
| `period` | `pre` (PredPol) or `post` (DICFP). |
| `arrest` | Arrests in the tract over the era. |
| `crime` | Reported crime incidents in the tract over the era. |
| `arrest_crime_ratio` | `arrest / crime`, descriptive only; the model uses the offset instead. |
| `pct_black_latino` | Black or Latino share of tract population, 0 to 1, from ACS 5-year estimates. |

Excel drops the leading zero from `GEOID` unless the column is imported as text.
The estimation sample is smaller than the file: rows with `crime == 0` or a
missing `pct_black_latino` are dropped, taking 2,384 rows down to 2,362.

## The pipeline

`code/pipeline/` built the CSVs from the source APIs, orchestrated by
`00-run-pipeline.R`:

```
01-build-crime-incidents.R   LAPD crime incidents (Socrata API)
02-build-arrests.R           LAPD arrests (Socrata API)
03-build-census.R            ACS race and population by tract
04-build-neighborhoods.R     LA neighborhood boundaries
05-backfill-crime-nibrs.R    unions NIBRS offenses into 2024 crime
06-build-spatial.R           spatial join of incidents to tracts
07-prep-dashboard.R          dashboard dataset
08-prep-period-comparison.R  builds the tract-by-era panel
09-join-demographics.R       joins tract racial composition onto the panel
10-yearly-counts.R           citywide counts by year
```

`_pipeline-helpers.R` holds shared paths and the era definitions, `_lapd-api.R`
the Socrata fetch logic, `_dashboard-plots.R` plot code shared with a companion
dashboard. `code/export-analysis-data.R` writes the CSVs from the pipeline's
output, and `code/model-helpers.R` holds the model and table-formatting
functions the paper uses.

Stages 01 through 05 call the LA City and Census APIs and need credentials that
are not part of this submission, so the pipeline is here to be read rather than
rerun. The CSVs in `data/` are its finished output.

## Rebuilding the paper

```bash
quarto render final-paper.qmd
```

Needs Quarto and R with `ggplot2`, `dplyr`, `tidyr`, `purrr`, `tibble`, `readr`,
`scales`, `knitr`, `kableExtra`, `MASS`, and `geeM`.

## Sources

- LAPD Crime Data and Arrest Data, Los Angeles Open Data Portal
- LAPD NIBRS Offenses, Los Angeles Open Data Portal
- American Community Survey 5-year estimates, US Census Bureau
