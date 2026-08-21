# approx-mult

Truncation based approximate multipliers in Verilog, explored across a design space, built up into a 2x2 systolic array with an on-chip weight memory, tested on MNIST, and run on a Zynq 7020.

![Pareto front: MNIST accuracy vs multiplier area](docs/figures/pareto_accuracy_vs_luts.png)

## Overview

This project measures how much arithmetic accuracy a neural network tolerates before classification fails, and what that approximation returns in hardware cost.

An 8x8 approximate multiplier truncates the low bits of both operands. It is swept across operand width and truncation depth, every configuration is synthesised, and the error is measured over all 65536 input pairs. The multiplier is then built up into a multiply-accumulate (MAC), a 2x2 systolic array, and a weight memory feeding the array.

Truncation error is one sided and therefore correctable with a single adder. That correction is measured here, along with the reason it improves classification accuracy less than the error reduction suggests.

This is a self-directed learning project. The scale is quite small, an 8 bit multiplier, a 2x2 array, and a small fully connected network.

## Systolic array

![Systolic array dataflow](docs/figures/Systolic_Array_Drawing.jpg)

Each cell contains an approximate MAC and two registers that forward the operands to its neighbours. Operands propagate through the array rather than being re-fetched for every cell, which is the source of the efficiency.

The drawing above records the timing derivation. Operands enter from the top and left, moved one cycle per row and column, so that corresponding terms arrive at each cell on the cycle it requires them.

Verified against a hand calculation. A = [[1,2],[3,4]] and B = [[5,6],[7,8]] give C = [[19,22],[43,50]], which the simulation reproduces.

## Weight memory

Dual port ROM written in the pattern Vivado infers as Block RAM, with an address generator that reproduces the systolic skew and accounts for the memory's one cycle read latency.

Verified against a hand calculation using real quantised MNIST weights. With mem[1..4] = 2, 5, 2, 248 and A = [[1,2],[3,4]] streamed in, the array produces C = [[6, 501], [14, 1007]]. The value 248 is the weight -8 read as an unsigned byte, since the multiplier is unsigned.

Synthesis infers a RAMB18E1, one block serving both read ports, placing the memory in a dedicated block rather than general fabric. Report in `syn/reports/bram_utilisation_synth.txt`.

## De-bias correction

Truncation always rounds down, so the error is a consistent negative bias, thus correctable.

Mean absolute error at 8 bits with TRUNC_BITS = 2 is 380. Adding 380 to every product cancels most of the bias at the cost of one adder, reducing total absolute error across all 65536 input pairs from 24.9M to 15.0M, approximately 40 percent.

![MNIST accuracy with and without de-bias correction](docs/figures/mnist_corrected_accuracy.png)

The correction has almost no effect on the MNIST accuracy cliff. A constant shifts every output by the same amount, and classification depends on which output is largest rather than on its magnitude, so a uniform shift cannot change the argmax. Accuracy at high truncation is limited by the variance of the per multiply error, which a constant correction does not address.

Bias is correctable, variance is not, and argmax is what decides.

## Design space

```verilog
a_trunc = (a >> TRUNC_BITS) << TRUNC_BITS;
b_trunc = (b >> TRUNC_BITS) << TRUNC_BITS;
product = a_trunc * b_trunc + CORRECTION;
```

Error measured over all 65536 input pairs at 8 bits with CORRECTION = 0, so this is the raw truncation tradeoff. LUT counts are for `mult_approx` alone.

| TRUNC_BITS | LUTs | mean abs error | max error |
|------------|------|----------------|-----------|
| 0 (exact)  | 70   | 0              | 0         |
| 2          | 39   | 380            | 1521      |
| 4          | 14   | 1856           | 7425      |
| 6          | 2    | 7040           | 28161     |

![Error vs truncation](docs/figures/error_vs_truncation.png)

The sweep covers two parameters, operand bit width and truncation depth, with every configuration synthesised.

At equal area, narrowing the operands outperforms truncating a wider multiplier. A 6 bit exact multiplier occupies 38 LUTs with zero error over its range. An 8 bit multiplier at TRUNC_BITS = 2 occupies 39 LUTs with a mean error of 380. The two parameters are not interchangeable.

![Area model: bit width vs truncation](docs/figures/area_model.png)

## On MNIST

| TRUNC_BITS | accuracy |
|------------|----------|
| 0          | 97.7%    |
| 2          | 97.7%    |
| 3          | 97.0%    |
| 4          | 81.4%    |
| 5          | 10.6%    |

![MNIST accuracy vs truncation](docs/figures/mnist_quantized_accuracy.png)

Accuracy holds to TRUNC_BITS = 3 despite a large per multiply error, because classification depends only on the argmax. Beyond that it collapses. TRUNC_BITS = 2 is the knee of the tradeoff.

## Energy

These figures are estimates rather than board measurements. Dynamic power is taken from the Vivado reports in `syn/reports/` and divided by the clock frequency to give energy per operation.

The network is 784-128-10, giving 784 x 128 + 128 x 10 = 101632 multiply accumulates per inference. One MAC unit at one operation per cycle takes 1.016 ms per inference at 100 MHz. Figures are per MAC, divided down from an array of 256 synthesised out of context, both of which are described under Synthesis.

| TRUNC_BITS | LUTs | FFs | accuracy | pJ per MAC | uJ per inference | vs exact |
|------------|------|-----|----------|------------|------------------|----------|
| 0 (exact)  | 64   | 32  | 97.7%    | 11.8       | 1.20             | -        |
| 2          | 42   | 28  | 97.7%    | 8.1        | 0.82             | 31.7% less |
| 4          | 15   | 24  | 81.4%    | 3.5        | 0.36             | 70.0% less |
| 6          | 4    | 20  | 9.7%     | 2.1        | 0.22             | 81.7% less |

![Accuracy vs estimated energy](docs/figures/pareto_accuracy_vs_energy.png)

At TRUNC_BITS = 2 the accuracy cost is 0.06 percentage points and the energy saving is 31.7 percent.

Between TRUNC_BITS = 0 and 6 the MAC falls from 64 LUTs to 4, a factor of 16, while energy falls by a factor of 5.6. The flip-flop column accounts for the difference. The multiplier reduces to 4 LUTs, but the accumulator retains 20 flip-flops, and truncating the operands does not shrink those or the clock network driving them.

Energy per inference is independent of the number of MAC units running in parallel, since power and cycle count scale together. Parallelism reduces latency and energy delay product rather than energy.

## On the FPGA

The multiplier is deployed on a Zynq 7020 with a UART interface so a host PC can drive it. I wrote the RX and TX state machines, covering bit timing at 115200 baud from the 50 MHz clock, mid bit sampling on receive, and a two flip flop synchroniser on the asynchronous receive line. The design accepts two operands over serial, multiplies on the board, and returns the 16 bit result. The returned bytes were checked on hardware against the truncation predictions.

An AXI4-Lite wrapper was added later so the ARM processing system can drive the accelerator instead of serial. The wrapper is in `rtl/axi/` and the C driver in `sw/`. Its verification status is recorded under Limitations.

## Running it

Tested with Icarus Verilog 12.0 and Vivado 2026.1, targeting xc7z020clg484-2.

```
# all three simulations
bash flow/run_sims.sh

# self-checking scoreboard, expect FAIL=0
iverilog -g2012 -o sim_sb tb/tb_mult_approx_scoreboard.v rtl/mult_approx.v && vvp sim_sb

# sweep and figures
python3 flow/sweep.py
python3 flow/plot_pareto.py

# energy metrics and the energy Pareto
python3 flow/energy.py
python3 flow/plot_energy.py
```

All commands run from the repository root, because `weight_mem.v` loads `weights.hex` by a bare relative path. For Vivado, add `weights.hex` to the project as a design source or `$readmemh` will not resolve it.

## Synthesis

Vivado 2026.1 targeting the Zynq 7020, part xc7z020clg484-2. Each module is synthesised standalone, so utilisation figures describe that module alone. The clock constraint is in `constr/mac.xdc`, a 10 ns period.

Every LUT, flip-flop and power figure in this README comes from a report in `syn/reports/`. The MAC sweep is scripted rather than run through the GUI.

```
vivado -mode batch -source syn/scripts/synth_mac.tcl
python3 flow/parse_reports.py
```

The flow makes two measurement decisions that change the results substantially.

Synthesis runs out of context, so Vivado does not insert I/O buffers. On a module this small the pads dominate. One MAC at TRUNC_BITS = 2 synthesised with pads reports 19 mW of dynamic power, 17 mW of which is I/O, against 0.8 mW out of context. Pads also distort the trend, since truncation leaves low operand bits unused and Vivado then removes their input buffers, causing the measurement to track pin count rather than arithmetic. A MAC inside an accelerator has no pads. Report in `syn/reports/mac_T2_withpads_power.rpt`.

The top level is an array of 256 MACs. A single MAC out of context reports 0.001 W, the smallest value `report_power` prints, so every truncation level would read identically. `syn/mac_array.v` instantiates 256 copies and the per-MAC figures are divided back down. Each copy XORs its operands with a distinct constant so synthesis cannot merge them, and every accumulator drives a slice of a wide output so none are removed.

### Timing

Maximum frequency derived from the worst negative slack against the 10 ns constraint.

| TRUNC_BITS | Fmax |
|------------|------|
| 0 (exact)  | 436.5 MHz |
| 2          | 456.4 MHz |
| 4          | 474.2 MHz |
| 6          | 471.5 MHz |

Truncation reduces delay as well as area, because dropping low operand bits shortens the carry chains in the partial product adder. All four configurations meet 100 MHz with a wide margin.

## Layout

- `rtl/` contains the multipliers, MAC, processing element, array, weight memory and address generator. `rtl/axi/` contains the AXI4-Lite slave wrapper
- `tb/` contains the testbenches, including the self-checking scoreboard
- `syn/reports/` contains the Vivado reports, `syn/scripts/` the batch flow that regenerates them
- `constr/` contains the timing and pin constraints
- `fpga/` contains the board top level for the UART deployment
- `sw/` contains the C driver that runs on the ARM side
- `flow/` contains the sweep, evaluation and plotting tooling
- `results/` contains the measured data, except `energy_results.csv` which is derived from `mac_results.csv`
- `docs/figures/` contains the figures
- `weights.hex` stays at the root because `$readmemh` loads it by bare filename

## Limitations

- The array is 2x2. The dataflow and memory interface generalise but the parameterised NxN version is not written.
- Everything is unsigned, so negative weights appear as large positive numbers. Signed arithmetic is the next extension.
- Power and energy are Vivado post synthesis estimates rather than board measurements. Vivado rates the confidence Medium, because switching activity is estimated from default toggle rates rather than a simulation of real data. A SAIF from an MNIST run would replace that estimate with measured activity.
- The energy model assumes one MAC per cycle and ignores data movement and memory stalls.
- The AXI4-Lite wrapper synthesised, the block design built, and the board booted and ran it, but no verified register read was obtained. A JTAG/DAP fault blocked the final step. The UART path is the one verified on hardware.
- The sweep is a script running one configuration at a time rather than an automated exploration framework.
- MNIST here is a small fully connected network rather than a CNN.

## Authorship

The hardware is mine. Every Verilog file in `rtl/` and `fpga/`, the measurement harness in `syn/mac_array.v`, the testbenches in `tb/`, every synthesis run and the hardware deployment, and the design decisions behind them, including the de-bias scheme and the bias versus variance analysis.

The tooling was written with AI assistance and reviewed by me. The Python in `flow/` and the Tcl in `syn/scripts/`.
