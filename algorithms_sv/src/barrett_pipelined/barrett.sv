import multiplier_pkg::*;
module barrett_pipelined (
  input  logic                    CLK_pci_sys_clk_p,
  input  logic                    CLK_pci_sys_clk_n,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,      // Input x.
  input  logic [DATA_LENGTH-1:0]  q_i,      // Modulus.
  input  logic [DATA_LENGTH-1:0]  q_bl_i,   // Modulus bitlength.
  input  logic [DATA_LENGTH-1:0]  mu_i,     // Modular inverse.
  output logic [DATA_LENGTH-1:0]  result_o, // Result.
  output logic                    valid_o   // Result valid flag.
);
localparam MULTIPLIER_DEPTH = NUM_MULS + 2;
localparam PIPELINE_DEPTH   = MULTIPLIER_DEPTH * 2 + 6;


logic [1:0] start_delayed [PIPELINE_DEPTH-1:0];

logic busy_p_o;
logic busy_a_o;
logic clk_i;

logic m_finish, a_finish, d_finish;
logic m_finish_delayed;

logic [DATA_LENGTH-1:0] x_reg, q_reg, q_bl_reg, res_reg, mu_reg;
logic [DATA_LENGTH-1:0] x_delayed;
logic [DATA_LENGTH-1:0] q_approx;

logic [2 * DATA_LENGTH-1:0] qm_result;
logic [2 * DATA_LENGTH-1:0] qm_result_reg;
logic [2 * DATA_LENGTH-1:0] xmu_precomp;
logic [2 * DATA_LENGTH-1:0] xmu_precomp_reg;

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
    .SHIFT((NUM_MULS + 2) * 2 + 4), // 2 * multiplier latency + 5 (5 because we need x_i 4 stages later)
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
  end else begin
    x_reg         <= x_i;
    q_reg         <= q_i;
    q_bl_reg      <= q_bl_i;
    mu_reg        <= mu_i;
  end
end

// x * mu
multiplier_top multiplier_precomp(
  .clk_i(clk_i),
  .rst_ni(rst_ni),
  .start_i(start_delayed[1]),
  .busy_o(busy_p_o),
  .finish_o(m_finish),
  .indata_a_i(x_reg),
  .indata_b_i(mu_reg),
  .outdata_r_o(xmu_precomp)
);

// pipeline register for lsb_rescaled
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    xmu_precomp_reg <= '0;
  end else if (start_delayed[MULTIPLIER_DEPTH + 1]) begin
    xmu_precomp_reg <= xmu_precomp;
  end
end

// q <- (x * mu) / 2^2k
always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    q_approx <= 64'b0;
  end else if (m_finish) begin
    q_approx <= xmu_precomp_reg >> (2 * q_bl_i);
  end else begin
    q_approx <= q_approx;
  end
end

// q * M
multiplier_top multiplier_approx(
  .clk_i(clk_i),               // Rising edge active clk.
  .rst_ni(rst_ni),             // Active low reset.
  .start_i(start_delayed[MULTIPLIER_DEPTH + 3]),  // Start signal.
  .busy_o(busy_a_o),           // Module busy.
  .finish_o(a_finish),         // Module finish.
  .indata_a_i(q_approx),       // Input data -> operand a.
  .indata_b_i(q_reg),          // Input data -> operand b.
  .outdata_r_o(qm_result)
);

// pipeline register for qm_result
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    qm_result_reg <= '0;
  end else if (start_delayed[MULTIPLIER_DEPTH * 2 + 4]) begin
    qm_result_reg <= qm_result;
  end
end

// r <- (x - q * M)
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    res_reg <= 64'b0;
  end else if (start_delayed[MULTIPLIER_DEPTH * 2 + 5]) begin
    res_reg <= x_delayed - qm_result_reg;
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

assign valid_o = start_delayed[PIPELINE_DEPTH - 1];

endmodule : barrett_pipelined
