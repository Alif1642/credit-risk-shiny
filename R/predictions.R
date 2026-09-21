validate_risk_inputs <- function(values) {
  rules <- c(
    age = values$age >= 18 && values$age <= 100,
    annual_income = values$annual_income > 0,
    loan_amount = values$loan_amount > 0,
    loan_term_months = values$loan_term_months > 0,
    credit_score = values$credit_score >= 300 && values$credit_score <= 850,
    previous_defaults = values$previous_defaults >= 0,
    debt_to_income = values$debt_to_income >= 0 && values$debt_to_income <= 1,
    credit_history_years = values$credit_history_years >= 0
  )

  if (!all(rules)) {
    stop("One or more inputs are outside the accepted range.")
  }

  invisible(TRUE)
}


new_applicant <- function(values) {
  validate_risk_inputs(values)

  tibble::tibble(
    customer_id = "MANUAL-INPUT",
    age = as.numeric(values$age),
    annual_income = as.numeric(values$annual_income),
    loan_amount = as.numeric(values$loan_amount),
    loan_term_months = as.numeric(values$loan_term_months),
    credit_score = as.numeric(values$credit_score),
    employment_status = factor(
      values$employment_status,
      levels = c("Salaried", "Self-employed", "Contract", "Unemployed")
    ),
    previous_defaults = as.numeric(values$previous_defaults),
    debt_to_income = as.numeric(values$debt_to_income),
    loan_purpose = factor(
      values$loan_purpose,
      levels = c("Business", "Education", "Home improvement", "Medical", "Personal")
    ),
    home_ownership = factor(values$home_ownership, levels = c("Rent", "Mortgage", "Own")),
    credit_history_years = as.numeric(values$credit_history_years)
  )
}


risk_category <- function(probability) {
  dplyr::case_when(
    probability < 0.25 ~ "Low",
    probability < 0.55 ~ "Medium",
    TRUE ~ "High"
  )
}


risk_explanation <- function(applicant, probability) {
  factors <- character()

  if (applicant$credit_score < 600) factors <- c(factors, "lower credit score")
  if (applicant$debt_to_income >= 0.45) factors <- c(factors, "higher debt-to-income ratio")
  if (applicant$previous_defaults > 0) factors <- c(factors, "previous default history")
  if (applicant$loan_amount / applicant$annual_income >= 0.45) factors <- c(factors, "higher loan-to-income ratio")
  if (applicant$employment_status %in% c("Contract", "Unemployed")) factors <- c(factors, "employment profile")
  if (applicant$credit_history_years < 3) factors <- c(factors, "shorter credit history")

  category <- risk_category(probability)
  if (length(factors) == 0) {
    return(paste0(
      "The model assigns a ", tolower(category),
      " risk category. No rule-based warning factor is prominent in the submitted profile."
    ))
  }

  paste0(
    "The model assigns a ", tolower(category),
    " risk category. Notable profile factors include ",
    paste(utils::head(factors, 3), collapse = ", "),
    ". This is an educational model output, not a lending decision."
  )
}


predict_applicant_risk <- function(fitted_workflow, applicant) {
  probability <- predict(fitted_workflow, applicant, type = "prob")$.pred_Yes[[1]]
  category <- risk_category(probability)

  list(
    probability = probability,
    category = category,
    explanation = risk_explanation(applicant, probability)
  )
}
