// TODO: now this will work just fine for 64bit values
//       might need to be used as a standalone module for 64x64
import multiplier_pkg::*;
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

// initial begin
//   $dumpfile("barrett.vcd");       // VCD file (or use FSDB for Verdi)
//   $dumpvars(0, barrett_pipelined); // Dump ALL signals in the module
//   // Or dump specific signals:
//   // $dumpvars(0, barrett_pipelined.x_pipe);
//   // $dumpvars(0, barrett_pipelined.m_pipe);
//   // ...
// end

// PRECOMP, APPROX, 
typedef enum logic[2:0] {LOAD, PRECOMP, APPROX, REDUCE, FINISH} state_t;

state_t curr_state, next_state;

// 1, start_mult2, 
logic start_mult, m_finish, p_finish, a_finish;
logic d_finish;

// TODO: but is this really necessary in this case?
shiftreg #(
  //4, because we only have 4 pipeline stages without intermediate steps for Barrett reduction
  // might have to change it to NUM_MULS + 2 + 4 when we use pipelined multiplication too
  // edit: it's not necessary to stall start_i by additional cycles due to multiplier, because multiplier is internally synchronized
  // additionally, the multiplier's finish_o signal is used to start with the next barrett pipeline stage
  // (NUM_MULS + 2) * 2*4 + 
    .SHIFT((NUM_MULS + 2) * 6 + 4), //4, because we only have 4 pipeline stages without intermediate steps
    .DATA(1) // sets the width of the data being shifted (1 bit wide)
) shift_finish ( // HINT: this is the name of the module
    // these are port connections:
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);

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
            if (start_mult) begin
                next_state = APPROX;
            end
        end
        // PRECOMP: begin
        //   if(p_finish) begin // p_finish can indicate that the multiplication has completed
        //     next_state = APPROX;
        //   end
        // end
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
logic [63:0] mu_pipe [3:0];   // Propagates m through stages
logic [63:0] q_pipe [1:0];   // Stores intermediate q
logic valid_pipe [3:0];
// 
// Stage 1: Multiply x * μ
logic ready;
assign ready = (!valid_pipe[0]) || valid_pipe[3]; 
always_ff @(posedge clk_i or negedge rst_ni) begin
  // x_mu <= x_i * mu_i; // This will be assigned the result of the multiplier module
  // x_mu <= xmu_precomp; // This will be assigned the result of the multiplier module
  if (!rst_ni) begin
    x_pipe[0] <= 0;  // Shift x to next stage
    // m_pipe[0] <= 0;  // Shift m to next stage
    // mu_pipe[0]<= 0;
    valid_pipe[0] <= 1'b0;
  end else begin
    // if (ready && start_i)
    // x_pipe[0] <= x_i;  // Update pipeline
    x_pipe[0] <= x_i;  // Shift x to next stage
    // m_pipe[0] <= m_i;  // Shift m to next stage
    // mu_pipe[0] <= mu_i;
    start_mult <= 1'b1;
    valid_pipe[0] <= 1'b1;
  end
  //  else if (valid_pipe[3]) begin
    // valid_pipe[0] <= 1'b0;
  // end
end

// Stage 2: Truncate q = floor(x * μ / 2^2k)
always_ff @(posedge clk_i) begin
  // i think it's okay to leave this here since bitshifts are not costly
  // 2*K could be part from a package
    // xmu_precomp[63:0]
  if(!busy_p_o) begin
    // q_pipe[0] <= xmu_precomp >> (2 * 32);  // Truncate
    // p_finish <= 1'b1;
    x_pipe[1] <= x_pipe[0];      // Shift x
    // m_pipe[1] <= m_pipe[0];      // Shift m
    // mu_pipe[1] <= mu_pipe[0];
    valid_pipe[1] <= valid_pipe[0];
  end
end


// Stage 3: Multiply q * m
// logic [63:0] q_m;
always_ff @(posedge clk_i) begin
  if(!busy_p_o && valid_pipe[1]) begin
  // q_pipe[1] <= q_pipe[0] * m_pipe[1];
    // q_pipe[1] <= q_approx;
    x_pipe[2] <= x_pipe[1];  // Shift x
    // m_pipe[2] <= m_pipe[1];  // Shift m (unused)
    // mu_pipe[2] <= mu_pipe[1];
    valid_pipe[2] <= valid_pipe[1];
  end
end

// Stage 4: Subtract x - (q * m) and correct
logic [63:0] tmp;

generate
  for(genvar i = 0; i < 3; i++) begin
    always_ff @(posedge clk_i) begin
      if(!busy_a_o && valid_pipe[2]) begin
        tmp = x_pipe[i] - qm_result;
        result_o <= (tmp < m_i) ? tmp : tmp - m_i;
        valid_pipe[3] <= valid_pipe[2];
      end
      // valid_o  <= 1'b1;  // Result valid
    end
  end
endgenerate

always_ff @(posedge clk_i) begin
  // q_pipe0: %h, q_pipe1: %h,
  // q_pipe[0], q_pipe[1],
  //  xmu: %h
    $display("Cycle: %d, State: %s, x[0]: %h, x[1]: %h, x[2]: %h, m: %h, x[2]: %h, busy_p_o: %b, m_finish: %b, a_finish: %b, d_finish: %b, vpipe[0]: %b, vpipe[1]: %b, vpipe[2]: %b, vpipe[3]: %b",
            $time, curr_state.name(), x_pipe[0], x_pipe[1], x_pipe[2], m_pipe[0], x_pipe[2], busy_p_o, m_finish, a_finish, d_finish, valid_pipe[0], valid_pipe[1], valid_pipe[2], valid_pipe[3]);
end

// logic [63:0] res;
// logic p_finish_delayed;
// always_ff @(posedge clk_i) begin
//   p_finish_delayed <= p_finish;
// end
logic busy_p_o;
logic [127:0] xmu_precomp;
logic [63:0] mult_a_input;
logic [63:0] mult_b_input;
multiplier_top multiplier_precomp(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_mult),          // Start signal.
  .busy_o(busy_p_o),          // Module busy.
  .finish_o(m_finish),        // Module finish.
  .indata_a_i(x_pipe[0]),           // Input data -> operand a.
  .indata_b_i(mu_i),          // Input data -> operand b.
  .outdata_r_o(xmu_precomp)
);

logic [63:0] q_approx;
assign q_approx = xmu_precomp >> (2 * 32);

logic busy_a_o;
logic [127:0] qm_result;
multiplier_top multiplier_approx(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(m_finish),          // Start signal.
  .busy_o(busy_a_o),          // Module busy.
  .finish_o(a_finish),        // Module finish.
  .indata_a_i(q_approx),     // Input data -> operand a.
  .indata_b_i(m_i),     // Input data -> operand b.
  .outdata_r_o(qm_result)
);

assign valid_o = d_finish;

endmodule : barrett_pipelined

// // -------------------------------------------------------------------------------------------------------------


// import multiplier_pkg::*;
// module barrett_pipelined (
//   input  logic                    clk_i,
//   input  logic                    rst_ni,
//   input  logic                    start_i,
//   input  logic [63:0]             x_i,       // Input (e.g., 64-bit)
//   input  logic [63:0]             m_i,       // Modulus (e.g., 32-bit)
//   input  logic [63:0]             mu_i,      // Precomputed μ
//   output logic [127:0]            result_o,
//   output logic                    valid_o,    // Result valid flag
//   output logic                    ready_o
// );

// // PRECOMP, APPROX, 
// typedef enum logic[2:0] {LOAD, PRECOMP, APPROX, REDUCE, FINISH} state_t;

// state_t curr_state, next_state;

// logic [127:0] xmu_result, qm_result;
// logic m1_finish, m2_finish, m1_busy, m2_busy;

// logic [63:0] x_pipe [4:0];  // Propagates x through stages
// logic [63:0] m_pipe [4:0];   // Propagates m through stages
// logic [63:0] mu_pipe [4:0];   // Propagates m through stages
// logic [63:0] q_pipe [1:0];   // Stores intermediate q
// logic valid_pipe [4:0];

// always_ff @(posedge clk_i) begin
//     if (rst_ni == 0) begin
//         curr_state <= LOAD;
//     end 
//     else begin
//         curr_state <= next_state;
//     end
// end

// always_comb begin
//     next_state = curr_state; // default is to stay in current state
//     case (curr_state)
//         LOAD : begin
//             if (valid_pipe[0]) begin
//                 next_state = PRECOMP;
//             end
//         end
//         PRECOMP: begin
//           if(m1_finish) begin // p_finish can indicate that the multiplication has completed
//             next_state = APPROX;
//           end
//         end
//         APPROX: begin
//           if(m2_finish) begin // a_finish can indicate that the approximation has completed
//             next_state = REDUCE;
//           end
//         end
//         REDUCE : begin
//             if (valid_pipe[4]) begin
//                 next_state = FINISH;
//             end
//         end
//         FINISH : begin
//             next_state = FINISH;
//         end
//         default : begin
//             next_state = LOAD;
//         end
//     endcase
// end

// assign ready_o = !valid_pipe[0];
// // || m1_finish

// always_ff @(posedge clk_i or posedge rst_ni) begin
//   if(!rst_ni) begin
//     valid_pipe[0] <= 1'b0;
//   end else begin
//     // else if (clk_i)
//     // Stage 0: Load new input only when ready
//     if (ready_o && start_i) begin
//       x_pipe[0]     <= x_i;
//       m_pipe[0]     <= m_i;
//       mu_pipe[0]    <= mu_i;
//       valid_pipe[0] <= 1'b1;
//     end else if (m1_finish) begin
//       valid_pipe[0] <= 1'b0;  // Clear after acceptance
//     end
//   end
// end

// always_ff @(posedge clk_i) begin
//    // Stage 1: First multiplier (x * μ)
//   if (!m1_busy && valid_pipe[0]) begin
//     x_pipe[1]     <= x_pipe[0];
//     m_pipe[1]     <= m_pipe[0];
//     mu_pipe[1]    <= mu_pipe[0];
//     valid_pipe[1] <= valid_pipe[0];
//   end
// end

// multiplier_top multiplier_precomp(
//   .clk_i(clk_i),              // Rising edge active clk.
//   .rst_ni(rst_ni),            // Active low reset.
//   .start_i(valid_pipe[1] && !m1_busy),          // Start signal.
//   .busy_o(m1_busy),          // Module busy.
//   .finish_o(m1_finish),        // Module finish.
//   .indata_a_i(x_pipe[1]),           // Input data -> operand a.
//   .indata_b_i(mu_pipe[1]),          // Input data -> operand b.
//   .outdata_r_o(xmu_result)
// );

// always_ff @(posedge clk_i) begin
//    // Stage 1: First multiplier (x * μ)
//   if (m1_finish) begin
//     x_pipe[2]     <= x_pipe[1];
//     m_pipe[2]     <= m_pipe[1];
//     mu_pipe[2]    <= mu_pipe[1];
//     valid_pipe[2] <= valid_pipe[1];
//   end
// end

// always_ff @(posedge clk_i) begin
//    // Stage 1: First multiplier (x * μ)
//   if (!m2_busy && valid_pipe[2]) begin
//     x_pipe[3]     <= x_pipe[2];
//     m_pipe[3]     <= m_pipe[2];
//     mu_pipe[3]    <= mu_pipe[2];
//     valid_pipe[3] <= valid_pipe[2];
//   end
// end
// logic [63:0] q_truncated = xmu_result >> (2 * 32);
// multiplier_top multiplier_approx(
//   .clk_i(clk_i),              // Rising edge active clk.
//   .rst_ni(rst_ni),            // Active low reset.
//   .start_i(valid_pipe[3] && !m2_busy),          // Start signal.
//   .busy_o(m2_busy),          // Module busy.
//   .finish_o(m2_finish),        // Module finish.
//   .indata_a_i(q_truncated),     // Input data -> operand a.
//   .indata_b_i(m_pipe[3]),     // Input data -> operand b.
//   .outdata_r_o(qm_result)
// );

// always_ff @(posedge clk_i) begin
//    // Stage 1: First multiplier (x * μ)
//   if (m2_finish) begin
//     x_pipe[4]     <= x_pipe[3];
//     m_pipe[4]     <= m_pipe[3];
//     mu_pipe[4]    <= mu_pipe[3];
//     valid_pipe[4] <= valid_pipe[3];
//   end
// end

// logic [63:0] tmp;
// always_ff @(posedge clk_i) begin
//    // Stage 1: First multiplier (x * μ)
//   if (valid_pipe[4]) begin
//     tmp = x_pipe[4] - qm_result[63:0];
//     result_o <= (tmp < m_pipe[4]) ? tmp : tmp - m_pipe[4];
//     valid_o <= 1'b1;
//   end else begin
//     valid_o <= 1'b0;
//   end
// end

// always_ff @(posedge clk_i) begin
//   // q_pipe0: %h, q_pipe1: %h,
//   // q_pipe[0], q_pipe[1],
//     $display("Cycle: %d, State: %s, x[0]: %h, m: %h, xmu: %h, x[2]: %h, q_pipe[1]: %h, mu: %h, ready_o: %b, valid_pipe[0]: %b, m1_finish: %b,  start_i: %b",
//             $time, curr_state.name(), x_pipe[0], m_pipe[0], xmu_result, x_pipe[2], q_pipe[1], mu_i, ready_o, valid_pipe[0], m1_finish, start_i);
// end


// endmodule:barrett_pipelined