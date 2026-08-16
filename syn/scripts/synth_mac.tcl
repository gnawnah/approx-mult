# Synthesise the MAC across truncation levels and write utilisation, power and
# timing reports for each configuration. See the Synthesis section of the README
# for why this is measured out of context and as an array.
#
# Run from the repo root:
#   vivado -mode batch -source syn/scripts/synth_mac.tcl
#   python3 flow/parse_reports.py

set part      xc7z020clg484-2
set trunc_set {0 2 4 6}
set array_n   256
set rpt_dir   syn/reports

file mkdir $rpt_dir

# Recorded next to the reports so the parser cannot disagree with what was built.
set fh [open $rpt_dir/array_n.txt w]
puts $fh $array_n
close $fh

foreach T $trunc_set {
    puts "=== synthesising mac_array (N=$array_n) with TRUNC_BITS=$T ==="

    # Fresh project each pass so nothing carries over between configs.
    create_project -in_memory -part $part

    read_verilog rtl/mult_approx.v
    read_verilog rtl/mac.v
    read_verilog syn/mac_array.v

    # Must be read before synth_design or power is estimated against no clock.
    read_xdc constr/mac.xdc

    synth_design -top mac_array -part $part \
                 -generic TRUNC_BITS=$T -generic N=$array_n \
                 -mode out_of_context

    report_utilization      -file $rpt_dir/mac_T${T}_utilisation.rpt
    report_power            -file $rpt_dir/mac_T${T}_power.rpt
    report_timing_summary   -file $rpt_dir/mac_T${T}_timing.rpt

    close_project
}

puts "=== done, reports in $rpt_dir ==="
