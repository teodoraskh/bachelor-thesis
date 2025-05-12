`timescale 1ns / 1ps
module montgomery_serialized (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [63:0]             x_i,       // Input: multiplication result from NTT, already in Montgomery form
  input  logic [63:0]             m_i,       // Modulus (e.g., 32-bit)
  input  logic [63:0]             m_bl_i,
  output logic [63:0]             result_o,
  output logic                    valid_o    // Result valid flag
);
// 1. Get xR^2 mod N as input, reduce twice to get x mod N
//    Maybe use  multiplier to compute xR^2?
typedef enum logic[2:0] {LOAD, REDUCE, FINISH} state_t;
state_t curr_state, next_state;
logic [63:0] accumulator_p, accumulator_n;
logic [8:0] idx_p, idx_n;
logic d_finish;

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        accumulator_p <= x_i;
        curr_state    <= LOAD;
        idx_p         <= 0;
    end 
    else begin
        curr_state    <= next_state;
        accumulator_p <= accumulator_n;
        idx_p         <= idx_n;
    end
end

// logic lsb = accumulator_p[0];

always_comb begin
  next_state    = curr_state; // default is to stay in current state
  accumulator_n = accumulator_p;
  idx_n         = idx_p;
  case (curr_state)
      LOAD : begin
          if (start_i) begin
              next_state = REDUCE;
          end
      end
      REDUCE : begin
        // WARNING: $bits(m_i) will always return 64/128/whatever!
        // find another solution to check the bit width with precision!
        if(idx_p == m_bl_i) begin
          next_state = FINISH;
        end else begin
          if(accumulator_p[0] == 1) begin
            accumulator_n = (accumulator_p + m_i) >> 1;
          end else begin
            accumulator_n = accumulator_p >> 1;
          end
            idx_n = idx_p + 1;
            next_state = REDUCE;
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

assign valid_o = (curr_state == FINISH);
assign result_o = (curr_state == FINISH) ? accumulator_p : 64'b0;

// always_ff @(posedge clk_i) begin
//     $display("Cycle: %d, State: %s, x_i: %h, m_i: %h, idx_p: %d, acc_p: %h, rst_ni: %b, bits_mi: %d",
//             $time, curr_state.name(), x_i, m_i, idx_p, accumulator_p, rst_ni, $clog2(m_i + 1));
// end

endmodule:montgomery_serialized