# Approximate Multiplier

A self-directed project to learn digital design. An 8×8 multiplier that truncates its operands to trade accuracy for hardware, synthesised on a Zynq-7020 and tested against a real neural network — a small design-space exploration of approximate arithmetic for energy-efficient inference.

## What it does

Zeroing the low bits of both operands before multiplying makes the hardware smaller but the result slightly wrong:

```verilog
assign a_trunc = (a >> TRUNC_BITS) << TRUNC_BITS;
assign product = a_trunc * b_trunc;
```

Thinking of `a × b` as the area of a rectangle, truncation drops thin strips off the edges. Truncating one operand drops one strip; truncating both drops two strips plus a corner, which is why the worst-case error roughly doubles:

<img width="2720" height="1680" alt="image" src="https://github.com/user-attachments/assets/e1ceca08-1711-44a9-a013-e5ef46c4a834" />

I swept `TRUNC_BITS` from 0 to 8 and measured the error, synthesised it at multiple bit-widths, dropped it into a MAC unit, and eventually ran a full MNIST classifier with it to see when the approximation actually starts to hurt.

<img width="960" height="720" alt="error_vs_truncation" src="https://github.com/user-attachments/assets/01e8088e-4a4a-4cd4-87d4-540d65290c46" />

## Results

### Multiplier area (8-bit, Zynq-7020, post-synthesis)

| TRUNC_BITS | LUTs | LUT saving | mean abs error |
|------------|------|------------|----------------|
| 0 (exact)  | 70   | —          | 0              |
| 2          | 39   | 44%        | 380            |
| 4          | 14   | 80%        | 1856           |
| 6          | 2    | 97%        | 7040           |

Truncating 2 bits removes 44% of the logic for under 1% average error — the approximation is nearly free in this region.

### MAC unit

| MAC        | LUTs | FFs | Fmax (post-synth) |
|------------|------|-----|-------------------|
| exact      | 86   | 32  | ~417 MHz          |
| approx T=2 | 51   | 28  | ~435 MHz          |

The approximate MAC is both smaller and slightly faster. The FF count also dropped (32 → 28): with the low product bits always zero, the synthesiser pruned the dead accumulator bits — the approximation propagated savings downstream into the register.

### Power

MAC dynamic power across truncation:

| TRUNC_BITS | dynamic power |
|------------|---------------|
| 0          | 0.032 W       |
| 2          | 0.019 W       |
| 4          | 0.015 W       |
| 6          | 0.012 W       |

Most of the saving comes in the first couple of bits — past T=2 the gains flatten off. The floor is I/O-dominated; in an actual accelerator where operands come from on-chip memory it would be lower.

### Bit-width as a second axis

Running the same synthesis at different bit-widths:

| config        | LUTs | mean error |
|---------------|------|------------|
| 8-bit exact   | 70   | 0          |
| 8-bit, T=2    | 39   | 380        |
| 6-bit exact   | 38   | 0          |
| 4-bit exact   | 16   | 0          |

A 6-bit exact multiplier and an 8-bit truncated-by-2 come out at almost the same LUT count — but the 6-bit version has zero error. If you're after a given area budget, narrowing the operands is a better trade than truncating a wider multiplier.

### MNIST accuracy

To see whether any of this actually matters for inference, I ran a 784→128→10 MLP on MNIST using the approximate multiplier for every multiply:

| TRUNC_BITS | accuracy |
|------------|----------|
| 0 (exact)  | 97.73%   |
| 2          | 97.67%   |
| 3          | 97.04%   |
| 4          | 81.4%    |
| 5          | 10.6%    |

The network is surprisingly tolerant — at T=3 the mean multiply error is ~880, but accuracy barely moves, because classification only cares about which output is largest. The drop-off at T=4 is sharp. T=3 sits between the T=2 and T=4 synthesis configs — roughly half the LUTs of the exact multiplier and ~40% less dynamic power — at under 1 percentage point accuracy loss (97.73% → 97.04%).

Note: the RTL multiplier is unsigned. In the MNIST test, signed weights are handled with sign-magnitude truncation in software. A proper signed approximate multiplier is on the to-do list.

## Files

- `mult_exact.v` / `mult_approx.v` — exact and approximate multipliers, WIDTH and TRUNC_BITS parameterised
- `tb_mult_exact.v` / `tb_mult_approx.v` / `tb_mac.v` — testbenches
- `mac.v` — multiply-accumulate unit, `mac.xdc` — constraints file
- `sweep.py` — sweeps TRUNC_BITS 0–8, runs iverilog + vvp, writes `sweep_results.csv`
- `plot.py` — error vs truncation plot, `plot_mnist_quantized.py` — MNIST accuracy plot
- `train_mnist_weights.py` — trains the MLP and saves weights to `weights/`
- `mnist_forward.py` — exact MLP inference (baseline)
- `mnist_quantized.py` — re-runs inference with approximate multiplier, writes `mnist_quantized_results.csv`
- `grid_results.csv`, `grid_cost.csv` — bit-width sweep results
- `mult_approx_utilisation_synth.txt`, `mult_exact_utilisation_synth.txt` — Vivado reports

## Run it

```bash
# error sweep
python3 sweep.py

# plot (pandas + matplotlib are in the venv, not system Python)
venv/bin/python3 plot.py

# MNIST sweep (train once, then run quantized inference across truncation levels)
venv/bin/python3 train_mnist_weights.py
venv/bin/python3 mnist_quantized.py
venv/bin/python3 plot_mnist_quantized.py

# simulate a testbench directly
iverilog -g2012 -o sim tb_mult_approx.v mult_approx.v && vvp sim
```

## Next

- Place and route (proper post-implementation timing, not just synthesis estimates)
- Signed approximate multiplier in RTL
- A second approximation method to compare against (e.g. Mitchell logarithmic multiplier)
- Systolic array of approximate MACs
- Get the best config running on the Zynq board

## Notes

This is a learning project. I wrote the Verilog (multipliers, testbenches, MAC) myself; I used an AI assistant as a tutor for concepts I was new to and to help write the Python tooling, which I then read through to understand. All design decisions and results are my own.
