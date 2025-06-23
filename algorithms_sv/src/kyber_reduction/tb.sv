import multiplier_pkg::*;
module kyber_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [DATA_LENGTH-1:0]     indata_x_i   [63:0];      // Input data -> operand a.
    logic [DATA_LENGTH-1:0]     indata_m_i;     
    logic [DATA_LENGTH-1:0]     outdata_r_o;     // Output data -> result a*b.

    logic [DATA_LENGTH-1:0]     reference_o [63:0];

   reduction_top uut(
     .clk_i            (clk_i),
     .rst_ni           (rst_ni),
     .start_i          (start_i),
     .x_i              (indata_x),
     .m_i              (indata_m_i),
     .result_o         (outdata_r_o),
     .valid_o          (finish_o)
   );

    initial forever #5 clk_i = ~clk_i;

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
    logic [DATA_LENGTH-1:0] indata_x;

    assign indata_m_bl_i = 12;
    assign indata_m_i    = 3329;

    
    initial begin
      $display("\n=======================================");
      $display("[%04t] > Start kyber test", $time);
      $display("=======================================\n");

      clk_i = 0;
      rst_ni = 1;
      start_i = 0;


      #20;
      rst_ni = 1;
      for(integer i = 0; i < NUM_DATA; i ++) begin
        #10;

        indata_x = indata_x_i[i];
        reference_o[i] = indata_x % indata_m_i;
        start_i = 1;

        $display("[%04t] > Set indata_x_i: %h", $time, indata_x);
        $display("[%04t] > Set REF: %h", $time, reference_o[i]);
        $display("");
      end

      #10;
      start_i = 0;
    end

    initial begin
      #10;
      $display("[%04t] < Wait for finish signal", $time);
      @(posedge finish_o)
      $display("[%04t] > Received finish signal", $time);
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
      $display("[%04t] > Finish kyber test", $time);
      $display("=======================================\n");

      #100;
      $finish;
    end

endmodule : kyber_tb 
