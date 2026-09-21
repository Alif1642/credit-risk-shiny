required_packages <- c(
  "shiny", "shinythemes", "tidyverse", "tidymodels", "randomForest",
  "plotly", "DT", "readr", "scales"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop(
    "Missing required packages: ", paste(missing_packages, collapse = ", "),
    ". Run source('install.R') before starting the app."
  )
}

suppressPackageStartupMessages({
  library(shiny)
  library(shinythemes)
  library(tidyverse)
  library(tidymodels)
  library(randomForest)
  library(plotly)
  library(DT)
  library(scales)
})

source(file.path("R", "data_prep.R"), local = TRUE)
source(file.path("R", "model.R"), local = TRUE)
source(file.path("R", "predictions.R"), local = TRUE)
source(file.path("R", "visualization.R"), local = TRUE)

credit_data <- load_or_generate_data()
model_bundle <- train_or_load_credit_model(credit_data)


kpi_card <- function(title, value_output, note, accent = "blue") {
  div(
    class = paste("kpi-card", paste0("kpi-", accent)),
    div(class = "kpi-title", title),
    div(class = "kpi-value", textOutput(value_output, inline = TRUE)),
    div(class = "kpi-note", note)
  )
}


section_header <- function(title, subtitle) {
  tagList(
    h2(class = "page-title", title),
    p(class = "page-subtitle", subtitle)
  )
}


overview_ui <- tagList(
  section_header(
    "Portfolio overview",
    "A business-focused view of the synthetic credit portfolio and observed default outcomes."
  ),
  fluidRow(
    column(3, kpi_card("Customers / loans", "kpi_total", "Synthetic records", "blue")),
    column(3, kpi_card("Default rate", "kpi_default_rate", "Observed outcome", "red")),
    column(3, kpi_card("Average loan", "kpi_average_loan", "Portfolio exposure", "gold")),
    column(3, kpi_card("Average income", "kpi_average_income", "Annual applicant income", "green"))
  ),
  fluidRow(
    column(
      8,
      div(
        class = "panel-card",
        h3("Portfolio risk profile"),
        plotlyOutput("overview_risk_chart", height = "380px")
      )
    ),
    column(
      4,
      div(
        class = "panel-card business-summary",
        h3("Business summary"),
        uiOutput("business_summary"),
        div(
          class = "info-callout",
          strong("Responsible-use note"),
          p("This dashboard uses synthetic data and is intended for education and portfolio demonstration only.")
        )
      )
    )
  )
)


data_explorer_ui <- tagList(
  section_header(
    "Data explorer",
    "Filter the portfolio, inspect records, review summary statistics, and assess data quality."
  ),
  div(
    class = "panel-card filter-bar",
    fluidRow(
      column(3, selectInput("filter_employment", "Employment status", choices = c("All", levels(credit_data$employment_status)))),
      column(3, selectInput("filter_default", "Default outcome", choices = c("All", "No", "Yes"))),
      column(4, sliderInput("filter_credit_score", "Credit score", min = 350, max = 850, value = c(350, 850), step = 10)),
      column(2, actionButton("reset_filters", "Reset filters", class = "btn btn-outline-primary reset-button"))
    )
  ),
  div(class = "panel-card", h3("Loan records"), DTOutput("credit_table")),
  fluidRow(
    column(
      5,
      div(
        class = "panel-card",
        h3("Summary statistics"),
        tableOutput("explorer_summary")
      )
    ),
    column(
      7,
      div(
        class = "panel-card",
        h3("Missing-value analysis"),
        plotlyOutput("missing_plot", height = "320px")
      )
    )
  ),
  div(
    class = "panel-card",
    selectInput(
      "distribution_variable",
      "Distribution variable",
      choices = c(
        "Annual income" = "annual_income",
        "Loan amount" = "loan_amount",
        "Credit score" = "credit_score",
        "Debt-to-income ratio" = "debt_to_income",
        "Age" = "age"
      )
    ),
    plotlyOutput("distribution_plot", height = "360px")
  )
)


risk_analysis_ui <- tagList(
  section_header(
    "Credit risk analysis",
    "Explore how observed default rates vary across applicant and loan segments."
  ),
  div(
    class = "panel-card",
    fluidRow(
      column(
        4,
        selectInput(
          "risk_dimension",
          "Analysis dimension",
          choices = c(
            "Income band", "Loan amount band", "Credit score band",
            "Employment status", "Loan purpose"
          )
        )
      ),
      column(
        8,
        div(
          class = "analysis-note",
          "Rates describe this synthetic dataset and should not be interpreted as causal effects or lending policy."
        )
      )
    ),
    plotlyOutput("risk_segment_plot", height = "460px")
  ),
  fluidRow(
    column(
      6,
      div(
        class = "panel-card",
        h3("Highest-risk segment"),
        uiOutput("highest_risk_segment")
      )
    ),
    column(
      6,
      div(
        class = "panel-card",
        h3("Analytical interpretation"),
        p("Use segment-level rates to identify patterns for further investigation. Validate findings with sample size, data quality, stability checks, and domain review before recommending action.")
      )
    )
  )
)


ml_prediction_ui <- tagList(
  section_header(
    "Machine-learning workflow",
    "A reproducible Random Forest classification pipeline built with tidymodels."
  ),
  fluidRow(
    column(
      7,
      div(
        class = "panel-card",
        h3("Workflow"),
        div(
          class = "workflow-grid",
          div(class = "workflow-step", strong("1. Split"), span("80/20 stratified train/test split")),
          div(class = "workflow-step", strong("2. Prepare"), span("Median imputation, unknown/novel categories, one-hot encoding")),
          div(class = "workflow-step", strong("3. Train"), span("Random Forest with 350 trees")),
          div(class = "workflow-step", strong("4. Evaluate"), span("Accuracy, precision, recall, F1, ROC-AUC, confusion matrix"))
        )
      )
    ),
    column(
      5,
      div(
        class = "panel-card model-facts",
        h3("Model facts"),
        tags$ul(
          tags$li(strong("Training rows: "), scales::comma(model_bundle$training_rows)),
          tags$li(strong("Test rows: "), scales::comma(model_bundle$test_rows)),
          tags$li(strong("Outcome: "), "Default (Yes / No)"),
          tags$li(strong("Engine: "), "randomForest"),
          tags$li(strong("Reproducibility seed: "), "1642")
        )
      )
    )
  ),
  div(class = "panel-card", h3("Holdout-set metrics"), DTOutput("ml_metrics_table")),
  div(
    class = "panel-card",
    h3("Example holdout predictions"),
    p(class = "muted", "The table displays a sample of untouched test-set predictions."),
    DTOutput("prediction_sample")
  )
)


individual_predictor_ui <- tagList(
  section_header(
    "Individual risk predictor",
    "Enter an applicant profile to estimate default probability using the trained educational model."
  ),
  fluidRow(
    column(
      7,
      div(
        class = "panel-card",
        h3("Applicant inputs"),
        fluidRow(
          column(4, numericInput("pred_age", "Age", 35, min = 18, max = 100)),
          column(4, numericInput("pred_income", "Annual income", 60000, min = 1000, step = 1000)),
          column(4, numericInput("pred_loan", "Loan amount", 18000, min = 500, step = 500))
        ),
        fluidRow(
          column(4, selectInput("pred_term", "Loan term (months)", c(12, 24, 36, 48, 60), selected = 36)),
          column(4, numericInput("pred_score", "Credit score", 680, min = 300, max = 850)),
          column(4, numericInput("pred_history", "Credit history (years)", 8, min = 0, max = 60, step = 0.5))
        ),
        fluidRow(
          column(4, selectInput("pred_employment", "Employment status", levels(credit_data$employment_status))),
          column(4, numericInput("pred_previous_defaults", "Previous defaults", 0, min = 0, max = 5)),
          column(4, sliderInput("pred_dti", "Debt-to-income ratio", min = 0, max = 0.90, value = 0.30, step = 0.01))
        ),
        fluidRow(
          column(6, selectInput("pred_purpose", "Loan purpose", levels(credit_data$loan_purpose))),
          column(6, selectInput("pred_ownership", "Home ownership", levels(credit_data$home_ownership)))
        ),
        actionButton("predict_risk", "Estimate default risk", class = "btn btn-primary predict-button")
      )
    ),
    column(
      5,
      div(
        class = "panel-card predictor-result",
        h3("Prediction result"),
        uiOutput("risk_result"),
        div(
          class = "warning-callout",
          "Academic demonstration only. Do not use this output for lending, pricing, eligibility, or other real financial decisions."
        )
      )
    )
  )
)


performance_ui <- tagList(
  section_header(
    "Model performance",
    "Inspect holdout-set discrimination, classification outcomes, and model-level feature importance."
  ),
  fluidRow(
    column(6, div(class = "panel-card", plotlyOutput("confusion_plot", height = "390px"))),
    column(6, div(class = "panel-card", plotlyOutput("roc_plot", height = "390px")))
  ),
  fluidRow(
    column(7, div(class = "panel-card", plotlyOutput("importance_plot", height = "430px"))),
    column(
      5,
      div(
        class = "panel-card",
        h3("How to interpret importance"),
        p("Random Forest importance indicates which prepared variables most reduced node impurity across the fitted trees."),
        tags$ul(
          tags$li("Higher importance means the model relied more on that feature during tree construction."),
          tags$li("Importance is not a causal effect and does not show whether the relationship increases or decreases risk."),
          tags$li("Dummy-encoded category levels appear as separate model features."),
          tags$li("A real credit model would require governance, fairness testing, stability monitoring, and independent validation.")
        )
      )
    )
  )
)


ui <- fluidPage(
  theme = shinythemes::shinytheme("flatly"),
  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$title("Credit Risk Analytics Dashboard"),
    includeCSS(file.path("www", "custom.css"))
  ),
  div(
    class = "app-shell",
    div(
      class = "app-sidebar",
      div(
        class = "brand-block",
        div(class = "brand-mark", "CR"),
        div(
          h1("Credit Risk Analytics"),
          p("Loan Default Prediction")
        )
      ),
      radioButtons(
        "nav",
        label = NULL,
        choices = c(
          "Overview" = "overview",
          "Data Explorer" = "data",
          "Credit Risk Analysis" = "analysis",
          "ML Prediction" = "ml",
          "Individual Predictor" = "predictor",
          "Model Performance" = "performance"
        ),
        selected = "overview"
      ),
      div(
        class = "sidebar-footer",
        strong("Portfolio project"),
        span("Synthetic data • Educational use")
      )
    ),
    div(
      class = "app-main",
      conditionalPanel("input.nav == 'overview'", overview_ui),
      conditionalPanel("input.nav == 'data'", data_explorer_ui),
      conditionalPanel("input.nav == 'analysis'", risk_analysis_ui),
      conditionalPanel("input.nav == 'ml'", ml_prediction_ui),
      conditionalPanel("input.nav == 'predictor'", individual_predictor_ui),
      conditionalPanel("input.nav == 'performance'", performance_ui)
    )
  )
)


server <- function(input, output, session) {
  overview_summary <- numeric_summary(credit_data)

  output$kpi_total <- renderText(scales::comma(overview_summary$customers))
  output$kpi_default_rate <- renderText(scales::percent(overview_summary$default_rate, accuracy = 0.1))
  output$kpi_average_loan <- renderText(scales::dollar(overview_summary$average_loan, accuracy = 1))
  output$kpi_average_income <- renderText(scales::dollar(overview_summary$average_income, accuracy = 1))

  output$overview_risk_chart <- renderPlotly({
    default_rate_plot(credit_data, "Credit score band")
  })

  output$business_summary <- renderUI({
    top_purpose <- credit_data |>
      dplyr::filter(!is.na(loan_purpose)) |>
      dplyr::count(loan_purpose, sort = TRUE) |>
      dplyr::slice_head(n = 1)

    tagList(
      p("The synthetic portfolio contains ", strong(scales::comma(nrow(credit_data))), " customer-level loan records."),
      p("Observed default rate is ", strong(scales::percent(overview_summary$default_rate, accuracy = 0.1)), "."),
      p("The most frequent loan purpose is ", strong(as.character(top_purpose$loan_purpose)), "."),
      p("Use the risk-analysis page to compare segment rates and the performance page to evaluate the model on held-out data.")
    )
  })

  observeEvent(input$reset_filters, {
    updateSelectInput(session, "filter_employment", selected = "All")
    updateSelectInput(session, "filter_default", selected = "All")
    updateSliderInput(session, "filter_credit_score", value = c(350, 850))
  })

  filtered_data <- reactive({
    req(input$filter_employment, input$filter_default, input$filter_credit_score)
    filter_credit_data(
      credit_data,
      employment = input$filter_employment,
      default = input$filter_default,
      score_range = input$filter_credit_score
    )
  })

  output$credit_table <- renderDT({
    datatable(
      filtered_data() |>
        dplyr::mutate(
          debt_to_income = scales::percent(debt_to_income, accuracy = 0.1),
          annual_income = scales::dollar(annual_income),
          loan_amount = scales::dollar(loan_amount)
        ),
      filter = "top",
      rownames = FALSE,
      options = list(pageLength = 8, scrollX = TRUE, dom = "tip")
    )
  })

  output$explorer_summary <- renderTable({
    summary <- numeric_summary(filtered_data())
    tibble::tibble(
      Metric = c("Rows", "Default rate", "Average income", "Average loan", "Average credit score", "Average DTI"),
      Value = c(
        scales::comma(summary$customers),
        scales::percent(summary$default_rate, accuracy = 0.1),
        scales::dollar(summary$average_income, accuracy = 1),
        scales::dollar(summary$average_loan, accuracy = 1),
        round(summary$average_credit_score, 1),
        scales::percent(summary$average_dti, accuracy = 0.1)
      )
    )
  }, striped = TRUE, bordered = FALSE, spacing = "s")

  output$missing_plot <- renderPlotly(missing_values_plot(filtered_data()))
  output$distribution_plot <- renderPlotly({
    req(input$distribution_variable)
    distribution_plot(filtered_data(), input$distribution_variable)
  })

  output$risk_segment_plot <- renderPlotly({
    req(input$risk_dimension)
    default_rate_plot(credit_data, input$risk_dimension)
  })

  output$highest_risk_segment <- renderUI({
    grouped <- switch(
      input$risk_dimension,
      "Income band" = credit_data |> dplyr::mutate(segment = ggplot2::cut_number(annual_income, 5, dig.lab = 8)),
      "Loan amount band" = credit_data |> dplyr::mutate(segment = ggplot2::cut_number(loan_amount, 5, dig.lab = 8)),
      "Credit score band" = credit_data |> dplyr::mutate(segment = cut(credit_score, c(300, 579, 669, 739, 799, 850), include.lowest = TRUE)),
      "Employment status" = credit_data |> dplyr::mutate(segment = employment_status),
      "Loan purpose" = credit_data |> dplyr::mutate(segment = loan_purpose)
    ) |>
      dplyr::filter(!is.na(segment)) |>
      dplyr::group_by(segment) |>
      dplyr::summarise(loans = dplyr::n(), rate = mean(default == "Yes"), .groups = "drop") |>
      dplyr::slice_max(rate, n = 1, with_ties = FALSE)

    tagList(
      div(class = "segment-highlight", as.character(grouped$segment)),
      p(strong(scales::percent(grouped$rate, accuracy = 0.1)), " observed default rate across ", scales::comma(grouped$loans), " loans."),
      p(class = "muted", "Descriptive result only; investigate confounding factors and sample stability before drawing conclusions.")
    )
  })

  formatted_metrics <- model_bundle$metrics |>
    dplyr::transmute(
      Metric = dplyr::recode(
        .metric,
        accuracy = "Accuracy",
        precision = "Precision",
        recall = "Recall",
        f_meas = "F1-score",
        roc_auc = "ROC-AUC"
      ),
      Estimate = round(.estimate, 3)
    )

  output$ml_metrics_table <- renderDT({
    datatable(
      formatted_metrics,
      rownames = FALSE,
      options = list(dom = "t", ordering = FALSE),
      class = "compact stripe"
    )
  })

  output$prediction_sample <- renderDT({
    sample_predictions <- model_bundle$predictions |>
      dplyr::slice_head(n = 12) |>
      dplyr::transmute(
        Customer = customer_id,
        Actual = default,
        Predicted = .pred_class,
        `Default probability` = scales::percent(.pred_Yes, accuracy = 0.1)
      )
    datatable(sample_predictions, rownames = FALSE, options = list(dom = "t", pageLength = 12))
  })

  risk_prediction <- eventReactive(input$predict_risk, {
    values <- list(
      age = input$pred_age,
      annual_income = input$pred_income,
      loan_amount = input$pred_loan,
      loan_term_months = as.numeric(input$pred_term),
      credit_score = input$pred_score,
      employment_status = input$pred_employment,
      previous_defaults = input$pred_previous_defaults,
      debt_to_income = input$pred_dti,
      loan_purpose = input$pred_purpose,
      home_ownership = input$pred_ownership,
      credit_history_years = input$pred_history
    )

    applicant <- tryCatch(
      new_applicant(values),
      error = function(e) {
        showNotification(conditionMessage(e), type = "error")
        NULL
      }
    )
    req(applicant)
    predict_applicant_risk(model_bundle$fitted_workflow, applicant)
  }, ignoreInit = TRUE)

  output$risk_result <- renderUI({
    result <- risk_prediction()
    req(result)
    risk_class <- paste0("risk-", tolower(result$category))

    tagList(
      div(
        class = paste("risk-gauge", risk_class),
        div(class = "risk-probability", scales::percent(result$probability, accuracy = 0.1)),
        div(class = "risk-label", paste(result$category, "risk"))
      ),
      div(
        class = "risk-progress",
        div(class = paste("risk-progress-fill", risk_class), style = paste0("width:", round(result$probability * 100), "%"))
      ),
      p(class = "prediction-explanation", result$explanation)
    )
  })

  output$confusion_plot <- renderPlotly(confusion_matrix_plot(model_bundle$confusion))
  output$roc_plot <- renderPlotly(roc_plot(model_bundle$roc_curve))
  output$importance_plot <- renderPlotly(feature_importance_plot(model_bundle$feature_importance))
}


shinyApp(ui, server)
