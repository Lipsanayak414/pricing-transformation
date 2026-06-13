# KPI & Metric Definitions

Every metric used in the model, dashboard, and deck — with its formula and source — so figures are
unambiguous and comparable.

| Metric | Definition | Formula / basis | Source / owner |
|---|---|---|---|
| ARR | Annual recurring revenue | Σ recurring (subscription + remaining maintenance) | Model / filings |
| ARR growth | Year-over-year ARR change | (ARR_t / ARR_t-1) − 1 | Model / filings |
| Net dollar retention (NDR) | Recurring revenue retained + expanded from existing base | renewed_ARR / prior_ARR | Bounded to 108–120% (DCT) |
| Blended gross margin | Gross profit ÷ total revenue | Σ(rev_line × GM_line) / total_rev | Model |
| Trough depth | Worst near-term revenue dip vs Year 0 | (rev_Y0 − min(rev_t)) / rev_Y0 | Model |
| Trough year | Year of the lowest reported revenue | argmin(total_rev_t) | Model |
| Conversion multiple | SaaS price vs prior maintenance | new_subscription_ARR / prior_maintenance_ARR | Scenario lever |
| Adoption rate | Share of base converted by year t | cumulative converted ÷ original base | Scenario assumption |
| Sunset window | Months perpetual remains sellable | parameter (base = 36) | Scenario lever |
| Gross retention | Recurring revenue retained before expansion | (prior_ARR − churn) / prior_ARR | Renewal methodology |
| TCV | Total contract value | Σ contracted value over term | Deal definition |

**Note on comparability:** ARR and NDR are defined slightly differently by each vendor (see
`ref_metric_definition`); cross-company comparisons cite the source definition.
