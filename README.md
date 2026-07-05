# approx-mult

Design space exploration of truncation based approximate multipliers for energy efficient AI hardware, taken from a single arithmetic unit up to a systolic array accelerator with an on-chip weight memory, evaluated on a real machine learning task and deployed to a physical Xilinx Zynq 7020 FPGA.

![Pareto front: MNIST accuracy vs multiplier area](pareto_accuracy_vs_luts.png)

## What this project is

I built an approximate 8 by 8 multiplier in Verilog and explored how much arithmetic accuracy you can trade away for area and power savings, then measured where that trade off starts to hurt a real neural network. From that single unit I built upward: a multiply accumulate cell, a 2 by 2 systolic array that performs matrix multiplication, and an on-chip weight memory that feeds the array, which together form the core of an approximate arithmetic AI accelerator rather than just an arithmetic unit. Along the way I added an original correction that removes the systematic bias of truncation, and I deployed the multiplier to a physical FPGA over a UART interface I wrote myself.

The whole project targets the question that energy efficient accelerator research asks: how far can you push approximate arithmetic before the application breaks, and what does that buy you in hardware.

## The parts I want to highlight

These are the pieces I am most proud of and that took the most of my own design work.

**The systolic array accelerator.** I built a 2 by 2 systolic array from my approximate multiply accumulate cells. This is the canonical architecture for AI accelerators such as the TPU, because a matrix multiply is exactly what a neural network layer computes. Each cell is my approximate MAC plus registers that forward operands to the neighbouring cells, and that operand forwarding is the sliding data movement that lets operands be reused across cells instead of refetched, which is where the energy and throughput efficiency comes from.

![Systolic array dataflow](Systolic_Array_Drawing.jpg)

The diagram is how I worked out the skew myself. Operands stream in from the top and left edges, staggered by one cycle per row and column, so that as they slide through the cells the correct matrix terms meet at the correct cell at the correct cycle. I verified the array in simulation against a hand computed matrix product, A = [[1,2],[3,4]] times B = [[5,6],[7,8]] gives C = [[19,22],[43,50]], and the simulation produces exactly that, with the diagonal completion wavefront you would expect as the top left cell finishes first and the bottom right cell finishes last.

**The on-chip weight memory.** I then added a dual-port weight memory that holds the weights and feeds them into the array, which is the weight stationary dataflow used in real accelerators. I wrote it as a registered-read ROM in the pattern that Vivado infers as Block RAM, and an address generator that reproduces the systolic skew while also accounting for the one cycle read latency the memory adds. I verified the memory-fed array still produces the correct matrix product, then loaded a real slice of the trained MNIST weights and confirmed the result against a hand calculation. Synthesis on the Zynq confirms the memory infers a RAMB18E1 Block RAM primitive, serving both read ports from the single natively dual-port block. The utilisation report is in `bram_utilisation_synth.txt`. This is the concrete evidence that the weight memory maps to a dedicated on-chip memory rather than to general logic.

**The de-bias correction.** Because truncation always rounds down, the error is not random noise, it is a consistent negative bias, which means it is correctable. I added a single constant correction term to the RTL that adds back the mean error, which costs one adder and is essentially free in hardware. On a single multiply this cut the total absolute error by about 40 percent. The part I am most proud of understanding is why it helps at the accuracy cliff but cannot move it: the correction removes a constant bias, but the collapse at high truncation is driven by variance, not bias, and a uniform bias shift cannot change which output is the argmax. Bias is correctable, variance is not, and argmax is what ultimately decides.

![MNIST accuracy with and without de-bias correction](mnist_corrected_accuracy.png)

**The FPGA deployment.** I deployed the approximate multiplier to the physical Zynq with a UART interface so a host PC can drive it with live data. I wrote the UART receiver and transmitter myself as state machines, including the bit timing at 115200 baud on the 50 MHz clock, the mid bit sampling on receive, and a two flip flop synchroniser on the asynchronous receive line to avoid metastability. The final version takes two operands over serial, multiplies them on the board, and returns the 16 bit result, and I verified on hardware that the returned bytes matched the truncation predictions exactly. This confirms the design runs on real silicon driven by external data, not just in simulation.

## Design space exploration

The multiplier truncates the low TRUNC_BITS of both operands before multiplying, which zeros the least significant bits and shrinks the hardware.

```verilog
a_trunc = (a >> TRUNC_BITS) << TRUNC_BITS;
b_trunc = (b >> TRUNC_BITS) << TRUNC_BITS;
product = a_trunc * b_trunc + CORRECTION;
```

Measured on the Zynq (xc7z020clg484-2, post synthesis), area and error scale cleanly with truncation:

| TRUNC_BITS | LUTs | max error |
|------------|------|-----------|
| 0 (exact)  | 70   | 0         |
| 2          | 39   | 380       |
| 4          | 14   | 1856      |
| 6          | 2    | 7040      |

![Error vs truncation](error_vs_truncation.png)

I swept the multiplier across two independent knobs, operand bit width and truncation, and synthesised every configuration on the real chip. One finding I can defend: for a given accuracy budget, reducing the operand bit width is more area efficient than truncating a wider multiplier. A 6 bit exact multiplier lands almost exactly where an 8 bit multiplier at TRUNC_BITS = 2 does, which tells you the two knobs are not equivalent and which one to reach for first.

![Area model: bit width vs truncation](area_model.png)

The approximate multiplier was then evaluated on MNIST inference with a small quantised MLP to find where the approximation actually costs accuracy:

| TRUNC_BITS | MNIST accuracy |
|------------|----------------|
| 0          | 97.7%          |
| 2          | 97.7%          |
| 3          | 97.0%          |
| 4          | 81.4%          |
| 5          | 10.6%          |

![MNIST accuracy vs truncation](mnist_quantized_accuracy.png)

The network tolerates approximation up to about TRUNC_BITS = 3 despite a large per multiply error, because classification depends only on which output is the argmax, not on the exact values. Past that point accuracy collapses sharply. This cliff is what the Pareto front shows, and the knee at TRUNC_BITS = 2 is the efficient operating point.

## Repository layout

- `mult_approx.v`, `mult_exact.v`, `mac.v` are the approximate and exact multipliers and the MAC
- `pe.v`, `systolic_2x2.v` are the systolic processing element and the 2 by 2 array
- `weight_mem.v`, `addr_gen.v` are the on-chip weight memory and its address generator
- `fpga/` holds the top level wrappers and constraints for the Zynq deployment (UART interface)
- `tb_*.v` are the testbenches for every module
- `bram_utilisation_synth.txt`, `mult_approx_utilisation_synth.txt`, `mult_exact_utilisation_synth.txt` are Vivado synthesis reports
- `pareto_accuracy_vs_luts.png`, `area_model.png`, `error_vs_truncation.png`, `mnist_quantized_accuracy.png`, `mnist_corrected_accuracy.png` are the result figures
- the Python scripts (`sweep.py`, `plot_pareto.py`, `mnist_quantized.py`, `train_mnist_weights.py`, `extract_weights.py` and the plotting scripts) are the exploration and evaluation tooling
- `*.csv` are the measured area, power, error, and accuracy data

## Notes on tools and authorship

I wrote all of the Verilog myself. That includes the approximate and exact multipliers, the MAC, the de-bias correction, the UART receiver and transmitter, the systolic processing element and array, and the weight memory and address generator. I ran all of the synthesis and the hardware deployment, and the design decisions, the de-bias idea, the bias versus variance analysis, and the systolic dataflow are mine.

The Python side is different. The MNIST training, quantisation, and inference tooling, the sweep automation, the weight extraction, and the plotting were AI assisted. I understand what that code does and how the MNIST evaluation works, and I use it as evidence for how the approximate arithmetic behaves on a real task, but I did not write it from scratch myself. I have kept this split honest on purpose: the hardware design is my own work, and the machine learning tooling is a supporting layer that I directed and understood rather than authored.