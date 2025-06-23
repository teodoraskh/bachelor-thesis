
// import multiplier_pkg::*;

module shiftadd_bp_tb;
    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [64-1:0]              indata_x_i;      // Input data -> operand a.
    logic [64-1:0]              indata_m_i;      // Input data -> operand b.
    logic [64-1:0]              indata_mu_i;     // Input data -> operand b.
    logic [64-1:0]              indata_m_bl_i;   // Input data -> operand b.
    logic [64-1:0]              outdata_r_o;     // Output data -> result a*b.

    logic [64-1:0]              reference_o;

    shiftadd_parallel uut (
      .x_i                    (indata_x_i),
      .m_i                    (indata_m_i),
      .m_bl_i                 (indata_m_bl_i),
      .result_o               (outdata_r_o)
    );

    initial forever #5 clk_i = ~clk_i;

    initial begin
        $dumpfile("shiftadd_bp_tb.vcd");
        $dumpvars(0, shiftadd_bp_tb);
    end

    integer inp_file;

    assign indata_m_bl_i = $clog2(indata_m_i);

    initial begin
    $display("\n=======================================");
    $display("[%04t] > Start shiftadd_bp_tb test", $time);
    $display("=======================================\n");

    clk_i     = 0;
    rst_ni    = 0;
    start_i   = 0;

    // indata_m_i = 64'h7FFFFFFF; // Mersenne
    indata_m_i = 32'h80000001; // Fermat

    inp_file = $fopen("input.txt", "r");
    if (inp_file == 0) begin
        $display("ERROR: Failed to open file.");
        $finish;
    end else begin
        $display("File opened.");
    end

    while (!$feof(inp_file)) begin
       $fscanf(inp_file, "%h", indata_x_i);
        #5
        if (indata_x_i != 0) begin
          $display("[%04t] > Input data    : %h", $time, indata_x_i);
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
    $display("[%04t] > Finish shiftadd_bp_tb test", $time);
    $display("=======================================\n");

    #100;
    $finish;
end

endmodule : shiftadd_bp_tb 
