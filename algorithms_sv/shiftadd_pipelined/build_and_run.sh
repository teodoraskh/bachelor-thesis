# 2. Compile all dependencies IN ORDER (packages first!)
iverilog -g2012 -I. -o shiftadd.vvp \
  shiftreg.sv \
  shiftadd.sv \
  tb.sv || { echo "Compilation failed"; exit 1; }

# 3. Run simulation (only if compilation succeeded)
vvp shiftadd.vvp || { echo "Simulation failed"; exit 1; }

# 4. Open waveforms (only if simulation succeeded)
if [ -f shiftadd_tb.vcd ]; then
  gtkwave shiftadd_tb.vcd &
else
  echo "No waveform file generated"
  exit 1
fi

# Cleanup (optional)
# rm -f *.vvp *.vcd