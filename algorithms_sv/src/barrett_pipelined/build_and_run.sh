# Preprocess with syntax check
iverilog -E -DSIMULATION ../../utils/multiplier_pkg.sv \
            ../../utils/params_pkg.sv || { echo "Package syntax error"; exit 1; }

# Compile the design and testbench with the SIMULATION define
iverilog -g2012 -DSIMULATION -I. -o barrett_tb.vvp \
  ../../utils/params_pkg.sv \
  ../../utils/multiplier_pkg.sv \
  ../../utils/multiplier_16x16.sv \
  ../../utils/multiplier_top_pipelined.sv \
  ../../utils/shiftreg.sv \
  barrett.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

# Run the simulation
vvp barrett_tb.vvp || { echo "Simulation failed"; exit 1; }

# View waveform if it exists
if [ -f barrett_tb.vcd ]; then
  gtkwave barrett_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi
