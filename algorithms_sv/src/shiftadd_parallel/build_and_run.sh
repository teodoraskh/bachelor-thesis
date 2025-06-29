iverilog -E ../../utils/multiplier_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -I. -o shiftadd_bp.vvp \
  ../../utils/multiplier_pkg.sv \
  shiftadd_bp.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp shiftadd_bp.vvp || { echo "Simulation failed"; exit 1; }

if [ -f shiftadd_bp_tb.vcd ]; then
  gtkwave shiftadd_bp_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi