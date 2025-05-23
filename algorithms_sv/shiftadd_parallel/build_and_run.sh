# 2. Compile all dependencies IN ORDER (packages first!)
iverilog -g2012 -I. -o shiftadd_bp.vvp \
  shiftadd_bp.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

# 3. Run simulation (only if compilation succeeded)
vvp shiftadd_bp.vvp || { echo "Simulation failed"; exit 1; }

# 4. Open waveforms (only if simulation succeeded)
if [ -f shiftadd_bp_tb.vcd ]; then
  gtkwave shiftadd_bp_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi

# Cleanup (optional)
# rm -f *.vvp *.vcd