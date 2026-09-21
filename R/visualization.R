credit_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", color = "#17324D", size = 14),
      plot.subtitle = ggplot2::element_text(color = "#60758A"),
      panel.grid.minor = ggplot2::element_blank(),
      axis.title = ggplot2::element_text(color = "#41576B"),
      legend.position = "bottom"
    )
}


default_rate_plot <- function(data, dimension) {
  plotted <- switch(
    dimension,
    "Income band" = data |>
      dplyr::mutate(segment = ggplot2::cut_number(annual_income, 5, dig.lab = 8)),
    "Loan amount band" = data |>
      dplyr::mutate(segment = ggplot2::cut_number(loan_amount, 5, dig.lab = 8)),
    "Credit score band" = data |>
      dplyr::mutate(
        segment = cut(
          credit_score,
          breaks = c(300, 579, 669, 739, 799, 850),
          labels = c("Poor", "Fair", "Good", "Very good", "Excellent"),
          include.lowest = TRUE
        )
      ),
    "Employment status" = data |> dplyr::mutate(segment = employment_status),
    "Loan purpose" = data |> dplyr::mutate(segment = loan_purpose),
    stop("Unsupported analysis dimension")
  )

  summary <- plotted |>
    dplyr::filter(!is.na(segment)) |>
    dplyr::group_by(segment) |>
    dplyr::summarise(
      loans = dplyr::n(),
      default_rate = mean(default == "Yes", na.rm = TRUE),
      .groups = "drop"
    )

  chart <- ggplot2::ggplot(
    summary,
    ggplot2::aes(x = segment, y = default_rate, text = paste0(
      "Segment: ", segment,
      "<br>Loans: ", scales::comma(loans),
      "<br>Default rate: ", scales::percent(default_rate, accuracy = 0.1)
    ))
  ) +
    ggplot2::geom_col(fill = "#1F77B4", width = 0.68) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::percent(default_rate, accuracy = 0.1)),
      vjust = -0.35,
      size = 3.5,
      color = "#17324D"
    ) +
    ggplot2::scale_y_continuous(labels = scales::percent, expand = ggplot2::expansion(mult = c(0, 0.14))) +
    ggplot2::labs(
      title = paste("Default rate by", tolower(dimension)),
      x = NULL,
      y = "Default rate"
    ) +
    credit_theme()

  plotly::ggplotly(chart, tooltip = "text") |>
    plotly::layout(margin = list(b = 80))
}


distribution_plot <- function(data, variable) {
  labels <- c(
    annual_income = "Annual income",
    loan_amount = "Loan amount",
    credit_score = "Credit score",
    debt_to_income = "Debt-to-income ratio",
    age = "Age"
  )

  chart <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data[[variable]], fill = default)
  ) +
    ggplot2::geom_histogram(bins = 30, alpha = 0.72, position = "identity", na.rm = TRUE) +
    ggplot2::scale_fill_manual(values = c("No" = "#2A9D8F", "Yes" = "#E76F51")) +
    ggplot2::labs(
      title = paste(labels[[variable]], "distribution"),
      x = labels[[variable]],
      y = "Customers",
      fill = "Default"
    ) +
    credit_theme()

  plotly::ggplotly(chart)
}


missing_values_plot <- function(data) {
  summary <- missing_value_summary(data) |>
    dplyr::filter(missing > 0)

  if (nrow(summary) == 0) {
    summary <- tibble::tibble(variable = "No missing values", missing = 0, missing_rate = 0)
  }

  chart <- ggplot2::ggplot(
    summary,
    ggplot2::aes(
      x = stats::reorder(variable, missing_rate),
      y = missing_rate,
      text = paste0(
        "Variable: ", variable,
        "<br>Missing: ", missing,
        "<br>Rate: ", scales::percent(missing_rate, accuracy = 0.1)
      )
    )
  ) +
    ggplot2::geom_col(fill = "#6C8EBF") +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(labels = scales::percent) +
    ggplot2::labs(title = "Missing-value profile", x = NULL, y = "Missing rate") +
    credit_theme()

  plotly::ggplotly(chart, tooltip = "text")
}


roc_plot <- function(roc_data) {
  chart <- ggplot2::ggplot(roc_data, ggplot2::aes(x = 1 - specificity, y = sensitivity)) +
    ggplot2::geom_abline(linetype = "dashed", color = "#A0AEC0") +
    ggplot2::geom_path(color = "#1F77B4", linewidth = 1.15) +
    ggplot2::coord_equal() +
    ggplot2::labs(title = "ROC curve", x = "False positive rate", y = "True positive rate") +
    credit_theme()

  plotly::ggplotly(chart)
}


confusion_matrix_plot <- function(confusion) {
  matrix_data <- as.data.frame(confusion$table)
  names(matrix_data) <- c("Prediction", "Truth", "Count")

  chart <- ggplot2::ggplot(
    matrix_data,
    ggplot2::aes(x = Truth, y = Prediction, fill = Count, text = paste0("Count: ", Count))
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 1.2) +
    ggplot2::geom_text(ggplot2::aes(label = Count), color = "white", fontface = "bold", size = 5) +
    ggplot2::scale_fill_gradient(low = "#8FB9D8", high = "#17324D") +
    ggplot2::labs(title = "Confusion matrix", x = "Actual class", y = "Predicted class") +
    credit_theme() +
    ggplot2::theme(legend.position = "none")

  plotly::ggplotly(chart, tooltip = "text")
}


feature_importance_plot <- function(importance, n = 12) {
  top_features <- importance |>
    dplyr::slice_max(importance, n = n, with_ties = FALSE) |>
    dplyr::arrange(importance)

  chart <- ggplot2::ggplot(
    top_features,
    ggplot2::aes(
      x = importance,
      y = stats::reorder(feature, importance),
      text = paste0("Feature: ", feature, "<br>Importance: ", round(importance, 2))
    )
  ) +
    ggplot2::geom_col(fill = "#2A9D8F") +
    ggplot2::labs(title = "Model feature importance", x = "Mean decrease in impurity", y = NULL) +
    credit_theme()

  plotly::ggplotly(chart, tooltip = "text")
}
