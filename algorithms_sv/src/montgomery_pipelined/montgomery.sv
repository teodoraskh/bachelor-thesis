import multiplier_pkg::*;
module montgomery_pipelined (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input x.
  input  logic [DATA_LENGTH-1:0]  q_i,       // Modulus.
  input  logic [DATA_LENGTH-1:0]  q_bl_i,    // Modulus bitlength.
  input  logic [DATA_LENGTH-1:0]  qinv_i,    // Modular inverse.
  output logic [DATA_LENGTH-1:0]  result_o,  // Result.
  output logic                    valid_o    // Result valid flag
);
logic busy_m_o;
logic busy_s_o;

logic s_finish, m_finish, d_finish;
logic start_delayed, s_finish_delayed;

logic [DATA_LENGTH-1:0] x_reg, q_reg, q_bl_reg, res_reg;
logic [DATA_LENGTH-1:0] qinv_reg;
logic [DATA_LENGTH-1:0] m_reg;
logic [DATA_LENGTH-1:0] lsb_reg;
logic [DATA_LENGTH-1:0] x_delayed;

logic [2 * DATA_LENGTH-1:0] m_rescaled;
logic [2 * DATA_LENGTH-1:0] lsb_rescaled;

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2 + 5), // 2 * multiplier latency + 5 (or +1 for each stage)
    .DATA(1) 
) shift_finish (
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2 + 3), // 2 * multiplier latency + 3 (3 because we need x_i 3 cycles later)
    .DATA(64)
) shift_in (
    .clk_i(clk_i),
    .data_i(x_i),
    .data_o(x_delayed)
);

// LOAD
always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    x_reg         <= 64'b0;
    q_reg         <= 64'b0;
    q_bl_reg      <= 64'b0;
    qinv_reg      <= 64'b0;
    start_delayed <= 0;
  end else begin
    x_reg         <= x_i;
    q_reg         <= q_i;
    q_bl_reg      <= q_bl_i;
    qinv_reg      <= qinv_i;
    start_delayed <= 1;
  end
end

// x mod R
always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    lsb_reg <= 64'b0;
  end else if(start_delayed) begin
    lsb_reg <= x_reg & ((1 << q_bl_reg) - 1);
  end else begin
    lsb_reg <= lsb_reg;
  end
end

// (x mod R) * Q'
multiplier_top multiplier_precomp(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_delayed),    // Start signal.
  .busy_o(busy_s_o),          // Module busy.
  .finish_o(s_finish),        // Module finish.
  .indata_a_i(lsb_reg),       // Input data -> operand a.
  .indata_b_i(qinv_reg),      // Input data -> operand b.
  .outdata_r_o(lsb_rescaled)
);

// m <- (x mod R) * Q' mod R
always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    m_reg <= 64'b0;
    s_finish_delayed <= 0;
  end else if(s_finish)begin
    m_reg <= lsb_rescaled & ((1 << q_bl_reg) - 1);
    s_finish_delayed <= 1;
  end else begin
    m_reg <= m_reg;
    s_finish_delayed <= 0;
  end
end

// m * Q
multiplier_top multiplier_approx(
  .clk_i(clk_i),                       // Rising edge active clk.
  .rst_ni(rst_ni),                     // Active low reset.
  .start_i(s_finish_delayed),          // Start signal.
  .busy_o(busy_m_o),                   // Module busy.
  .finish_o(m_finish),                 // Module finish.
  .indata_a_i(m_reg),                  // Input data -> operand a.
  .indata_b_i(q_reg),                  // Input data -> operand b.
  .outdata_r_o(m_rescaled)
);

// t <- (x + m * Q) / R
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    res_reg <= 64'b0;
  end else if(m_finish)begin
    res_reg <= (x_delayed + m_rescaled) >> q_bl_reg;
  end else begin
    res_reg <= res_reg;
  end
end

// Conditional subtraction
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 64'b0;
  end else begin
    result_o <= (res_reg >= q_reg) ? res_reg - q_reg : res_reg;
  end
end

assign valid_o = d_finish;

endmodule : montgomery_pipelined
