// TODO: now this will work just fine for 64bit values
//       might need to be used as a standalone module for 64x64

module barrett_pipelined (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [63:0]             x_i,       // Input (e.g., 64-bit)
  input  logic [63:0]             m_i,       // Modulus (e.g., 32-bit)
  input  logic [63:0]             mu_i,      // Precomputed μ
  output logic [127:0]            result_o,
  output logic                    valid_o    // Result valid flag
);

// PRECOMP, APPROX, 
typedef enum logic[2:0] {LOAD, PRECOMP, APPROX, REDUCE, FINISH} state_t;

state_t curr_state, next_state;

logic p_finish, a_finish;
logic d_finish;

// TODO: but is this really necessary in this case?
shiftreg #(
  //4, because we only have 4 pipeline stages without intermediate steps for Barrett reduction
  // might have to change it to NUM_MULS + 2 + 4 when we use pipelined multiplication too
    .SHIFT(4), //4, because we only have 4 pipeline stages without intermediate steps
    .DATA(1) // sets the width of the data being shifted (1 bit wide)
) shift_finish ( // HINT: this is the name of the module
    // these are port connections:
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);

always_comb begin
    next_state = curr_state; // default is to stay in current state
    case (curr_state)
        LOAD : begin
            if (start_i == 1) begin
                next_state = PRECOMP;
            end
        end
        PRECOMP: begin
          if(p_finish) begin // p_finish can indicate that the multiplication has completed
            next_state = APPROX;
          end
        end
        APPROX: begin
          if(a_finish) begin // a_finish can indicate that the approximation has completed
            next_state = REDUCE;
          end
        end
        REDUCE : begin
            if (d_finish) begin
                next_state = FINISH;
            end
        end
        FINISH : begin
            next_state = FINISH;
        end
        default : begin
            next_state = LOAD;
        end
    endcase
end

logic [63:0] x_pipe [3:0];  // Propagates x through stages
logic [63:0] m_pipe [3:0];   // Propagates m through stages
logic [63:0] q_pipe [1:0];   // Stores intermediate q

// Stage 1: Multiply x * μ
logic [127:0] x_mu;
always_ff @(posedge clk_i) begin
  x_mu <= x_i * mu_i; // This will be assigned the result of the multiplier module
  x_pipe[0] <= x_i;  // Shift x to next stage
  m_pipe[0] <= m_i;  // Shift m to next stage
end

// Stage 2: Truncate q = floor(x * μ / 2^2k)
always_ff @(posedge clk_i) begin
  // i think it's okay to leave this here since bitshifts are not costly
  // 2*K could be part from a package
  q_pipe[0] <= x_mu >> (2 * $bits(m_i));  // Truncate
  x_pipe[1] <= x_pipe[0];      // Shift x
  m_pipe[1] <= m_pipe[0];      // Shift m
end

// Stage 3: Multiply q * m
logic [63:0] q_m;
always_ff @(posedge clk_i) begin
  q_m <= q_pipe[0] * m_pipe[1];
  x_pipe[2] <= x_pipe[1];  // Shift x
  m_pipe[2] <= m_pipe[1];  // Shift m (unused)
end

// Stage 4: Subtract x - (q * m) and correct
logic [63:0] tmp;
always_ff @(posedge clk_i) begin
  tmp = x_pipe[2] - q_m;
  result_o <= (tmp < m_pipe[2]) ? tmp : tmp - m_pipe[2];
  // valid_o  <= 1'b1;  // Result valid
end

// logic busy_p_o;
// logic [127:0] xmu_precomp;
// multiplier_top multiplier(
//     .clk_i(clk_i),              // Rising edge active clk.
//     .rst_ni(rst_ni),            // Active low reset.
//     .start_i(start_i),          // Start signal.
//     .busy_o(busy_p_o),          // Module busy.
//     .finish_o(p_finish),        // Module finish.
//     .indata_a_i(x_i),           // Input data -> operand a.
//     .indata_b_i(mu_i),          // Input data -> operand b.
//     .outdata_r_o(xmu_precomp)
// )


assign valid_o = d_finish;

endmodule : barrett_pipelined