#!/bin/bash
# Run from the repo root: bash flow/run_sims.sh
# weight_mem.v loads weights.hex by a bare relative path, so the working
# directory must be the repo root.
set -e
iverilog -g2012 -o sim_mult tb/tb_mult_approx.v rtl/mult_approx.v && vvp sim_mult
iverilog -g2012 -o sim_sys tb/tb_systolic_2x2.v rtl/systolic_2x2.v rtl/pe.v rtl/mult_approx.v && vvp sim_sys
iverilog -g2012 -o sim_mem tb/tb_mem_systolic.v rtl/addr_gen.v rtl/weight_mem.v rtl/systolic_2x2.v rtl/pe.v rtl/mult_approx.v && vvp sim_mem
