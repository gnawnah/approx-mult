# Approximate Multiplier

A self-directed project to learn digital design. An 8×8 multiplier that truncates its operands to trade accuracy for hardware, synthesised on a Zynq-7020 and tested against a real neural network. A small design-space exploration of approximate arithmetic for energy-efficient inference.

The whole project in one figure, showing how far you can shrink the multiplier before a real network's accuracy falls off a cliff:

![accuracy vs hardware cost](pareto_accuracy_vs_luts.png)

Truncating up to about T=2 cuts the hardware nearly in half with almost no accuracy loss. Past that, accuracy collapses.

## What it does

Zeroing the low bits of both operands before multiplying makes the hardware smaller but the result slightly wrong:

```verilog
assign a_trunc = (a >> TRUNC_BITS) << TRUNC_BITS;
assign product = a_trunc * b_trunc;
```

Thinking of `a × b` as the area of a rectangle, truncation drops thin strips off the edges. Truncating one operand drops one strip; truncating both drops two strips plus a corner, which is why the worst-case error roughly doubles:

<img width="2720" height="1680" alt="area model" src="https://github.com/user-attachments/assets/e1ceca08-1711-44a9-a013-e5ef46c4a834" />

I swept `TRUNC_BITS` from 0 to 8 and measured the error, synthesised it at multiple bit-widths, dropped it into a MAC unit, and eventually ran a full MNIST classifier with it to see when the approximation actually starts to hurt.

<img width="960" height="720" alt="error vs truncation" src="https://github.com/user-attachments/assets/01e8088e-4a4a-4cd4-87d4-540d65290c46" />

## Results

### Multiplier area (8-bit, Zynq-7020, post-synthesis)

| TRUNC_BITS | LUTs | LUT saving | mean abs error |
|------------|------|------------|----------------|
| 0 (exact)  | 70   | —          | 0              |
| 2          | 39   | 44%        | 380            |
| 4          | 14   | 80%        | 1856           |
| 6          | 2    | 97%        | 7040           |

Truncating 2 bits removes 44% of the logic for under 1% average error, so the approximation is nearly free in this region.

### MAC unit

| MAC        | LUTs | FFs | Fmax (post-synth) |
|------------|------|-----|-------------------|
| exact      | 86   | 32  | ~417 MHz          |
| approx T=2 | 51   | 28  | ~435 MHz          |

The approximate MAC is both smaller and slightly faster. The FF count also dropped (32 to 28): with the low product bits always zero, the synthesiser pruned the dead accumulator bits, so the approximation propagated savings downstream into the register.

### Power

MAC dynamic power across truncation:

| TRUNC_BITS | dynamic power |
|------------|---------------|
| 0          | 0.032 W       |
| 2          | 0.019 W       |
| 4          | 0.015 W       |
| 6          | 0.012 W       |

Most of the saving comes in the first couple of bits, and past T=2 the gains flatten off. The floor is I/O-dominated; in an actual accelerator where operands come from on-chip memory it would be lower.

### Bit-width as a second axis

Running the same synthesis at different bit-widths:

| config        | LUTs | mean error |
|---------------|------|------------|
| 8-bit exact   | 70   | 0          |
| 8-bit, T=2    | 39   | 380        |
| 6-bit exact   | 38   | 0          |
| 4-bit exact   | 16   | 0          |

A 6-bit exact multiplier and an 8-bit truncated-by-2 come out at almost the same LUT count, but the 6-bit version has zero error. If you're after a given area budget, narrowing the operands is a better trade than truncating a wider multiplier.

### MNIST accuracy

To see whether any of this actually matters for inference, I ran a 784→128→10 MLP on MNIST using the approximate multiplier for every multiply:

![MNIST accuracy vs truncation](mnist_quantized_accuracy.png)

| TRUNC_BITS | accuracy |
|------------|----------|
| 0 (exact)  | 97.73%   |
| 2          | 97.67%   |
| 3          | 97.04%   |
| 4          | 81.4%    |
| 5          | 10.6%    |

The network is surprisingly tolerant. At T=3 the mean multiply error is around 880, but accuracy barely moves, because classification only cares about which output is largest (the argmax), not the exact values. The drop-off at T=4 is sharp. T=3 sits between the T=2 and T=4 synthesis configs, so roughly half the LUTs of the exact multiplier and about 40% less dynamic power, at under 1 percentage point accuracy loss (97.73% to 97.04%).

Note: the RTL multiplier is unsigned. In the MNIST test, activations use truncation identical to the hardware, and signed weights use sign-magnitude truncation. A signed approximate multiplier in RTL is future work.

### De-bias correction

The truncation error is one-directional, since it only ever rounds down, so it forms a predictable bias rather than random noise, which means it can be corrected. I add the mean multiply error back as a constant, which is nearly free in hardware (one adder). On a single multiply this cut total absolute error by about 40%. In a MAC, where the bias accumulates over a dot product, a matched correction reduced the accumulated error from 3021 to 1, because once the bias is removed the remaining errors are roughly symmetric and cancel when summed.

On the full network the effect is smaller and localised:

![de-bias correction effect](mnist_corrected_accuracy.png)

| TRUNC_BITS | accuracy | + correction |
|------------|----------|--------------|
| 2          | 97.67%   | 97.71%       |
| 3          | 97.04%   | 97.05%       |
| 4          | 81.40%   | 82.24%       |
| 5          | 10.64%   | 10.64%       |

Correction helps most right at the accuracy cliff (T=4, +0.84%), where the systematic bias was tipping some argmax decisions the wrong way. It does not move the cliff itself. Past T=4 the collapse is driven by error variance, not bias, and a constant correction only removes bias. Since classification depends only on which output is largest, the network is already insensitive to the roughly-uniform part of the error, so de-biasing only helps at the margin, where decisions are close.

## Files

- `mult_exact.v` / `mult_approx.v`: exact and approximate multipliers, parameterised by WIDTH, TRUNC_BITS, and the de-bias CORRECTION term
- `tb_mult_exact.v` / `tb_mult_approx.v` / `tb_mac.v`: testbenches
- `mac.v`: multiply-accumulate unit. `mac.xdc`: clock constraints for timing/power
- `sweep.py`: sweeps TRUNC_BITS (and bit-width), runs iverilog + vvp, writes the error CSVs
- `plot.py` / `plot_pareto.py` / `plot_mnist_quantized.py` / `plot_mnist_corrected.py`: plots
- `train_mnist_weights.py`: trains the MLP, saves weights to `weights/`
- `mnist_forward.py`: exact MLP inference (float baseline)
- `mnist_quantized.py`: int8 inference with the approximate multiplier and optional de-bias correction, writes the accuracy CSVs
- `grid_results.csv` / `grid_cost.csv`: bit-width sweep (error and LUTs)
- `mac_results.csv` / `power_results.csv`: MAC synthesis and power data
- `mnist_quantized_results.csv` / `mnist_corrected_results.csv`: inference accuracy
- `mult_approx_utilisation_synth.txt` / `mult_exact_utilisation_synth.txt`: Vivado reports

## Run it

```bash
# error sweep + plots (matplotlib/pandas live in the venv, not system Python)
python3 sweep.py
venv/bin/python3 plot.py
venv/bin/python3 plot_pareto.py

# MNIST: train once, then run inference across truncation levels (plain + corrected)
venv/bin/python3 train_mnist_weights.py
venv/bin/python3 mnist_quantized.py
venv/bin/python3 plot_mnist_quantized.py
venv/bin/python3 plot_mnist_corrected.py

# simulate a testbench directly
iverilog -g2012 -o sim tb_mult_approx.v mult_approx.v && vvp sim
```

## Next

- Place and route for true post-implementation timing (these are synthesis estimates)
- A signed approximate multiplier in RTL, to match the signed weights in the network
- A second approximation method to compare against (for example a Mitchell logarithmic multiplier)
- A systolic array of approximate MACs
- Deploy the best config on the Zynq board

## Notes on tools and authorship

This is a learning project, and I've tried to be precise about what I designed versus what I used tools to help with.

Designed and written by me:

- All the Verilog: the exact and approximate multipliers, the parameterisation (WIDTH, TRUNC_BITS, the de-bias CORRECTION term), the MAC unit, and the testbenches.
- The synthesis work in Vivado: running it and reading and interpreting the utilisation, timing, and power reports.
- The ideas and findings: the error/strip decomposition, the precision-vs-truncation conclusion, the flip-flop pruning observation, the accumulating-bias finding, the de-bias correction, and the bias-vs-variance analysis of the MNIST result.

AI-assisted, where I specified what I wanted and then read through and understood the output:

- The Python tooling: the sweep and plotting scripts, and the MNIST pipeline (`train_mnist_weights.py`, `mnist_forward.py`, `mnist_quantized.py`). I don't write Python fluently, so I described what each script needed to do, used an AI assistant to write it, then went through the result to understand it. The approximate-multiply and de-bias logic inside these scripts mirrors my Verilog. The standard ML boilerplate (quantisation, training, data loading) is not something I wrote from scratch.

All design decisions, results, and interpretations are my own.