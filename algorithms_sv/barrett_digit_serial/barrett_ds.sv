module barrett_ds (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [63:0]             x_i,       // Input
  input  logic [63:0]             m_i,       // Modulus
  input  logic [63:0]             m_bl_i,    // Modulus bitlength
  input  logic [63:0]             mu_i,      // Precomputed mu
  output logic [127:0]            result_o,  // Result
  output logic                    valid_o    // Result valid flag
);

typedef enum logic[2:0] {LOAD, PRECOMP, APPROX, REDUCE, FINISH} state_t;

state_t curr_state, next_state;
logic [127:0] x_mu;
logic [63:0] q_m;
logic [63:0] tmp;
logic [63:0] mul_i;
logic [63:0] result_n, result_p;


logic ctrl_update_operands;
logic ctrl_update_result;
logic ctrl_adjust_result;
logic ctrl_clear_regs;
logic ctrl_update_res_with_xmu;
logic ctrl_update_res_with_qm;

// =======================================================================
//  It is serialized, in the sense that it uses the 16x16-bit 
//  serial multiplier. This seemed like the least error-prone approach 
//  given the chained multiplications + the shift.
// =======================================================================


always_comb begin
  ctrl_update_operands    = (curr_state == LOAD);
  ctrl_update_res_with_xmu= (curr_state == PRECOMP) && (m_finish == 1);
  ctrl_update_result      = (curr_state == FINISH);
  ctrl_update_res_with_qm = (curr_state == APPROX) && (a_finish == 1);
  ctrl_adjust_result      = (curr_state == REDUCE);
end

always_ff @(posedge clk_i) begin
    if (rst_ni == 0) begin
        mul_i <= 0;
    end 
    else if (ctrl_update_operands) begin
        mul_i <= x_i;
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


logic [127:0] xmu_precomp;
logic m_finish;
logic busy_p_o;
multiplier_top multiplier_precomp(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_i),          // Start signal.
  .busy_o(busy_p_o),          // Module busy.
  .finish_o(m_finish),        // Module finish.
  .indata_a_i(mul_i),         // Input data -> operand a.
  .indata_b_i(mu_i),          // Input data -> operand a.
  .outdata_r_o(xmu_precomp)
);

logic busy_a_o;
logic [127:0] qm_result;
multiplier_top multiplier_approx(
  .clk_i(clk_i),             // Rising edge active clk.
  .rst_ni(rst_ni),           // Active low reset.
  .start_i(m_finish),        // Start signal.
  .busy_o(busy_a_o),         // Module busy.
  .finish_o(a_finish),       // Module finish.
  .indata_a_i(result_p),     // Input data -> operand a.
  .indata_b_i(m_i),          // Input data -> operand b.
  .outdata_r_o(qm_result)
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
        result_p <= xmu_precomp >> (2 * m_bl_i); // Approximation step
    end
    else if (ctrl_update_res_with_qm) begin
        result_p <= mul_i - qm_result; // Final reduction step
    end
end

always_ff @(posedge clk_i) begin
  if(!rst_ni || ctrl_update_operands) begin
    result_n <= 64'b0;
  end
  else if (ctrl_adjust_result) begin
    if(result_p >= m_i) begin
      result_n <= result_p - m_i;
    end 
    else begin
      result_n <= result_p;
    end
  end else begin
    result_n <= 64'b0;
  end
end


assign valid_o  = (curr_state == FINISH);
assign result_o = result_n;


endmodule : barrett_ds
