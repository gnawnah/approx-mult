# Synthesise the MAC across truncation levels and write utilisation, power and
# timing reports for each configuration.
#
# Run from the repo root:
#   vivado -mode batch -source syn/scripts/synth_mac.tcl
#
# The point of this script is provenance. results/mac_results.csv used to be
# typed by hand from the GUI, which meant no reader could check the numbers and
# the clock frequency the power estimate assumed was not recorded anywhere.
# Every number the energy analysis depends on comes out of the reports this
# writes. Parse them with flow/parse_reports.py.

set part      xc7z020clg484-2
set trunc_set {0 2 4 6}
set rpt_dir   syn/reports

file mkdir $rpt_dir

foreach T $trunc_set {
    puts "=== synthesising mac with TRUNC_BITS=$T ==="

    # Fresh in-memory project each pass so nothing carries over between configs.
    create_project -in_memory -part $part

    read_verilog rtl/mult_approx.v
    read_verilog rtl/mac.v

    # The clock constraint has to be read before synth_design, otherwise power
    # is estimated against no clock and the result is meaningless.
    read_xdc constr/mac.xdc

    synth_design -top mac -part $part -generic TRUNC_BITS=$T

    report_utilization      -file $rpt_dir/mac_T${T}_utilisation.rpt
    report_power            -file $rpt_dir/mac_T${T}_power.rpt
    report_timing_summary   -file $rpt_dir/mac_T${T}_timing.rpt

    close_project
}

puts "=== done, reports in $rpt_dir ==="
puts "Next: python3 flow/parse_reports.py"
