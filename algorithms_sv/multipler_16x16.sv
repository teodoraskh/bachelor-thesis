import multipler_pkg::*;

// module multipler_16x16 (
//     input  logic                        clk_i,          // Rising edge active clk.
//     input  logic [BLOCK_LENGTH-1:0]     indata_a_i,     // Input data -> operand a.
//     input  logic [BLOCK_LENGTH-1:0]     indata_b_i,     // Input data -> operand b.
//     output logic [BLOCK_LENGTH*2-1:0]   outdata_r_o     // Output data -> result a*b.
// );

// always_comb begin
//     outdata_r_o = indata_a_i * indata_b_i;
// end

// endmodule : multipler_16x16

module multipler_16x16 (
    input  logic                        clk_i,          // Rising edge active clk.
    input  logic [BLOCK_LENGTH-1:0]     indata_a_i,     // Input data -> operand a.
    input  logic [BLOCK_LENGTH-1:0]     indata_b_i,     // Input data -> operand b.
    output logic [BLOCK_LENGTH*2-1:0]   outdata_r_o     // Output data -> result a*b.
);

logic [BLOCK_LENGTH*2-1:0] result_buffer;

always_ff @(posedge clk_i) begin
    result_buffer <= indata_a_i * indata_b_i;
end

assign outdata_r_o = result_buffer;

endmodule : multipler_16x16