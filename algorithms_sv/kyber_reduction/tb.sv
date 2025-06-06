
// // import multiplier_pkg::*;

// module kyber_tb;
//   logic                       clk_i;           // Rising edge active clk.
//   logic                       rst_ni;          // Active low reset.
//   logic                       start_i;         // Start signal.
//   logic                       busy_o;          // Module busy. 
//   logic                       finish_o;        // Module finish.
//   logic [24-1:0]              indata_x_i;      // Input data -> operand a.
//   logic [24-1:0]              indata_xm_i;     // Input data -> operand a.
//   logic [24-1:0]              indata_m_i;      // Input data -> operand b.
//   logic [24-1:0]              indata_minv_i;   // Input data -> operand b.
//   logic [24-1:0]              indata_m_bl_i;   // Input data -> operand b.
//   logic [24-1:0]              outdata_r_o;     // Output data -> result a*b.

//   logic [24-1:0]              reference_o;

//   // Instantiate module
//   kyber_reduction uut (
//     .x_i                    (indata_x_i),
//     .m_i                    (indata_m_i),
//     .result_o               (outdata_r_o)
//   );

//   // reduction_top uut(
//   //   .clk_i            (clk_i),
//   //   .rst_ni           (rst_ni),
//   //   .start_i          (start_i),
//   //   .x_i              (indata_x_i),
//   //   .m_i              (indata_m_i),
//   //   .result_o         (outdata_r_o),
//   //   .valid_o          (finish_o)
//   // );

//   initial forever #5 clk_i = ~clk_i;

//   initial begin
//       $dumpfile("kyber_tb.vcd");
//       $dumpvars(0, kyber_tb);
//   end

//   integer inp_file;

//   assign indata_m_bl_i = $clog2(indata_m_i);

//   // Stimulus generation
//   initial begin
//   $display("\n=======================================");
//   $display("[%04t] > Start kyber_tb test", $time);
//   $display("=======================================\n");

//   clk_i     = 0;
//   rst_ni    = 0;
//   start_i   = 0;

//   // indata_minv_i = 64'hD988C5E7CA39B7ED;
//   // indata_m_i    = 64'h3A32E4C4C7A8C21B;
//   // indata_m_i = 64'h7FFFFFFF; // Mersenne
//   // indata_m_i = 32'h80000001; // Fermat
//   // indata_m_i = 32'h21;
//   // indata_m_i = 32'h2001;
//   indata_minv_i = 24'hFCFF;
//   indata_m_i = 24'hD01;

//   inp_file = $fopen("input_reduced.txt", "r");
//   if (inp_file == 0) begin
//       $display("ERROR: Failed to open file.");
//       $finish;
//   end else begin
//       $display("File opened.");
//   end
  
//   while (!$feof(inp_file)) begin
//     $fscanf(inp_file, "%h", indata_x_i);
//     #5
//     if (indata_x_i != 0) begin
//       $display("[%04t] > Input data    : %h", $time, indata_x_i);
//       reference_o = indata_x_i % indata_m_i;

//       $display("[%04t] > Received data : %h", $time, outdata_r_o);
//       $display("[%04t] > Reference data: %h", $time, reference_o);
//       if (outdata_r_o == reference_o)
//           $display("[%04t] > Data is VALID", $time);
//       else
//           $display("[%04t] > Data is INVALID", $time);
//       $display("");
//     end
//   end

//   $display("\n=======================================");
//   $display("[%04t] > Finish kyber_tb test", $time);
//   $display("=======================================\n");

//   // Finish simulation
//   #100;
//   $finish;
// end

// endmodule : kyber_tb 



// import multiplier_pkg::*;

module kyber_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [24-1:0]              indata_x_i   [58:0];      // Input data -> operand a.
    logic [24-1:0]              indata_m_i;     
    logic [24-1:0]              outdata_r_o;     // Output data -> result a*b.

    logic [24-1:0]              reference_o [58:0];

    // Instantiate module
   reduction_top uut(
     .clk_i            (clk_i),
     .rst_ni           (rst_ni),
     .start_i          (start_i),
     .x_i              (indata_x),
     .m_i              (indata_m_i),
     .result_o         (outdata_r_o),
     .valid_o          (finish_o)
   );

    // Clock generation
    initial forever #5 clk_i = ~clk_i;

    // Dumpfile 
    initial begin
        $dumpfile("kyber_tb.vcd");
        $dumpvars(0, kyber_tb);
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

    integer inp_file;
    logic [24-1:0] indata_x;

    assign indata_m_bl_i = $clog2(indata_m_i);
    // Stimulus generation
    initial begin
      $display("\n=======================================");
      $display("[%04t] > Start shiftadd test", $time);
      $display("=======================================\n");

      // Initialize inputs
      clk_i = 0;
      rst_ni = 1;
      start_i = 0;
      // indata_m_i = 64'h7FFFFFFF; // Mersenne
      // indata_m_i = 64'h80000001; // Fermat
      indata_m_i = 24'hD01;

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
      $display("[%04t] > Finish shiftadd test", $time);
      $display("=======================================\n");

      // Finish simulation
      #100;
      $finish;
    end

endmodule : kyber_tb 
