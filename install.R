required_packages <- c(
  "shiny",
  "shinythemes",
  "tidyverse",
  "tidymodels",
  "randomForest",
  "plotly",
  "DT",
  "readr",
  "scales"
)

installed <- rownames(installed.packages())
missing <- setdiff(required_packages, installed)

if (length(missing) == 0) {
  message("All required packages are already installed.")
} else {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
}
