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

// PRECOMP, APPROX, 
typedef enum logic[2:0] {LOAD, PRECOMP, APPROX, REDUCE, FINISH} state_t;

state_t curr_state, next_state;

// 1, start_mult2, 
logic start_mult, m_finish, a_finish;
logic d_finish;
logic [63:0] x_delayed;

// TODO: but is this really necessary in this case?
shiftreg #(
  //4, because we only have 4 pipeline stages without intermediate steps for Barrett reduction
  // might have to change it to NUM_MULS + 2 + 4 when we use pipelined multiplication too
  // edit: it's not necessary to stall start_i by additional cycles due to multiplier, because multiplier is internally synchronized
  // additionally, the multiplier's finish_o signal is used to start with the next barrett pipeline stage
  // (NUM_MULS + 2) * 2*4 + 
    .SHIFT((NUM_MULS + 2) * 2 + 4), //4, because we only have 4 pipeline stages without intermediate steps
    .DATA(1) // sets the width of the data being shifted (1 bit wide)
) shift_finish ( // HINT: this is the name of the module
    // these are port connections:
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2 + 3), //4, because we only have 4 pipeline stages without intermediate steps
    .DATA(64) // sets the width of the data being shifted (1 bit wide)
) shift_in (
    .clk_i(clk_i),
    .data_i(x_i),
    .data_o(x_delayed)
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
            if (start_i) begin
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

// always_ff @(posedge clk_i) begin
//     $display("Cycle: %d, State: %s, x_i: %h, x_delayed: %h, busy_p_o: %b, m_finish: %b, a_finish: %b, d_finish: %b",
//             $time, curr_state.name(), x_i, x_delayed, busy_p_o, m_finish, a_finish, d_finish);
// end

always_ff @(posedge clk_i) begin
    $display("Cycle: %d, State: %s, x_i: %h, x_delayed: %h, out: %h, valid: %b",
            $time, curr_state.name(), x_i, x_delayed, result_o, valid_o);
end

logic busy_p_o;
logic [127:0] xmu_precomp;
logic [63:0] mult_a_input;
logic [63:0] mult_b_input;
multiplier_top multiplier_precomp(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_i),          // Start signal.
  .busy_o(busy_p_o),          // Module busy.
  .finish_o(m_finish),        // Module finish.
  .indata_a_i(x_i),           // Input data -> operand a.
  .indata_b_i(mu_i),          // Input data -> operand b.
  .outdata_r_o(xmu_precomp)
);

logic [63:0] q_approx;
assign q_approx = xmu_precomp >> (2 * 32);

logic busy_a_o;
logic [127:0] qm_result;
multiplier_top multiplier_approx(
  .clk_i(clk_i),             // Rising edge active clk.
  .rst_ni(rst_ni),           // Active low reset.
  .start_i(m_finish),        // Start signal.
  .busy_o(busy_a_o),         // Module busy.
  .finish_o(a_finish),       // Module finish.
  .indata_a_i(q_approx),     // Input data -> operand a.
  .indata_b_i(m_i),          // Input data -> operand b.
  .outdata_r_o(qm_result)
);

logic [127:0] result_next;
logic [63:0] tmp;

always_comb begin
  result_next = result_o;
  if (!busy_a_o) begin
    tmp = x_delayed - qm_result;
    result_next = (tmp < m_i) ? tmp : tmp - m_i;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 127'b0;
  end else begin
    result_o <= result_next;
  end
end

assign valid_o = d_finish;

endmodule : barrett_pipelined
