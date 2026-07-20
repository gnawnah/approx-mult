#!/usr/bin/env python3
import csv
import matplotlib.pyplot as plt

# MNIST accuracy per truncation level
acc_by_T = {}
with open("mnist_quantized_results.csv") as f:
    for row in csv.DictReader(f):
        acc_by_T[int(row["trunc_bits"])] = float(row["accuracy"]) * 100

# MAC LUT cost per truncation level (from Vivado synthesis)
luts_by_T = {}
with open("mac_results.csv") as f:
    for row in csv.DictReader(f):
        luts_by_T[int(row["trunc_bits"])] = int(row["luts"])

# keep only configs present in both
T        = sorted(set(acc_by_T) & set(luts_by_T))
accuracy = [acc_by_T[t] for t in T]
luts     = [luts_by_T[t] for t in T]

plt.figure(figsize=(7, 5))
plt.plot(luts, accuracy, marker="o", linewidth=2, color="steelblue")

for t, l, a in zip(T, luts, accuracy):
    plt.annotate(f"T={t}", (l, a),
                 textcoords="offset points", xytext=(8, 6), fontsize=10)

plt.xlabel("MAC hardware cost (LUTs)")
plt.ylabel("MNIST accuracy (%)")
plt.title("Accuracy vs hardware cost across truncation")
plt.grid(True, alpha=0.3)
plt.ylim(0, 100)
plt.tight_layout()
plt.savefig("pareto_accuracy_vs_luts.png", dpi=150)
print(f"saved pareto_accuracy_vs_luts.png ({len(T)} configs: T={T})")