# Assumptions & Risk Register

## Assumptions (scenario layer — Tier 3)

| ID | Assumption | Value | Rationale / bound |
|---|---|---|---|
| AS-01 | Starting convertible maintenance ARR | $180M | Calibrated to disclosed insurance-software mix |
| AS-02 | Conversion multiples (A/B/C) | 1.25x / 1.5x / 2.0x | Spans value-capture range |
| AS-03 | Perpetual sunset window | 36 months | Base case; flexed in sensitivity (24/36/48) |
| AS-04 | Adoption ceilings (A/B/C) | 92% / 82% / 66% | Higher price → slower adoption |
| AS-05 | Cumulative churn (A/B/C) | ~4% / ~5% / ~11% | Higher price → more resistance |
| AS-06 | Gross margins (lic/maint/sub/svc) | 95% / 90% / 65% / 25% | SaaS below maintenance (cloud COGS) |
| AS-07 | Non-migration revenue | held flat | Isolates the migration effect |

## Risk register

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| RK-01 | Recommendation is sensitive to churn assumption (AS-05) | High | High | Sensitivity analysis; flip point published; B is risk-adjusted default |
| RK-02 | Some seed figures are derived, not lifted verbatim | Medium | Medium | `is_derived` flag; verify against 10-K before presenting |
| RK-03 | Benchmark guardrails partly uncited | Medium | Low | `ref_benchmark` placeholders flagged; replace with cited reports |
| RK-04 | Duck Creek data is stale (private since 2023) | Certain | Low | Treated as historical corroborator, labelled as such |
| RK-05 | Adoption faster/slower than modelled | Medium | Medium | Run WTP study before committing to Scenario C |
| RK-06 | Margin compression deeper than assumed | Medium | Medium | Gross-margin floor guardrail (≥55%) in deal desk |
