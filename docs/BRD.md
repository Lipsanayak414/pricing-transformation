# Business Requirements Document (BRD)

| | |
|---|---|
| **Project** | Enterprise SaaS Pricing Transformation — Perpetual → SaaS migration |
| **Version** | 1.0 |
| **Status** | Approved for build |
| **Author** | Pricing Analyst |
| **Audience** | CFO, Head of Pricing, Sales Leadership, RevOps |

---

## 1. Purpose

Define the business need, objectives, scope, and requirements for a decision-support model that
determines **how** an insurance software platform vendor should migrate its perpetual-license base
to SaaS subscriptions — on what conversion terms, at what pace, and under what governance.

## 2. Background & business problem

The vendor sells core insurance software (policy admin, claims, billing) historically under
perpetual licenses plus annual maintenance. The market is moving to cloud subscription. The
challenge is **revenue recognition**: perpetual license is recognised upfront, while SaaS is
recognised ratably over the term. A migration that improves long-term value can therefore produce a
**near-term reported-revenue trough** — the primary concern of the CFO and board.

The decision is not *whether* to migrate (the market forces it) but the **commercial structure**:
the conversion price relative to prior maintenance, the speed of sunsetting perpetual, and the
discount and approval governance around it.

## 3. Business objectives & success criteria

| Objective | Success criterion |
|---|---|
| Maximise long-term recurring revenue | Year-5 ARR materially above the status-quo path |
| Keep the transition affordable to the P&L | Reported-revenue trough within board tolerance |
| Protect margin and cash through the transition | Gross margin modelled, not just revenue; floor enforced |
| Ground the analysis in defensible evidence | Core figures traceable to public filings |
| Make the recommendation robust | Sensitivity-tested; conditions for each scenario explicit |

## 4. Scope

**In scope:** migration scenario model (conversion multiples, sunset, adoption); revenue/ARR/margin
projection and trough analysis; sensitivity analysis; discount governance and deal-desk approval
framework; executive dashboard and presentation; analysis grounded in Guidewire/Sapiens/Duck Creek
disclosures.

**Out of scope:** synthetic customer-level data; deep consumption/AI-platform pricing; full
multi-currency build (UK treated as a secondary segment); implementation/migration project
execution.

## 5. Stakeholders

| Stakeholder | Interest | RACI (on the pricing decision) |
|---|---|---|
| CFO | Revenue trough, margin, cash | Accountable |
| Head of Pricing | Conversion terms, governance | Responsible |
| Sales Leadership | Deal velocity, discount latitude | Consulted |
| Deal Desk | Approval routing, guardrails | Consulted |
| RevOps / Finance | ARR reporting, rev-rec | Informed |

## 6. Business requirements

| ID | Requirement |
|---|---|
| BR-01 | Evaluate at least three conversion-multiple scenarios (1.25x / 1.5x / 2.0x of prior maintenance). |
| BR-02 | Quantify the near-term reported-revenue trough (depth and timing) for each scenario. |
| BR-03 | Ground the analytical core in public company disclosures, with citations. |
| BR-04 | Model gross margin endogenously — a revenue multiple is not a profit multiple. |
| BR-05 | Test how sensitive the recommendation is to the adoption/price-resistance assumption. |
| BR-06 | Provide a discount-governance and deal-desk approval framework with guardrails. |
| BR-07 | Deliver executive reporting (dashboard + presentation) for leadership. |
| BR-08 | Maintain an auditable separation between disclosed fact and modelled assumption. |

## 7. Assumptions, constraints & risks

Modelling assumptions and the risk register are maintained in
[`assumptions_and_risks.md`](assumptions_and_risks.md). Key constraint: ~40–60 hours; hence the
scope cuts in §4. Key risk: the recommendation is sensitive to the price-resistance assumption
(mitigated by sensitivity analysis and a risk-adjusted default).

## 8. Success metrics

Defined in [`kpi_definitions.md`](kpi_definitions.md): ARR and ARR growth, trough depth and year,
blended gross margin, and net dollar retention (bounded to the disclosed 108–120% band).
