import multiplier_pkg::*;

module montgomery_parallel_top (
  input  logic                      clk_i,
  input  logic                      rst_ni,
  input  logic                      start_i,
  input  logic [DATA_LENGTH-1:0]    x_i,
  input  logic [DATA_LENGTH-1:0]    m_i,
  input  logic [DATA_LENGTH-1:0]    m_bl_i,
  input  logic signed [DATA_LENGTH-1:0]    minv_i,
  output logic [DATA_LENGTH-1:0]    result_o,
  output logic                      valid_o
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

//----------------------- Barrett arithmetic -> 1 cycle -----------------------
montgomery_parallel parallel_module(
  .x_i          (x_reg),
  .m_i          (m_i),
  .m_bl_i       (m_bl_i),
  .minv_i       (minv_i),
  .result_o     (red_reg)
);

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

endmodule : montgomery_parallel_top