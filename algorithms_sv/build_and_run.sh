iverilog -E multiplier_pkg.sv multiplier_16x16.sv multiplier_top.sv

iverilog -g2012 -o barrett.vvp tb.sv barrett.sv shiftreg.sv
vvp barrett.vvp

gtkwave -f barrett.vcd # new session -> empty 
# gtkwave -f barrett.vcd -3 # restore previous gtk session

rm *.vvp
rm *.vcd