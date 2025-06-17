iverilog -E ../utils/multiplier_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -I. -o montgomery_bp_tb.vvp \
  ../utils/multiplier_pkg.sv \
  ../utils/multiplier_16x16_parallel.sv \
  ../utils/multiplier_parallel.sv \
  montgomery_bp.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp montgomery_bp_tb.vvp || { echo "Simulation failed"; exit 1; }

if [ -f montgomery_bp_tb.vcd ]; then
  gtkwave montgomery_bp_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi

# Cleanup (optional)
# rm -f *.vvp *.vcd