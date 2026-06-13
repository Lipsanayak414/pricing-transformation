-- =====================================================================
-- 03_analytical_queries.sql  |  Phase 5 -- analytical SQL
-- Runs on the disclosed core seeded by 02_public_data_schema.sql.
-- Each query documents: business question | CFO relevance | pricing relevance.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. TRANSITION ARC -- Guidewire revenue by line, FY2023 -> FY2025
-- Business question: is the perpetual->subscription shift actually happening?
-- CFO relevance: shows recurring revenue replacing one-time license.
-- Pricing relevance: the empirical pattern our migration model reproduces.
-- ---------------------------------------------------------------------
SELECT p.fiscal_year,
       MAX(CASE WHEN f.revenue_line_code = 'LICENSE'     THEN f.amount_musd END) AS license,
       MAX(CASE WHEN f.revenue_line_code = 'SUB_SUPPORT' THEN f.amount_musd END) AS subscription_support,
       MAX(CASE WHEN f.revenue_line_code = 'SERVICES'    THEN f.amount_musd END) AS services
FROM fact_financials f
JOIN dim_fiscal_period p ON f.period_id = p.period_id
WHERE f.company_id = 1
GROUP BY p.fiscal_year
ORDER BY p.fiscal_year;

-- ---------------------------------------------------------------------
-- B. REVENUE MIX % -- share of total by line, per year (reconciliation gate)
-- Business question: what share of revenue is recurring vs one-time?
-- CFO relevance: recurring-revenue quality is the valuation driver.
-- Pricing relevance: the base mix every scenario must reconcile to.
-- ---------------------------------------------------------------------
SELECT p.fiscal_year, f.revenue_line_code, f.amount_musd,
       ROUND(100.0 * f.amount_musd
             / SUM(f.amount_musd) OVER (PARTITION BY p.fiscal_year), 1) AS pct_of_total
FROM fact_financials f
JOIN dim_fiscal_period p ON f.period_id = p.period_id
WHERE f.company_id = 1
ORDER BY p.fiscal_year, pct_of_total DESC;

-- ---------------------------------------------------------------------
-- C. ARR WALK -- year-over-year ARR and growth for the anchor
-- Business question: how fast is recurring revenue compounding?
-- CFO relevance: ARR growth is the headline board metric.
-- Pricing relevance: validates the ARR trajectory our model projects.
-- ---------------------------------------------------------------------
SELECT p.fiscal_year, m.metric_value AS arr_musd,
       ROUND(m.metric_value
             - LAG(m.metric_value) OVER (ORDER BY p.fiscal_year), 1) AS arr_change,
       ROUND(100.0 * (m.metric_value / LAG(m.metric_value) OVER (ORDER BY p.fiscal_year) - 1), 1) AS arr_growth_pct
FROM fact_metrics m
JOIN dim_fiscal_period p ON m.period_id = p.period_id
WHERE m.company_id = 1 AND m.metric_code = 'ARR'
ORDER BY p.fiscal_year;

-- ---------------------------------------------------------------------
-- D. COMPETITIVE BENCHMARK -- recurring revenue & retention across vendors
-- Business question: how do the comparators frame recurring revenue?
-- CFO relevance: positions our economics against the public peer set.
-- Pricing relevance: bounds our NDR and mix assumptions to disclosed reality.
-- ---------------------------------------------------------------------
SELECT c.company_name, c.role_in_project, p.fiscal_year,
       m.metric_code, m.metric_value, m.unit
FROM fact_metrics m
JOIN dim_company c        ON m.company_id = c.company_id
JOIN dim_fiscal_period p  ON m.period_id = p.period_id
WHERE m.metric_code IN ('ARR','ARR_GROWTH','NDR','SAAS_ACV_MIX')
ORDER BY c.role_in_project, c.company_name, m.metric_code;

-- ---------------------------------------------------------------------
-- E. PROVENANCE AUDIT -- how much of the core is disclosed vs derived?
-- Business question: can every figure be traced to a filing?
-- CFO relevance: auditability of the analysis.
-- Pricing relevance: defends the model in due diligence / interview.
-- ---------------------------------------------------------------------
SELECT is_derived,
       COUNT(*)                AS rows,
       ROUND(SUM(amount_musd),1) AS total_musd
FROM fact_financials
GROUP BY is_derived
ORDER BY is_derived;
