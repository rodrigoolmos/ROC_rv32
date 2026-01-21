# Vivado batch flow for ROC_RV32 on Nexys A7
# Usage:
#   vivado -mode batch -source vivado/run.tcl

set proj_name roc_rv32
set proj_dir  [file normalize "./vivado/vivado_proj"]
set top_name  soc
set flist     "ROC_RV32.flist"

# Nexys A7 device (Artix-7 100T)
set part_name xc7a100tcsg324-1

set xdc_file "vivado/constraints.xdc"

# Create project
if {[file exists $proj_dir]} {
    file delete -force $proj_dir
}
create_project -force $proj_name $proj_dir -part $part_name
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]

# Add sources from file list
if {![file exists $flist]} {
    puts "ERROR: missing file list: $flist"
    exit 1
}

set src_files {}
set inc_dirs  {}
set fd [open $flist r]
while {[gets $fd line] >= 0} {
    set line [string trim $line]
    if {$line eq ""} { continue }
    if {[string match "//*" $line]} { continue }
    if {[string match "+incdir+*" $line]} {
        set dir [string range $line 8 end]
        lappend inc_dirs $dir
        continue
    }
    lappend src_files $line
}
close $fd

foreach f $src_files {
    if {![file exists $f]} {
        puts "ERROR: missing source file: $f"
        exit 1
    }
}
add_files -norecurse $src_files
if {[llength $inc_dirs] > 0} {
    set_property include_dirs $inc_dirs [current_fileset]
}
set_property top $top_name [current_fileset]

# Add constraints (placeholder pins)
if {![file exists $xdc_file]} {
    puts "ERROR: missing constraints file: $xdc_file"
    exit 1
}
add_files -fileset constrs_1 -norecurse $xdc_file

# Synthesis + Implementation + bitstream
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Reports
open_run impl_1
report_timing_summary -file [file join $proj_dir timing_summary.rpt] -delay_type max
report_utilization    -file [file join $proj_dir utilization.rpt]

puts "DONE. Bitstream at: $proj_dir/$proj_name.runs/impl_1/${top_name}.bit"
