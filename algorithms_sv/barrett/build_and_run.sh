iverilog -g2012 -o barrett_np.vvp barrett_np.sv tb.sv 
vvp barrett_np.vvp

gtkwave -f barrett_np.vcd # new session -> empty 
# gtkwave -f multipler.vcd -3 # restore previous gtk session

rm *.vvp
rm *.vcd