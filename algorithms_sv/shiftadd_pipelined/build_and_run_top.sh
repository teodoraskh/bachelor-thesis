# 2. Compile all dependencies IN ORDER (packages first!)
iverilog -g2012 -I. -o shiftadd.vvp \
  shiftreg.sv \
  shiftadd.sv \
  shiftadd_pipelined_top.sv \
  tb_top.sv || { echo "Compilation failed"; exit 1; }

# 3. Run simulation (only if compilation succeeded)
vvp shiftadd.vvp || { echo "Simulation failed"; exit 1; }

# 4. Open waveforms (only if simulation succeeded)
if [ -f shiftadd_tb_top.vcd ]; then
  gtkwave shiftadd_tb_top.vcd &
else
  echo "No waveform file generated"
  exit 1
fi

# Cleanup (optional)
# rm -f *.vvp *.vcd