module shiftadd_serialized (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [63:0]             x_i,       // Input
  input  logic [31:0]             m_i,       // Modulus
  input  logic [31:0]             m_bl_i,
  output logic [63:0]             result_o,
  output logic                    valid_o    // Result valid flag
);
// 1. Get xR^2 mod N as input, reduce twice to get x mod N
//    Maybe use  multiplier to compute xR^2?
typedef enum logic[2:0] {LOAD, REDUCE, FINISH} state_t;
state_t curr_state, next_state;
logic signed [63:0] accumulator_p, accumulator_n;
logic [8:0] idx_p, idx_n;
logic d_finish;

always_ff @(posedge clk_i) begin
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

logic msb_mask;    
logic inner_mask;  
logic is_fermat;   
logic is_mersenne; 
logic fold_sign_n, fold_sign_p;


assign msb_mask    = 1 << (m_bl_i - 1);
assign inner_mask  = ((1 << (m_bl_i - 1)) - 1) & ~1;
assign is_fermat   = (m_i & msb_mask) && (m_i & 1) && ((m_i & inner_mask) == 0);
// assign is_mersenne = ((m_i ^ ((1 << m_bl_i) - 1)) == 0);
// assign fold_sign   = is_mersenne ? 1 : (is_fermat ? -1 : 1);

assign hi = (x_i >> m_bl_i);
assign lo = (x_i & ((1 << m_bl_i) - 1));

always_comb begin
  next_state    = curr_state; // default is to stay in current state
  accumulator_n = accumulator_p;
  fold_sign_n   = fold_sign_p;
  idx_n         = idx_p;
  case (curr_state)
      LOAD : begin
          if (start_i) begin
              next_state = REDUCE;
          end
      end
      REDUCE : begin
        if(((x_i >> idx_p * m_bl_i) & m_i) == 0) begin
            next_state = FINISH;
        end else begin
            accumulator_n = accumulator_p + fold_sign_p * ((x_i >> (idx_p * m_bl_i)) & m_i);
            idx_n = idx_p + 1;
            fold_sign_n = is_fermat ? -fold_sign_p : fold_sign_p;
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

always_ff @(posedge clk_i) begin
    $display("Cycle: %d, State: %s, x_i: %h, m_i: %h, idx_p: %d, res: %h, next?: %d, fold: %d",
            $time, curr_state.name(), x_i, m_i, idx_p, result_o, (((x_i >> idx_p * m_bl_i) & m_i) == 0), fold_sign_p);
end

logic is_gt_mod;  
logic is_lt_zero;
assign is_gt_mod  = (accumulator_p >= m_i);
assign is_lt_zero = (accumulator_p < 0);

assign valid_o = (curr_state == FINISH);
assign result_o = (curr_state == FINISH) ? (is_gt_mod ? accumulator_p - $signed(m_i) : (is_lt_zero ? $signed(m_i) + accumulator_p : accumulator_p)) : 64'b0;


endmodule : shiftadd_serialized