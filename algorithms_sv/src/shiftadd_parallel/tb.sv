
import params_pkg::*;
module shiftadd_bp_tb;
    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy.
    logic                       finish_o;        // Module finish.
    logic [DATA_LENGTH-1:0]     indata_x_i;      // Number to reduce x.
    logic [DATA_LENGTH-1:0]     indata_m_i;      // Modulus.
    logic [DATA_LENGTH-1:0]     indata_m_bl_i;   // Modulus bitlength.
    logic [DATA_LENGTH-1:0]     outdata_r_o;     // Result x mod m.

    logic [DATA_LENGTH-1:0]     reference_o;

    shiftadd_parallel_top uut (
      .CLK_pci_sys_clk_p      (clk_i),
      .rst_ni                 (rst_ni),
      .start_i                (start_i),
      .x_i                    (indata_x_i),
      .m_i                    (indata_m_i),
      .m_bl_i                 (indata_m_bl_i),
      .result_o               (outdata_r_o),
      .valid_o                (finish_o)
    );

    initial forever #5 clk_i = ~clk_i;

    initial begin
        $dumpfile("shiftadd_bp_tb.vcd");
        $dumpvars(0, shiftadd_bp_tb);
    end

    integer inp_file;

    assign indata_m_bl_i = MODULUS_LENGTH;
    assign indata_m_i    = MODULUS;

    initial begin
    $display("\n=======================================");
    $display("[%04t] > Start shiftadd_bp_tb test", $time);
    $display("=======================================\n");

    clk_i     = 0;
    rst_ni    = 0;
    start_i   = 0;


    inp_file = $fopen("input.txt", "r");
    if (inp_file == 0) begin
        $display("ERROR: Failed to open file.");
        $finish;
    end else begin
        $display("File opened.");
    end

    #10;
    rst_ni = 0;
    #40;
    rst_ni = 1;
    #20;

    while (!$feof(inp_file)) begin
       $fscanf(inp_file, "%h", indata_x_i);
        #5
        if (indata_x_i != 0) begin
          $display("[%04t] > Input data    : %h", $time, indata_x_i);
          reference_o = indata_x_i % indata_m_i;

          @(posedge clk_i);
          start_i = 1;
          @(posedge clk_i);
          start_i = 0;
          wait (finish_o == 1);

          @(posedge clk_i);

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
