
import multiplier_pkg::*;
import params_pkg::*;

module barrett_tb;

    logic                       clk_i;                               // Rising edge active clk.
    logic                       rst_ni;                              // Active low reset.
    logic                       start_i;                             // Start signal.
    logic                       busy_o;                              // Module busy. 
    logic                       finish_o;                            // Module finish.
    logic [DATA_LENGTH-1:0]     indata_x_i   [DATA_LENGTH-1:0];      // Input x.
    logic [DATA_LENGTH-1:0]     indata_q_i;                          // Modulus.
    logic [DATA_LENGTH-1:0]     indata_q_bl_i;                       // Modulus bitlength.
    logic [DATA_LENGTH-1:0]     indata_mu_i;                         // Precomputed mu.
    logic [DATA_LENGTH-1:0]     outdata_r_o;                         // Output data.
    logic [DATA_LENGTH-1:0]     reference_o [DATA_LENGTH-1:0];       // Finish signal.

    barrett_pipelined uut (
      .clk_i                  (clk_i),              // Rising edge active clk.
      .rst_ni                 (rst_ni),             // Active low reset.
      .start_i                (start_i),            // Start signal.
      .x_i                    (indata_x),           // Input x. 
      .q_i                    (indata_q_i),         // Modulus.
      .q_bl_i                 (indata_q_bl_i),      // Modulus bitlength.
      .mu_i                   (indata_mu_i),        // Precomputed mu.
      .result_o               (outdata_r_o),        // Result.
      .valid_o                (finish_o)            // Finish signal.
    );

    initial forever #5 clk_i = ~clk_i;

    initial begin
      $dumpfile("barrett_tb.vcd");
      $dumpvars(0, barrett_tb);
    end

    integer NUM_DATA;
    initial begin
      integer fp;

      fp = $fopen("dilithium_input.txt", "r");
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

    logic [DATA_LENGTH-1:0] indata_x;
    
    assign indata_q_bl_i = MODULUS_LENGTH;
    assign indata_q_i    = MODULUS;
    assign indata_mu_i   = MU;

    initial begin
      $display("\n=======================================");
      $display("[%04t] > Start barrett precomp test", $time);
      $display("=======================================\n");

      clk_i = 0;
      rst_ni = 1;
      start_i = 0;

      #20;
      rst_ni = 1;
      for(integer i = 0; i < NUM_DATA; i ++) begin
        #10;

        indata_x = indata_x_i[i];
        reference_o[i] = indata_x % indata_q_i;
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

endmodule : barrett_tb 
