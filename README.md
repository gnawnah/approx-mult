# approx-mult

Truncation based approximate multipliers in Verilog, explored across a design space, built up into a 2x2 systolic array with an on-chip weight memory, tested on MNIST, and run on a Zynq 7020.

![Pareto front: MNIST accuracy vs multiplier area](pareto_accuracy_vs_luts.png)

## What it is

I wanted to know how much arithmetic accuracy you can throw away before a neural network stops working, and what you get back in hardware for doing it.

So I wrote an 8x8 approximate multiplier that truncates the low bits of both operands, swept it across bit width and truncation, synthesised every configuration, and measured the error exhaustively. Then I built it up: a MAC, a 2x2 systolic array, and a weight memory feeding the array. That last part is the interesting one, because a systolic array doing matrix multiplication is what an AI accelerator actually is.

I also found that truncation error is one sided, which means you can cancel most of it with a single adder, and worked out why that helps less than you would expect.

## Systolic array

![Systolic array dataflow](Systolic_Array_Drawing.jpg)

Each cell is an approximate MAC plus two registers that pass the operands on to its neighbours. That forwarding is the whole point: operands slide through the array instead of being fetched again for every cell, which is where the efficiency comes from.

The drawing is how I worked out the timing. Operands enter from the top and left, staggered one cycle per row and column, so the right terms meet at the right cell on the right cycle.

Verified against a hand calculation. A = [[1,2],[3,4]], B = [[5,6],[7,8]] gives C = [[19,22],[43,50]], and the simulation produces exactly that, with the diagonal completion wavefront you would expect.

## Weight memory

Dual port ROM holding the weights, written in the pattern Vivado infers as Block RAM, plus an address generator that reproduces the systolic skew and accounts for the memory's one cycle read latency.

Checked against a hand calculation using real quantised MNIST weights. With mem[1..4] = 2, 5, 2, 248 loaded and A = [[1,2],[3,4]] streamed in, the array gives C = [[6, 501], [14, 1007]]. The 248 is the weight -8 read as an unsigned byte, since the multiplier is unsigned.

Synthesis confirms it infers a RAMB18E1, one block serving both read ports. Report is in `bram_utilisation_synth.txt`.

## De-bias correction

Truncation always rounds down, so the error is not noise, it is a consistent negative bias. That makes it correctable.

Mean absolute error at 8 bits with TRUNC_BITS = 2 is 380, so adding 380 back into the product cancels most of the bias for one adder. Across all 65536 input pairs that takes total absolute error from 24.9M down to 15.0M, about 40 percent.

![MNIST accuracy with and without de-bias correction](mnist_corrected_accuracy.png)

The thing I actually learned here: it barely moves the accuracy cliff. Adding a constant shifts every output by the same amount, and classification depends on which output is largest, not on the values. So a uniform shift cannot change the argmax. What kills accuracy at high truncation is variance in the per multiply error, and a constant correction does nothing about variance.

Bias is correctable, variance is not, and argmax is what decides.

## Design space

```verilog
a_trunc = (a >> TRUNC_BITS) << TRUNC_BITS;
b_trunc = (b >> TRUNC_BITS) << TRUNC_BITS;
product = a_trunc * b_trunc + CORRECTION;
```

Error measured over all 65536 input pairs at 8 bits, with CORRECTION = 0 so this is the raw truncation tradeoff:

| TRUNC_BITS | LUTs | mean abs error | max error |
|------------|------|----------------|-----------|
| 0 (exact)  | 70   | 0              | 0         |
| 2          | 39   | 380            | 1521      |
| 4          | 14   | 1856           | 7425      |
| 6          | 2    | 7040           | 28161     |

![Error vs truncation](error_vs_truncation.png)

I swept two knobs, operand bit width and truncation, and synthesised every configuration.

One result worth stating: narrowing the operands beats truncating a wider multiplier. A 6 bit exact multiplier is 38 LUTs with zero error over its range. An 8 bit multiplier at TRUNC_BITS = 2 is 39 LUTs with a mean error of 380. Same hardware, very different error. The two knobs are not interchangeable.

![Area model: bit width vs truncation](area_model.png)

## On MNIST

| TRUNC_BITS | accuracy |
|------------|----------|
| 0          | 97.7%    |
| 2          | 97.7%    |
| 3          | 97.0%    |
| 4          | 81.4%    |
| 5          | 10.6%    |

![MNIST accuracy vs truncation](mnist_quantized_accuracy.png)

The network copes fine up to about TRUNC_BITS = 3 even though the per multiply error is large, because only the argmax matters. Past that it falls off a cliff. The knee at TRUNC_BITS = 2 is the operating point worth having.

## On the FPGA

Deployed the multiplier to a Zynq 7020 with a UART interface so a host PC can drive it. I wrote the RX and TX state machines myself, including the bit timing at 115200 baud off the 50 MHz clock, mid bit sampling on receive, and a two flip flop synchroniser on the async receive line.

Takes two operands over serial, multiplies on the board, returns the 16 bit result. Checked on hardware that the bytes coming back matched the truncation predictions.

Later added an AXI4-Lite wrapper so the ARM side can drive it instead of serial, using Vivado and Vitis. Wrapper and C driver are in `vitis/`.

## Running it

Tested with Icarus Verilog 12.0 and Vivado 2026.1, targeting xc7z020clg484-2.

```
# multiplier, exhaustive
iverilog -g2012 -o sim_mult tb_mult_approx.v mult_approx.v && vvp sim_mult

# 2x2 array, expect 19 22 43 50
iverilog -g2012 -o sim_sys tb_systolic_2x2.v systolic_2x2.v pe.v mult_approx.v && vvp sim_sys

# memory fed array with real weights, expect 6 501 14 1007
iverilog -g2012 -o sim_mem tb_mem_systolic.v addr_gen.v weight_mem.v systolic_2x2.v pe.v mult_approx.v && vvp sim_mem

# sweep and figures
python3 sweep.py
python3 plot_pareto.py
```

Run from the repo root. `weight_mem.v` loads `weights.hex` with a relative path. For Vivado, add `weights.hex` to the project as a design source or `$readmemh` will not find it.

## Layout

- `mult_approx.v`, `mult_exact.v`, `mac.v` are the multipliers and the MAC
- `pe.v`, `systolic_2x2.v` are the processing element and the array
- `weight_mem.v`, `addr_gen.v` are the weight memory and its address generator
- `fpga/` is the top level and constraints for the UART deployment
- `vitis/` is the AXI4-Lite wrapper and C driver
- `tb_*.v` are the testbenches
- `*_utilisation_synth.txt` are Vivado reports
- `*.png` are the figures
- `*.py` is the sweep, evaluation and plotting tooling
- `*.csv` is the measured data

## What it does not do yet

- The array is 2x2. The dataflow and memory interface generalise but the parameterised NxN version is not written.
- Everything is unsigned, so negative weights come through as large positive numbers. Signed arithmetic is the obvious next thing.
- Power numbers are Vivado post synthesis estimates, not measured on the board.
- The sweep is a script running one configuration at a time, not a real automated exploration framework.
- MNIST here is a small fully connected network, not a CNN.

## Who wrote what

All the Verilog is mine. The multipliers, the MAC, the de-bias correction, the UART, the processing element and array, the weight memory and address generator, the AXI wrapper. I ran the synthesis and the hardware deployment. The de-bias idea, the bias versus variance conclusion and the systolic timing are mine too.

**The Python is not mine in the same way.** The MNIST training and quantisation, the inference evaluation, the sweep automation, the weight extraction and all the plotting were written with AI assistance. I directed it, I read it, and I understand what it does and why the numbers come out the way they do, but I did not write it line by line and I am not going to claim I did. It is tooling that measures the hardware, not the hardware itself.