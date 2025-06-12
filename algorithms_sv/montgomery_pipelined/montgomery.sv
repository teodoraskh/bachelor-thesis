// TODO: now this will work just fine for 64bit values
//       might need to be used as a standalone module for 64x64
import multiplier_pkg::*;
module montgomery_pipelined (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [63:0]             x_i,       // Input (e.g., 64-bit)
  input  logic [63:0]             m_i,       // Modulus (e.g., 32-bit)
  input  logic [63:0]             m_bl_i,
  input  logic [63:0]             minv_i,       // Input (e.g., 64-bit)
  output logic [63:0]             result_o,
  output logic                    valid_o    // Result valid flag
);

typedef enum logic[2:0] {LOAD, SCALE, REDUCE, FINISH} state_t;

state_t curr_state, next_state;

// 1, start_mult2, 
logic s_finish, m_finish;
logic d_finish;
logic [63:0] x_delayed;

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2 + 2),
    .DATA(1) 
) shift_finish (
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2),
    .DATA(64)
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
                next_state = SCALE;
            end
        end
        SCALE: begin
          if(s_finish) begin
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
//     $display("Cycle: %d, State: %s, x_i: %h, x_delayed: %h, busy_s_o: %b, s_finish: %b, m_finish: %b, d_finish: %b",
//             $time, curr_state.name(), x_i, x_delayed, busy_s_o, s_finish, m_finish, d_finish);
// end

// always_ff @(posedge clk_i) begin
//     $display("Cycle: %d, State: %s, x_i: %h, x_delayed: %h, out: %h, valid: %b",
//             $time, curr_state.name(), x_i, x_delayed, result_o, valid_o);
// end

logic busy_s_o;
logic [127:0] lsb_scaled;
logic [127:0] lsb;
assign lsb = x_i & ((1 << m_bl_i) - 1);

// lsb_scaled = (T mod R) * Q'
multiplier_top multiplier_precomp(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_i),          // Start signal.
  .busy_o(busy_s_o),          // Module busy.
  .finish_o(s_finish),        // Module finish.
  .indata_a_i(x_i & ((1 << m_bl_i) - 1)),           // Input data -> operand a.
  .indata_b_i(minv_i),          // Input data -> operand b.
  .outdata_r_o(lsb_scaled)
);

logic [63:0] m;
// lsb_scaled mod R
assign m = lsb_scaled & ((1 << m_bl_i) - 1); // 

logic busy_m_o;
logic [127:0] m_rescaled;
multiplier_top multiplier_approx(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(s_finish),         // Start signal.
  .busy_o(busy_m_o),          // Module busy.
  .finish_o(m_finish),        // Module finish.
  .indata_a_i(m),             // Input data -> operand a.
  .indata_b_i(m_i),           // Input data -> operand b.
  .outdata_r_o(m_rescaled)
);

logic [63:0] result_next;
logic [63:0] tmp;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_next <= 64'b0;
  end else if(m_finish)begin
    result_next <= (x_delayed + m_rescaled) >> m_bl_i;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 64'b0;
  end else begin
    result_o <= (result_next < m_i) ? result_next : result_next - m_i;
  end
end

assign valid_o = d_finish;

endmodule : montgomery_pipelined
