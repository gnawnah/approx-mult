# Approximate Multiplier
A self-directed project to learn digital design and approximate arithmetic.
An 8x8 multiplier that truncates its operands to trade accuracy for hardware, written in Verilog and simulated with Icarus Verilog.

## What it does

Zeroing the low bits of both operands before multiplying makes the hardware
smaller but the result slightly wrong:

\`\`\`verilog
assign a_trunc = (a >> TRUNC_BITS) << TRUNC_BITS;
assign product = a_trunc * b_trunc;
\`\`\`

Thinking of `a × b` as the area of a rectangle, truncation drops thin strips off the edges. Truncating one operand drops one strip; truncating both drops two strips plus a corner, which is why the worst-case error roughly doubles:

<img width="2720" height="1680" alt="image" src="https://github.com/user-attachments/assets/e1ceca08-1711-44a9-a013-e5ef46c4a834" />


I swept `TRUNC_BITS` from 0 to 8 and measured the error, then dropped the multiplier into a multiply-accumulate (MAC) unit to see what happens over a dot product.

<img width="960" height="720" alt="error_vs_truncation" src="https://github.com/user-attachments/assets/01e8088e-4a4a-4cd4-87d4-540d65290c46" />

## What I found

- Truncating 2-3 bits barely changes the result, but past that the error grows fast.
- The worst-case error matches what the math predicts (e.g. 1521 at T=2).
- The error always rounds down, so in the MAC it builds up across a dot product instead of cancelling - a 10-term dot product at T=2 was off by 90, exactly 10x the per-multiply error. Relevant because inference is all dot products.

## Files

- `mult_exact.v` / `mult_approx.v` — exact and approximate multipliers
- `tb_*.v` — testbenches
- `mac.v` — multiply-accumulate unit
- `sweep.py`, `plot.py` — run the sweep, make the plot

## Run it

\`\`\`bash
python3 sweep.py
python3 plot.py
\`\`\`

## Next

Synthesise in Vivado to measure the area savings.

## Notes

This is a learning project. I wrote the Verilog (multipliers, testbenches, MAC) myself; I used an AI assistant as a tutor for concepts I was new to and to help write the Python tooling (sweep and plot scripts), which I then read through tounderstand. All design decisions and results are my own.
