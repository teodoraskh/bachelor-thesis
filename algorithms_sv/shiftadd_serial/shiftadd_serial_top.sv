module shiftadd_serial_top (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus
  input  logic [DATA_LENGTH-1:0]  m_bl_i,
  output logic [DATA_LENGTH-1:0]  result_o,
  output logic                    valid_o    // Result valid flag
);
localparam DATA_LENGTH = 64;
typedef enum logic[2:0] {LOAD, REDUCE, FINISH} state_t;
state_t curr_state, next_state;

logic entered_reduce;
logic state_was_reduce;
logic recurse_condition_met;
logic prev_recurse_condition_met;
logic recurse_pulse;
logic trigger_start;
logic start_flag;
logic start_module;


assign recurse_condition_met = (curr_state == REDUCE) && valid_rec && (res >= m_i);
assign recurse_pulse = recurse_condition_met && !prev_recurse_condition_met;
assign entered_reduce = (curr_state == REDUCE) && !state_was_reduce;
assign trigger_start = entered_reduce || recurse_pulse;
// we need start_module high for two cycles since entered_reduce or recurse_pulse
// one cycle will not suffice and it will get it stuck in load in the next recursion
assign start_module = trigger_start || start_flag;

// but this: (valid_rec && (res >= m_i) can be true for multiple cycles, and we only want to capture the edge.
// assign ctrl_recurse = ((curr_state == REDUCE) && !state_was_reduce) || (valid_rec && (res >= m_i));


// always_ff @(posedge clk_i) begin
//     $display("Cycle: %d, State: %s, start_i: %d, res: %h, recurse?: %d",
//             $time, curr_state.name(), start_i, res, start_module);
// end


always_comb begin
  next_state = curr_state;
  case (curr_state)
      LOAD : begin
          if (start_i) begin
            next_state = REDUCE;
          end
      end
      REDUCE : begin
        if (valid_rec && res < m_i) begin
          next_state = FINISH;
        end else begin
          next_state = REDUCE;
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


logic [63:0] input_shiftadd;
logic [63:0] res;
logic [63:0] result;
logic valid_rec;

shiftadd_serialized shiftadd_module(
  .clk_i      (clk_i),
  .rst_ni     (rst_ni),
  .start_i    (start_module),
  .x_i        (input_shiftadd),
  .m_i        (m_i),
  .m_bl_i     (m_bl_i),
  .result_o   (res),
  .valid_o    (valid_rec)
);

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    start_flag <= 1'b0;
  else
    start_flag <= trigger_start;
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    prev_recurse_condition_met <= 1'b0;
  else
    prev_recurse_condition_met <= recurse_condition_met;
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    state_was_reduce <= 1'b0;
  else
    state_was_reduce <= (curr_state == REDUCE);
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    result <= 0;
  else if (valid_rec)
    result <= res;
  else if (start_i)
    result <= x_i;
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    input_shiftadd <= 0;
  else if (valid_rec)
    input_shiftadd <= res;
  else if (start_i)
    input_shiftadd <= x_i;
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    curr_state  <= LOAD;
  end else begin
    curr_state  <= next_state;
  end
end

assign result_o = result;
assign valid_o  = (curr_state == FINISH);

endmodule : shiftadd_serial_top