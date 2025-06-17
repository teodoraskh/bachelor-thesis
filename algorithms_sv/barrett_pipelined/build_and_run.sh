iverilog -E ../utils/multiplier_pkg.sv \ || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -I. -o barrett_tb.vvp \
  ../utils/multiplier_pkg.sv \
  ../utils/multiplier_16x16.sv \
  ../utils/multiplier_top_pipelined.sv \
  ../utils/shiftreg.sv \
  barrett.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp barrett_tb.vvp || { echo "Simulation failed"; exit 1; }

if [ -f barrett_tb.vcd ]; then
  gtkwave barrett_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi