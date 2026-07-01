#!/usr/bin/env python3
import matplotlib.pyplot as plt

# configs where we have BOTH accuracy and hardware cost
T        = [0, 2, 4, 6]
accuracy = [97.73, 97.67, 81.4, 9.7]   # MNIST %, from mnist_quantized_results
luts     = [86, 51, 21, 4]             # MAC LUTs, from synthesis

plt.figure(figsize=(7, 5))
plt.plot(luts, accuracy, marker="o", linewidth=2, color="steelblue")

# label each point with its T value
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
print("saved pareto_accuracy_vs_luts.png")