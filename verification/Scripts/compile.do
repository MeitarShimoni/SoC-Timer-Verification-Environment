# === compile.do (relative to verification/scripts) ===

# paths:
# scripts -> ..     = verification
# scripts -> ../..  = project root
set verification_path  ..
set design_path        ../../design

echo "INFO: Starting compile.do ..."
echo "CWD:             [pwd]"
echo "design_path:     $design_path"
echo "verification:    $verification_path"

onerror {quit -f}

# fresh work library
vlib work
vmap work work

# ============
#  File lists
# ============

# Use [list ...] + quotes so $design_path expands!
set design_files [list \
    "$design_path/design_params_pkg.sv" \
    "$design_path/timer_periph_update.sv" \
    
]

set verify_files [list \
    "$verification_path/bus_trans_pkg.sv" \
    "$verification_path/bus_if.sv" \
    "$verification_path/Driver.sv" \
    "$verification_path/Monitor.sv" \
    "$verification_path/Scoreboard.sv" \
    "$verification_path/Sequencer.sv" \
    "$verification_path/coverage_collector_timer.sv" \
    "$verification_path/timer_sva.sv" \
    "$verification_path/testbench_top.sv" \
]

# ============
#  Compile
# ============

foreach f $design_files {
    if {![file exists $f]} {
        echo "ERROR: Missing design file: $f"
        quit -code 1
    }
    echo "INFO: Compiling DESIGN file: $f"
    vlog -sv -work work "$f"
}

foreach f $verify_files {
    if {![file exists $f]} {
        echo "ERROR: Missing verification file: $f"
        quit -code 1
    }
    echo "INFO: Compiling VERIF file: $f"
    vlog -sv -work work "$f"
}

echo "INFO: Compilation completed successfully!"
quit -f
