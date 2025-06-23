import multiplier_pkg::*;
module montgomery_pipelined (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input (e.g., 64-bit)
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus (e.g., 32-bit)
  input  logic [DATA_LENGTH-1:0]  m_bl_i,
  input  logic [DATA_LENGTH-1:0]  minv_i,    // Input (e.g., 64-bit)
  output logic [DATA_LENGTH-1:0]  result_o,
  output logic                    valid_o    // Result valid flag
);

typedef enum logic[2:0] {LOAD, SCALE, REDUCE, FINISH} state_t;

state_t curr_state, next_state;

logic s_finish, m_finish;
logic d_finish;
logic [DATA_LENGTH-1:0] x_delayed;

shiftreg #(
    .SHIFT((NUM_MULS + 2) * 2 + 4),
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
          if(s_finish_delayed) begin
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

logic busy_s_o;
logic start_delayed;
logic [2 * DATA_LENGTH-1:0] lsb_scaled;
logic [2 * DATA_LENGTH-1:0] lsb_reg;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    lsb_reg <= 64'b0;
    start_delayed <= 0;
  end else if(start_i) begin
    lsb_reg <= x_i & ((1 << m_bl_i) - 1);
    start_delayed <= 1;
  end else begin
    lsb_reg <= lsb_reg;
    start_delayed <= 0;
  end
end

// lsb_scaled = (T mod R) * Q'
multiplier_top multiplier_precomp(
  .clk_i(clk_i),              // Rising edge active clk.
  .rst_ni(rst_ni),            // Active low reset.
  .start_i(start_delayed),    // Start signal.
  .busy_o(busy_s_o),          // Module busy.
  .finish_o(s_finish),        // Module finish.
  .indata_a_i(lsb_reg),           // Input data -> operand a.
  .indata_b_i(minv_i),          // Input data -> operand b.
  .outdata_r_o(lsb_scaled)
);

logic [DATA_LENGTH-1:0] lsb_resc_remainder_reg;
logic s_finish_delayed;

// lsb_scaled mod R
always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    lsb_resc_remainder_reg <= 64'b0;
    s_finish_delayed <= 0;
  end else if(s_finish)begin
    lsb_resc_remainder_reg <= lsb_scaled & ((1 << m_bl_i) - 1);
    s_finish_delayed <= 1;
  end else begin
    lsb_resc_remainder_reg <= lsb_resc_remainder_reg;
    s_finish_delayed <= 0;
  end
end

logic busy_m_o;
logic [127:0] m_rescaled;
multiplier_top multiplier_approx(
  .clk_i(clk_i),                       // Rising edge active clk.
  .rst_ni(rst_ni),                     // Active low reset.
  .start_i(s_finish_delayed),          // Start signal.
  .busy_o(busy_m_o),                   // Module busy.
  .finish_o(m_finish),                 // Module finish.
  .indata_a_i(lsb_resc_remainder_reg), // Input data -> operand a.
  .indata_b_i(m_i),                    // Input data -> operand b.
  .outdata_r_o(m_rescaled)
);

logic [DATA_LENGTH-1:0] result_next;
logic [DATA_LENGTH-1:0] tmp;

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
