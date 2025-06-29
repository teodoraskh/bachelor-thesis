import multiplier_pkg::*;
module reduction_top (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input (e.g., 64-bit)
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus (e.g., 32-bit)
  output logic [DATA_LENGTH-1:0]  result_o,
  output logic                    valid_o    // Result valid flag
);

logic start_delayed;

logic [DATA_LENGTH-1:0] x_reg, red_reg;

shiftreg #(
    .SHIFT(3), // 1 for each delaying cycle
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
    end else if(start_i) begin
      x_reg     <= x_i;
    end
end

//----------------------- dilithium arithmetic -> 1 cycle -----------------------
reduction dilithium(
  .x_i          (x_reg),
  .m_i          (m_i),
  .result_o     (red_reg)
);

//----------------------- Getting the output -> 1 cycle -----------------------
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 0;
    valid_o  <= 0;
  end else begin
    result_o <= (red_reg > m_i) ? red_reg - m_i : red_reg;
    valid_o  <= start_delayed;
  end
end


endmodule : reduction_top