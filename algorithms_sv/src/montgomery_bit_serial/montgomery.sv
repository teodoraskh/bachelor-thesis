import multiplier_pkg::*;
module montgomery_bs (
  input  logic                    CLK_pci_sys_clk_p,
  input  logic                    CLK_pci_sys_clk_n,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input: the result of the multiplication (in Montgomery form)
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus
  input  logic [DATA_LENGTH-1:0]  m_bl_i,    // Modulus bitlength
  input  logic [DATA_LENGTH-1:0]  minv_i,    // Modular inverse
  output logic [DATA_LENGTH-1:0]  result_o,  // Result (will be out of Montgomery form)
  output logic                    valid_o    // Result valid flag
);

typedef enum logic[2:0] {LOAD, SCALE_LSB, RESC_IN, REDUCE, FINISH} state_t;

state_t curr_state, next_state;

logic [2 * DATA_LENGTH-1:0] m_rescaled;
logic [2 * DATA_LENGTH-1:0] lsb_scaled;
logic [2 * DATA_LENGTH-1:0] x_mu;

logic [DATA_LENGTH-1:0] tmp;
logic [DATA_LENGTH-1:0] x_reg, m_reg, m_bl_reg, minv_reg;
logic [DATA_LENGTH-1:0] result_n, result_p;
logic adjust_cycle_done;
logic adjust_done;
logic m_finish_d;
logic m_finish;
logic busy_p_o;
logic busy_a_o;

logic ctrl_update_operands;
logic ctrl_update_result;
logic ctrl_adjust_result;
logic ctrl_clear_regs;
logic ctrl_update_res_with_lsb;
logic ctrl_update_res_with_m_resc;

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
  ctrl_update_res_with_lsb     = (curr_state == SCALE_LSB) && (m_finish == 1);
  ctrl_update_result           = (curr_state == FINISH);
  ctrl_update_res_with_m_resc  = (curr_state == RESC_IN) && (a_finish == 1);
  ctrl_adjust_result           = (curr_state == REDUCE);
end

always_ff @(posedge clk_i) begin
    if (rst_ni == 0) begin
      x_reg    <= 0;
      m_reg    <= 0;
      m_bl_reg <= 0;
      minv_reg <= 0;
    end else if (ctrl_update_operands) begin
      x_reg    <= x_i;
      m_reg    <= m_i;
      m_bl_reg <= m_bl_i;
      minv_reg <= minv_i;
    end else begin
      x_reg    <= x_reg;
      m_reg    <= m_reg;
      m_bl_reg <= m_bl_reg;
      minv_reg <= minv_reg;
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
                next_state = SCALE_LSB;
            end
        end
        SCALE_LSB: begin
            if(m_finish)
              next_state = RESC_IN;
        end
        RESC_IN: begin
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
  .indata_a_i(x_reg & ((1 << m_bl_reg) - 1)),         // Input data -> operand a.
  .indata_b_i(minv_reg),      // Input data -> operand a.
  .result_o(lsb_scaled)
);

// delays m_finish by 1 cc
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    m_finish_d <= 0;
  else
    m_finish_d <= m_finish;
end

multiplier_bs multiplier_approx(
  .clk_i(clk_i),             // Rising edge active clk.
  .rst_ni(rst_ni),           // Active low reset.
  .start_i(m_finish_d),        // Start signal.
  .busy_o(busy_a_o),         // Module busy.
  .finish_o(a_finish),       // Module finish.
  .indata_a_i(result_p ),    // Input data -> operand a.
  .indata_b_i(m_reg),        // Input data -> operand b.
  .result_o(m_rescaled)
);

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
    else if (ctrl_update_res_with_lsb) begin
        result_p <= lsb_scaled & ((1 << m_bl_reg) - 1); // Approximation step
    end
    else if (ctrl_update_res_with_m_resc) begin
      result_p <= x_reg + m_rescaled >> m_bl_reg;
    end
end

always_ff @(posedge clk_i) begin
  if(!rst_ni || ctrl_update_operands) begin
    result_n <= 64'b0;
  end
  else if (ctrl_adjust_result) begin
    if(result_p >= m_reg) begin
      result_n <= result_p - m_reg;
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

endmodule : montgomery_bs
