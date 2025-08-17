iverilog -E -DSIMULATION ../../utils/multiplier_pkg.sv \
            ../../utils/params_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -DSIMULATION -I. -o montgomery.vvp \
  ../../utils/params_pkg.sv \
  ../../utils/multiplier_pkg.sv \
  ../../utils/multiplier_16x16.sv \
  ../../utils/multiplier_top_serial.sv \
  montgomery.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp montgomery.vvp || { echo "Simulation failed"; exit 1; }

if [ -f montgomery_tb.vcd ]; then
  gtkwave montgomery_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi