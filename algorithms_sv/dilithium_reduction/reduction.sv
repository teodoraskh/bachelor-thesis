module dilithium_reduction (        // Rising edge active clk.
    input  logic [46-1:0]     x_i,     // Input data -> operand a.
    input  logic [23-1:0]     m_i,     // Input data -> modulus.
    output logic [46-1:0]     result_o     // Output data -> result a*b.
);
logic [46-1:0] tmp;
assign tmp = x_i[22:0] + 
                  (({1'b0, x_i[32:23]} + {2'b0, x_i[42:33]} + {2'b0, x_i[45:43]}) << 13) +
                  ~({2'b0, x_i[45:23]} + {2'b0, x_i[45:33]} + {2'b0, x_i[45:43]}) + 1;
assign result_o = (tmp > m_i) ? tmp - m_i : tmp;

endmodule : dilithium_reduction