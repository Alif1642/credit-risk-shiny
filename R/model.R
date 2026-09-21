credit_model_version <- "1.0.0"


build_credit_recipe <- function(training_data) {
  recipes::recipe(default ~ ., data = training_data) |>
    recipes::update_role(customer_id, new_role = "id") |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_unknown(recipes::all_nominal_predictors(), new_level = "Unknown") |>
    recipes::step_novel(recipes::all_nominal_predictors(), new_level = "New") |>
    recipes::step_dummy(recipes::all_nominal_predictors(), one_hot = TRUE) |>
    recipes::step_zv(recipes::all_predictors())
}


build_credit_model <- function() {
  parsnip::rand_forest(
    mode = "classification",
    trees = 350,
    mtry = 6,
    min_n = 10
  ) |>
    parsnip::set_engine("randomForest", importance = TRUE)
}


extract_feature_importance <- function(fitted_workflow) {
  engine <- workflows::extract_fit_engine(fitted_workflow)
  importance <- randomForest::importance(engine)

  if (is.matrix(importance)) {
    preferred <- intersect(c("MeanDecreaseGini", "MeanDecreaseAccuracy"), colnames(importance))
    values <- if (length(preferred) > 0) importance[, preferred[[1]]] else importance[, 1]
    feature_names <- rownames(importance)
  } else {
    values <- importance
    feature_names <- names(importance)
  }

  tibble::tibble(
    feature = feature_names,
    importance = as.numeric(values)
  ) |>
    dplyr::mutate(feature = stringr::str_replace_all(feature, "_", " ")) |>
    dplyr::arrange(dplyr::desc(importance))
}


evaluate_credit_model <- function(fitted_workflow, test_data) {
  class_predictions <- predict(fitted_workflow, test_data, type = "class")
  probability_predictions <- predict(fitted_workflow, test_data, type = "prob")

  predictions <- test_data |>
    dplyr::select(customer_id, default) |>
    dplyr::bind_cols(class_predictions, probability_predictions)

  metrics <- dplyr::bind_rows(
    yardstick::accuracy(predictions, truth = default, estimate = .pred_class),
    yardstick::precision(
      predictions,
      truth = default,
      estimate = .pred_class,
      event_level = "second"
    ),
    yardstick::recall(
      predictions,
      truth = default,
      estimate = .pred_class,
      event_level = "second"
    ),
    yardstick::f_meas(
      predictions,
      truth = default,
      estimate = .pred_class,
      event_level = "second"
    ),
    yardstick::roc_auc(
      predictions,
      truth = default,
      .pred_Yes,
      event_level = "second"
    )
  )

  list(
    predictions = predictions,
    metrics = metrics,
    confusion = yardstick::conf_mat(
      predictions,
      truth = default,
      estimate = .pred_class
    ),
    roc_curve = yardstick::roc_curve(
      predictions,
      truth = default,
      .pred_Yes,
      event_level = "second"
    )
  )
}


train_credit_model <- function(data, seed = 1642) {
  modelling_data <- data |>
    dplyr::mutate(default = factor(default, levels = c("No", "Yes")))

  set.seed(seed)
  split <- rsample::initial_split(modelling_data, prop = 0.80, strata = default)
  training_data <- rsample::training(split)
  test_data <- rsample::testing(split)

  workflow <- workflows::workflow() |>
    workflows::add_recipe(build_credit_recipe(training_data)) |>
    workflows::add_model(build_credit_model())

  fitted_workflow <- generics::fit(workflow, data = training_data)
  evaluation <- evaluate_credit_model(fitted_workflow, test_data)

  list(
    model_version = credit_model_version,
    fitted_workflow = fitted_workflow,
    split = split,
    training_rows = nrow(training_data),
    test_rows = nrow(test_data),
    predictions = evaluation$predictions,
    metrics = evaluation$metrics,
    confusion = evaluation$confusion,
    roc_curve = evaluation$roc_curve,
    feature_importance = extract_feature_importance(fitted_workflow),
    trained_at = Sys.time()
  )
}


train_or_load_credit_model <- function(
    data,
    path = file.path("models", "credit_risk_model.rds"),
    force_retrain = FALSE) {
  if (!force_retrain && file.exists(path)) {
    cached <- tryCatch(readRDS(path), error = function(e) NULL)
    if (!is.null(cached) && identical(cached$model_version, credit_model_version)) {
      return(cached)
    }
  }

  bundle <- train_credit_model(data)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tryCatch(
    saveRDS(bundle, path),
    error = function(e) message("Model cache could not be written: ", conditionMessage(e))
  )
  bundle
}
