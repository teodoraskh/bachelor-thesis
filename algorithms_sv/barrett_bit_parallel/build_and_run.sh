iverilog -E multiplier_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -I. -o barrett_bp_tb.vvp \
  multiplier_pkg.sv \
  multiplier_16x16.sv \
  multiplier_parallel.sv \
  barrett_bp.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp barrett_bp_tb.vvp || { echo "Simulation failed"; exit 1; }

if [ -f barrett_bp_tb.vcd ]; then
  gtkwave barrett_bp_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi

# Cleanup (optional)
# rm -f *.vvp *.vcd