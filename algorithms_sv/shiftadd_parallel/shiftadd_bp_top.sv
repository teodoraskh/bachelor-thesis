module shiftadd_bp_top (
  input  logic                               clk_i,
  input  logic                               rst_ni,
  input  logic                               start_i,
  input  logic [DATA_LENGTH-1:0]             x_i,       // Input
  input  logic [DATA_LENGTH-1:0]             m_i,       // Modulus
  input  logic [DATA_LENGTH-1:0]             m_bl_i,
  output logic [DATA_LENGTH-1:0]             result_o,
  output logic                               valid_o    // Result valid flag
);

localparam DATA_LENGTH = 64;


typedef enum logic[2:0] {LOAD, REDUCE, FINISH} state_t;
state_t curr_state, next_state;

logic [DATA_LENGTH-1:0] input_shiftadd;
logic [DATA_LENGTH-1:0] res;
logic [DATA_LENGTH-1:0] result;
logic recursion_done;

// FSM logic
always_comb begin
  next_state = curr_state;
  case (curr_state)
    LOAD: begin
      if (start_i)
        next_state = REDUCE;
    end
    REDUCE: begin
      if (res < m_i && recursion_done) begin
        next_state = FINISH;
      end
      else begin
        next_state = REDUCE;
      end
    end
    FINISH: begin
      next_state = LOAD;
    end
    default: next_state = LOAD;
  endcase
end

shiftadd_parallel shiftadd_module (
  .x_i      (input_shiftadd),
  .m_i      (m_i),
  .m_bl_i   (m_bl_i),
  .result_o (res)
);

always_ff @(posedge clk_i) begin
  if (!rst_ni) begin
    recursion_done <= 1'b0;
  end
  else begin
    recursion_done <= (curr_state == LOAD && start_i) || (curr_state == REDUCE && res >= m_i);
  end
end

always_ff @(posedge clk_i) begin
  if (!rst_ni) begin
    result <= 64'd0;
  end
  else if (curr_state == REDUCE && res < m_i && recursion_done) begin
    result <= res;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    input_shiftadd <= 64'h0;
  end 
  else if (curr_state == LOAD && start_i) begin
    input_shiftadd <= x_i;
  end
  else if (curr_state == REDUCE && res >= m_i) begin
    input_shiftadd <= res;
  end
end

always_ff @(posedge clk_i) begin
  if (!rst_ni) begin
    curr_state <= LOAD;
  end
  else begin
    curr_state <= next_state;
  end
end

assign result_o = result;
assign valid_o  = (curr_state == FINISH);

// always_ff @(posedge clk_i) begin
//     $display("Cycle: %d, State: %s, start_i: %d, res_o: %h, in_shiftadd: %h",
//             $time, curr_state.name(), start_i, result_o, input_shiftadd);
// end

endmodule : shiftadd_bp_top