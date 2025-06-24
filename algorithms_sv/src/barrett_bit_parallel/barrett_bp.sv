import multiplier_pkg::*;

module barrett_parallel (
  input  logic                      clk_i,
  input  logic                      rst_ni,
  input  logic                      start_i,
  input  logic [DATA_LENGTH-1:0]    x_i,
  input  logic [DATA_LENGTH-1:0]    m_i,
  input  logic [DATA_LENGTH-1:0]    m_bl_i,
  input  logic [DATA_LENGTH-1:0]    mu_i,
  output logic [DATA_LENGTH-1:0]    result_o,
  output  logic                     valid_o
);
logic start_delayed;

logic [DATA_LENGTH-1:0] x_reg, m_reg, m_bl_reg, mu_reg, res_reg, red_reg;
logic [DATA_LENGTH-1:0] q_approx;
logic [2 * DATA_LENGTH-1:0] xmu_precomp;
logic [2 * DATA_LENGTH-1:0] qm_result;

shiftreg #(
    .SHIFT(3), // 1 for each ff
    .DATA(1)
) shift_in (
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(start_delayed)
);

//----------------------- Register inputs -> 1 cycle -----------------------
always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      x_reg     <= 0;
      m_reg     <= 0;
      m_bl_reg  <= 0;
      mu_reg    <= 0;
    end else if(start_i) begin
      x_reg     <= x_i;
      m_reg     <= m_i;
      m_bl_reg  <= m_bl_i;
      mu_reg    <= mu_i;
    end
  end

//----------------------- Barrett arithmetic -> 1 cycle -----------------------
multiplier_top multiplier_precomp(
  .indata_a_i(x_reg),           // Input data -> operand a.
  .indata_b_i(mu_reg),          // Input data -> operand a.
  .outdata_r_o(xmu_precomp)
);

assign q_approx = xmu_precomp >> (2 * m_bl_i);

multiplier_top multiplier_approx(
  .indata_a_i(q_approx),     // Input data -> operand a.
  .indata_b_i(m_reg),        // Input data -> operand b.
  .outdata_r_o(qm_result)
);

assign res_reg = x_reg - qm_result;
assign red_reg = (res_reg >= m_reg) ? (res_reg - m_reg) : res_reg;

//----------------------- Getting the output -> 1 cycle -----------------------
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 0;
    valid_o  <= 0;
  end else begin
    result_o <= red_reg;
    valid_o  <= start_delayed;
  end
end

endmodule : barrett_parallel