# iverilog -E multiplier_pkg.sv 
# iverilog -E multiplier_16x16.sv multiplier_top.sv

# iverilog -g2012 -o barrett.vvp tb.sv barrett.sv shiftreg.sv
# vvp barrett.vvp

# gtkwave -f barrett.vcd # new session -> empty 
# # gtkwave -f barrett.vcd -3 # restore previous gtk session

# rm *.vvp
# rm *.vcd


#!/bin/bash
# -------------------------------------------------------------------------------------------
# 1. First compile JUST the package to check for syntax errors
# iverilog -E multiplier_pkg.sv || { echo "Package syntax error"; exit 1; }

# 2. Compile all dependencies IN ORDER (packages first!)
iverilog -g2012 -I. -o montgomery.vvp \
  montgomery.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

# 3. Run simulation (only if compilation succeeded)
vvp montgomery.vvp || { echo "Simulation failed"; exit 1; }

# 4. Open waveforms (only if simulation succeeded)
if [ -f montgomery_tb.vcd ]; then
  gtkwave montgomery_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi

# Cleanup (optional)
# rm -f *.vvp *.vcd