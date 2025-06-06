module kyber_reduction (        // Rising edge active clk.
    input  logic [24-1:0]     x_i,     // Input data -> operand a.
    input  logic [12-1:0]     m_i,     // Input data -> modulus.
    output logic [24-1:0]     result_o     // Output data -> result a*b.
);
logic [23:0] tmp;
assign tmp = x_i[11:0] + 
                  (({1'b0, x_i[23:15]} + {2'b0, x_i[23:16]} + {2'b0, x_i[14:12]}) << 9) +
                  (({1'b0, x_i[23:15]} + {2'b0, x_i[23:16]} + {2'b0, x_i[15:12]}) << 8) +
                  ~({2'b0, x_i[23:15]} + {2'b0, x_i[23:16]} + {2'b0, x_i[23:12]}) + 1;
assign result_o = (tmp > m_i) ? tmp - m_i : tmp;

endmodule : kyber_reduction