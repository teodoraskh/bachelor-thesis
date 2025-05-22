import multiplier_pkg::*;
module multiplier_16x16 (        // Rising edge active clk.
    input  logic [BLOCK_LENGTH-1:0]     indata_a_i,     // Input data -> operand a.
    input  logic [BLOCK_LENGTH-1:0]     indata_b_i,     // Input data -> operand b.
    output logic [BLOCK_LENGTH*2-1:0]   outdata_r_o     // Output data -> result a*b.
);

logic [BLOCK_LENGTH*2-1:0] result_buffer;

assign outdata_r_o = indata_a_i * indata_b_i;

endmodule : multiplier_16x16