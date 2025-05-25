
iverilog -g2012 -I. -o shiftadd_serial_top.vvp \
  shiftadd.sv \
  shiftadd_serial_top.sv \
  tb_top.sv || { echo "Compilation failed"; exit 1; }

# 3. Run simulation (only if compilation succeeded)
vvp shiftadd_serial_top.vvp || { echo "Simulation failed"; exit 1; }

# 4. Open waveforms (only if simulation succeeded)
if [ -f shiftadd_tb_top.vcd ]; then
  gtkwave shiftadd_tb_top.vcd &
else
  echo "No waveform file generated"
  exit 1
fi

# Cleanup (optional)
# rm -f *.vvp *.vcd