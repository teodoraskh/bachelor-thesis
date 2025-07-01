import multiplier_pkg::*;
module reduction_top (
  input  logic                    CLK_pci_sys_clk_p,
  input  logic                    CLK_pci_sys_clk_n,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input (e.g., 64-bit)
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus (e.g., 32-bit)
  output logic [DATA_LENGTH-1:0]  result_o,
  output logic                    valid_o    // Result valid flag
);

logic start_delayed;
logic clk_i;
logic [DATA_LENGTH-1:0] x_reg, red_reg;

`ifdef SIMULATION
    assign clk_i = CLK_pci_sys_clk_p; // Fake the clock in simulation
`else
    clk_wiz_0 cw (
      .clk_in1_p(CLK_pci_sys_clk_p),
      .clk_in1_n(CLK_pci_sys_clk_n),
      .clk_out1(clk_i),
      .reset(~rst_ni)
    );
`endif

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
  end else begin
    x_reg     <= x_reg;
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