#!/usr/bin/env python3
"""Build results/mac_results.csv from the Vivado reports in syn/reports/.

Run from the repo root after syn/scripts/synth_mac.tcl.
"""
import csv
import re
from pathlib import Path

RPT_DIR = Path("syn/reports")
OUT_CSV = Path("results/mac_results.csv")
TRUNC_SET = [0, 2, 4, 6]


def read_array_n():
    """MACs per report. Read rather than hardcoded so the divisor cannot drift."""
    path = RPT_DIR / "array_n.txt"
    if not path.exists():
        raise SystemExit(
            f"missing {path}. Run syn/scripts/synth_mac.tcl first, which writes it."
        )
    return int(path.read_text().strip())


def read(path):
    if not path.exists():
        raise SystemExit(
            f"missing {path}. Run: vivado -mode batch -source syn/scripts/synth_mac.tcl"
        )
    return path.read_text(errors="replace")


def parse_utilisation(text):
    """LUT and flip-flop counts from report_utilization."""
    luts = re.search(r"\|\s*Slice LUTs\*?\s*\|\s*(\d+)", text)
    ffs = re.search(r"\|\s*Register as Flip Flop\s*\|\s*(\d+)", text)
    if luts is None:
        raise SystemExit("could not find Slice LUTs row in utilisation report")
    return int(luts.group(1)), int(ffs.group(1)) if ffs else 0


def parse_power(text):
    """Dynamic power in watts, plus Vivado's confidence level.

    Confidence is Low for a vectorless estimate and rises when a SAIF from a
    real simulation is read in.
    """
    dyn = re.search(r"\|\s*Dynamic \(W\)\s*\|\s*([\d.]+)", text)
    if dyn is None:
        raise SystemExit("could not find Dynamic (W) row in power report")
    conf = re.search(r"\|\s*Confidence [Ll]evel\s*\|\s*(\w+)", text)
    return float(dyn.group(1)), conf.group(1) if conf else "unknown"


def parse_timing(text):
    """Clock frequency from the clock summary, WNS from the timing summary."""
    clk = re.search(r"^\s*\S+\s+\{[^}]*\}\s+([\d.]+)\s+([\d.]+)\s*$",
                    text, re.MULTILINE)
    period_ns = float(clk.group(1)) if clk else None
    clk_mhz = float(clk.group(2)) if clk else None

    # The WNS value sits on the first data row under the dashed separator that
    # follows the WNS(ns) column header.
    wns = re.search(r"WNS\(ns\)[^\n]*\n\s*-[-\s]*\n\s*(-?[\d.]+)", text)
    wns_ns = float(wns.group(1)) if wns else None

    fmax_mhz = None
    if period_ns and wns_ns is not None and period_ns - wns_ns > 0:
        fmax_mhz = round(1000.0 / (period_ns - wns_ns), 1)

    return clk_mhz, wns_ns, fmax_mhz


def main():
    n = read_array_n()
    rows = []
    for t in TRUNC_SET:
        luts, ffs = parse_utilisation(read(RPT_DIR / f"mac_T{t}_utilisation.rpt"))
        power_w, confidence = parse_power(read(RPT_DIR / f"mac_T{t}_power.rpt"))
        clk_mhz, wns_ns, fmax_mhz = parse_timing(read(RPT_DIR / f"mac_T{t}_timing.rpt"))

        # Per-instance figures divide by n. Timing does not: the critical path
        # is one MAC deep either way.
        rows.append({
            "config": "mac",
            "trunc_bits": t,
            "array_n": n,
            "luts": round(luts / n),
            "ffs": round(ffs / n),
            "dynamic_power_W": round(power_w / n, 9),
            "clk_mhz": clk_mhz,
            "wns_ns": wns_ns,
            "fmax_mhz": fmax_mhz,
            "power_confidence": confidence,
        })

    OUT_CSV.parent.mkdir(exist_ok=True)
    with open(OUT_CSV, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    header = (f"{'T':>2} | {'LUTs':>5} | {'FFs':>4} | {'mW/MAC':>8} | "
              f"{'MHz':>6} | {'Fmax':>7} | conf")
    print(f"per-MAC figures, divided from an array of {n}")
    print(header)
    print("-" * len(header))
    for r in rows:
        print(f"{r['trunc_bits']:>2} | {r['luts']:>5} | {r['ffs']:>4} | "
              f"{r['dynamic_power_W'] * 1e3:>8.4f} | {str(r['clk_mhz']):>6} | "
              f"{str(r['fmax_mhz']):>7} | {r['power_confidence']}")

    confidences = {r["power_confidence"] for r in rows}
    if confidences & {"Low", "unknown"}:
        print("\nPower confidence is Low: this is a vectorless estimate with default")
        print("toggle rates. Read a SAIF from a real simulation to replace it.")

    print(f"\nwrote {OUT_CSV} ({len(rows)} configs)")


if __name__ == "__main__":
    main()
