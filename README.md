# approx-mult

Truncation based approximate multipliers in Verilog, explored across a design space, built up into a 2x2 systolic array with an on-chip weight memory, tested on MNIST, and run on a Zynq 7020.

![Pareto front: MNIST accuracy vs multiplier area](docs/figures/pareto_accuracy_vs_luts.png)

## Overview

I wanted to know how much arithmetic accuracy a neural network can lose before it stops working, and what you get back in hardware for giving it up.

I started with an 8x8 approximate multiplier that truncates the low bits of both operands, swept it across operand width and truncation depth, synthesised every configuration, and measured the error over all 65536 input pairs. Then I built it up into a MAC, a 2x2 systolic array, and a weight memory feeding the array. Truncation error is one sided, so a single adder cancels most of it, and I measured why that helps less than the error numbers suggest.

This is a self-directed learning project, not coursework. The scale is small on purpose, an 8 bit multiplier, a 2x2 array, and a small fully connected network. The measurements are reproducible from this repo, and where a number is estimated rather than measured, or something was built but not verified, I say so.

## Systolic array

![Systolic array dataflow](docs/figures/Systolic_Array_Drawing.jpg)

Each cell is an approximate MAC plus two registers that pass the operands on to its neighbours. The operands move through the array instead of being fetched again for every cell, and that is where the efficiency comes from.

I used the drawing above to work out the timing. Operands enter from the top and left, staggered one cycle per row and column, so the right terms meet at each cell on the cycle it needs them.

Verified by hand. A = [[1,2],[3,4]] and B = [[5,6],[7,8]] give C = [[19,22],[43,50]], and the simulation gives exactly that.

## Weight memory

Dual port ROM written in the pattern Vivado infers as Block RAM, plus an address generator that reproduces the systolic skew and accounts for the memory's one cycle read latency.

Verified by hand with real quantised MNIST weights. With mem[1..4] = 2, 5, 2, 248 and A = [[1,2],[3,4]] streamed in, the array gives C = [[6, 501], [14, 1007]]. The 248 is the weight -8 read as an unsigned byte, since the multiplier is unsigned.

Synthesis confirms it infers a RAMB18E1, one block serving both read ports, so it uses a dedicated block instead of general fabric. Report in `syn/reports/bram_utilisation_synth.txt`.

## De-bias correction

Truncation always rounds down, so the error is a consistent negative bias rather than noise. That makes it correctable.

Mean absolute error at 8 bits with TRUNC_BITS = 2 is 380, so adding 380 back into the product cancels most of the bias for one adder. Across all 65536 input pairs that takes total absolute error from 24.9M to 15.0M, about 40 percent.

![MNIST accuracy with and without de-bias correction](docs/figures/mnist_corrected_accuracy.png)

It barely moves the accuracy cliff. A constant shifts every output by the same amount, and classification depends on which output is largest, so a uniform shift cannot change the argmax. What limits accuracy at high truncation is the variance of the per multiply error, and a constant does nothing about variance.

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

For the same area, narrowing the operands beats truncating a wider multiplier. A 6 bit exact multiplier is 38 LUTs with zero error over its range. An 8 bit multiplier at TRUNC_BITS = 2 is 39 LUTs with a mean error of 380. Same hardware cost, very different error. The two parameters are not interchangeable.

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

Accuracy holds to TRUNC_BITS = 3 even though the per multiply error is large, because only the argmax matters. After that it collapses. TRUNC_BITS = 2 is the knee.

## Energy

Estimates, not board measurements. I took dynamic power from the Vivado reports in `syn/reports/` and divided by the clock frequency.

The network is 784-128-10, so 784 x 128 + 128 x 10 = 101632 multiply accumulates per inference, and one MAC unit at one per cycle takes 1.016 ms at 100 MHz. Figures are per MAC, divided down from an array of 256 synthesised out of context, both explained under Synthesis.

| TRUNC_BITS | LUTs | FFs | accuracy | pJ per MAC | uJ per inference | vs exact |
|------------|------|-----|----------|------------|------------------|----------|
| 0 (exact)  | 64   | 32  | 97.7%    | 11.8       | 1.20             | -        |
| 2          | 42   | 28  | 97.7%    | 8.1        | 0.82             | 31.7% less |
| 4          | 15   | 24  | 81.4%    | 3.5        | 0.36             | 70.0% less |
| 6          | 4    | 20  | 9.7%     | 2.1        | 0.22             | 81.7% less |

![Accuracy vs estimated energy](docs/figures/pareto_accuracy_vs_energy.png)

At TRUNC_BITS = 2 the accuracy cost is 0.06 percentage points and the energy saving is 31.7 percent.

Going from TRUNC_BITS = 0 to 6 cuts the MAC from 64 LUTs to 4, a factor of 16, but energy only drops by 5.6. The flip-flop column shows why. The multiplier ends up at 4 LUTs, but the accumulator still has 20 flip-flops, and truncating the operands does not shrink those or the clock network driving them.

Energy per inference does not change with how many MAC units run in parallel, since power and cycle count scale together. Parallelism cuts latency and energy delay product, not energy.

## On the FPGA

I deployed the multiplier to a Zynq 7020 with a UART interface so a host PC can drive it. I wrote the RX and TX state machines, including bit timing at 115200 baud from the 50 MHz clock, mid bit sampling on receive, and a two flip flop synchroniser on the asynchronous receive line. It takes two operands over serial, multiplies on the board, and returns the 16 bit result. I checked on hardware that the bytes coming back matched the truncation predictions.

I later added an AXI4-Lite wrapper so the ARM side can drive it instead of serial. The wrapper is in `rtl/axi/` and the C driver in `sw/`. See Limitations for how far I got with it.

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

Everything runs from the repo root, because `weight_mem.v` loads `weights.hex` by a bare relative path. For Vivado, add `weights.hex` to the project as a design source or `$readmemh` will not find it.

## Synthesis

Vivado 2026.1 targeting the Zynq 7020, part xc7z020clg484-2. Each module is synthesised on its own, so the utilisation numbers are for that module only. Clock constraint is in `constr/mac.xdc`, a 10 ns period.

Every LUT, flip-flop and power number in this README comes from a report in `syn/reports/`. The MAC sweep is scripted rather than done by hand in the GUI.

```
vivado -mode batch -source syn/scripts/synth_mac.tcl
python3 flow/parse_reports.py
```

Two things about that flow need explaining.

It runs out of context, so Vivado does not insert I/O buffers. On a module this small the pads dominate. One MAC at TRUNC_BITS = 2 with pads reports 19 mW of dynamic power, 17 mW of which is I/O, against 0.8 mW out of context. Pads also distort the trend, since truncation leaves low operand bits unused and Vivado then deletes their input buffers, so the measurement partly tracks pin count instead of arithmetic. A MAC inside a real accelerator has no pads. Report in `syn/reports/mac_T2_withpads_power.rpt`.

The top level is an array of 256 MACs rather than one, because a single MAC out of context reports 0.001 W, the smallest figure `report_power` prints, so every truncation level would read the same. `syn/mac_array.v` instantiates 256 copies and the per-MAC figures divide back down. Each copy XORs its operands with a different constant so synthesis cannot merge them, and every accumulator drives a slice of a wide output so none get deleted.

### Timing

Maximum frequency from the worst negative slack against the 10 ns constraint.

| TRUNC_BITS | Fmax |
|------------|------|
| 0 (exact)  | 436.5 MHz |
| 2          | 456.4 MHz |
| 4          | 474.2 MHz |
| 6          | 471.5 MHz |

Truncation makes the design faster as well as smaller, because dropping low operand bits shortens the carry chains in the partial product adder. All four meet 100 MHz easily, so timing is not the limit here.

## Layout

- `rtl/` is the design, so the multipliers, MAC, processing element, array, weight memory and address generator. `rtl/axi/` is the AXI4-Lite slave wrapper
- `tb/` is the testbenches, including the self-checking scoreboard
- `syn/reports/` is the Vivado reports, `syn/scripts/` is the batch flow for regenerating them
- `constr/` is the timing and pin constraints
- `fpga/` is the board top level for the UART deployment
- `sw/` is the C driver that runs on the ARM side
- `flow/` is the sweep, evaluation and plotting tooling
- `results/` is the measured data, except `energy_results.csv` which is derived from `mac_results.csv`
- `docs/figures/` is the figures
- `weights.hex` stays at the root because `$readmemh` loads it by bare filename

## Limitations

- The array is 2x2. The dataflow and memory interface generalise but the parameterised NxN version is not written.
- Everything is unsigned, so negative weights come through as large positive numbers. Signed arithmetic is the next extension.
- Power and energy are Vivado post synthesis estimates, not board measurements. Vivado rates the confidence Medium, because it estimates switching activity from default toggle rates rather than a simulation of real data. A SAIF from an MNIST run would replace that guess with measured activity.
- The energy model assumes one MAC per cycle and ignores data movement and memory stalls.
- The AXI4-Lite wrapper synthesised, the block design built and the board booted and ran it, but I never got a verified register read back out. A JTAG/DAP fault blocked the last step. The UART path is the one verified on hardware.
- The sweep is a script running one configuration at a time, not a real automated exploration framework.
- MNIST here is a small fully connected network, not a CNN.

## Authorship

I used an AI assistant on parts of this project. You cannot tell which parts from the files, so here it is.

**Written by me**

- Every Verilog file in `rtl/` and `fpga/`, so the multipliers, MAC, de-bias correction, UART receiver and transmitter, processing element and array, weight memory, address generator and AXI4-Lite wrapper
- `syn/mac_array.v`, the harness used for the power measurements
- All the testbenches in `tb/`
- Every synthesis run and the hardware deployment
- The design decisions and the analysis, including the de-bias scheme, the bias versus variance conclusion, and the systolic timing

**Written with AI assistance, then read and understood**

- Every Python file in `flow/`
- The Tcl in `syn/scripts/`
- Much of the prose in this README

The hardware is mine and the tooling that measures it is not. I can explain any line in either list, but I did not write the second one from scratch and I am not going to claim I did.
