iverilog -E -DSIMULATION ../../utils/multiplier_pkg.sv \
            ../../utils/params_pkg.sv  || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -DSIMULATION -I.. -o barrett_dp_tb.vvp \
  ../../utils/params_pkg.sv \
  ../../utils/multiplier_pkg.sv \
  ../../utils/multiplier_16x16_parallel.sv \
  ../../utils/multiplier_parallel.sv \
  ../../utils/shiftreg.sv \
  barrett_dp.sv \
  barrett_dp_top.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp barrett_dp_tb.vvp || { echo "Simulation failed"; exit 1; }

if [ -f barrett_dp_tb.vcd ]; then
  gtkwave barrett_dp_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi