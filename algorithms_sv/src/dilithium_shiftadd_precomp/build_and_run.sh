iverilog -E -DSIMULATION ../../utils/multiplier_pkg.sv \
            ../../utils/params_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -DSIMULATION -I. -o dilithium_tb.vvp \
  ../../utils/multiplier_pkg.sv \
  ../../utils/params_pkg.sv \
  ../../utils/shiftreg.sv \
  reduction.sv \
  reduction_top.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp dilithium_tb.vvp || { echo "Simulation failed"; exit 1; }

if [ -f dilithium_tb.vcd ]; then
  gtkwave dilithium_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi