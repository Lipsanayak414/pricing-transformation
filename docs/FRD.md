# Functional Requirements Document (FRD)

| | |
|---|---|
| **Project** | Enterprise SaaS Pricing Transformation |
| **Version** | 1.0 |
| **Traces to** | [BRD.md](BRD.md) — see [requirements_traceability_matrix.md](requirements_traceability_matrix.md) |

---

## 1. Purpose

Translate the business requirements (BRD) into functional specifications for the data layer,
scenario engine, governance framework, and reporting layer. Each requirement has an ID and
acceptance criteria.

## 2. Solution overview

Two layers. An **analytical core** holds disclosed, cited figures (revenue by line, ARR, margins,
retention). A **scenario layer** holds modelling assumptions (conversion multiple, sunset, adoption,
churn) and projects forward from the disclosed base. See [`methodology.md`](methodology.md) and
[`process_flows.md`](process_flows.md).

## 3. Functional requirements

### Data layer (DL)

| ID | Requirement | Acceptance criteria |
|---|---|---|
| FR-DL-01 | Store disclosed financials at company × period × revenue-line grain | `fact_financials` loads; reconciliation query returns Guidewire FY25 mix |
| FR-DL-02 | Store disclosed non-revenue metrics (ARR, NDR, margins) with citations | `fact_metrics` populated; each row carries `source_citation` |
| FR-DL-03 | Flag any figure derived from a disclosed growth rate | `is_derived = TRUE` on inferred rows; provenance audit query runs |
| FR-DL-04 | Capture each vendor's metric definitions | `ref_metric_definition` distinguishes ARR/NDR definitions |

### Scenario engine (SE)

| ID | Requirement | Acceptance criteria |
|---|---|---|
| FR-SE-01 | Accept conversion multiple, sunset window, adoption/churn as parameters | `dim_scenario` / model params drive A/B/C |
| FR-SE-02 | Project license, subscription, services, total revenue, ARR, and **gross margin** by year | `fact_scenario_projection` / CSV produced; margin compresses with mix |
| FR-SE-03 | Identify the reported-revenue trough (depth and year) per scenario | Trough flagged; depths 12.6 / 7.7 / 3.1% reproduced |
| FR-SE-04 | Run a sensitivity on price resistance and find the decision flip point | `sensitivity.py` outputs the ~20% churn flip point |
| FR-SE-05 | Tie every assumption to a justification/benchmark | `fact_scenario_assumption` references `ref_benchmark` |

### Governance (GV)

| ID | Requirement | Acceptance criteria |
|---|---|---|
| FR-GV-01 | Define discount-approval authority by band, with modifiers and guardrails | `deal_desk_approval_matrix.md` complete |
| FR-GV-02 | Specify migration pricing rules (credits, step-up ramps, margin floor) | Rules documented; guardrails enforce ≥55% sub margin, NDR band |

### Reporting (RP)

| ID | Requirement | Acceptance criteria |
|---|---|---|
| FR-RP-01 | Four-page executive dashboard on model outputs + disclosed core | Pages: Exec Summary, Migration Economics, Margin & Governance, Competitive Benchmark |
| FR-RP-02 | 10-slide executive deck populated with actual model results | Deck reflects real trough/ARR/sensitivity figures |

## 4. Business rules & calculations

| Rule | Definition |
|---|---|
| Revenue recognition | License = point-in-time; maintenance & subscription = ratable; services = as delivered |
| ARR | Recurring only (subscription + remaining maintenance); excludes perpetual license |
| Conversion | New subscription ARR = converted maintenance ARR × conversion multiple |
| Trough driver | Forgone upfront license bookings as perpetual sunsets (separate from the multiple) |
| Gross margin | Σ(revenue_line × margin_line) ÷ total revenue; SaaS margin < maintenance margin |
| Adoption elasticity | Higher conversion multiple → lower adoption ceiling and higher churn |

## 5. Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-01 | **Auditability** — every core figure traceable to a filing; fact/assumption seam explicit |
| NFR-02 | **Reproducibility** — model re-runs from source with documented dependencies |
| NFR-03 | **Reconciliation** — scenario base ties to disclosed revenue mix before assumptions apply |
| NFR-04 | **Portability** — runs on a standard PostgreSQL + Python + Power BI stack |
