module reduction_top (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [24-1:0]           x_i,       // Input (e.g., 64-bit)
  input  logic [12-1:0]           m_i,       // Modulus (e.g., 32-bit)
  output logic [24-1:0]           result_o,
  output logic                    valid_o    // Result valid flag
);

localparam NUM_RED = 4;

logic [24-1:0] x_delayed [NUM_RED-1:0];
logic [24-1:0] x_delayed1;
logic [24-1:0] x_delayed2;
logic [24-1:0] x_delayed3;
logic [24-1:0] x_delayed4;
logic [24-1:0] res_delayed [NUM_RED-1:0];
logic finish_delayed [NUM_RED-1:0];

// debug
assign x_delayed1 =  x_delayed[0];
assign x_delayed2 =  x_delayed[1];
assign x_delayed3 =  x_delayed[2];
assign x_delayed4 =  x_delayed[3];

always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    x_delayed[0] <= '0;
    x_delayed[1] <= '0;
    x_delayed[2] <= '0;
    x_delayed[3] <= '0;
  end else begin
    x_delayed[0] <= x_i;
    x_delayed[1] <= res_delayed[0];
    x_delayed[2] <= res_delayed[1];
    x_delayed[3] <= res_delayed[2];
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    finish_delayed[0] <= 0;
    finish_delayed[1] <= 0;
    finish_delayed[2] <= 0;
    finish_delayed[3] <= 0;
  end else begin
    finish_delayed[0] <= start_i;
    finish_delayed[1] <= finish_delayed[0];
    finish_delayed[2] <= finish_delayed[1];
    finish_delayed[3] <= finish_delayed[2];
  end
end

genvar i;
generate
  for (i = 0; i < NUM_RED; i++) begin
    kyber_reduction uut (
      .x_i      (x_delayed[i]),
      .m_i      (m_i),
      .result_o (res_delayed[i])
    );
  end
endgenerate


assign result_o = res_delayed[NUM_RED-1];
assign valid_o = finish_delayed[NUM_RED-1];


endmodule : reduction_top