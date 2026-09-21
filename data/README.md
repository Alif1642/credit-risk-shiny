# Data Directory

The application runs immediately without an external dataset. If `data/credit_data.csv` is absent, `R/data_prep.R` creates a deterministic synthetic dataset with 3,000 records.

No real customer or private financial data is included.

## Optional CSV Schema

To use another non-sensitive dataset, create `data/credit_data.csv` with these exact columns:

| Column | Type | Example / allowed values |
|---|---|---|
| `customer_id` | character | `CR00001` |
| `age` | numeric | `35` |
| `annual_income` | numeric | `60000` |
| `loan_amount` | numeric | `18000` |
| `loan_term_months` | numeric | `12`, `24`, `36`, `48`, `60` |
| `credit_score` | numeric | `300` to `850` |
| `employment_status` | categorical | `Salaried`, `Self-employed`, `Contract`, `Unemployed` |
| `previous_defaults` | numeric | `0`, `1`, `2` |
| `debt_to_income` | numeric | proportion from `0` to `1` |
| `loan_purpose` | categorical | `Business`, `Education`, `Home improvement`, `Medical`, `Personal` |
| `home_ownership` | categorical | `Rent`, `Mortgage`, `Own` |
| `credit_history_years` | numeric | non-negative years |
| `default` | categorical outcome | `No`, `Yes` |

The modelling recipe safely imputes missing numeric values and handles unknown or novel categorical values.

`credit_data.csv` is ignored by Git to reduce the risk of accidentally committing private data. Review data provenance and privacy before changing that rule.
