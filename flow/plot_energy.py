#!/usr/bin/env python3
"""Accuracy vs estimated energy per inference, across truncation levels.

Reads results/energy_results.csv (written by energy.py). Run energy.py first.
"""
import csv
import matplotlib.pyplot as plt

rows = []
with open("results/energy_results.csv") as f:
    for row in csv.DictReader(f):
        rows.append({
            "T": int(row["trunc_bits"]),
            "energy_uJ": float(row["energy_per_inference_uJ"]),
            "accuracy": float(row["accuracy_pct"]),
        })

rows.sort(key=lambda r: r["T"])
energy = [r["energy_uJ"] for r in rows]
accuracy = [r["accuracy"] for r in rows]

KNEE_T = 2

fig, ax = plt.subplots(figsize=(7, 5))
ax.plot(energy, accuracy, marker="o", linewidth=2, markersize=8,
        color="steelblue", zorder=2)

# highlight the knee, labelled so identity is not carried by colour alone
knee = next(r for r in rows if r["T"] == KNEE_T)
ax.plot(knee["energy_uJ"], knee["accuracy"], marker="o", markersize=13,
        markerfacecolor="none", markeredgecolor="firebrick",
        markeredgewidth=2, zorder=3)

for r in rows:
    label = f"T={r['T']} (knee)" if r["T"] == KNEE_T else f"T={r['T']}"
    # points near the ceiling get their label below, clear of the title
    offset = (10, -16) if r["accuracy"] > 90 else (10, 7)
    ax.annotate(label, (r["energy_uJ"], r["accuracy"]),
                textcoords="offset points", xytext=offset, fontsize=10)

ax.set_xlabel("Estimated dynamic energy per inference (uJ)")
ax.set_ylabel("MNIST accuracy (%)")
ax.set_title("Accuracy vs estimated energy across truncation")
ax.grid(True, alpha=0.3)
ax.set_ylim(0, 105)
ax.set_xlim(0, max(energy) * 1.18)

fig.text(0.01, 0.01,
         "ESTIMATED: Vivado post-synthesis dynamic power at 100 MHz, out of context, "
         "per MAC from an array of 256.\n"
         "101632 MACs per inference (784-128-10 MLP). Not measured on hardware. "
         "Excludes static power and data movement.",
         fontsize=7.5, color="dimgray", va="bottom")

fig.tight_layout(rect=(0, 0.06, 1, 1))
fig.savefig("docs/figures/pareto_accuracy_vs_energy.png", dpi=150)
print(f"saved docs/figures/pareto_accuracy_vs_energy.png ({len(rows)} configs: "
      f"T={[r['T'] for r in rows]})")
