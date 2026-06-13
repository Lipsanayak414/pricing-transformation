# python/ — Scenario model (Phase 6)

Holds the migration / pricing / renewal scenario model. It reads the disclosed base from
Postgres (`fact_financials`, `fact_metrics`), applies the assumptions in `dim_scenario`, and
writes results to `fact_scenario_projection` and/or `../exports/*.csv` for Power BI.

Planned:
- `scenario_migration.py` — conversion-multiple economics, trough, margin compression
- `sensitivity.py`        — sweep multiple x sunset window x adoption drag
- `requirements.txt`      — pinned dependencies

All code will be heavily commented (assumptions stated inline) for interview defensibility.
