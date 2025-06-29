import multiplier_pkg::*;
module reduction (

  input  logic [DATA_LENGTH-1:0]  x_i,       // Input (e.g., 64-bit)
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus (e.g., 32-bit)
  output logic [DATA_LENGTH-1:0]  result_o
);

logic [DATA_LENGTH-1:0] tmp;
logic signed [DATA_LENGTH-1:0] res;

assign tmp = x_i[22:0] + 
                  (({1'b0, x_i[32:23]} + {2'b0, x_i[42:33]} + {2'b0, x_i[45:43]}) << 13) +
                  ~({2'b0, x_i[45:23]} + {2'b0, x_i[45:33]} + {2'b0, x_i[45:43]}) + 1;

assign result_o = (tmp > m_i) ? tmp - m_i : tmp;

endmodule : reduction