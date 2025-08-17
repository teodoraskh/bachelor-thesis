import multiplier_pkg::*;
module barrett_bs (
  input  logic                    CLK_pci_sys_clk_p,
  input  logic                    CLK_pci_sys_clk_n,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus
  input  logic [DATA_LENGTH-1:0]  m_bl_i,    // Modulus bitlength
  input  logic [DATA_LENGTH-1:0]  mu_i,      // Modular inverse
  output logic [DATA_LENGTH-1:0]  result_o,  // Result
  output logic                    valid_o    // Result valid flag
);

typedef enum logic[2:0] {LOAD, PRECOMP, APPROX, REDUCE, FINISH} state_t;

logic m_finish_d;
logic busy_a_o;
logic [2 * DATA_LENGTH-1:0] qm_result;
state_t curr_state, next_state;
logic [2 * DATA_LENGTH-1:0] x_mu;
logic [2 * DATA_LENGTH-1:0] xmu_precomp;
logic m_finish;
logic busy_p_o;
logic [DATA_LENGTH-1:0] tmp;
logic [DATA_LENGTH-1:0] x_reg, q_reg, q_bl_reg, mu_reg;
logic [DATA_LENGTH-1:0] result_n, result_p;

logic ctrl_update_operands;
logic ctrl_update_result;
logic ctrl_adjust_result;
logic ctrl_clear_regs;
logic ctrl_update_res_with_xmu;
logic ctrl_update_res_with_qm;

logic clk_i;
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

always_comb begin
  ctrl_update_operands         = (curr_state == LOAD);
  ctrl_update_res_with_xmu     = (curr_state == PRECOMP) && (m_finish == 1);
  ctrl_update_result           = (curr_state == FINISH);
  ctrl_update_res_with_qm      = (curr_state == APPROX) && (a_finish == 1);
  ctrl_adjust_result           = (curr_state == REDUCE);
end

always_ff @(posedge clk_i) begin
    if (rst_ni == 0) begin
      x_reg    <= 0;
      q_reg    <= 0;
      q_bl_reg <= 0;
      mu_reg   <= 0;
    end else if (ctrl_update_operands) begin
      x_reg    <= x_i;
      q_reg    <= m_i;
      q_bl_reg <= m_bl_i;
      mu_reg   <= mu_i;
    end else begin
      x_reg    <= x_reg;
      q_reg    <= q_reg;
      q_bl_reg <= q_bl_reg;
      mu_reg   <= mu_reg;
    end
end

always_ff @(posedge clk_i) begin
    if (rst_ni == 0) begin
        curr_state <= LOAD;
    end
    else begin
        curr_state <= next_state;
    end
end

always_comb begin
    next_state = curr_state; // default is to stay in current state
    case (curr_state)
        LOAD : begin
            if (start_i == 1) begin
                next_state = PRECOMP;
            end
        end
        PRECOMP: begin
            if(m_finish)
              next_state = APPROX;
        end
        APPROX: begin
          if(a_finish)
            next_state = REDUCE;
        end
        REDUCE : begin
          if (adjust_done) begin
            next_state = FINISH;
          end else begin
            next_state = REDUCE; // stay here until done
          end
        end
        FINISH : begin
            next_state = LOAD;
        end
        default : begin
            next_state = LOAD;
        end
    endcase
end

multiplier_bs multiplier_precomp(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_i),          // Start signal.
  .busy_o(busy_p_o),          // Module busy.
  .finish_o(m_finish),        // Module finish.
  .indata_a_i(x_reg),         // Input data -> operand a.
  .indata_b_i(mu_reg),      // Input data -> operand a.
  .result_o(xmu_precomp)
);

multiplier_bs multiplier_approx(
  .clk_i(clk_i),             // Rising edge active clk.
  .rst_ni(rst_ni),           // Active low reset.
  .start_i(m_finish_d),        // Start signal.
  .busy_o(busy_a_o),         // Module busy.
  .finish_o(a_finish),       // Module finish.
  .indata_a_i(result_p),    // Input data -> operand a.
  .indata_b_i(q_reg),        // Input data -> operand b.
  .result_o(qm_result)
);

logic adjust_cycle_done;
logic adjust_done;
assign adjust_done = adjust_cycle_done;
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni || ctrl_update_operands) begin
    adjust_cycle_done <= 1'b0;
  end else if (ctrl_adjust_result) begin
    adjust_cycle_done <= 1'b1;  // done after one cycle in ADJUST
  end else begin
    adjust_cycle_done <= 1'b0;
  end
end

always_ff @(posedge clk_i) begin
    if (ctrl_update_operands || start_i) begin
        result_p <= 0;
    end
    else if (ctrl_update_res_with_xmu) begin
        result_p <= xmu_precomp >> (2 * q_bl_reg); // Approximation step
    end
    else if (ctrl_update_res_with_qm) begin
        result_p <= x_reg - qm_result; // Final reduction step
    end
end

// delays m_finish by 1 cc
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    m_finish_d <= 0;
  else
    m_finish_d <= m_finish;
end

always_ff @(posedge clk_i) begin
  if(!rst_ni || ctrl_update_operands) begin
    result_n <= 64'b0;
  end
  else if (ctrl_adjust_result) begin
    if(result_p >= q_reg) begin
      result_n <= result_p - q_reg;
    end
    else begin
      result_n <= result_p;
    end
  end else begin
    result_n <= 64'b0;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 0;
    valid_o  <= 0;
  end else begin
    result_o <= result_n;
    valid_o  <= (curr_state == FINISH);
  end
end

endmodule : barrett_bs
