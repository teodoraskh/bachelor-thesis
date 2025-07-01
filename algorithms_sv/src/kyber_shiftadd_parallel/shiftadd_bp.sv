import multiplier_pkg::*;
module shiftadd_parallel (
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus
  input  logic [DATA_LENGTH-1:0]  m_bl_i,    // Bitlength
  output logic [DATA_LENGTH-1:0]  result_o
);

localparam NUM_CHUNKS = 3;

logic signed [DATA_LENGTH-1:0] chunk [NUM_CHUNKS-1:0];

logic [DATA_LENGTH-1:0] lo;
logic [DATA_LENGTH-1:0] mask;

assign mask = (1 << m_bl_i)-1;


generate
    for (genvar i = 0; i < NUM_CHUNKS; i++) begin
      if(i == 0) begin
        assign chunk[i] = (x_i & ((1 << m_bl_i) - 1));
      end else begin
        assign chunk[i] = ((x_i >> ((i) * m_bl_i)) & mask);
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
      else begin
        result_o = result_o;
      end
    end
    else begin
      result_o = result_o + scale_chunk_kyber(chunk[i], i);
    end
  end
end

// Computes scaled value of `chunk` by (2^9 + 2^8 - 1)^i
function automatic logic [DATA_LENGTH-1:0] scale_chunk_kyber (
    input logic [31:0] chunk,
    input int unsigned i
);
    logic [127:0] tmp;
    tmp = chunk;
    for (int j = 0; j < i; j++) begin
        tmp = (tmp << 9) + (tmp << 8) - tmp;
    end
    return tmp;
endfunction

endmodule : shiftadd_parallel
