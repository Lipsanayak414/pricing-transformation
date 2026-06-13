# Data Dictionary

Documents the schema in `sql/02_public_data_schema.sql`. Grain = what one row represents.

## Analytical core (disclosed)

### dim_company — one vendor
| Column | Type | Description |
|---|---|---|
| company_id | INT PK | Surrogate key |
| company_name, ticker, exchange | TEXT | Identity |
| annual_filing_type | TEXT | 10-K / 20-F |
| is_public_current, went_private_date | BOOL / DATE | Current status |
| role_in_project | TEXT | anchor / corroborator / historical |

### dim_fiscal_period — one company × fiscal period
| Column | Type | Description |
|---|---|---|
| period_id | INT PK | Surrogate key |
| company_id | INT FK | → dim_company |
| fiscal_year, fiscal_quarter | INT | quarter 0 = annual |
| period_end_date, period_type | DATE / TEXT | annual / quarterly |

### dim_revenue_line — standardised revenue taxonomy
| Column | Type | Description |
|---|---|---|
| revenue_line_code | TEXT PK | LICENSE / SUB_SUPPORT / SUBSCRIPTION / MAINTENANCE / SERVICES |
| recognition_method | TEXT | point_in_time / ratable / as_delivered |
| is_recurring | BOOL | Recurring vs one-time |

### fact_financials — one company × period × revenue line (the core)
| Column | Type | Description |
|---|---|---|
| fin_id | INT PK | Surrogate key |
| period_id, company_id, revenue_line_code | FK | Dimensions |
| amount_musd | NUMERIC | USD millions |
| is_derived | BOOL | TRUE if computed from a disclosed growth rate |
| source_citation, source_url | TEXT | Provenance |

### fact_metrics — one disclosed non-revenue metric
| Column | Type | Description |
|---|---|---|
| metric_id | INT PK | Surrogate key |
| metric_code | TEXT | ARR / ARR_GROWTH / NDR / SAAS_ACV_MIX / OP_MARGIN |
| metric_value, unit | NUMERIC / TEXT | Value + unit |
| is_derived, source_citation | BOOL / TEXT | Provenance |

### ref_metric_definition / dim_product_module / ref_benchmark
Definitions per company (guards non-comparable metrics); disclosed P&C module taxonomy; and
benchmark guardrails (ranges with source; placeholders flagged until cited).

## Scenario layer (assumptions)

### dim_scenario — one modelled scenario
| Column | Type | Description |
|---|---|---|
| scenario_id | INT PK | Surrogate key |
| scenario_name, scenario_type | TEXT | e.g. B_1.50x / migration |
| conversion_multiple, sunset_window_months, adoption_drag_param | NUMERIC | Levers |
| base_company_id, base_fiscal_year | FK / INT | Disclosed base it operates on |

### fact_scenario_assumption — one assumption with justification
Links each numeric assumption to a `ref_benchmark` row — the audit trail for "why that number?".

### fact_scenario_projection — one scenario × projection year (model output)
Projected license / subscription / services / total revenue, ARR, gross margin, YoY growth,
and the trough-year flag.
