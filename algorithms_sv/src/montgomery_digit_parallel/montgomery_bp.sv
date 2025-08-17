import multiplier_pkg::*;
module montgomery_parallel (
  input  logic [DATA_LENGTH-1:0]             x_i,       // Input (e.g., 64-bit)
  input  logic [DATA_LENGTH-1:0]             m_i,       // Modulus (e.g., 32-bit)
  input  logic signed [DATA_LENGTH-1:0]      minv_i,    // Input (e.g., 64-bit)
  input  logic [DATA_LENGTH-1:0]             m_bl_i,
  output logic [DATA_LENGTH-1:0]             result_o
);

logic [DATA_LENGTH-1:0] m;
logic [DATA_LENGTH-1:0] res;
logic [2 * DATA_LENGTH-1:0] lsb_scaled;
logic [2 * DATA_LENGTH-1:0] m_rescaled;


multiplier_top multiplier_scale_lsb(
  .indata_a_i(x_i & ((1 << m_bl_i) - 1)),           // Input data -> operand a.
  .indata_b_i(minv_i),                              // Input data -> operand b.
  .outdata_r_o(lsb_scaled)
);

assign m = lsb_scaled & ((1 << m_bl_i) - 1);

multiplier_top multiplier_rescale_input(
  .indata_a_i(m),             // Input data -> operand a.
  .indata_b_i(m_i),           // Input data -> operand b.
  .outdata_r_o(m_rescaled)
);

assign res = (x_i + m_rescaled) >> m_bl_i;
assign result_o = (res >= m_i) ? (res - m_i) : res;

endmodule : montgomery_parallel
