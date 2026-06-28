#!/usr/bin/env python3
import subprocess # this allows python to launch external programs
import re # pull the two numbers out of the testbench's output line
import csv # writes csv file

NUM_CASES = 256 * 256 # number of input pairs

# make filenames constant for reusability
MODULE_FILE    = "mult_approx.v" 
TESTBENCH_FILE = "tb_mult_approx.v"
COMPILED_SIM   = "sim_approx"
CSV_OUTPUT     = "sweep_results.csv"

results = [] # empty list that will grow after every T

for T in range(9): # gives 0 to 8
# building a list, allows python to run program directly without involving shell
    compile_cmd = [
        "iverilog",
        "-g2012",
        f"-Ptb_mult_approx.TRUNC_BITS={T}", # f string, T gets replaced by the current loop value, P overrides the parameter
        "-o", COMPILED_SIM,
        TESTBENCH_FILE,
        MODULE_FILE,
    ]
    subprocess.run(compile_cmd, check=True) # launch iverilog, wait for it to finish

    run_result = subprocess.run( # this runs the simulation
        ["vvp", COMPILED_SIM],
        capture_output=True,
        text=True,
        check=True,
    )
    output = run_result.stdout # grab the captured text

    # captures
    match = re.search(r"total abs error = (\d+), max error = (\d+)", output)

    if match is None:
        print(f"T={T}: could not parse output:\n{output}")
        continue

    total_abs_error = int(match.group(1))
    max_error       = int(match.group(2))
    mean_abs_error  = total_abs_error / NUM_CASES

    results.append({
        "T":               T,
        "total_abs_error": total_abs_error,
        "mean_abs_error":  mean_abs_error,
        "max_error":       max_error,
    })

    print(f"  T={T} done  (total_err={total_abs_error}, max_err={max_error})")

print()

header = (
    f"{'T':>4} | "
    f"{'total_abs_error':>18} | "
    f"{'mean_abs_error':>16} | "
    f"{'max_error':>12}"
)
print(header)
print("-" * len(header))

for r in results:
    print(
        f"{r['T']:>4} | " # right align
        f"{r['total_abs_error']:>18} | "
        f"{r['mean_abs_error']:>16.2f} | "
        f"{r['max_error']:>12}"
    )

with open(CSV_OUTPUT, "w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=["T", "total_abs_error", "mean_abs_error", "max_error"]
    )
    writer.writeheader()
    writer.writerows(results)

print(f"\nResults saved to {CSV_OUTPUT}")