import multiplier_pkg::*;

module shiftadd_parallel_top (
  input  logic                      CLK_pci_sys_clk_p,
  input  logic                      CLK_pci_sys_clk_n,
  input  logic                      rst_ni,
  input  logic                      start_i,
  input  logic [DATA_LENGTH-1:0]    x_i,
  input  logic [DATA_LENGTH-1:0]    m_i,
  input  logic [DATA_LENGTH-1:0]    m_bl_i,
  output logic [DATA_LENGTH-1:0]    result_o,
  output logic                      valid_o
);
// This could be a tunable parameter though
// This is the recursion depth for dilithium though
// I think for 64-bit inputs this should be enough
localparam NUM_RED = 3;

logic start_delayed;
logic clk_i;
logic [DATA_LENGTH-1:0] m_reg, m_bl_reg;

logic [DATA_LENGTH-1:0] x_delayed [NUM_RED-1:0];
logic [DATA_LENGTH-1:0] res_delayed [NUM_RED-1:0];
logic finish_delayed [NUM_RED-1:0];


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
    m_reg     <= 0;
    m_bl_reg  <= 0;
  end else if(start_i) begin
    m_reg     <= m_i;
    m_bl_reg  <= m_bl_i;
  end else begin
    m_reg     <= m_reg;
    m_bl_reg  <= m_bl_reg;
  end
end


always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    x_delayed[0] <= '0;
    x_delayed[1] <= '0;
    x_delayed[2] <= '0;
  end else begin
    x_delayed[0] <= x_i;
    x_delayed[1] <= res_delayed[0];
    x_delayed[2] <= res_delayed[1];
  end
end

genvar i;
generate
  for (i = 0; i < NUM_RED; i++) begin
    shiftadd_parallel parallel_module(
      .x_i          (x_delayed[i]),
      .m_i          (m_reg),
      .m_bl_i       (m_bl_reg),
      .result_o     (res_delayed[i])
    );
  end
endgenerate


always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 0;
    valid_o  <= 0;
  end else begin
    result_o <= (res_delayed[NUM_RED-1] > m_i) ? res_delayed[NUM_RED-1] - m_i : res_delayed[NUM_RED-1];
    valid_o  <= start_delayed;
  end
end


endmodule : shiftadd_parallel_top