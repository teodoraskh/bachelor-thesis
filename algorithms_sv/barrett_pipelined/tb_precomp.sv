
// import multiplier_pkg::*;

module barrett_precomp_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [64-1:0]              indata_x_i   [49-1:0];      // Input data -> operand a.
    logic [64-1:0]              indata_m_i;      // Input data -> operand b.
    logic [64-1:0]              indata_mu_i;   // Input data -> modular inverse.
    logic [64-1:0]              outdata_r_o;     // Output data -> result a*b.

    logic [64-1:0]              reference_o [49-1:0];

    // Instantiate module
    barrett_pipelined uut (
      .clk_i                  (clk_i),           // Rising edge active clk.
      .rst_ni                 (rst_ni),          // Active low reset.
      .start_i                (start_i),         // Start signal.
      .x_i                    (indata_x),        // Module busy. 
      .m_i                    (indata_m_i),      // Module finish.
      .mu_i                   (indata_mu_i),     // Input data -> operand a.
      .result_o               (outdata_r_o),
      .valid_o                (finish_o)
    );

    // Clock generation
    initial forever #5 clk_i = ~clk_i;

    // Dumpfile 
    initial begin
      $dumpfile("barrett_precomp_tb.vcd");
      $dumpvars(0, barrett_precomp_tb);
    end

    integer NUM_DATA;
    initial begin
      integer fp;

      fp = $fopen("input.txt", "r");
      if (!fp) begin
        $fatal(1, "Cannot open input file.");
      end

      NUM_DATA = 0;
      while (!$feof(fp)) begin
        $fscanf(fp, "%h", indata_x_i[NUM_DATA]);
        NUM_DATA++;
      end

      $fclose(fp);

      $display("Loaded %d inputs from file.", NUM_DATA);
    end

    logic [63:0] indata_x;

    // Stimulus generation
    initial begin
      $display("\n=======================================");
      $display("[%04t] > Start barrett precomp test", $time);
      $display("=======================================\n");

      // Initialize inputs
      clk_i = 0;
      rst_ni = 1;
      start_i = 0;
      indata_m_i    = 64'h3A32E4C4C7A8C21B;
      indata_mu_i   = 64'h466123E72A6BDD53;

      #20;
      // $display("[%04t] > Set reset signal", $time);
      rst_ni = 1;
      for(integer i = 0; i < NUM_DATA; i ++) begin
        #10;
        // $display("[%04t] > Set start signal", $time);
        // Wait a few cycles
        indata_x = indata_x_i[i];
        reference_o[i] = indata_x % indata_m_i;
        start_i = 1;

        $display("[%04t] > Set indata_x_i: %h", $time, indata_x);
        $display("[%04t] > Set REF: %h", $time, reference_o[i]);
        $display("");
      end

      #10;
      // $display("[%04t] > Reset start signal", $time);
      start_i = 0;
      // $display("");
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
        if (outdata_r_o == reference_o[i]) begin
            $display("[%04t] > Data is VALID", $time);
        end else begin
            $display("[%04t] > Data is INVALID", $time);
        end
        $display("");

        @(posedge clk_i);
        #1;
      end

      $display("\n=======================================");
      $display("[%04t] > Finish barrett precomp test", $time);
      $display("=======================================\n");

      // Finish simulation
      #100;
      $finish;
    end

endmodule : barrett_precomp_tb 
