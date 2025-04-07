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

// typedef struct packed {
//   logic [63:0] x;   // Input value
//   logic [63:0] m;   // Modulus
//   logic [63:0] mu;  // Precomputed μ
//   logic        valid; // Validity flag
// } barrett_op_t;

// barrett_op_t op_pipe [3:0];  // Pipeline stages

// TODO: but is this really necessary in this case?
shiftreg #(
  //4, because we only have 4 pipeline stages without intermediate steps for Barrett reduction
  // might have to change it to NUM_MULS + 2 + 4 when we use pipelined multiplication too
  // edit: it's not necessary to stall start_i by additional cycles due to multiplier, because multiplier is internally synchronized
  // additionally, the multiplier's finish_o signal is used to start with the next barrett pipeline stage
  // (NUM_MULS + 2) * 2*4 + 
    .SHIFT((NUM_MULS + 2) * 2 + 2), //4, because we only have 4 pipeline stages without intermediate steps
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
logic [63:0] mu_pipe [3:0];   // Propagates m through stages
logic [63:0] q_pipe [1:0];   // Stores intermediate q
// 
// Stage 1: Multiply x * μ
logic [127:0] x_mu;
always_ff @(posedge clk_i) begin
  // x_mu <= x_i * mu_i; // This will be assigned the result of the multiplier module
  // x_mu <= xmu_precomp; // This will be assigned the result of the multiplier module
  if (!rst_ni) begin
    x_pipe[0] <= 0;  // Shift x to next stage
    m_pipe[0] <= 0;  // Shift m to next stage
    mu_pipe[0]<= 0;
  end else begin
    // x_pipe[0] <= x_i;  // Update pipeline
    x_pipe[0] <= x_i;  // Shift x to next stage
    m_pipe[0] <= m_i;  // Shift m to next stage
    mu_pipe[0] <= mu_i;
    start_mult <= 1'b1;
  end
end

// Stage 2: Truncate q = floor(x * μ / 2^2k)
always_ff @(posedge clk_i) begin
  // i think it's okay to leave this here since bitshifts are not costly
  // 2*K could be part from a package
    // xmu_precomp[63:0]
  if(m_finish) begin
    q_pipe[0] <= xmu_precomp >> (2 * 32);  // Truncate
    p_finish <= 1'b1;
  end
  x_pipe[1] <= x_pipe[0];      // Shift x
  m_pipe[1] <= m_pipe[0];      // Shift m
  mu_pipe[1] <= mu_pipe[0];
end


// Stage 3: Multiply q * m
// logic [63:0] q_m;
always_ff @(posedge clk_i) begin
  if(p_finish) begin
  // q_pipe[1] <= q_pipe[0] * m_pipe[1];
    q_pipe[1] <= q_approx;
  end
  x_pipe[2] <= x_pipe[1];  // Shift x
  m_pipe[2] <= m_pipe[1];  // Shift m (unused)
  mu_pipe[2] <= mu_pipe[1];
end

// Stage 4: Subtract x - (q * m) and correct
logic [63:0] tmp;
always_ff @(posedge clk_i) begin
  if(a_finish) begin
    tmp = x_pipe[2] - q_pipe[1];
    result_o <= (tmp < m_pipe[2]) ? tmp : tmp - m_pipe[2];
  end
  // valid_o  <= 1'b1;  // Result valid
end

always_ff @(posedge clk_i) begin
  // q_pipe0: %h, q_pipe1: %h,
  // q_pipe[0], q_pipe[1],
    $display("Cycle: %d, State: %s, x[0]: %h, m: %h, x[2]: %h, q_pipe[1]: %h, mu: %h, busy_p_o: %b, d_finish: %b, start_i: %b",
            $time, curr_state.name(), x_pipe[0], m_pipe[0], x_pipe[2], q_pipe[1], mu_i, busy_p_o, d_finish, start_i);
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
// assign mult_a_input = x_pipe[0];
// assign mult_b_input = mu_pipe[0];
multiplier_top multiplier_precomp(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_mult),          // Start signal.
  .busy_o(busy_p_o),          // Module busy.
  .finish_o(m_finish),        // Module finish.
  .indata_a_i(x_i),           // Input data -> operand a.
  .indata_b_i(mu_i),          // Input data -> operand b.
  .outdata_r_o(xmu_precomp)
);

logic busy_a_o;
logic [127:0] q_approx;
multiplier_top multiplier_approx(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_mult),          // Start signal.
  .busy_o(busy_a_o),          // Module busy.
  .finish_o(a_finish),        // Module finish.
  .indata_a_i(q_pipe[0]),     // Input data -> operand a.
  .indata_b_i(m_pipe[1]),     // Input data -> operand b.
  .outdata_r_o(q_approx)
);

assign valid_o = d_finish;

endmodule : barrett_pipelined

// -------------------------------------------------------------------------------------------------------------

// module barrett_pipelined (
//   input  logic          clk_i, rst_ni, start_i,
//   input  logic [63:0]   x_i, m_i, mu_i,  // Inputs: x, modulus (m), precomputed μ
//   output logic [63:0]   result_o,         // Final result: x mod m
//   output logic          valid_o           // Result valid flag
// );

//   // --- Pipeline Structure ---
//   typedef struct packed {
//     logic [63:0] x;     // Input value
//     logic [63:0] m;     // Modulus
//     logic [63:0] mu;    // Precomputed μ
//     logic        valid;  // Validity flag
//   } barrett_op_t;

//   barrett_op_t op_pipe [3:0];  // 4-stage pipeline (LOAD, PRECOMP, APPROX, REDUCE)

//   // --- Multiplier Signals ---
//   logic [127:0] xmu_result;  // Result of x * μ
//   logic [127:0] qm_result;   // Result of q * m
//   logic mult1_finish, mult2_finish;

//   // --- Pipeline Control ---
//   always_ff @(posedge clk_i or negedge rst_ni) begin
//     if (!rst_ni) begin
//       op_pipe <= 0;  // Reset all stages
//     end else begin
//       // Propagate valid operations through stages
//       for (int i = 0; i < 3; i++) begin
//         if (!op_pipe[i+1].valid) begin
//           op_pipe[i+1] <= op_pipe[i];  // Move data if next stage is free
//         end
//       end
//       // Load new operation into stage 0
//       if (start_i) begin
//         op_pipe[0].x     <= x_i;
//         op_pipe[0].m     <= m_i;
//         op_pipe[0].mu    <= mu_i;
//         op_pipe[0].valid <= 1'b1;
//       end else begin
//         op_pipe[0].valid <= 1'b0;
//       end
//     end
//   end

//   // --- Stage 1: Compute x * μ ---
//   multiplier_top mult1 (
//     .clk_i(clk_i),
//     .rst_ni(rst_ni),
//     .start_i(op_pipe[0].valid),  // Start when stage 0 is valid
//     .indata_a_i(op_pipe[0].x),
//     .indata_b_i(op_pipe[0].mu),
//     .outdata_r_o(xmu_result),
//     .finish_o(mult1_finish)
//   );

//   // --- Stage 2: Truncate q = floor(x*μ / 2^(2k)) ---
//   logic [63:0] q_truncated;
//   always_ff @(posedge clk_i) begin
//     if (op_pipe[1].valid && mult1_finish) begin
//       q_truncated <= xmu_result >> (2 * 32);  // k=32 for 64-bit modulus
//     end
//   end

//   // --- Stage 3: Compute q * m ---
//   multiplier_top mult2 (
//     .clk_i(clk_i),
//     .rst_ni(rst_ni),
//     .start_i(op_pipe[1].valid && mult1_finish),  // Start when stage 1 is valid
//     .indata_a_i(q_truncated),
//     .indata_b_i(op_pipe[1].m),  // Use original modulus m
//     .outdata_r_o(qm_result),
//     .finish_o(mult2_finish)
//   );

//   // --- Stage 4: Final Reduction (x - q*m) ---
//   logic [63:0] tmp;
//   always_ff @(posedge clk_i) begin
//     if (op_pipe[2].valid && mult2_finish) begin
//       tmp = op_pipe[2].x - qm_result[63:0];
//       result_o <= (tmp < op_pipe[2].m) ? tmp : tmp - op_pipe[2].m;
//       valid_o  <= 1'b1;
//     end else begin
//       valid_o <= 1'b0;
//     end
//   end

// endmodule


// import multiplier_pkg::*;
// module barrett_pipelined (
//   input  logic                    clk_i,
//   input  logic                    rst_ni,
//   input  logic                    start_i,
//   input  logic [63:0]             x_i,       // Input (e.g., 64-bit)
//   input  logic [63:0]             m_i,       // Modulus (e.g., 32-bit)
//   input  logic [63:0]             mu_i,      // Precomputed μ
//   output logic [127:0]            result_o,
//   output logic                    valid_o    // Result valid flag
// );

// initial begin
//   $dumpfile("barrett.vcd");       // VCD file (or use FSDB for Verdi)
//   $dumpvars(0, barrett_pipelined); // Dump ALL signals in the module
//   // Or dump specific signals:
//   // $dumpvars(0, barrett_pipelined.x_pipe);
//   // $dumpvars(0, barrett_pipelined.m_pipe);
//   // ...
// end

// PRECOMP, APPROX, 
// typedef enum logic[2:0] {LOAD, PRECOMP, APPROX, REDUCE, FINISH} state_t;

// state_t curr_state, next_state;

// logic start_mult, m_finish, p_finish, a_finish;
// logic d_finish;


// shiftreg #(
//   //4, because we only have 4 pipeline stages without intermediate steps for Barrett reduction
//   // might have to change it to NUM_MULS + 2 + 4 when we use pipelined multiplication too
//   // edit: it's not necessary to stall start_i by additional cycles due to multiplier, because multiplier is internally synchronized
//   // additionally, the multiplier's finish_o signal is used to start with the next barrett pipeline stage
//   // (NUM_MULS + 2) * 2*4 + 
//     .SHIFT((NUM_MULS + 2) * 2 + 2), //4, because we only have 4 pipeline stages without intermediate steps
//     .DATA(1) // sets the width of the data being shifted (1 bit wide)
// ) shift_finish ( // HINT: this is the name of the module
//     // these are port connections:
//     .clk_i(clk_i),
//     .data_i(start_i),
//     .data_o(d_finish)
// );

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
//             if (start_i == 1) begin
//                 next_state = PRECOMP;
//             end
//         end
//         PRECOMP: begin
//           if(op_pipe[0].valid) begin // p_finish can indicate that the multiplication has completed
//             next_state = APPROX;
//           end
//         end
//         APPROX: begin
//           if(op_pipe[1].valid) begin // a_finish can indicate that the approximation has completed
//             next_state = REDUCE;
//           end
//         end
//         REDUCE : begin
//             if (op_pipe[2].valid) begin
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

// typedef struct packed {
//   logic [63:0] x;   // Input value
//   logic [63:0] m;   // Modulus
//   logic [63:0] mu;  // Precomputed μ
//   logic        valid; // Validity flag
// } barrett_op_t;

// barrett_op_t op_pipe [3:0];  // Pipeline stages

// always_ff @(posedge clk_i) begin
//   if(rst_ni) begin
//     op_pipe[0] <= '{default: 0};
//   end
// end

// endmodule: barrett_pipelined