# Process Flows

Diagrams render natively on GitHub. Three flows: the solution data pipeline, the
migration-decision process, and the deal-desk discount-approval workflow.

## 1. Solution data flow (source → deliverable)

```mermaid
flowchart LR
  A[Public filings<br/>GWRE · SPNS · DCT] --> B[Source inventory<br/>fields + citations]
  B --> C[(Postgres schema<br/>disclosed core)]
  C --> D[Python scenario model<br/>A / B / C]
  D --> E[CSV exports]
  E --> F[Power BI dashboard]
  E --> G[Executive deck]
  C -. reconciliation gate .-> D
```

## 2. Migration-decision process

```mermaid
flowchart TD
  S[Installed base<br/>perpetual + maintenance] --> T[Segment by DWP tier]
  T --> M{Set conversion<br/>multiple}
  M -->|1.25x| A[Scenario A]
  M -->|1.50x| B[Scenario B]
  M -->|2.00x| C[Scenario C]
  A --> P[Model ARR, trough,<br/>margin by year]
  B --> P
  C --> P
  P --> X[Sensitivity:<br/>price resistance]
  X --> D{Trough within<br/>board tolerance?}
  D -->|Yes| R[Recommend scenario]
  D -->|No| M
```

## 3. Deal-desk discount-approval workflow

```mermaid
flowchart TD
  R[Discount request] --> Q{Discount band?}
  Q -->|up to 10%| A[Rep approves]
  Q -->|10–20%| B[Sales manager]
  Q -->|20–30%| C[VP Sales / Head of Pricing]
  Q -->|over 30%| D[CFO]
  A --> E[Approved & recorded<br/>in deal desk]
  B --> E
  C --> E
  D --> E
  Q -. margin floor / NDR guardrails .-> E
```
