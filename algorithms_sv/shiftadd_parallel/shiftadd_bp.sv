module shiftadd_parallel (
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus
  input  logic [DATA_LENGTH-1:0]  m_bl_i,
  output logic [DATA_LENGTH-1:0]  result_o
);

localparam NUM_CHUNKS = 3;
localparam DATA_LENGTH = 64;
localparam CHUNK_LENGTH = 32;

logic signed [DATA_LENGTH-1:0] chunk [NUM_CHUNKS-1:0];
logic fold_sign [NUM_CHUNKS-1:0];

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
      if(i == 0) begin
        assign chunk[i] = (x_i & ((1 << bitlength) - 1));
      end else begin
        assign chunk[i] = ((x_i >> ((i) * bitlength)) & mask);
        // i is a genvar, which is just an integer during elaboration.
        // when we write i[0], we're accessing the LSB of i.
        assign fold_sign[i] = (i[0] == 1);
      end
    end
endgenerate

always_comb begin
  result_o = '0;
  for (int i = 0; i < NUM_CHUNKS + 1; i++) begin
    if (i == 0) begin
      result_o = chunk[i];
    end
    else if (i == NUM_CHUNKS) begin
      if (result_o >= m_i) begin
          result_o = result_o - m_i;
      end
      else if (is_fermat && $signed(result_o < 0)) begin
        result_o = result_o + $signed(m_i);
      end
      else begin
        result_o = result_o;
      end
    end
    else begin
      if(is_mersenne) begin
        result_o += chunk[i];
      end
      else begin
        if($signed(result_o) < 0) begin
          result_o = (result_o + $signed(m_i)) + (fold_sign[i] ? -chunk[i] : chunk[i]);
        end
        else begin
          result_o = result_o + (fold_sign[i] ? -chunk[i] : chunk[i]);
        end
      end
    end
  end
end

endmodule : shiftadd_parallel
