import multiplier_pkg::*;
module montgomery_pipelined (
  input  logic                    CLK_pci_sys_clk_p,
  input  logic                    CLK_pci_sys_clk_n,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input: the result of the multiplication (in Montgomery form)
  input  logic [DATA_LENGTH-1:0]  q_i,       // Modulus.
  input  logic [DATA_LENGTH-1:0]  q_bl_i,    // Modulus bitlength.
  input  logic [DATA_LENGTH-1:0]  qinv_i,    // Modular inverse.
  output logic [DATA_LENGTH-1:0]  result_o,  // Result (will be out of Montgomery form)
  output logic                    valid_o    // Result valid flag.
);
localparam MULTIPLIER_DEPTH = NUM_MULS + 2;
localparam PIPELINE_DEPTH   = MULTIPLIER_DEPTH * 2 + 7;

logic start_delayed [PIPELINE_DEPTH-1:0];

logic busy_m_o;
logic busy_s_o;
logic clk_i;

logic s_finish, m_finish, d_finish;

logic [DATA_LENGTH-1:0] x_reg, q_reg, q_bl_reg, res_reg, qinv_reg, m_reg, lsb_reg;
logic [DATA_LENGTH-1:0] x_delayed;

logic [2 * DATA_LENGTH-1:0] m_rescaled;
logic [2 * DATA_LENGTH-1:0] m_rescaled_reg;
logic [2 * DATA_LENGTH-1:0] lsb_rescaled;
logic [2 * DATA_LENGTH-1:0] lsb_rescaled_reg;

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

always @(posedge clk_i) begin
    start_delayed[0] <= start_i;
end

generate
    for(genvar shft=0; shft < PIPELINE_DEPTH-1; shft=shft+1) begin: DELAY_BLOCK
        always @(posedge clk_i) begin
            start_delayed[shft+1] <= start_delayed[shft];
        end
    end
endgenerate

shiftreg #(
    .SHIFT(MULTIPLIER_DEPTH * 2 + 5), // 2 * multiplier latency + 5 (5 because we need x_i 5 stages later)
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
  end else if (start_i) begin
    x_reg         <= x_i;
    q_reg         <= q_i;
    q_bl_reg      <= q_bl_i;
    qinv_reg      <= qinv_i;
  end else begin
    x_reg         <= x_reg;
    q_reg         <= q_reg;
    q_bl_reg      <= q_bl_reg;
    qinv_reg      <= qinv_reg;
  end

end

// x mod R
always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    lsb_reg <= 64'b0;
  end else if(start_delayed[0]) begin
    lsb_reg <= x_reg & ((1 << q_bl_reg) - 1);
  end else begin
    lsb_reg <= lsb_reg;
  end
end

// (x mod R) * Q'
multiplier_top multiplier_scale_lsb(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_delayed[1]), // Start signal.
  .busy_o(busy_s_o),          // Module busy.
  .finish_o(s_finish),        // Module finish.
  .indata_a_i(lsb_reg),       // Input data -> operand a.
  .indata_b_i(qinv_reg),      // Input data -> operand b.
  .outdata_r_o(lsb_rescaled)
);

// pipeline register for lsb_rescaled
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    lsb_rescaled_reg <= 0;
  end else if (start_delayed[MULTIPLIER_DEPTH + 1]) begin
    lsb_rescaled_reg <= lsb_rescaled;
  end
end

logic smth1;
assign smth1 = start_delayed[MULTIPLIER_DEPTH + 1];

// m <- (x mod R) * Q' mod R
always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    m_reg <= 64'b0;
  end else if(start_delayed[MULTIPLIER_DEPTH + 2])begin
    m_reg <= lsb_rescaled_reg & ((1 << q_bl_reg) - 1);
  end else begin
    m_reg <= m_reg;
  end
end

// m * Q
multiplier_top multiplier_rescale_input(
  .clk_i(clk_i),                       // Rising edge active clk.
  .rst_ni(rst_ni),                     // Active low reset.
  .start_i(start_delayed[MULTIPLIER_DEPTH + 3]),// Start signal.
  .busy_o(busy_m_o),                   // Module busy.
  .finish_o(m_finish),                 // Module finish.
  .indata_a_i(m_reg),                  // Input data -> operand a.
  .indata_b_i(q_reg),                  // Input data -> operand b.
  .outdata_r_o(m_rescaled)
);

// pipeline register for m_rescaled
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    m_rescaled_reg <= '0;
  end else if (start_delayed[MULTIPLIER_DEPTH * 2 + 3]) begin
    m_rescaled_reg <= m_rescaled;
  end
end

// t <- (x + m * Q) / R
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    res_reg <= 64'b0;
  end else if(start_delayed[MULTIPLIER_DEPTH * 2 + 4])begin
    res_reg <= (x_delayed + m_rescaled_reg) >> q_bl_reg;
  end else begin
    res_reg <= res_reg;
  end
end

// Conditional subtraction
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 64'b0;
  end else if (start_delayed[MULTIPLIER_DEPTH * 2 + 5]) begin
    result_o <= (res_reg >= q_reg) ? res_reg - q_reg : res_reg;
  end else begin
    result_o <= result_o;
  end
end

assign valid_o = start_delayed[PIPELINE_DEPTH - 1];

endmodule : montgomery_pipelined
