iverilog -E -DSIMULATION ../../utils/multiplier_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -DSIMULATION -I. -o kyber_tb.vvp \
  ../../utils/multiplier_pkg.sv\
  ../../utils/shiftreg.sv\
  reduction.sv \
  reduction_top.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp kyber_tb.vvp || { echo "Simulation failed"; exit 1; }

if [ -f kyber_tb.vcd ]; then
  gtkwave kyber_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi