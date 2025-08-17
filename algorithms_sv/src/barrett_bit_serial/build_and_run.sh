iverilog -E -DSIMULATION ../../utils/multiplier_pkg.sv \
            ../../utils/params_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -DSIMULATION -I. -o barrett.vvp \
  ../../utils/multiplier_pkg.sv \
  ../../utils/params_pkg.sv \
  ../../utils/multiplier_16x16.sv \
  ../../utils/multiplier_bs.sv \
  barrett.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp barrett.vvp || { echo "Simulation failed"; exit 1; }

if [ -f barrett_bs_tb.vcd ]; then
  gtkwave barrett_bs_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi

  # ../../utils/multiplier_bs.sv \
  # ../../utils/multiplier_top_serial.sv \