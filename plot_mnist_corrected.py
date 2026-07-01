#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt

data = pd.read_csv("mnist_corrected_results.csv")

plt.figure(figsize=(7, 4.5))
plt.plot(data["trunc_bits"], data["accuracy_plain"] * 100,
         marker="o", linewidth=2, label="approximate (no correction)")
plt.plot(data["trunc_bits"], data["accuracy_corrected"] * 100,
         marker="s", linewidth=2, label="approximate + de-bias correction")

plt.xlabel("TRUNC_BITS (T)")
plt.ylabel("MNIST accuracy (%)")
plt.title("Effect of de-bias correction on approximate inference")
plt.xticks(data["trunc_bits"])
plt.ylim(0, 100)
plt.grid(True, alpha=0.3)
plt.legend()
plt.tight_layout()
plt.savefig("mnist_corrected_accuracy.png", dpi=150)
print("saved mnist_corrected_accuracy.png")