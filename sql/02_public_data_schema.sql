-- =====================================================================
-- ENTERPRISE SaaS PRICING TRANSFORMATION  |  PUBLIC-DATA SCHEMA (PostgreSQL)
-- v1.0  (2026-06-09)
--
-- SUPERSEDES the synthetic carrier-level fact tables from
-- 01_pricing_data_model.sql. Architecture is now two layers:
--
--   ANALYTICAL CORE  (Tier 1, disclosed + cited)
--     dim_company, dim_fiscal_period, dim_revenue_line,
--     fact_financials, fact_metrics, ref_metric_definition,
--     dim_product_module
--
--   SCENARIO LAYER  (Tier 3, assumptions bounded by ref_benchmark)
--     dim_scenario, fact_scenario_assumption, fact_scenario_projection
--
-- Every row in the core carries a source_citation. Scenarios operate ON
-- the disclosed base, never on fabricated carrier records.
-- =====================================================================

DROP TABLE IF EXISTS fact_scenario_projection, fact_scenario_assumption,
    dim_scenario, ref_benchmark, ref_metric_definition, fact_metrics,
    fact_financials, dim_product_module, dim_revenue_line,
    dim_fiscal_period, dim_company CASCADE;

-- ---------------------------------------------------------------------
-- DIM_COMPANY -- the real vendors behind the analysis.
-- ---------------------------------------------------------------------
CREATE TABLE dim_company (
    company_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_name      TEXT NOT NULL,
    ticker            TEXT,
    exchange          TEXT,
    annual_filing_type TEXT NOT NULL,        -- 10-K / 20-F
    fiscal_year_end   TEXT NOT NULL,         -- e.g. 'Jul 31'
    reporting_currency CHAR(3) NOT NULL DEFAULT 'USD',
    is_public_current BOOLEAN NOT NULL,
    went_private_date DATE,                  -- null if still public
    role_in_project   TEXT NOT NULL          -- anchor / corroborator / historical
);

-- ---------------------------------------------------------------------
-- DIM_FISCAL_PERIOD -- annual and quarterly periods per company.
-- quarter = 0 denotes a full-year period.
-- ---------------------------------------------------------------------
CREATE TABLE dim_fiscal_period (
    period_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id   INT NOT NULL REFERENCES dim_company(company_id),
    fiscal_year  INT NOT NULL,
    fiscal_quarter SMALLINT NOT NULL,        -- 0 = annual, 1..4 = quarterly
    period_end_date DATE NOT NULL,
    period_type  TEXT NOT NULL,              -- annual / quarterly
    CONSTRAINT ck_period_q CHECK (fiscal_quarter BETWEEN 0 AND 4),
    CONSTRAINT uq_period UNIQUE (company_id, fiscal_year, fiscal_quarter)
);

-- ---------------------------------------------------------------------
-- DIM_REVENUE_LINE -- standardised revenue taxonomy. Companies label
-- differently (GWRE: 'subscription & support'; DCT: 'subscription' +
-- 'maintenance & support' separately) so we map all to common codes.
-- recognition_method + typical_margin_band drive the migration model.
-- ---------------------------------------------------------------------
CREATE TABLE dim_revenue_line (
    revenue_line_code TEXT PRIMARY KEY,      -- LICENSE / SUB_SUPPORT / SUBSCRIPTION / MAINTENANCE / SERVICES
    description       TEXT NOT NULL,
    recognition_method TEXT NOT NULL,        -- point_in_time / ratable / as_delivered
    is_recurring      BOOLEAN NOT NULL,
    CONSTRAINT ck_rl_recog CHECK (recognition_method IN ('point_in_time','ratable','as_delivered'))
);

-- ---------------------------------------------------------------------
-- FACT_FINANCIALS -- THE CORE. One disclosed revenue figure.
-- Grain: company x period x revenue line. Every row cited.
-- ---------------------------------------------------------------------
CREATE TABLE fact_financials (
    fin_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    period_id        INT NOT NULL REFERENCES dim_fiscal_period(period_id),
    company_id       INT NOT NULL REFERENCES dim_company(company_id),
    revenue_line_code TEXT NOT NULL REFERENCES dim_revenue_line(revenue_line_code),
    amount_musd      NUMERIC(12,2) NOT NULL, -- USD millions
    is_non_gaap      BOOLEAN NOT NULL DEFAULT FALSE,
    is_derived       BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE if computed from a disclosed growth rate
    source_citation  TEXT NOT NULL,          -- e.g. 'GWRE FY2025 8-K, 2025-09-04'
    source_url       TEXT
);

-- ---------------------------------------------------------------------
-- FACT_METRICS -- disclosed non-revenue metrics (ARR, margins, NDR,
-- customer count, ACV mix). metric_code is free but conventional.
-- ---------------------------------------------------------------------
CREATE TABLE fact_metrics (
    metric_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    period_id        INT NOT NULL REFERENCES dim_fiscal_period(period_id),
    company_id       INT NOT NULL REFERENCES dim_company(company_id),
    metric_code      TEXT NOT NULL,          -- ARR / ARR_GROWTH / NDR / SAAS_ACV_MIX / CUSTOMER_COUNT / OP_MARGIN
    metric_value     NUMERIC(14,4) NOT NULL,
    unit             TEXT NOT NULL,          -- musd / pct / count / ratio
    is_derived       BOOLEAN NOT NULL DEFAULT FALSE,
    source_citation  TEXT NOT NULL,
    source_url       TEXT
);

-- ---------------------------------------------------------------------
-- REF_METRIC_DEFINITION -- each company defines ARR/NDR/ACV slightly
-- differently. Capturing the definition text protects you from
-- comparing non-comparable metrics in the benchmark.
-- ---------------------------------------------------------------------
CREATE TABLE ref_metric_definition (
    def_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id    INT REFERENCES dim_company(company_id), -- null = industry-general
    metric_code   TEXT NOT NULL,
    definition_text TEXT NOT NULL,
    source_citation TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- DIM_PRODUCT_MODULE -- real disclosed P&C core-system taxonomy.
-- Used to structure the Enterprise Price Book.
-- ---------------------------------------------------------------------
CREATE TABLE dim_product_module (
    module_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    module_name   TEXT NOT NULL,             -- Policy admin / Claims / Billing / Rating / Data / AI
    is_core_system BOOLEAN NOT NULL,
    source_citation TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- REF_BENCHMARK -- guardrails that bound Tier 3 assumptions. Ranges,
-- not points, with a source. Rows without a real source are flagged.
-- ---------------------------------------------------------------------
CREATE TABLE ref_benchmark (
    benchmark_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    metric        TEXT NOT NULL,             -- DISCOUNT_RANGE / RENEWAL_UPLIFT / NDR_NORM / SAAS_GM_BAND
    segment       TEXT,                      -- DWP tier / region / null
    low_value     NUMERIC(10,4),
    high_value    NUMERIC(10,4),
    unit          TEXT NOT NULL,
    source_name   TEXT NOT NULL,             -- 'PLACEHOLDER' until a real report is cited
    source_year   INT,
    notes         TEXT
);

-- ---------------------------------------------------------------------
-- DIM_SCENARIO -- the assumption layer. One row per modelled scenario.
-- Operates on a base company's disclosed metrics (base_company_id).
-- ---------------------------------------------------------------------
CREATE TABLE dim_scenario (
    scenario_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_name        TEXT NOT NULL,
    scenario_type        TEXT NOT NULL,      -- migration / pricing / renewal
    base_company_id      INT NOT NULL REFERENCES dim_company(company_id),
    base_fiscal_year     INT NOT NULL,       -- the disclosed year the scenario starts from
    conversion_multiple  NUMERIC(6,4),       -- migration: new sub ARR / prior maintenance ARR
    sunset_window_months INT,                -- migration: perpetual sellable window
    adoption_drag_param  NUMERIC(6,4),       -- links higher multiple to slower adoption
    annual_uplift_pct    NUMERIC(6,4),       -- renewal: contractual price increase
    description          TEXT,
    CONSTRAINT ck_scn_type CHECK (scenario_type IN ('migration','pricing','renewal'))
);

-- ---------------------------------------------------------------------
-- FACT_SCENARIO_ASSUMPTION -- each numeric assumption, with the
-- benchmark or disclosure that justifies it. This is the audit trail
-- that lets you answer "why that number?" in an interview.
-- ---------------------------------------------------------------------
CREATE TABLE fact_scenario_assumption (
    assumption_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id   INT NOT NULL REFERENCES dim_scenario(scenario_id),
    assumption_name TEXT NOT NULL,
    assumption_value NUMERIC(12,4) NOT NULL,
    unit          TEXT NOT NULL,
    justification TEXT NOT NULL,             -- prose linking to a benchmark/disclosure
    benchmark_id  INT REFERENCES ref_benchmark(benchmark_id)
);

-- ---------------------------------------------------------------------
-- FACT_SCENARIO_PROJECTION -- model output. One row per scenario x year.
-- Derived from the disclosed base + the scenario assumptions. This is
-- what the Python model writes and the dashboard reads.
-- ---------------------------------------------------------------------
CREATE TABLE fact_scenario_projection (
    projection_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id       INT NOT NULL REFERENCES dim_scenario(scenario_id),
    projection_year   INT NOT NULL,
    projected_license_musd      NUMERIC(12,2),
    projected_subscription_musd NUMERIC(12,2),
    projected_services_musd     NUMERIC(12,2),
    projected_total_rev_musd    NUMERIC(12,2),
    projected_arr_musd          NUMERIC(12,2),
    projected_gross_margin_pct  NUMERIC(6,4),
    yoy_total_rev_growth_pct    NUMERIC(6,4),
    is_trough_year    BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_proj UNIQUE (scenario_id, projection_year)
);

-- =====================================================================
-- SEED DATA -- verified disclosures (see source_inventory.md §4).
-- =====================================================================

INSERT INTO dim_company (company_name, ticker, exchange, annual_filing_type, fiscal_year_end, is_public_current, went_private_date, role_in_project) VALUES
 ('Guidewire Software, Inc.', 'GWRE', 'NYSE',   '10-K', 'Jul 31', TRUE,  NULL,         'anchor'),
 ('Sapiens International Corp N.V.', 'SPNS', 'NASDAQ', '20-F', 'Dec 31', TRUE, NULL,    'corroborator'),
 ('Duck Creek Technologies, Inc.', 'DCT', 'NASDAQ', '10-K', 'Aug 31', FALSE, DATE '2023-03-01', 'historical'),
 ('Majesco', 'MJCO', 'NASDAQ', '10-K', 'Mar 31', FALSE, DATE '2020-09-21', 'historical');

INSERT INTO dim_revenue_line (revenue_line_code, description, recognition_method, is_recurring) VALUES
 ('LICENSE',      'Perpetual / term license fees',          'point_in_time', FALSE),
 ('SUB_SUPPORT',  'Subscription and support (GWRE combined)','ratable',       TRUE),
 ('SUBSCRIPTION', 'SaaS subscription (standalone)',          'ratable',       TRUE),
 ('MAINTENANCE',  'Maintenance and support (standalone)',    'ratable',       TRUE),
 ('SERVICES',     'Professional / implementation services',  'as_delivered',  FALSE);

-- Guidewire fiscal years (annual periods)
INSERT INTO dim_fiscal_period (company_id, fiscal_year, fiscal_quarter, period_end_date, period_type) VALUES
 (1, 2022, 0, DATE '2022-07-31', 'annual'),
 (1, 2023, 0, DATE '2023-07-31', 'annual'),
 (1, 2024, 0, DATE '2024-07-31', 'annual'),
 (1, 2025, 0, DATE '2025-07-31', 'annual'),
 (3, 2022, 0, DATE '2022-08-31', 'annual'),
 (2, 2024, 0, DATE '2024-12-31', 'annual');

-- Guidewire revenue by line (verified; FY24 lines derived from FY25 growth rates)
INSERT INTO fact_financials (period_id, company_id, revenue_line_code, amount_musd, is_non_gaap, is_derived, source_citation) VALUES
 (1, 1, 'SUB_SUPPORT', 343.70, FALSE, FALSE, 'GWRE FY2022 8-K (2022-09-06)'),
 (2, 1, 'SUB_SUPPORT', 429.70, FALSE, FALSE, 'GWRE FY2023 8-K (2023-09-07)'),
 (2, 1, 'LICENSE',     265.60, FALSE, FALSE, 'GWRE FY2023 8-K (2023-09-07)'),
 (2, 1, 'SERVICES',    210.10, FALSE, FALSE, 'GWRE FY2023 8-K (2023-09-07)'),
 (4, 1, 'SUB_SUPPORT', 731.30, FALSE, FALSE, 'GWRE FY2025 8-K (2025-09-04)'),
 (4, 1, 'LICENSE',     251.90, FALSE, FALSE, 'GWRE FY2025 8-K (2025-09-04)'),
 (4, 1, 'SERVICES',    219.20, FALSE, FALSE, 'GWRE FY2025 8-K (2025-09-04)'),
 (3, 1, 'SUB_SUPPORT', 549.80, FALSE, TRUE,  'Derived from GWRE FY2025 8-K (+33% YoY)'),
 (3, 1, 'LICENSE',     249.40, FALSE, TRUE,  'Derived from GWRE FY2025 8-K (+1% YoY)'),
 (3, 1, 'SERVICES',    181.20, FALSE, TRUE,  'Derived from GWRE FY2025 8-K (+21% YoY)');

-- Duck Creek FY2022 revenue by line (verified)
INSERT INTO fact_financials (period_id, company_id, revenue_line_code, amount_musd, is_non_gaap, is_derived, source_citation) VALUES
 (5, 3, 'SUBSCRIPTION', 153.50, FALSE, FALSE, 'DCT FY2022 8-K (2022-10-12)'),
 (5, 3, 'SERVICES',     106.30, FALSE, FALSE, 'DCT FY2022 8-K (2022-10-12)'),
 (5, 3, 'LICENSE',       17.30, FALSE, FALSE, 'DCT FY2022 8-K (2022-10-12)'),
 (5, 3, 'MAINTENANCE',   25.80, FALSE, FALSE, 'DCT FY2022 8-K (2022-10-12)');

-- Sapiens 2024 total revenue (non-GAAP guidance midpoint)
INSERT INTO fact_financials (period_id, company_id, revenue_line_code, amount_musd, is_non_gaap, is_derived, source_citation) VALUES
 (6, 2, 'SUBSCRIPTION', 542.00, TRUE, TRUE, 'SPNS 2024 non-GAAP revenue guidance midpoint (6-K, 2024)');

-- Disclosed metrics
INSERT INTO fact_metrics (period_id, company_id, metric_code, metric_value, unit, is_derived, source_citation) VALUES
 (2, 1, 'ARR',          763.00, 'musd', FALSE, 'GWRE FY2023 8-K (2023-09-07)'),
 (2, 1, 'ARR_GROWTH',    15.00, 'pct',  FALSE, 'GWRE FY2023 8-K (2023-09-07)'),
 (3, 1, 'ARR',          864.00, 'musd', FALSE, 'GWRE FY2024 (per FY2025 8-K comparative)'),
 (4, 1, 'ARR',         1032.00, 'musd', FALSE, 'GWRE FY2025 8-K (2025-09-04)'),
 (4, 1, 'ARR_GROWTH',    19.00, 'pct',  FALSE, 'GWRE FY2025 8-K (2025-09-04)'),
 (5, 3, 'SAAS_ARR',     169.30, 'musd', FALSE, 'DCT FY2022 8-K (2022-10-12)'),
 (5, 3, 'NDR',          108.00, 'pct',  FALSE, 'DCT FY2022 10-K MD&A'),
 (5, 3, 'SAAS_ACV_MIX',  97.00, 'pct',  FALSE, 'DCT FY2022 10-K MD&A'),
 (6, 2, 'ARR',          168.00, 'musd', FALSE, 'SPNS Q1 2024 6-K'),
 (6, 2, 'ARR_GROWTH',    12.70, 'pct',  FALSE, 'SPNS Q1 2024 6-K'),
 (6, 2, 'OP_MARGIN',     18.00, 'pct',  TRUE,  'SPNS 2024 6-K (approx)');

-- Metric definitions (guard against comparing non-comparable ARR/NDR)
INSERT INTO ref_metric_definition (company_id, metric_code, definition_text, source_citation) VALUES
 (1, 'ARR', 'Annualized recurring value of term licenses, subscriptions, support and hosting in active contracts; excludes perpetual licenses and services.', 'GWRE earnings releases'),
 (2, 'ARR', 'Annualized value of subscriptions, term licenses, maintenance, application maintenance and cloud, run-rated from the most recent quarter x4.', 'SPNS 6-K'),
 (3, 'SAAS_ARR', 'Recurring SaaS revenue in the last month of the period, annualized; excludes one legacy contract.', 'DCT 10-K'),
 (3, 'NDR', 'Net dollar retention on SaaS recurring revenue for customers present throughout the measurement period.', 'DCT 10-K');

-- P&C core-system module taxonomy (from disclosed definitions)
INSERT INTO dim_product_module (module_name, is_core_system, source_citation) VALUES
 ('Policy administration', TRUE,  'DCT 10-K core-systems definition'),
 ('Claims management',     TRUE,  'DCT 10-K core-systems definition'),
 ('Billing',               TRUE,  'DCT 10-K core-systems definition'),
 ('Rating',                FALSE, 'DCT product disclosures'),
 ('Data / analytics',      FALSE, 'GWRE / DCT product disclosures'),
 ('AI add-ons',            FALSE, 'GWRE product disclosures');

-- Benchmark guardrails -- PLACEHOLDERS until a cited report replaces them
INSERT INTO ref_benchmark (metric, segment, low_value, high_value, unit, source_name, source_year, notes) VALUES
 ('NDR_NORM',       'P&C SaaS',     108.0000, 120.0000, 'pct', 'Duck Creek disclosed range', 2022, 'Empirical from DCT FY20-22'),
 ('DISCOUNT_RANGE', 'Enterprise',    0.0000,   0.0000,  'pct', 'PLACEHOLDER', NULL, 'Replace with cited SaaS benchmark'),
 ('RENEWAL_UPLIFT', 'Enterprise',    0.0000,   0.0000,  'pct', 'PLACEHOLDER', NULL, 'Replace with cited benchmark'),
 ('SAAS_GM_BAND',   'Insurance SW',  0.0000,   0.0000,  'pct', 'PLACEHOLDER', NULL, 'Replace with cited benchmark');
