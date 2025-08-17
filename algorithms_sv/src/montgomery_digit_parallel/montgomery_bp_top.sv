import multiplier_pkg::*;

module montgomery_parallel_top (
  input  logic                    CLK_pci_sys_clk_p, // Clocking wizard positive clock
  input  logic                    CLK_pci_sys_clk_n, // Clocking wizard negative clock
  input  logic                      rst_ni,
  input  logic                      start_i,
  input  logic [DATA_LENGTH-1:0]    x_i,          // Input: the result of the multiplication (in Montgomery form)
  input  logic [DATA_LENGTH-1:0]    m_i,          // Modulus
  input  logic [DATA_LENGTH-1:0]    m_bl_i,       // Modulus bitlength
  input  logic [DATA_LENGTH-1:0]    minv_i,       // Modular inverse
  output logic [DATA_LENGTH-1:0]    result_o,     // Result (will be out of Montgomery form)
  output logic                      valid_o       // Valid signal
);
logic start_delayed;
logic clk_i;


logic [DATA_LENGTH-1:0] x_reg, m_reg, m_bl_reg, minv_reg, red_reg;

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
    m_reg     <= 0;
    m_bl_reg  <= 0;
    minv_reg  <= 0;
  end else if(start_i) begin
    x_reg     <= x_i;
    m_reg     <= m_i;
    m_bl_reg  <= m_bl_i;
    minv_reg  <= minv_i;
  end else begin
    x_reg     <= x_reg;
    m_reg     <= m_reg;
    m_bl_reg  <= m_bl_reg;
    minv_reg  <= minv_reg;
  end
end

//----------------------- Montgomery arithmetic -> 1 cycle -----------------------
montgomery_parallel parallel_module(
  .x_i          (x_reg),
  .m_i          (m_reg),
  .m_bl_i       (m_bl_reg),
  .minv_i       (minv_reg),
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