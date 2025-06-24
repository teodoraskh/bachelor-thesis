import multiplier_pkg::*;
module barrett_pipelined (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,      // Input x.
  input  logic [DATA_LENGTH-1:0]  q_i,      // Modulus.
  input  logic [DATA_LENGTH-1:0]  q_bl_i,   // Modulus bitlength.
  input  logic [DATA_LENGTH-1:0]  mu_i,     // Modular inverse.
  output logic [DATA_LENGTH-1:0]  result_o, // Result.
  output logic                    valid_o   // Result valid flag.
);
logic busy_p_o;
logic busy_a_o;

logic m_finish, a_finish, d_finish;
logic start_delayed, m_finish_delayed;

logic [DATA_LENGTH-1:0] x_reg, q_reg, q_bl_reg, res_reg, mu_reg;
logic [DATA_LENGTH-1:0] x_delayed;
logic [DATA_LENGTH-1:0] q_approx;

logic [2 * DATA_LENGTH-1:0] qm_result;
logic [2 * DATA_LENGTH-1:0] xmu_precomp;

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2 + 4), // 2 * multiplier latency + 4 (or +1 for each stage)
    .DATA(1)
) shift_finish (
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2 + 2), // 2 * multiplier latency + 2 (2 because we need x_i 2 stages later)
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
    mu_reg        <= 64'b0;
    start_delayed <= 0;
  end else begin
    x_reg         <= x_i;
    q_reg         <= q_i;
    q_bl_reg      <= q_bl_i;
    mu_reg        <= mu_i;
    start_delayed <= 1;
  end
end

// x * mu
multiplier_top multiplier_precomp(
  .clk_i(clk_i),    
  .rst_ni(rst_ni),
  .start_i(start_delayed),
  .busy_o(busy_p_o),
  .finish_o(m_finish),
  .indata_a_i(x_reg),        
  .indata_b_i(mu_reg),
  .outdata_r_o(xmu_precomp)
);

// q <- (x * mu) / 2^2k
always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    q_approx <= 64'b0;
    m_finish_delayed <= 0;
  end else if (m_finish) begin
    q_approx <= xmu_precomp >> (2 * q_bl_i);
    m_finish_delayed <= 1;
  end else begin
    q_approx <= q_approx;
    m_finish_delayed <= 0;
  end
end

// q * M
multiplier_top multiplier_approx(
  .clk_i(clk_i),               // Rising edge active clk.
  .rst_ni(rst_ni),             // Active low reset.
  .start_i(m_finish_delayed),  // Start signal.
  .busy_o(busy_a_o),           // Module busy.
  .finish_o(a_finish),         // Module finish.
  .indata_a_i(q_approx),       // Input data -> operand a.
  .indata_b_i(q_reg),          // Input data -> operand b.
  .outdata_r_o(qm_result)
);

// r <- (x - q * M)
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    res_reg <= 64'b0;
  end else if (a_finish) begin
    res_reg <= x_delayed - qm_result;
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

endmodule : barrett_pipelined
