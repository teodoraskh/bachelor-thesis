module shiftadd_serialized (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [63:0]             x_i,       // Input
  input  logic [63:0]             m_i,       // Modulus
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

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        accumulator_p <= lo;
        curr_state    <= LOAD;
        idx_p         <= 1;
        fold_sign_p   <= 1;
    end 
    else begin
        curr_state    <= next_state;
        accumulator_p <= accumulator_n;
        idx_p         <= idx_n;
        fold_sign_p   <= fold_sign_n;
    end
end

logic [63:0] hi;
logic [63:0] lo;
logic [63:0] mask;
logic [63:0] bitlength;

logic [63:0] msb_mask;    
logic [63:0] inner_mask;  
logic is_fermat;   
logic is_mersenne; 
logic fold_sign;
logic fold_sign_n, fold_sign_p;


assign msb_mask    = 1 << (m_bl_i - 1);
assign inner_mask  = ((1 << (m_bl_i - 1)) - 1) & ~1;
assign is_fermat   = ((m_i & msb_mask)==msb_mask) && ((m_i & 1)==1) && ((m_i & inner_mask) == 0);
assign is_mersenne = ((m_i ^ ((1 << m_bl_i) - 1)) == 0);
assign fold_sign   = is_fermat ? 0 : 1;
assign bitlength   = is_fermat ? (m_bl_i - 1) : m_bl_i;


// assign hi = (x_i >> m_bl_i);
// assign hi = ((x_i >> (idx_p * m_bl_i)) & ((1 << (m_bl_i-1))-1));
assign mask = is_fermat ? ((1 << (m_bl_i-1))-1) : m_i;
assign hi = ((x_i >> (idx_p * bitlength)) & mask);
assign lo = (x_i & ((1 << bitlength) - 1));

always_comb begin
  next_state    = curr_state; // default is to stay in current state
  accumulator_n = accumulator_p;
  idx_n         = idx_p;
  fold_sign_n   = fold_sign_p;
  case (curr_state)
      LOAD : begin
          if (start_i) begin
              next_state = REDUCE;
          end
      end
      REDUCE : begin
        if(hi == 0) begin
            next_state = FINISH;
        end else begin
            if(is_mersenne) begin
                accumulator_n = accumulator_p + hi;
            end else begin
                accumulator_n = accumulator_p + (fold_sign_p ? -hi : hi);
                // wrap acc back in (0, M]
                if (is_fermat && $signed(accumulator_n) < 0) begin
                    accumulator_n = accumulator_n + $signed(m_i);
                end
                fold_sign_n = ~fold_sign_p;
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

// always_ff @(posedge clk_i) begin
//     $display("Cycle: %d, State: %s, x_i: %h, hi: %h, idx_p: %d, res: %h, acc?: %h, is neg: %d",
//             $time, curr_state.name(), x_i, hi, idx_p, result_o, accumulator_p, (is_fermat && accumulator_n < 0));
// end

logic is_gt_mod;  
logic is_lt_zero;
assign is_gt_mod  = (accumulator_p >= m_i);
assign is_lt_zero = (accumulator_p < 0);

assign valid_o = (curr_state == FINISH);
// assign result_o = (curr_state == FINISH) ? (is_gt_mod ? accumulator_p - $signed(m_i) : (is_lt_zero ? $signed(m_i) + accumulator_p : accumulator_p)) : 64'b0;
// assign result_o = (curr_state == FINISH) ? ((accumulator_p >= m_i) ? accumulator_p - m_i : accumulator_p) : 64'b0;

     assign result_o = (curr_state == FINISH) ? 
    ((accumulator_p >= m_i) ? accumulator_p - m_i : 
     (accumulator_p < 0)    ? accumulator_p + m_i : accumulator_p) : 64'b0;


endmodule : shiftadd_serialized