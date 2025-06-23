module shiftadd_pipelined (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus
  input  logic [DATA_LENGTH-1:0]  m_bl_i,
  output logic [DATA_LENGTH-1:0]  result_o,
  output logic                    valid_o    // Result valid flag
);

localparam NUM_CHUNKS = 3;
localparam DATA_LENGTH = 64;
localparam CHUNK_LENGTH = 32;

typedef enum logic[2:0] {LOAD, COMP_BLOCK, REDUCE, ADJUST, FINISH} state_t;
state_t curr_state, next_state;

logic d_finish;
logic signed [DATA_LENGTH-1:0] result_p, result_n;
logic signed [DATA_LENGTH-1:0] d_mul_i [NUM_CHUNKS-1:0];
logic signed [DATA_LENGTH-1:0] d_accumulator [NUM_CHUNKS-1:0];
logic signed [DATA_LENGTH-1:0] d_result [NUM_CHUNKS-1:0];
logic signed [DATA_LENGTH-1:0] d_chunk [NUM_CHUNKS-1:0];
logic fold_sign [NUM_CHUNKS-1];

shiftreg #(
    .SHIFT(NUM_CHUNKS+1),
    .DATA(1)
) shift_finish (
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);

logic [DATA_LENGTH-1:0] lo;
logic [DATA_LENGTH-1:0] mask;
logic [DATA_LENGTH-1:0] bitlength;

logic [DATA_LENGTH-1:0] msb_mask;    
logic [DATA_LENGTH-1:0] inner_mask;
logic [NUM_CHUNKS-1:0]  num_folds;

logic is_fermat;   
logic is_mersenne; 

assign msb_mask    = 1 << (m_bl_i - 1);
assign inner_mask  = ((1 << (m_bl_i - 1)) - 1) & ~1;
assign is_fermat   = ((m_i & msb_mask)==msb_mask) && ((m_i & 1)==1) && ((m_i & inner_mask) == 0);
assign is_mersenne = ((m_i ^ ((1 << m_bl_i) - 1)) == 0);
assign bitlength   = is_fermat ? (m_bl_i - 1) : m_bl_i;
assign mask = is_fermat ? ((1 << (m_bl_i-1))-1) : m_i;

generate
    for (genvar i = 0; i < NUM_CHUNKS; i++) begin
      if(i == 0)
        assign d_chunk[i] = (d_mul_i[i] & ((1 << bitlength) - 1));
      else
        assign d_chunk[i] = ((d_mul_i[i] >> ((i) * bitlength)) & mask);
    end
endgenerate

logic signed [DATA_LENGTH-1:0] tmp [NUM_CHUNKS-1:0];
generate
  for (genvar i = 0; i < NUM_CHUNKS; i++) begin
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (i == 0) begin
          d_accumulator[i] <= d_chunk[i];
        end
        else begin
          if(is_mersenne) begin
            d_accumulator[i] <= d_accumulator[i-1] + d_chunk[i];
          end
          else begin
            if($signed(d_accumulator[i-1]) < 0) begin
              d_accumulator[i] <= (d_accumulator[i-1] + $signed(m_i)) + (fold_sign[i-1] ? -d_chunk[i] : d_chunk[i]);
            end
            else begin
              d_accumulator[i] <= d_accumulator[i-1] + (fold_sign[i-1] ? -d_chunk[i] : d_chunk[i]);
            end
          end
        end
      end
  end
endgenerate

generate
  for (genvar i = 0; i < NUM_CHUNKS; i++) begin
    always_ff @(posedge clk_i) begin
      if(i==0) begin
        fold_sign[i] <= 1;
      end
      else if (is_fermat) begin
        fold_sign[i] <= ~fold_sign[i-1];
      end
      else begin
        fold_sign[i] <= fold_sign[i-1];
      end
    end
  end
endgenerate

always_comb begin
    for (int i = 0; i < NUM_CHUNKS; i++) begin
        if (d_accumulator[i] >= m_i) begin
          d_result[i] = d_accumulator[i] - m_i;
        end
        else if (is_fermat && $signed(d_accumulator[i]) < 0) begin
          d_result[i] = d_accumulator[i] + $signed(m_i);
        end
        else begin
          d_result[i] = d_accumulator[i];
        end
    end
end

always_comb begin
  next_state = curr_state;
  case (curr_state)
      LOAD : begin
        if (start_i) begin
            next_state = REDUCE;
        end
      end
      REDUCE : begin
        if(d_finish) begin
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

assign valid_o  = d_finish;
assign result_o = d_result[NUM_CHUNKS-1];

generate
  for (genvar i=0; i<NUM_CHUNKS; i++) begin
    always_ff @(posedge clk_i) begin
      if (i == 0) begin
        d_mul_i[i] <= x_i;
      end 
      else begin
        d_mul_i[i] <= d_mul_i[i-1];
      end
    end
  end
endgenerate

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    curr_state  <= LOAD;
  end else begin
    curr_state  <= next_state;
  end
end

endmodule : shiftadd_pipelined
