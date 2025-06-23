import multiplier_pkg::*;
module montgomery_pipelined (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input (e.g., 64-bit)
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus (e.g., 32-bit)
  input  logic [DATA_LENGTH-1:0]  m_bl_i,
  input  logic [DATA_LENGTH-1:0]  minv_i,    // Input (e.g., 64-bit)
  output logic [DATA_LENGTH-1:0]  result_o,
  output logic                    valid_o    // Result valid flag
);

logic s_finish, m_finish, d_finish;
logic busy_m_o;
logic busy_s_o;
logic start_delayed, s_finish_delayed;

logic [DATA_LENGTH-1:0] x_reg, m_reg, m_bl_reg, res_reg;
logic signed [DATA_LENGTH-1:0] minv_reg;

logic [DATA_LENGTH-1:0] lsb_resc_remainder_reg;
logic [DATA_LENGTH-1:0] x_delayed;
logic [2 * DATA_LENGTH-1:0] lsb_rescaled;
logic [DATA_LENGTH-1:0] lsb_reg;

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2 + 5),
    .DATA(1) 
) shift_finish (
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2 + 3),
    .DATA(64)
) shift_in (
    .clk_i(clk_i),
    .data_i(x_i),
    .data_o(x_delayed)
);

always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    x_reg         <= 64'b0;
    m_reg         <= 64'b0;
    m_bl_reg      <= 64'b0;
    minv_reg      <= 64'b0;
    start_delayed <= 0;
  end else begin
    x_reg         <= x_i;
    m_reg         <= m_i;
    m_bl_reg      <= m_bl_i;
    minv_reg      <= minv_i;
    start_delayed <= 1;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    lsb_reg <= 64'b0;
  end else if(start_delayed) begin
    lsb_reg <= x_reg & ((1 << m_bl_reg) - 1);
  end else begin
    lsb_reg <= lsb_reg;
  end
end

// lsb_scaled = (T mod R) * Q'
multiplier_top multiplier_precomp(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_delayed),    // Start signal.
  .busy_o(busy_s_o),          // Module busy.
  .finish_o(s_finish),        // Module finish.
  .indata_a_i(lsb_reg),       // Input data -> operand a.
  .indata_b_i(minv_reg),      // Input data -> operand b.
  .outdata_r_o(lsb_rescaled)
);

// lsb_scaled mod R
always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    lsb_resc_remainder_reg <= 64'b0;
    s_finish_delayed <= 0;
  end else if(s_finish)begin
    lsb_resc_remainder_reg <= lsb_rescaled & ((1 << m_bl_reg) - 1);
    s_finish_delayed <= 1;
  end else begin
    lsb_resc_remainder_reg <= lsb_resc_remainder_reg;
    s_finish_delayed <= 0;
  end
end
// 4c46de
// 4C46DE
// 57F922
// 2BF19233B922
// 57E325

logic [127:0] m_rescaled;
multiplier_top multiplier_approx(
  .clk_i(clk_i),                       // Rising edge active clk.
  .rst_ni(rst_ni),                     // Active low reset.
  .start_i(s_finish_delayed),          // Start signal.
  .busy_o(busy_m_o),                   // Module busy.
  .finish_o(m_finish),                 // Module finish.
  .indata_a_i(lsb_resc_remainder_reg), // Input data -> operand a.
  .indata_b_i(m_reg),                    // Input data -> operand b.
  .outdata_r_o(m_rescaled)
);

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    res_reg <= 64'b0;
  end else if(m_finish)begin
    res_reg <= (x_delayed + m_rescaled) >> m_bl_reg;
  end else begin
    res_reg <= res_reg;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 64'b0;
  end else begin
    result_o <= (res_reg >= m_reg) ? res_reg - m_reg : res_reg;
  end
end

assign valid_o = d_finish;

endmodule : montgomery_pipelined
