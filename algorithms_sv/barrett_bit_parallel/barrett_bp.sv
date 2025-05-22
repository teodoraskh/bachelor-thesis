module barrett_parallel (
  input  logic [63:0]             x_i,       // Input (e.g., 64-bit)
  input  logic [63:0]             m_i,       // Modulus (e.g., 32-bit)
  input  logic [63:0]             m_bl_i,    // Precomputed μ
  input  logic [63:0]             mu_i,      // Precomputed μ
  output logic [63:0]             result_o
);

logic [127:0] xmu_precomp;
logic m_finish;
logic busy_p_o;
multiplier_top multiplier_precomp(
  .indata_a_i(x_i),           // Input data -> operand a.
  .indata_b_i(mu_i),          // Input data -> operand a.
  .outdata_r_o(xmu_precomp)
);

logic [63:0] q_approx;
assign q_approx = xmu_precomp >> (2 * m_bl_i);

logic busy_a_o;
logic [127:0] qm_result;
multiplier_top multiplier_approx(
  .indata_a_i(q_approx),     // Input data -> operand a.
  .indata_b_i(m_i),          // Input data -> operand b.
  .outdata_r_o(qm_result)
);

assign result_o = x_i - qm_result;

endmodule : barrett_parallel