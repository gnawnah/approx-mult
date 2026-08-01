#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt


data = pd.read_csv("results/mnist_quantized_results.csv")
baseline = data.loc[data["trunc_bits"] == 0, "accuracy"].iloc[0]

plt.figure(figsize=(7, 4.5))
plt.plot(
    data["trunc_bits"],
    data["accuracy"] * 100,
    marker="o",
    linewidth=2,
    label="approximate integer inference",
)
plt.axhline(
    baseline * 100,
    color="gray",
    linestyle="--",
    linewidth=1,
    label=f"exact integer baseline ({baseline * 100:.2f}%)",
)
plt.xlabel("TRUNC_BITS (T)")
plt.ylabel("MNIST accuracy (%)")
plt.title("Quantized MNIST accuracy vs multiplier truncation")
plt.xticks(data["trunc_bits"])
plt.ylim(0, 100)
plt.grid(True, alpha=0.3)
plt.legend()
plt.tight_layout()
plt.savefig("docs/figures/mnist_quantized_accuracy.png", dpi=150)
