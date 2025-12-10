

echo "INFO: Staring simulation script..."

vlog -sv  timer_periph.sv timer_periph_update.sv design_params_pkg.sv  timer_sva.sv bus_trans_pkg.sv  bus_if.sv Driver.sv coverage_collector_timer.sv Monitor.sv Scoreboard.sv Sequencer.sv testbench_top.sv

echo "INFO: Compilation Completed!"

vsim -coverage -voptargs=+acc work.testbench_top

echo "INFO: simulation loaded!"

add wave -r sim:/testbench_top/DUT/*

onfinish stop;

run -all

echo "INFO: Simulation finished!"