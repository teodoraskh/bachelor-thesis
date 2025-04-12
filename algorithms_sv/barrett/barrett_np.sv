module barrett_np (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [63:0]             x_i,       // Input (e.g., 64-bit)
  input  logic [63:0]             m_i,       // Modulus (e.g., 32-bit)
  input  logic [63:0]             mu_i,      // Precomputed μ
  output logic [127:0]            result_o,
  output logic                    valid_o    // Result valid flag
);

typedef enum logic[2:0] {LOAD, PRECOMP, APPROX, REDUCE, FINISH} state_t;

state_t curr_state, next_state;
logic [127:0] x_mu;
logic [63:0] q_m;
logic [63:0] tmp;

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
            x_mu = x_i * mu_i;
            next_state = APPROX;
        end
        APPROX: begin
          q_m = (x_mu >> (2 * $bits(m_i))) * m_i;
          next_state = REDUCE;
        end
        REDUCE : begin
                tmp = x_i - q_m;
                result_o = (tmp < m_i) ? tmp : tmp - m_i;
                next_state = FINISH;
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
//     $display("Cycle: %d, State: %s, x_i: %h, busy_o: %b, valid_o: %b",
//             $time, curr_state.name(), x_i, busy_o, valid_o);
// end

assign valid_o = (curr_state == FINISH);
assign busy_o = (curr_state != LOAD && curr_state != FINISH);


endmodule : barrett_np

