#!/usr/bin/env python3
import subprocess
import re
import csv

MODULE_FILE    = "mult_approx.v"
TESTBENCH_FILE = "tb_mult_approx.v"
COMPILED_SIM   = "sim_approx"
CSV_OUTPUT     = "grid_results.csv"

WIDTHS = [4, 6, 8]

results = []

for W in WIDTHS:
    for T in range(W):          # 0 .. W-1, so T is always < W
        compile_cmd = [
            "iverilog",
            "-g2012",
            f"-Ptb_mult_approx.WIDTH={W}",
            f"-Ptb_mult_approx.TRUNC_BITS={T}",
            "-o", COMPILED_SIM,
            TESTBENCH_FILE,
            MODULE_FILE,
        ]
        subprocess.run(compile_cmd, check=True)

        run_result = subprocess.run(
            ["vvp", COMPILED_SIM],
            capture_output=True,
            text=True,
            check=True,
        )
        output = run_result.stdout

        match = re.search(r"total abs error = (\d+), max error = (\d+)", output)

        if match is None:
            print(f"W={W} T={T}: could not parse output:\n{output}")
            continue

        total_abs_error = int(match.group(1))
        max_error       = int(match.group(2))
        num_cases       = (1 << W) ** 2          # (2^W)^2, per width
        mean_abs_error  = total_abs_error / num_cases

        results.append({
            "W": W,
            "T": T,
            "total_abs_error": total_abs_error,
            "mean_abs_error":  mean_abs_error,
            "max_error":       max_error,
        })

        print(f"  W={W} T={T} done  (mean_err={mean_abs_error:.3f}, max_err={max_error})")

print()

header = (
    f"{'W':>3} | "
    f"{'T':>3} | "
    f"{'total_abs_error':>16} | "
    f"{'mean_abs_error':>14} | "
    f"{'max_error':>10}"
)
print(header)
print("-" * len(header))

for r in results:
    print(
        f"{r['W']:>3} | "
        f"{r['T']:>3} | "
        f"{r['total_abs_error']:>16} | "
        f"{r['mean_abs_error']:>14.3f} | "
        f"{r['max_error']:>10}"
    )

with open(CSV_OUTPUT, "w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=["W", "T", "total_abs_error", "mean_abs_error", "max_error"]
    )
    writer.writeheader()
    writer.writerows(results)

print(f"\nResults saved to {CSV_OUTPUT}")