import pandas as pd

BASE_MAINTENANCE_ARR = 180.0
BASE_SUBSCRIPTION_ARR = 120.0
BASE_LICENSE_BOOKINGS = 90.0
BASE_SERVICES_REV = 80.0
LICENSE_RAMP = [1.00, 0.66, 0.33, 0.00, 0.00, 0.00]
HORIZON = 6

# Scenario B (the comparator), fixed.
B = {"mult": 1.50,
     "adopt": [0.00, 0.25, 0.48, 0.68, 0.77, 0.82],
     "churn": [0.00, 0.02, 0.03, 0.04, 0.05, 0.05]}
# Scenario C base assumptions, before stress.
C_BASE = {"mult": 2.00,
          "adopt": [0.00, 0.15, 0.32, 0.50, 0.60, 0.66],
          "churn": [0.00, 0.03, 0.06, 0.08, 0.10, 0.11]}


def year5_arr(mult, adopt, churn):
    conv, churned = adopt[5], churn[5]
    remaining = max(0.0, 1.0 - conv - churned)
    subscription = BASE_SUBSCRIPTION_ARR + BASE_MAINTENANCE_ARR * conv * mult
    maintenance = BASE_MAINTENANCE_ARR * remaining
    return subscription + maintenance


def stress_C(r):
    """Scale C's resistance by r: churn *= r, adoption ceiling shrinks."""
    churn = [min(0.9, c * r) for c in C_BASE["churn"]]
    # adoption ceiling erodes as resistance rises (people who would have converted now stall)
    shrink = 1.0 - 0.20 * (r - 1.0)
    adopt = [a * max(0.4, shrink) for a in C_BASE["adopt"]]
    return adopt, churn


def main():
    b_arr = year5_arr(B["mult"], B["adopt"], B["churn"])
    rows, flip = [], None
    r = 1.0
    while r <= 2.6:
        adopt, churn = stress_C(r)
        c_arr = year5_arr(C_BASE["mult"], adopt, churn)
        rows.append({"resistance_r": round(r, 2),
                     "C_cum_churn_pct": round(churn[5] * 100, 1),
                     "C_year5_arr": round(c_arr, 1),
                     "B_year5_arr": round(b_arr, 1),
                     "C_beats_B": c_arr > b_arr})
        if flip is None and c_arr <= b_arr:
            flip = (round(r, 2), round(churn[5] * 100, 1))
        r += 0.1

    df = pd.DataFrame(rows)
    df.to_csv("../exports/sensitivity_resistance.csv", index=False)
    pd.set_option("display.width", 140)
    print(df.to_string(index=False))
    if flip:
        print(f"\nFLIP POINT: B overtakes C at resistance r={flip[0]} "
              f"(cumulative 2.0x churn ~{flip[1]}%).")
        print("Below that churn, C wins; at/above it, B is the risk-adjusted choice.")
    else:
        print("\nC beats B across the full stress range tested.")


if __name__ == "__main__":
    main()
