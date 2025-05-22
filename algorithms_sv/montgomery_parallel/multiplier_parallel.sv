import multiplier_pkg::*;

module multiplier_top (
    input  logic [DATA_LENGTH-1:0]      indata_a_i,      // Input data -> operand a.
    input  logic [DATA_LENGTH-1:0]      indata_b_i,      // Input data -> operand b.
    output logic [DATA_LENGTH*2-1:0]    outdata_r_o      // Output data -> result a*b.
);

logic [LENGTH-1:0] mul16_a [NUM_MULS-1:0];
logic [LENGTH-1:0] mul16_b [NUM_MULS-1:0];
logic [LENGTH*2-1:0] mul16_res [NUM_MULS-1:0];

generate
  for (genvar i=0; i<NUM_MULS; i++) begin
      
    assign mul16_a[i] = indata_a_i[BLOCK_LENGTH*(i%NUM_BLOCKS)+:BLOCK_LENGTH];
    assign mul16_b[i] = indata_b_i[BLOCK_LENGTH*(i/NUM_BLOCKS)+:BLOCK_LENGTH];

    multiplier_16x16 multiplier_16x16_i (
      .indata_a_i     (mul16_a[i]),
      .indata_b_i     (mul16_b[i]),
      .outdata_r_o    (mul16_res[i])
    );
  end
endgenerate


always_comb begin
  outdata_r_o = '0;
  for (int i = 0; i < NUM_MULS; i++) begin
    outdata_r_o += (mul16_res[i] << (i%NUM_BLOCKS + i/NUM_BLOCKS)*BLOCK_LENGTH);
  end
end

endmodule : multiplier_top