iverilog -g2012 -I. -o shiftadd.vvp \
  shiftadd.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp shiftadd.vvp || { echo "Simulation failed"; exit 1; }

if [ -f shiftadd_tb.vcd ]; then
  gtkwave shiftadd_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi