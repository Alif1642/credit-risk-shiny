generate_credit_data <- function(n = 3000, seed = 1642) {
  stopifnot(n >= 500, length(seed) == 1)
  set.seed(seed)

  employment_levels <- c("Salaried", "Self-employed", "Contract", "Unemployed")
  purpose_levels <- c("Business", "Education", "Home improvement", "Medical", "Personal")
  ownership_levels <- c("Rent", "Mortgage", "Own")

  age <- pmin(pmax(round(stats::rnorm(n, 39, 11)), 21), 70)
  employment_status <- sample(
    employment_levels,
    n,
    replace = TRUE,
    prob = c(0.48, 0.26, 0.18, 0.08)
  )

  income_multiplier <- dplyr::case_when(
    employment_status == "Salaried" ~ 1.12,
    employment_status == "Self-employed" ~ 1.18,
    employment_status == "Contract" ~ 0.90,
    TRUE ~ 0.58
  )

  annual_income <- round(stats::rlnorm(n, log(56000), 0.52) * income_multiplier, -2)
  annual_income <- pmin(pmax(annual_income, 12000), 260000)
  loan_amount <- round(stats::rlnorm(n, log(17000), 0.60), -2)
  loan_amount <- pmin(pmax(loan_amount, 1000), 90000)
  loan_term_months <- sample(c(12, 24, 36, 48, 60), n, replace = TRUE, prob = c(0.12, 0.20, 0.34, 0.19, 0.15))
  credit_score <- round(stats::rnorm(n, 660, 72))
  credit_score <- pmin(pmax(credit_score, 350), 850)
  previous_defaults <- stats::rbinom(n, 2, 0.09)
  debt_to_income <- stats::rbeta(n, 2.4, 5.2) * 0.82
  debt_to_income <- round(pmin(pmax(debt_to_income, 0.03), 0.82), 3)
  loan_purpose <- sample(purpose_levels, n, replace = TRUE, prob = c(0.29, 0.13, 0.17, 0.12, 0.29))
  home_ownership <- sample(ownership_levels, n, replace = TRUE, prob = c(0.44, 0.37, 0.19))
  credit_history_years <- round(pmin(pmax(age - 18, 1), stats::rgamma(n, 3.5, 0.32)), 1)

  employment_effect <- dplyr::case_when(
    employment_status == "Unemployed" ~ 1.05,
    employment_status == "Contract" ~ 0.38,
    employment_status == "Self-employed" ~ 0.14,
    TRUE ~ 0
  )
  purpose_effect <- dplyr::case_when(
    loan_purpose == "Personal" ~ 0.32,
    loan_purpose == "Medical" ~ 0.26,
    loan_purpose == "Business" ~ 0.10,
    TRUE ~ 0
  )
  ownership_effect <- dplyr::case_when(
    home_ownership == "Rent" ~ 0.20,
    home_ownership == "Own" ~ -0.22,
    TRUE ~ 0
  )

  log_odds <- -1.75 +
    0.0085 * (650 - credit_score) +
    3.35 * (debt_to_income - 0.30) +
    1.18 * previous_defaults +
    0.95 * ((loan_amount / annual_income) - 0.30) +
    0.010 * (loan_term_months - 36) +
    employment_effect + purpose_effect + ownership_effect -
    0.020 * (credit_history_years - 8)

  default_probability <- stats::plogis(log_odds)
  default <- factor(
    ifelse(stats::runif(n) < default_probability, "Yes", "No"),
    levels = c("No", "Yes")
  )

  data <- tibble::tibble(
    customer_id = sprintf("CR%05d", seq_len(n)),
    age = age,
    annual_income = annual_income,
    loan_amount = loan_amount,
    loan_term_months = loan_term_months,
    credit_score = credit_score,
    employment_status = factor(employment_status, levels = employment_levels),
    previous_defaults = previous_defaults,
    debt_to_income = debt_to_income,
    loan_purpose = factor(loan_purpose, levels = purpose_levels),
    home_ownership = factor(home_ownership, levels = ownership_levels),
    credit_history_years = credit_history_years,
    default = default
  )

  set.seed(seed + 1)
  columns_with_missing <- c(
    "annual_income", "loan_amount", "credit_score",
    "employment_status", "debt_to_income", "credit_history_years"
  )
  for (column in columns_with_missing) {
    missing_rows <- sample(seq_len(n), size = max(1, floor(n * 0.012)))
    data[[column]][missing_rows] <- NA
  }

  data
}


load_or_generate_data <- function(path = file.path("data", "credit_data.csv"), n = 3000) {
  if (file.exists(path)) {
    data <- readr::read_csv(path, show_col_types = FALSE)
    required <- c(
      "customer_id", "age", "annual_income", "loan_amount",
      "loan_term_months", "credit_score", "employment_status",
      "previous_defaults", "debt_to_income", "loan_purpose",
      "home_ownership", "credit_history_years", "default"
    )
    missing_columns <- setdiff(required, names(data))
    if (length(missing_columns) > 0) {
      stop("Dataset is missing required columns: ", paste(missing_columns, collapse = ", "))
    }

    return(
      data |>
        dplyr::mutate(
          employment_status = factor(employment_status),
          loan_purpose = factor(loan_purpose),
          home_ownership = factor(home_ownership),
          default = factor(default, levels = c("No", "Yes"))
        )
    )
  }

  generate_credit_data(n = n)
}


missing_value_summary <- function(data) {
  tibble::tibble(
    variable = names(data),
    missing = vapply(data, function(x) sum(is.na(x)), integer(1)),
    missing_rate = vapply(data, function(x) mean(is.na(x)), numeric(1))
  ) |>
    dplyr::arrange(dplyr::desc(missing))
}


numeric_summary <- function(data) {
  data |>
    dplyr::summarise(
      customers = dplyr::n(),
      default_rate = mean(default == "Yes", na.rm = TRUE),
      average_income = mean(annual_income, na.rm = TRUE),
      average_loan = mean(loan_amount, na.rm = TRUE),
      average_credit_score = mean(credit_score, na.rm = TRUE),
      average_dti = mean(debt_to_income, na.rm = TRUE)
    )
}


filter_credit_data <- function(data, employment = "All", default = "All", score_range = c(350, 850)) {
  filtered <- data |>
    dplyr::filter(
      is.na(credit_score) |
        dplyr::between(credit_score, score_range[[1]], score_range[[2]])
    )

  if (!identical(employment, "All")) {
    filtered <- filtered |> dplyr::filter(employment_status == employment)
  }
  if (!identical(default, "All")) {
    filtered <- filtered |> dplyr::filter(.data$default == default)
  }

  filtered
}
