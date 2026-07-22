#!/bin/bash
set -e
iverilog -g2012 -o sim_mult tb_mult_approx.v mult_approx.v && vvp sim_mult
iverilog -g2012 -o sim_sys tb_systolic_2x2.v systolic_2x2.v pe.v mult_approx.v && vvp sim_sys
iverilog -g2012 -o sim_mem tb_mem_systolic.v addr_gen.v weight_mem.v systolic_2x2.v pe.v mult_approx.v && vvp sim_mem
