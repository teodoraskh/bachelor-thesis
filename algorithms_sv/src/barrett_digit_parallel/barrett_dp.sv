import multiplier_pkg::*;
module barrett_parallel (
  input  logic [DATA_LENGTH-1:0]    x_i,
  input  logic [DATA_LENGTH-1:0]    m_i,
  input  logic [DATA_LENGTH-1:0]    m_bl_i,
  input  logic [DATA_LENGTH-1:0]    mu_i,
  output logic [DATA_LENGTH-1:0]    result_o
);

logic [DATA_LENGTH-1:0] res_reg;
logic [DATA_LENGTH-1:0] q_approx;
logic [2 * DATA_LENGTH-1:0] xmu_precomp;
logic [2 * DATA_LENGTH-1:0] qm_result;


multiplier_top multiplier_precomp(
  .indata_a_i(x_i),           // Input data -> operand a.
  .indata_b_i(mu_i),          // Input data -> operand a.
  .outdata_r_o(xmu_precomp)
);
// assign xmu_precomp = x_i * mu_i;

assign q_approx = xmu_precomp >> (2 * m_bl_i);

multiplier_top multiplier_approx(
  .indata_a_i(q_approx),     // Input data -> operand a.
  .indata_b_i(m_i),          // Input data -> operand b.
  .outdata_r_o(qm_result)
);
// assign qm_result = q_approx * m_i;

assign res_reg = x_i - qm_result;
assign result_o = (res_reg >= m_i) ? (res_reg - m_i) : res_reg;

endmodule : barrett_parallel