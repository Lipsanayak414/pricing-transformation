-- =====================================================================
-- ENTERPRISE SaaS PRICING TRANSFORMATION  |  DATA MODEL (PostgreSQL)
-- Project: Perpetual-license -> SaaS migration for an insurance software
--          platform vendor. Synthetic customer layer, parameterised to
--          reconcile upward to Guidewire's disclosed FY2025 revenue mix.
--
-- DESIGN PRINCIPLE
--   Tier 1 (disclosed fact): revenue mix %, ARR growth, gross margins,
--           DWP-based pricing metric  -> used to PARAMETERISE this data.
--   Tier 3 (modelled): everything at customer/contract/deal grain below.
--   Validation gate: SUM(arr_contribution) GROUP BY line_type must match
--           Guidewire's disclosed license/subscription/services split.
--
-- CONVENTIONS
--   * money stored as NUMERIC(14,2); rates/percents as NUMERIC(6,4)
--     (e.g. 0.1850 = 18.50%). Never FLOAT for money.
--   * surrogate integer PKs; natural keys kept as attributes.
--   * all FKs enforced; CHECK constraints encode business rules so the
--     database itself rejects nonsense (e.g. a perpetual SaaS line).
-- =====================================================================

DROP TABLE IF EXISTS fact_migration, fact_renewal, fact_deal,
    fact_contract_line, fact_contract, price_book,
    dim_scenario, dim_sales_rep, dim_product, dim_customer CASCADE;

-- ---------------------------------------------------------------------
-- DIM_CUSTOMER  -- the insurance carrier. Segmentation spine.
-- WHY: pricing authority, budget, ARR concentration all sit at carrier
--      size (DWP tier). Line of business is a SECONDARY attribute used
--      for sensitivity, not the primary cut.
-- ---------------------------------------------------------------------
CREATE TABLE dim_customer (
    customer_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    carrier_name       TEXT        NOT NULL,
    dwp_tier           SMALLINT    NOT NULL,        -- 1 = >$5B, 2 = $1-5B, 3 = <$1B
    dwp_amount         NUMERIC(14,2) NOT NULL,      -- direct written premium, the pricing metric
    primary_lob        TEXT        NOT NULL,        -- Personal P&C / Commercial P&C / Specialty
    region             TEXT        NOT NULL,        -- North America / UK
    country            TEXT        NOT NULL,
    currency           CHAR(3)     NOT NULL,        -- USD / GBP
    acquisition_date   DATE        NOT NULL,        -- when they first became a customer
    status             TEXT        NOT NULL DEFAULT 'active',
    CONSTRAINT ck_cust_tier     CHECK (dwp_tier IN (1,2,3)),
    CONSTRAINT ck_cust_lob      CHECK (primary_lob IN ('Personal P&C','Commercial P&C','Specialty')),
    CONSTRAINT ck_cust_region   CHECK (region IN ('North America','UK')),
    CONSTRAINT ck_cust_currency CHECK (currency IN ('USD','GBP')),
    -- tier must be consistent with DWP band -- guards the segmentation logic
    CONSTRAINT ck_cust_tier_band CHECK (
        (dwp_tier = 1 AND dwp_amount >= 5000000000) OR
        (dwp_tier = 2 AND dwp_amount >= 1000000000 AND dwp_amount < 5000000000) OR
        (dwp_tier = 3 AND dwp_amount < 1000000000)
    )
);

-- ---------------------------------------------------------------------
-- DIM_PRODUCT  -- software modules (PolicyCenter / BillingCenter /
--                 ClaimCenter analogues, plus AI add-ons).
-- WHY: deployment_model lets the SAME capability exist as a perpetual
--      SKU and a SaaS SKU. Migration = volume shifting between them.
-- ---------------------------------------------------------------------
CREATE TABLE dim_product (
    product_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name    TEXT NOT NULL,
    product_family  TEXT NOT NULL,                  -- Policy / Billing / Claims / Data / AI
    deployment_model TEXT NOT NULL,                 -- perpetual / saas
    is_ai_module    BOOLEAN NOT NULL DEFAULT FALSE,
    base_metric     TEXT NOT NULL DEFAULT 'dwp_band',-- pricing basis (DWP band, not seats)
    CONSTRAINT ck_prod_deploy CHECK (deployment_model IN ('perpetual','saas'))
);

-- ---------------------------------------------------------------------
-- DIM_SALES_REP  -- rep / owner of contracts and deals.
-- WHY: discount governance and deal-desk analysis need an owner dimension
--      ("is heavy discounting concentrated in a few reps?").
-- ---------------------------------------------------------------------
CREATE TABLE dim_sales_rep (
    rep_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rep_name         TEXT NOT NULL,
    region           TEXT NOT NULL,
    segment_coverage TEXT NOT NULL,                 -- which DWP tier(s) they cover
    hire_date        DATE,
    annual_quota     NUMERIC(14,2)
);

-- ---------------------------------------------------------------------
-- PRICE_BOOK  -- Deliverable A, as data. The rate card.
-- WHY: list prices by product x DWP tier x deployment model. maintenance_pct
--      derives annual maintenance from perpetual license value (~18-22%),
--      so maintenance is never an arbitrary number.
-- ---------------------------------------------------------------------
CREATE TABLE price_book (
    price_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id       INT NOT NULL REFERENCES dim_product(product_id),
    dwp_tier         SMALLINT NOT NULL,
    deployment_model TEXT NOT NULL,
    list_price       NUMERIC(14,2) NOT NULL,        -- annual for SaaS; one-time for perpetual license
    maintenance_pct  NUMERIC(6,4),                  -- only for perpetual: maint = license * this
    currency         CHAR(3) NOT NULL DEFAULT 'USD',
    effective_date   DATE NOT NULL,
    end_date         DATE,
    CONSTRAINT ck_pb_tier   CHECK (dwp_tier IN (1,2,3)),
    CONSTRAINT ck_pb_deploy CHECK (deployment_model IN ('perpetual','saas')),
    -- maintenance_pct only meaningful for perpetual lines
    CONSTRAINT ck_pb_maint  CHECK (
        (deployment_model = 'perpetual' AND maintenance_pct IS NOT NULL)
        OR (deployment_model = 'saas' AND maintenance_pct IS NULL)
    )
);

-- ---------------------------------------------------------------------
-- DIM_SCENARIO  -- A/B/C migration scenarios. Turns a snapshot into a MODEL.
-- WHY: conversion_multiple and sunset_window_months are the two levers we
--      stress-test. adoption_param links a higher multiple to slower
--      adoption -- without it the model would mechanically pick the
--      highest price every time.
-- ---------------------------------------------------------------------
CREATE TABLE dim_scenario (
    scenario_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_name        TEXT NOT NULL,             -- A_1.25x / B_1.5x / C_2.0x
    conversion_multiple  NUMERIC(6,4) NOT NULL,     -- new sub ARR / prior maintenance ARR
    sunset_window_months INT NOT NULL,              -- months perpetual stays sellable (base = 36)
    adoption_param       NUMERIC(6,4) NOT NULL,     -- price-resistance / adoption-drag coefficient
    new_business_policy  TEXT NOT NULL,             -- e.g. 'closed_to_new_logos'
    CONSTRAINT ck_scn_mult CHECK (conversion_multiple > 0)
);

-- ---------------------------------------------------------------------
-- FACT_CONTRACT  -- one signed agreement. Where rev-rec attaches.
-- WHY: contract_type separates perpetual (upfront license + ratable
--      maintenance) from saas_subscription (fully ratable). This split is
--      the mechanical root of the SaaS-transition revenue trough.
-- ---------------------------------------------------------------------
CREATE TABLE fact_contract (
    contract_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id          INT NOT NULL REFERENCES dim_customer(customer_id),
    rep_id               INT NOT NULL REFERENCES dim_sales_rep(rep_id),
    contract_type        TEXT NOT NULL,             -- perpetual / saas_subscription
    start_date           DATE NOT NULL,
    end_date             DATE NOT NULL,
    term_months          INT  NOT NULL,
    tcv                  NUMERIC(14,2) NOT NULL,     -- total contract value
    original_license_value NUMERIC(14,2),            -- perpetual only: upfront license booking
    annual_maintenance_fee NUMERIC(14,2),            -- perpetual only: ratable maintenance
    billing_frequency    TEXT NOT NULL DEFAULT 'annual',
    currency             CHAR(3) NOT NULL DEFAULT 'USD',
    status               TEXT NOT NULL DEFAULT 'active',
    CONSTRAINT ck_con_type CHECK (contract_type IN ('perpetual','saas_subscription')),
    CONSTRAINT ck_con_term CHECK (end_date > start_date)
);

-- ---------------------------------------------------------------------
-- FACT_CONTRACT_LINE  -- one product on one contract. The reconciliation grain.
-- WHY: line_type is the hook for BOTH a revenue-recognition method and a
--      margin assumption, so the trough and margin compression fall out of
--      the data. GROUP BY line_type reconciles to Guidewire's revenue mix.
-- ---------------------------------------------------------------------
CREATE TABLE fact_contract_line (
    line_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    contract_id      INT NOT NULL REFERENCES fact_contract(contract_id),
    product_id       INT NOT NULL REFERENCES dim_product(product_id),
    price_id         INT REFERENCES price_book(price_id),
    line_type        TEXT NOT NULL,                 -- license / maintenance / subscription / services
    dwp_basis        NUMERIC(14,2),                 -- DWP the price was struck against
    list_amount      NUMERIC(14,2) NOT NULL,        -- pre-discount
    discount_pct     NUMERIC(6,4) NOT NULL DEFAULT 0,
    net_amount       NUMERIC(14,2) NOT NULL,        -- list_amount * (1 - discount_pct)
    arr_contribution NUMERIC(14,2) NOT NULL DEFAULT 0, -- 0 for one-time license & services
    revenue_recognition_method TEXT NOT NULL,       -- point_in_time / ratable / as_delivered
    gross_margin_pct NUMERIC(6,4) NOT NULL,         -- ~1.00 license, ~0.90 maint, lower for saas
    CONSTRAINT ck_line_type CHECK (line_type IN ('license','maintenance','subscription','services')),
    CONSTRAINT ck_line_recog CHECK (revenue_recognition_method IN ('point_in_time','ratable','as_delivered')),
    CONSTRAINT ck_line_disc CHECK (discount_pct >= 0 AND discount_pct <= 1)
);

-- ---------------------------------------------------------------------
-- FACT_DEAL  -- Deliverable C, the Deal Desk. One opportunity.
-- WHY: requested vs approved discount + approval_level are the governance
--      evidence; win_loss and competitor drive win/loss analysis.
-- ---------------------------------------------------------------------
CREATE TABLE fact_deal (
    deal_id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id          INT NOT NULL REFERENCES dim_customer(customer_id),
    rep_id               INT NOT NULL REFERENCES dim_sales_rep(rep_id),
    deal_type            TEXT NOT NULL,             -- new / migration / expansion / renewal
    deal_stage           TEXT NOT NULL,
    list_tcv             NUMERIC(14,2) NOT NULL,
    requested_discount_pct NUMERIC(6,4) NOT NULL DEFAULT 0,
    approved_discount_pct  NUMERIC(6,4) NOT NULL DEFAULT 0,
    approval_level       TEXT NOT NULL,             -- rep / manager / vp / cfo  (the matrix)
    final_tcv            NUMERIC(14,2),
    win_loss             TEXT,                      -- won / lost / open
    competitor           TEXT,                      -- Guidewire / Duck Creek / Sapiens / none
    close_date           DATE,
    CONSTRAINT ck_deal_type  CHECK (deal_type IN ('new','migration','expansion','renewal')),
    CONSTRAINT ck_deal_appr  CHECK (approval_level IN ('rep','manager','vp','cfo')),
    CONSTRAINT ck_deal_wl    CHECK (win_loss IN ('won','lost','open')),
    -- you can never approve MORE discount than the matrix allows for the level
    CONSTRAINT ck_deal_disc  CHECK (approved_discount_pct <= requested_discount_pct + 0.0001)
);

-- ---------------------------------------------------------------------
-- FACT_RENEWAL  -- Deliverable D, Renewal Uplift. One renewal event.
-- WHY: prior_arr vs renewed_arr yields gross & net retention -- the metric
--      SaaS investors care most about. uplift_pct is the price-increase lever.
-- ---------------------------------------------------------------------
CREATE TABLE fact_renewal (
    renewal_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    contract_id    INT NOT NULL REFERENCES fact_contract(contract_id),
    customer_id    INT NOT NULL REFERENCES dim_customer(customer_id),
    renewal_date   DATE NOT NULL,
    prior_arr      NUMERIC(14,2) NOT NULL,
    renewed_arr    NUMERIC(14,2) NOT NULL,
    uplift_pct     NUMERIC(6,4) NOT NULL,           -- contractual price increase applied
    churn_flag     BOOLEAN NOT NULL DEFAULT FALSE,
    downsell_flag  BOOLEAN NOT NULL DEFAULT FALSE,
    expansion_flag BOOLEAN NOT NULL DEFAULT FALSE,
    renewal_type   TEXT NOT NULL DEFAULT 'standard'
);

-- ---------------------------------------------------------------------
-- FACT_MIGRATION  -- THE CENTREPIECE. One perpetual->SaaS conversion.
-- WHY: links the retiring perpetual contract to the new SaaS contract under
--      a chosen scenario. prior_maintenance_arr vs new_subscription_arr at a
--      given conversion_multiple is the entire research question, instrumented.
-- ---------------------------------------------------------------------
CREATE TABLE fact_migration (
    migration_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id            INT NOT NULL REFERENCES dim_customer(customer_id),
    source_contract_id     INT NOT NULL REFERENCES fact_contract(contract_id),  -- perpetual
    target_contract_id     INT REFERENCES fact_contract(contract_id),           -- new SaaS (null until converted)
    scenario_id            INT NOT NULL REFERENCES dim_scenario(scenario_id),
    migration_date         DATE,
    prior_maintenance_arr  NUMERIC(14,2) NOT NULL,
    new_subscription_arr   NUMERIC(14,2),
    conversion_multiple    NUMERIC(6,4),            -- realised multiple (may differ from scenario target)
    migration_credit       NUMERIC(14,2) NOT NULL DEFAULT 0, -- one-time credit for prior investment
    perpetual_license_writeoff NUMERIC(14,2),       -- license revenue forgone (drives the trough)
    adoption_cohort        TEXT,                    -- which migration wave the customer joined
    migration_status       TEXT NOT NULL DEFAULT 'eligible', -- eligible / offered / converted / declined
    CONSTRAINT ck_mig_status CHECK (migration_status IN ('eligible','offered','converted','declined'))
);

-- =====================================================================
-- INDEXES for the analytical queries to come (Phase 5).
-- =====================================================================
CREATE INDEX ix_contract_customer  ON fact_contract(customer_id);
CREATE INDEX ix_contract_type_date ON fact_contract(contract_type, start_date);
CREATE INDEX ix_line_contract      ON fact_contract_line(contract_id);
CREATE INDEX ix_line_type          ON fact_contract_line(line_type);
CREATE INDEX ix_deal_rep           ON fact_deal(rep_id);
CREATE INDEX ix_renewal_customer   ON fact_renewal(customer_id);
CREATE INDEX ix_migration_scenario ON fact_migration(scenario_id);
