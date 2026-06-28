import pandas as pd
import matplotlib.pyplot as plt

data = pd.read_csv("sweep_results.csv")

plt.plot(data["T"], data["max_error"], marker="o", label="max error")
plt.plot(data["T"], data["mean_abs_error"], marker="o", label="mean absolute error")

plt.xlabel("TRUNC_BITS (T)")
plt.ylabel("error")
plt.title("approximate multiplier: error vs truncation")
plt.legend()
plt.grid(True)
plt.savefig("error_vs_truncation.png", dpi=150)