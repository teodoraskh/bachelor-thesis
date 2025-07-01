iverilog -E -DSIMULATION ../../utils/multiplier_pkg.sv \
                         ../../utils/params_pkg.sv || { echo "Package syntax error"; exit 1; }

iverilog -g2012 -DSIMULATION -I. -o shiftadd_bp.vvp \
  ../../utils/multiplier_pkg.sv \
  ../../utils/params_pkg.sv\
  ../../utils/shiftreg.sv \
  shiftadd_bp.sv \
  shiftadd_bp_top.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

vvp shiftadd_bp.vvp || { echo "Simulation failed"; exit 1; }

if [ -f shiftadd_bp_tb.vcd ]; then
  gtkwave shiftadd_bp_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi