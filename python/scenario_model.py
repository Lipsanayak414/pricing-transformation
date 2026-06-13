"""
scenario_model.py  |  Perpetual-license -> SaaS migration model
================================================================
Phase 6 deliverable. Models three migration paths (A/B/C) and identifies
which maximises long-term ARR while keeping the near-term reported-revenue
trough within CFO/board tolerance.

PROVENANCE
----------
The STRUCTURE and proportions are calibrated to disclosed insurance-software
economics (Guidewire revenue mix; Duck Creek SaaS NDR band; lower SaaS gross
margin from cloud COGS). The starting-state levels and the adoption/churn
schedules are Tier-3 modelling assumptions, stated explicitly below and
bounded by those disclosures. No fabricated customer-level records are used.

KEY MODELLING PRINCIPLES (defend these in interview)
----------------------------------------------------
1. Revenue multiple != profit multiple. SaaS carries hosting COGS, so its
   gross margin is structurally below maintenance. We report gross PROFIT,
   not just revenue, so a higher multiple does not automatically "win".
2. The trough is driven by forgone upfront PERPETUAL LICENSE bookings as the
   product is sunset -- NOT by the conversion multiple. Sunset window and
   conversion multiple are separate levers.
3. Higher conversion multiple -> more subscription per conversion, but slower
   adoption and higher churn (price resistance). Without this elasticity the
   model would mechanically pick the highest multiple every time.
"""

import pandas as pd

# ---------------------------------------------------------------------------
# STARTING STATE (Year 0).  USD millions.  Tier-3 assumption, calibrated to
# insurance-software proportions for a ~$470M-revenue vendor mid-transition.
# ---------------------------------------------------------------------------
BASE_MAINTENANCE_ARR = 180.0   # convertible perpetual-maintenance pool
BASE_SUBSCRIPTION_ARR = 120.0  # ARR already on SaaS (held flat to isolate the migration effect)
BASE_LICENSE_BOOKINGS = 90.0   # annual new perpetual license, recognised in-year (the trough driver)
BASE_SERVICES_REV = 80.0       # held flat to isolate the migration effect

# Gross margin by revenue stream. SaaS << maintenance because of cloud COGS.
GM = {"license": 0.95, "maintenance": 0.90, "subscription": 0.65, "services": 0.25}

# Sunset: perpetual closed to net-new logos immediately; license bookings ramp
# to zero across the 36-month window (Years 0->3), then stay zero.
LICENSE_RAMP = [1.00, 0.66, 0.33, 0.00, 0.00, 0.00]   # fraction of BASE_LICENSE_BOOKINGS by year

HORIZON = 6  # Year 0..5

# ---------------------------------------------------------------------------
# SCENARIOS.  mult = subscription ARR per unit of converted maintenance ARR.
# adopt[] = CUMULATIVE fraction of the ORIGINAL maintenance base converted by
# end of each year. churn[] = cumulative fraction lost (left rather than
# converted). Lower multiple -> faster adoption, less churn (less resistance).
# ---------------------------------------------------------------------------
SCENARIOS = {
    "A_1.25x": {"mult": 1.25,
                "adopt": [0.00, 0.35, 0.60, 0.80, 0.88, 0.92],
                "churn": [0.00, 0.01, 0.02, 0.03, 0.03, 0.04]},
    "B_1.50x": {"mult": 1.50,
                "adopt": [0.00, 0.25, 0.48, 0.68, 0.77, 0.82],
                "churn": [0.00, 0.02, 0.03, 0.04, 0.05, 0.05]},
    "C_2.00x": {"mult": 2.00,
                "adopt": [0.00, 0.15, 0.32, 0.50, 0.60, 0.66],
                "churn": [0.00, 0.03, 0.06, 0.08, 0.10, 0.11]},
}


def project(name, p):
    """Build the year-by-year projection for one scenario."""
    rows = []
    for t in range(HORIZON):
        conv = p["adopt"][t]                       # cumulative converted fraction
        churned = p["churn"][t]                     # cumulative churned fraction
        remaining = max(0.0, 1.0 - conv - churned)  # still on maintenance

        # Revenue streams (USD millions)
        license_rev      = BASE_LICENSE_BOOKINGS * LICENSE_RAMP[t]
        maintenance_rev  = BASE_MAINTENANCE_ARR * remaining
        subscription_rev = BASE_SUBSCRIPTION_ARR + BASE_MAINTENANCE_ARR * conv * p["mult"]
        services_rev     = BASE_SERVICES_REV

        total_rev = license_rev + maintenance_rev + subscription_rev + services_rev
        # ARR = recurring only (subscription + remaining maintenance); license excluded.
        arr = subscription_rev + maintenance_rev

        gross_profit = (license_rev * GM["license"] + maintenance_rev * GM["maintenance"]
                        + subscription_rev * GM["subscription"] + services_rev * GM["services"])
        blended_gm = gross_profit / total_rev

        rows.append({
            "scenario": name, "year": t,
            "license_musd": round(license_rev, 1),
            "maintenance_musd": round(maintenance_rev, 1),
            "subscription_musd": round(subscription_rev, 1),
            "services_musd": round(services_rev, 1),
            "total_rev_musd": round(total_rev, 1),
            "arr_musd": round(arr, 1),
            "gross_profit_musd": round(gross_profit, 1),
            "blended_gm_pct": round(blended_gm * 100, 1),
        })
    df = pd.DataFrame(rows)
    df["yoy_rev_growth_pct"] = (df["total_rev_musd"].pct_change() * 100).round(1)
    # Trough = lowest total revenue across the horizon (vs Year 0).
    trough_val = df["total_rev_musd"].min()
    df["is_trough_year"] = df["total_rev_musd"] == trough_val
    return df


def summarise(df):
    """One-line scorecard per scenario."""
    y0 = df.loc[df.year == 0, "total_rev_musd"].iloc[0]
    trough = df["total_rev_musd"].min()
    return {
        "scenario": df["scenario"].iloc[0],
        "year0_rev_musd": y0,
        "trough_rev_musd": trough,
        "trough_depth_pct": round((y0 - trough) / y0 * 100, 1),
        "trough_year": int(df.loc[df.is_trough_year, "year"].iloc[0]),
        "year5_arr_musd": df.loc[df.year == 5, "arr_musd"].iloc[0],
        "year5_total_rev_musd": df.loc[df.year == 5, "total_rev_musd"].iloc[0],
        "year5_blended_gm_pct": df.loc[df.year == 5, "blended_gm_pct"].iloc[0],
        "year5_gross_profit_musd": df.loc[df.year == 5, "gross_profit_musd"].iloc[0],
    }


def main():
    all_proj, summary = [], []
    for name, p in SCENARIOS.items():
        df = project(name, p)
        all_proj.append(df)
        summary.append(summarise(df))

    proj = pd.concat(all_proj, ignore_index=True)
    summ = pd.DataFrame(summary)

    proj.to_csv("../exports/scenario_projections.csv", index=False)
    summ.to_csv("../exports/scenario_summary.csv", index=False)

    # Emit SQL to load fact_scenario_projection (end-to-end consistency with the schema).
    with open("../sql/04_scenario_seed.sql", "w") as f:
        f.write("-- Auto-generated by scenario_model.py. Loads model output into the schema.\n")
        f.write("-- Scenarios operate on the disclosed base; see methodology.md.\n\n")
        f.write("INSERT INTO dim_scenario (scenario_name, scenario_type, base_company_id, base_fiscal_year, conversion_multiple, sunset_window_months, description) VALUES\n")
        vals = []
        for name, p in SCENARIOS.items():
            vals.append(f" ('{name}', 'migration', 1, 2025, {p['mult']}, 36, 'Subscription = {p['mult']}x prior maintenance ARR')")
        f.write(",\n".join(vals) + ";\n")

    pd.set_option("display.width", 160, "display.max_columns", 20)
    print("\n=== SCENARIO SUMMARY (the decision) ===")
    print(summ.to_string(index=False))
    print("\n=== FULL PROJECTION ===")
    print(proj.to_string(index=False))


if __name__ == "__main__":
    main()
