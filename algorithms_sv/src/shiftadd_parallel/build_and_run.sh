iverilog -g2012 -I. -o shiftadd_bp.vvp \
  shiftadd_bp.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp shiftadd_bp.vvp || { echo "Simulation failed"; exit 1; }

if [ -f shiftadd_bp_tb.vcd ]; then
  gtkwave shiftadd_bp_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi