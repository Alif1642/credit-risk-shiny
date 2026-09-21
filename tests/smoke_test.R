required_packages <- c(
  "tidyverse", "tidymodels", "randomForest", "plotly", "DT",
  "shiny", "shinythemes", "readr", "scales"
)

missing <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop("Missing packages: ", paste(missing, collapse = ", "))
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(tidymodels)
  library(randomForest)
})

source(file.path("R", "data_prep.R"))
source(file.path("R", "model.R"))
source(file.path("R", "predictions.R"))
source(file.path("R", "visualization.R"))

data <- generate_credit_data(n = 700, seed = 1642)
stopifnot(nrow(data) == 700, all(c("default", "credit_score", "loan_amount") %in% names(data)))

bundle <- train_credit_model(data, seed = 1642)
expected_metrics <- c("accuracy", "precision", "recall", "f_meas", "roc_auc")
stopifnot(all(expected_metrics %in% bundle$metrics$.metric))
stopifnot(nrow(bundle$feature_importance) > 0)

applicant <- new_applicant(list(
  age = 35,
  annual_income = 60000,
  loan_amount = 18000,
  loan_term_months = 36,
  credit_score = 680,
  employment_status = "Salaried",
  previous_defaults = 0,
  debt_to_income = 0.30,
  loan_purpose = "Business",
  home_ownership = "Mortgage",
  credit_history_years = 8
))

prediction <- predict_applicant_risk(bundle$fitted_workflow, applicant)
stopifnot(
  prediction$probability >= 0,
  prediction$probability <= 1,
  prediction$category %in% c("Low", "Medium", "High")
)

message("Smoke test passed.")
