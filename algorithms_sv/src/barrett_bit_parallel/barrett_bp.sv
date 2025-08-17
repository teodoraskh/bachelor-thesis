import multiplier_pkg::*;
module barrett_bp (
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


bp_multiplier_64x64 multiplier_precomp(
  .a(x_i),           // Input data -> operand a.
  .b(mu_i),          // Input data -> operand a.
  .product(xmu_precomp)
);

assign q_approx = xmu_precomp >> (2 * m_bl_i);

bp_multiplier_64x64 multiplier_approx(
  .a(q_approx),     // Input data -> operand a.
  .b(m_i),          // Input data -> operand b.
  .product(qm_result)
);

assign res_reg = x_i - qm_result;
assign result_o = (res_reg >= m_i) ? (res_reg - m_i) : res_reg;

endmodule : barrett_bp