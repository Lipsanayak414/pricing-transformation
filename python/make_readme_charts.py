"""Generate README output charts from the committed model data."""
import csv, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

NAVY, GREY, TEAL, AMBER, MUTE, GRID = "#16243B", "#6B7686", "#0F9E99", "#DB8A34", "#64748B", "#EAEEF4"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11,
                     "axes.edgecolor": "#C9D2DE", "axes.linewidth": 0.8})

def read(path):
    with open(path) as f:
        return list(csv.DictReader(f))

def style(ax, title, ylab):
    ax.set_title(title, color=NAVY, fontsize=14, fontweight="bold", loc="left", pad=12)
    ax.set_ylabel(ylab, color=MUTE)
    ax.spines["top"].set_visible(False); ax.spines["right"].set_visible(False)
    ax.tick_params(colors=MUTE); ax.yaxis.grid(True, color=GRID, lw=0.8); ax.set_axisbelow(True)

proj = read("exports/scenario_projections.csv")
def series(scn, col):
    return [float(r[col]) for r in proj if r["scenario"] == scn]
yrs = sorted({int(r["year"]) for r in proj})
cmap = {"A_1.25x": GREY, "B_1.50x": TEAL, "C_2.00x": AMBER}
lab = {"A_1.25x": "A — 1.25x", "B_1.50x": "B — 1.50x", "C_2.00x": "C — 2.00x"}

# 1) Revenue trough
fig, ax = plt.subplots(figsize=(8, 4.4), dpi=130)
for scn in cmap:
    ax.plot(yrs, series(scn, "total_rev_musd"), marker="o", color=cmap[scn], lw=2.6, label=lab[scn])
ax.set_ylim(380, 490); ax.set_xlabel("Year", color=MUTE)
style(ax, "Reported revenue trough by scenario (USD M)", "Total revenue")
ax.legend(frameon=False, loc="lower right")
ax.annotate("Trough — Year 3", xy=(3, 410.6), xytext=(3.2, 396), color=MUTE, fontsize=10,
            arrowprops=dict(arrowstyle="->", color=MUTE))
fig.tight_layout(); fig.savefig("docs/images/trough.png", bbox_inches="tight"); plt.close()

# 2) Long-term ARR
fig, ax = plt.subplots(figsize=(8, 4.4), dpi=130)
for scn in cmap:
    ax.plot(yrs, series(scn, "arr_musd"), marker="o", color=cmap[scn], lw=2.6, label=lab[scn])
ax.set_xlabel("Year", color=MUTE)
style(ax, "Long-term ARR by scenario (USD M)", "ARR")
ax.legend(frameon=False, loc="upper left")
fig.tight_layout(); fig.savefig("docs/images/arr.png", bbox_inches="tight"); plt.close()

# 3) Sensitivity (flip point)
sens = read("exports/sensitivity_resistance.csv")
churn = [float(r["C_cum_churn_pct"]) for r in sens]
cval = [float(r["C_year5_arr"]) for r in sens]
bval = [float(r["B_year5_arr"]) for r in sens]
fig, ax = plt.subplots(figsize=(8, 4.4), dpi=130)
ax.plot(churn, cval, marker="o", color=AMBER, lw=2.6, label="C — 2.00x (stressed)")
ax.plot(churn, bval, color=TEAL, lw=2.6, ls="--", label="B — 1.50x (steady)")
ax.axvline(20, color=MUTE, lw=1, ls=":")
ax.set_xlabel("Cumulative churn at 2.0x (%)", color=MUTE)
style(ax, "Sensitivity: where Scenario B overtakes C", "Year-5 ARR (USD M)")
ax.legend(frameon=False, loc="upper right")
ax.annotate("flip ~20%", xy=(20, 365), xytext=(21, 392), color=NAVY, fontsize=10, fontweight="bold")
fig.tight_layout(); fig.savefig("docs/images/sensitivity.png", bbox_inches="tight"); plt.close()

# 4) Real transition arc (Guidewire)
gw = read("exports/guidewire_transition.csv")
years = [r["fiscal_year"] for r in gw]
lic = [float(r["license_musd"]) for r in gw]
sub = [float(r["subscription_support_musd"]) for r in gw]
srv = [float(r["services_musd"]) for r in gw]
import numpy as np
x = np.arange(len(years)); w = 0.26
fig, ax = plt.subplots(figsize=(8, 4.4), dpi=130)
ax.bar(x - w, lic, w, color=GREY, label="License")
ax.bar(x, sub, w, color=TEAL, label="Subscription & support")
ax.bar(x + w, srv, w, color="#B9C2D0", label="Services")
ax.set_xticks(x); ax.set_xticklabels(years)
style(ax, "The transition is real — Guidewire FY23–FY25 (USD M)", "Revenue")
ax.legend(frameon=False, loc="upper left")
fig.tight_layout(); fig.savefig("docs/images/transition_arc.png", bbox_inches="tight"); plt.close()

print("wrote 4 charts to docs/images/")
