iverilog -E ../../utils/multiplier_pkg.sv\
            ../../utils/params_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -I. -o barrett_ds_tb.vvp \
  ../../utils/params_pkg.sv \
  ../../utils/multiplier_pkg.sv \
  ../../utils/multiplier_16x16.sv \
  ../../utils/multiplier_top_serial.sv \
  barrett_ds.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp barrett_ds_tb.vvp || { echo "Simulation failed"; exit 1; }

if [ -f barrett_ds_tb.vcd ]; then
  gtkwave barrett_ds_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi