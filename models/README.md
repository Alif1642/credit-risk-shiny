# Models Directory

The application trains a Random Forest model on first launch and attempts to cache the fitted bundle here:

```text
models/credit_risk_model.rds
```

The generated `.rds` file is excluded from Git because it is reproducible from the source code and synthetic dataset. Delete it to force retraining after changing the data or modelling code.

The cache is reused only when its internal model version matches the version declared in `R/model.R`.
