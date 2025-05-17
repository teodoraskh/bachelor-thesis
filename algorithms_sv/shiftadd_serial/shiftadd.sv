module shiftadd_serialized (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]             x_i,       // Input
  input  logic [DATA_LENGTH-1:0]             m_i,       // Modulus
  input  logic [DATA_LENGTH-1:0]             m_bl_i,
  output logic [DATA_LENGTH-1:0]             result_o,
  output logic                    valid_o    // Result valid flag
);

localparam NUM_CHUNKS = 3;
localparam DATA_LENGTH = 64;
localparam CHUNK_LENGTH = 32;

typedef enum logic[1:0] {LOAD, COMP_BLOCK, REDUCE, FINISH} state_t;
state_t curr_state, next_state;
//  TODO: replace 64 with DATA_LENGTH
//  TODO: replace 32 with CHUNK_LENGTH
//  TODO: replace  3 with NUM_CHUNKS

logic [1:0]  hi_index;
logic [DATA_LENGTH-1:0] result_p;
logic [DATA_LENGTH-1:0] mul_i;
logic [DATA_LENGTH-1:0] result;
logic [CHUNK_LENGTH-1:0] higher_bits [NUM_CHUNKS-1:0];

logic fold_sign_p, fold_sign_n;
logic ctrl_update_operands;
logic ctrl_update_result;
logic ctrl_update_fold_sign;
logic ctrl_update_mul_counter;


logic [DATA_LENGTH-1:0] lo;
logic [DATA_LENGTH-1:0] mask;
logic [DATA_LENGTH-1:0] bitlength;

logic [DATA_LENGTH-1:0] msb_mask;    
logic [DATA_LENGTH-1:0] inner_mask;  
logic is_fermat;   
logic is_mersenne; 


assign msb_mask    = 1 << (m_bl_i - 1);
assign inner_mask  = ((1 << (m_bl_i - 1)) - 1) & ~1;
assign is_fermat   = ((m_i & msb_mask)==msb_mask) && ((m_i & 1)==1) && ((m_i & inner_mask) == 0);
assign is_mersenne = ((m_i ^ ((1 << m_bl_i) - 1)) == 0);
assign bitlength   = is_fermat ? (m_bl_i - 1) : m_bl_i;
assign mask = is_fermat ? ((1 << (m_bl_i-1))-1) : m_i;
assign lo   = (mul_i & ((1 << bitlength) - 1));


generate
    for (genvar i = 0; i < NUM_CHUNKS; i++) begin
        assign higher_bits[i] = ((mul_i >> ((i+1) * bitlength)) & mask);
    end
endgenerate


always_comb begin
    ctrl_update_operands    = (curr_state == LOAD);
    ctrl_update_mul_counter = (curr_state == COMP_BLOCK);
    ctrl_update_fold_sign   = (curr_state == REDUCE);
    ctrl_update_result      = (curr_state == REDUCE);
end


always_comb begin
  next_state    = curr_state;
  case (curr_state)
      LOAD : begin
        if (start_i) begin
            next_state = REDUCE;
        end
      end
      COMP_BLOCK : begin
        // TODO: change 2 into NUM_CHUNKS - 1
        if (hi_index == NUM_CHUNKS-1) begin
            next_state = FINISH;
        end else  begin
            next_state = REDUCE;
        end
      end
      REDUCE : begin
        next_state = COMP_BLOCK;
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

always_comb begin
  if(curr_state == FINISH) begin
    if(result_p >= m_i) begin
      result_o = result_p - m_i;
    end 
    else if($signed(result_p) < 0) begin
      result_o = result_p + m_i;
    end
    else begin
      result_o = result_p;
    end
  end else begin
    result_o = 64'b0;
  end
end

always_comb begin
    if (is_fermat && $signed(result_p) < 0) begin
        result_p = result_p + $signed(m_i);
    end
end

always_ff @(posedge clk_i) begin
    $display("Cycle: %d, State: %s, start_i: %d, result_p: %h, valid_o: %d, index_p: %d",
            $time, curr_state.name(), start_i, result_p, valid_o, hi_index);
end

always_ff @(posedge clk_i) begin
    if (rst_ni == 0) begin
        mul_i <= 0;
    end 
    else if (ctrl_update_operands) begin
        mul_i <= x_i;
    end
end

always_ff @(posedge clk_i) begin
    if (rst_ni == 0) begin
        hi_index <= 0;
    end 
    else if (ctrl_update_mul_counter) begin
        hi_index <= (hi_index == NUM_CHUNKS - 1) ? 0 : hi_index + 1;
    end
end


always_ff @(posedge clk_i) begin
    if (rst_ni == 0) begin
        result_p <= lo;
    end 
    else if (ctrl_update_result) begin
        if (is_mersenne) begin
            result_p <= result_p + higher_bits[hi_index];
        end else begin
            result_p <= result_p + (fold_sign_p ? -higher_bits[hi_index] : higher_bits[hi_index]);
        end
    end
end

always_ff @(posedge clk_i) begin
    if(!rst_ni) begin
        fold_sign_p <= 1;
    end
    else if(ctrl_update_fold_sign) begin
        fold_sign_p <= ~fold_sign_p;
    end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    curr_state  <= LOAD;
  end else begin
    curr_state  <= next_state;
  end
end

endmodule : shiftadd_serialized