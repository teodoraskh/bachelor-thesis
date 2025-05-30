module shiftadd_pipelined_top (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [63:0]             x_i,
  input  logic [63:0]             m_i,
  input  logic [63:0]             m_bl_i,
  output logic [63:0]             result_o,
  output logic                    valid_o
);

logic [63:0] res;
logic valid_rec;
localparam NUM_IN = 1;
localparam DATA_LENGTH = 64;
typedef enum logic[2:0] {LOAD, REDUCE, FINISH} state_t;
state_t curr_state, next_state;

logic [63:0] queue [NUM_IN-1:0];
logic needs_recursion [NUM_IN-1:0];

logic recurse_d;
logic start_module;
logic recurse_now;
logic recurse;

assign recurse = (res >= m_i);

assign start_module = start_i || recurse;

always_comb begin
  next_state = curr_state;
  case (curr_state)
      LOAD : begin
          if (start_module) begin
            next_state = REDUCE;
          end
      end
      REDUCE : begin
        if (!recurse) begin
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


shiftadd_pipelined shiftadd (
  .clk_i      (clk_i),
  .rst_ni     (rst_ni),
  .start_i    (start_module),
  .x_i        (input_shiftadd),
  .m_i        (m_i),
  .m_bl_i     (m_bl_i),
  .result_o   (res),
  .valid_o    (valid_rec)
);

logic valid_rec_d1, valid_rec_d2;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    valid_rec_d1 <= 1'b0;
    valid_rec_d2 <= 1'b0;
  end else begin
    valid_rec_d1 <= valid_rec;
    valid_rec_d2 <= valid_rec_d1;
  end
end

logic [63:0] input_shiftadd;
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    input_shiftadd <= 0;
  else if (valid_rec_d2 && queue[read_index] >= m_i)
    input_shiftadd <= queue[read_index];
  else if (start_i)
    input_shiftadd <= x_i;
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 64'd0;
    valid_o <= 0;
    // remove "&& res < m_i" to make it not recurse
  end else if (valid_rec_d1 && res < m_i) begin
    result_o <= res;
    valid_o <= valid_rec_d1;
  end
end

logic [8:0] write_index;
logic [8:0] read_index;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni || write_index == NUM_IN-1) begin
    write_index <= 0;
  end else if (valid_rec_d1) begin
    write_index <= write_index + 1;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni || read_index == NUM_IN-1) begin
    read_index <= 0;
  end else if (start_module) begin
    read_index <= read_index + 1;
  end
end
logic [63:0] queue_0;
assign queue_0 = queue[0];

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    queue[0] <= 64'd0;
  end else if (valid_rec_d1 && res >= m_i) begin
    queue[write_index] <= res;
  end
  // think of what you could do in this other case
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 64'd0;
    valid_o <= 0;
    // remove "&& res < m_i" to make it not recurse
  end else if (valid_rec_d1 && res < m_i) begin
    result_o <= res;
    valid_o <= valid_rec_d1;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    curr_state <= LOAD;
  else
    curr_state <= next_state;
end

always_ff @(posedge clk_i) begin
    $display("Cycle: %d, State: %s, start_i: %d",
            $time, curr_state.name(), start_module);
end

endmodule
