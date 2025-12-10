# === elaborate.do ===
onerror {quit -f}

set TB   testbench_top
set SNAP ${TB}_opt

echo "INFO: Starting elaboration for $TB ..."
echo "INFO: Creating optimized snapshot: $SNAP"

# +acc=npr → give visibility for waves & debug
vopt +acc=npr work.$TB -L work -o $SNAP

if {$? != 0} {
    echo "ERROR: vopt failed"
    quit -code 1
}

echo "INFO: Elaboration completed successfully. Snapshot: $SNAP"
quit -f
