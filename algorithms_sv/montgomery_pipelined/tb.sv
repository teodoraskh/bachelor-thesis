
// import multiplier_pkg::*;

module montgomery_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [64-1:0]              indata_x_i   [64-1:0];      // Input data -> operand a.
    logic [64-1:0]              indata_x_m_i [64-1:0];      // Input data -> operand a.
    logic [64-1:0]              indata_m_i;      // Input data -> operand b.
    logic [64-1:0]              indata_m_bl_i;
    logic [64-1:0]              indata_minv_i;   // Input data -> modular inverse.
    logic [64-1:0]              outdata_r_o;     // Output data -> result a*b.

    logic [64-1:0]              reference_o [64-1:0];

    // Instantiate module
    montgomery_pipelined uut (
      .clk_i                  (clk_i),
      .rst_ni                 (rst_ni),
      .start_i                (start_i),    
      .x_i                    (indata_x_m),
      .m_i                    (indata_m_i),
      .m_bl_i                 (indata_m_bl_i), //Modulus bitlength
      .minv_i                 (indata_minv_i),
      .result_o               (outdata_r_o),
      .valid_o                (finish_o)    
    );

    // Clock generation
    initial forever #5 clk_i = ~clk_i;

    // Dumpfile 
    initial begin
        $dumpfile("montgomery_tb.vcd");
        $dumpvars(0, montgomery_tb);
    end

    integer NUM_DATA;
    initial begin
      integer fp;

      fp = $fopen("kyber_input.txt", "r");
      if (!fp) begin
        $fatal(1, "Cannot open input file.");
      end

      NUM_DATA = 0;
      while (!$feof(fp)) begin
        $fscanf(fp, "%h %h", indata_x_i[NUM_DATA], indata_x_m_i[NUM_DATA]);
        NUM_DATA++;
      end

      $fclose(fp);

      $display("Loaded %d inputs from file.", NUM_DATA);
    end

    integer inp_file;
    logic [63:0] indata_x;
    logic [63:0] indata_x_m;

    assign indata_m_bl_i = $clog2(indata_m_i);
    // Stimulus generation
    initial begin
      $display("\n=======================================");
      $display("[%04t] > Start montgomery test", $time);
      $display("=======================================\n");

      // Initialize inputs
      clk_i = 0;
      rst_ni = 1;
      start_i = 0;
      // indata_minv_i = 64'hD988C5E7CA39B7ED;
      // indata_m_i    = 64'h3A32E4C4C7A8C21B;

      indata_m_i = 12'hD01;    // Kyber
      indata_minv_i = -24'h301;
      // indata_minv_i = 24'hFCFF;

      // indata_m_i    = 23'h7FE001;    // Dilithium
      // indata_minv_i = -23'h2001;   // -(2^13 + 1)      
      // indata_minv_i = 23'hDFFF;    // twos(-(2^13 + 1))

      #20;
      // $display("[%04t] > Set reset signal", $time);
      rst_ni = 1;
      for(integer i = 0; i < NUM_DATA; i ++) begin
        #10;
        // $display("[%04t] > Set start signal", $time);
        // Wait a few cycles
        indata_x = indata_x_i[i];
        indata_x_m = indata_x_m_i[i];
        reference_o[i] = indata_x % indata_m_i;
        start_i = 1;

        $display("[%04t] > Set indata_x_i: %h", $time, indata_x_m);
        $display("[%04t] > Set REF: %h", $time, reference_o[i]);
        $display("");
      end

      #10;
      // $display("[%04t] > Reset start signal", $time);
      start_i = 0;
    end

    initial begin
      #10;
      $display("[%04t] < Wait for finish signal", $time);
      @(posedge finish_o)
      $display("[%04t] > Received finish signal", $time);
      // $display("");
      #1;
      for(integer i = 0; i < NUM_DATA; i ++) begin
        $display("[%04t] > OUT data : %h", $time, outdata_r_o);
        $display("[%04t] > REF data : %h", $time, reference_o[i]);
        if (outdata_r_o == reference_o[i])
            $display("[%04t] > Data is VALID", $time);
        else
            $display("[%04t] > Data is INVALID", $time);
        $display("");

        @(posedge clk_i);
        #1;
      end

      $display("\n=======================================");
      $display("[%04t] > Finish montgomery test", $time);
      $display("=======================================\n");

      // Finish simulation
      #100;
      $finish;
    end

endmodule : montgomery_tb 
