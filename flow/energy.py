#!/usr/bin/env python3
"""Energy metrics for the approximate MAC.

ESTIMATED, not measured on hardware. Dynamic power comes from Vivado
post-synthesis estimates in mac_results.csv. Everything here is derived from
those numbers.

The clock is assumed to be 100 MHz, the constraint in mac.xdc. That assumption
is not recorded anywhere in the power data itself, so if the power runs used a
different frequency every pJ/MAC figure is wrong by that ratio.

Model:
  energy per MAC operation = dynamic power / clock frequency
  MACs per inference       = 784*128 + 128*10 = 101632 (the 784-128-10 MLP)
  latency per inference    = MACs / clock frequency, one MAC unit, one MAC/cycle
  energy per inference     = energy per MAC * MACs per inference
  EDP                      = energy per inference * latency per inference

Assumptions, stated because they matter:
  - One MAC unit processing one multiply-accumulate per cycle. No data
    movement, memory stall, or control overhead is counted.
  - Biases and the ReLU are ignored. They are not multiplies.
  - Static (leakage) power is excluded. This is a dynamic-energy comparison
    between configurations, not a total power budget.
"""
import csv

# Fallback only. Once flow/parse_reports.py has been run, mac_results.csv
# carries a clk_mhz column read out of the Vivado timing report and that is
# used instead, which removes the assumption entirely.
CLK_HZ_ASSUMED = 100e6  # from constr/mac.xdc: create_clock -period 10.000
HIDDEN = 128
INPUTS = 784
OUTPUTS = 10
MACS_PER_INFERENCE = INPUTS * HIDDEN + HIDDEN * OUTPUTS

MAC_CSV = "results/mac_results.csv"
ACC_CSV = "results/mnist_quantized_results.csv"
OUT_CSV = "results/energy_results.csv"


def load_mac_results(path):
    rows = {}
    with open(path) as f:
        for row in csv.DictReader(f):
            clk_mhz = row.get("clk_mhz")
            rows[int(row["trunc_bits"])] = {
                "luts": int(row["luts"]),
                "ffs": int(row["ffs"]),
                "power_w": float(row["dynamic_power_W"]),
                "clk_hz": float(clk_mhz) * 1e6 if clk_mhz else None,
            }
    return rows


def load_accuracy(path):
    acc = {}
    with open(path) as f:
        for row in csv.DictReader(f):
            acc[int(row["trunc_bits"])] = float(row["accuracy"]) * 100
    return acc


def main():
    mac = load_mac_results(MAC_CSV)
    acc = load_accuracy(ACC_CSV)

    assumed_clock = False
    results = []
    for t in sorted(set(mac) & set(acc)):
        clk_hz = mac[t]["clk_hz"]
        if clk_hz is None:
            clk_hz = CLK_HZ_ASSUMED
            assumed_clock = True

        power_w = mac[t]["power_w"]
        latency_s = MACS_PER_INFERENCE / clk_hz
        energy_per_mac_j = power_w / clk_hz
        energy_per_inf_j = energy_per_mac_j * MACS_PER_INFERENCE
        edp = energy_per_inf_j * latency_s

        results.append({
            "trunc_bits": t,
            "luts": mac[t]["luts"],
            "accuracy_pct": round(acc[t], 2),
            "dynamic_power_W": power_w,
            "clk_mhz": round(clk_hz / 1e6, 1),
            "energy_per_mac_pJ": round(energy_per_mac_j * 1e12, 1),
            "latency_per_inference_ms": round(latency_s * 1e3, 3),
            "energy_per_inference_uJ": round(energy_per_inf_j * 1e6, 2),
            "edp_uJ_ms": round(edp * 1e6 * 1e3, 3),
        })

    baseline = next((r for r in results if r["trunc_bits"] == 0), None)

    header = (
        f"{'T':>2} | {'LUTs':>5} | {'acc %':>6} | {'pJ/MAC':>7} | "
        f"{'uJ/inf':>7} | {'EDP uJ.ms':>10} | {'vs exact':>9}"
    )
    print("ESTIMATED energy metrics from Vivado post-synthesis power")
    print(f"{MACS_PER_INFERENCE} MACs per inference, "
          f"{results[0]['latency_per_inference_ms']:.3f} ms per inference "
          f"on one MAC unit at {results[0]['clk_mhz']} MHz")
    if assumed_clock:
        print("Clock frequency ASSUMED, not read from a report. Run "
              "syn/scripts/synth_mac.tcl then flow/parse_reports.py to fix.")
    print()
    print(header)
    print("-" * len(header))
    for r in results:
        if baseline:
            saving = 100 * (1 - r["energy_per_inference_uJ"]
                            / baseline["energy_per_inference_uJ"])
            saving_str = f"{saving:>8.1f}%"
        else:
            saving_str = "        -"
        print(
            f"{r['trunc_bits']:>2} | {r['luts']:>5} | {r['accuracy_pct']:>6.2f} | "
            f"{r['energy_per_mac_pJ']:>7.1f} | {r['energy_per_inference_uJ']:>7.2f} | "
            f"{r['edp_uJ_ms']:>10.3f} | {saving_str}"
        )

    with open(OUT_CSV, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(results[0].keys()))
        writer.writeheader()
        writer.writerows(results)

    print(f"\nsaved {OUT_CSV} ({len(results)} configs)")


if __name__ == "__main__":
    main()
