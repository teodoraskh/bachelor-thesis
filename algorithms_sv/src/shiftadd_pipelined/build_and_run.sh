iverilog -E ../../utils/multiplier_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -I. -o shiftadd.vvp \
  ../../utils/multiplier_pkg.sv \
  ../../utils/shiftreg.sv \
  shiftadd.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp shiftadd.vvp || { echo "Simulation failed"; exit 1; }

if [ -f shiftadd_tb.vcd ]; then
  gtkwave shiftadd_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi