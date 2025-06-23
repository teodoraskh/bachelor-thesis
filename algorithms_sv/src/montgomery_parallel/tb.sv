
import multiplier_pkg::*;
import params_pkg::*;

module montgomery_bp_tb;
  logic                       clk_i;           // Rising edge active clk.
  logic                       rst_ni;          // Active low reset.
  logic                       start_i;         // Start signal.
  logic                       busy_o;          // Module busy. 
  logic                       finish_o;        // Module finish.
  logic [DATA_LENGTH-1:0]     indata_x_i;      // Input data -> operand a.
  logic [DATA_LENGTH-1:0]     indata_xm_i;     // Input data -> operand a.
  logic [DATA_LENGTH-1:0]     indata_m_i;      // Input data -> operand b.
  logic [DATA_LENGTH-1:0]     indata_minv_i;   // Input data -> operand b.
  logic [DATA_LENGTH-1:0]     indata_m_bl_i;   // Input data -> operand b.
  logic [DATA_LENGTH-1:0]     outdata_r_o;     // Output data -> result a*b.

  logic [DATA_LENGTH-1:0]     reference_o;

  montgomery_parallel uut (
    .x_i                    (indata_xm_i),
    .m_i                    (indata_m_i),
    .minv_i                 (indata_minv_i),
    .m_bl_i                 (indata_m_bl_i),
    .result_o               (outdata_r_o)
  );

  initial forever #5 clk_i = ~clk_i;

  initial begin
      $dumpfile("montgomery_bp_tb.vcd");
      $dumpvars(0, montgomery_bp_tb);
  end

  integer inp_file;

  assign indata_m_bl_i = MODULUS_LENGTH;
  assign indata_m_i    = MODULUS;
  assign indata_minv_i = MOD_INV;  

  // Stimulus generation
  initial begin
  $display("\n=======================================");
  $display("[%04t] > Start montgomery_bp_tb test", $time);
  $display("=======================================\n");

  clk_i     = 0;
  rst_ni    = 0;
  start_i   = 0;

  inp_file = $fopen("dilithium_input.txt", "r");
  if (inp_file == 0) begin
      $display("ERROR: Failed to open file.");
      $finish;
  end else begin
      $display("File opened.");
  end
  
  while (!$feof(inp_file)) begin
    $fscanf(inp_file, "%h %h", indata_x_i, indata_xm_i);
    #5
    if (indata_x_i != 0) begin
      $display("[%04t] > Input data    : %h", $time, indata_xm_i);
      reference_o = indata_x_i % indata_m_i;

      $display("[%04t] > Received data : %h", $time, outdata_r_o);
      $display("[%04t] > Reference data: %h", $time, reference_o);
      if (outdata_r_o == reference_o)
          $display("[%04t] > Data is VALID", $time);
      else
          $display("[%04t] > Data is INVALID", $time);
      $display("");
    end
  end

  $display("\n=======================================");
  $display("[%04t] > Finish montgomery_bp_tb test", $time);
  $display("=======================================\n");

  #100;
  $finish;
end

endmodule : montgomery_bp_tb 
