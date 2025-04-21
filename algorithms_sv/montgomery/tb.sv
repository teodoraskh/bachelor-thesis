
// import multiplier_pkg::*;

module montgomery_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [64-1:0]              indata_x_i;      // Input data -> operand a.
    logic [64-1:0]              indata_m_i;      // Input data -> operand b.
    logic [64-1:0]              outdata_r_o;     // Output data -> result a*b.

    logic [64-1:0]              reference_o;

    // Instantiate module
    montgomery_serialized uut (
        .clk_i                  (clk_i),
        .rst_ni                 (rst_ni),
        .start_i                (start_i),    
        .x_i                    (indata_x_i),
        .m_i                    (indata_m_i),
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

    integer inp_file;
    logic [63:0] indata_x;

    // Stimulus generation
    initial begin
        $display("\n=======================================");
        $display("[%04t] > Start montgomery test", $time);
        $display("=======================================\n");

        // Initialize inputs
        clk_i = 0;
        rst_ni = 0;
        start_i = 0;
        indata_m_i = 64'h3A32E4C4C7A8C21B;
        indata_x_i = 64'h1;
        indata_x = 64'h1;
        // indata_mu_i = 64'h2CDE_B2B0;

        inp_file  = $fopen("input.txt", "r");
        // outp_file = $fopen("output.txt", "w");

        while (indata_x != 0) begin
          rst_ni = 0;
          // 10C26604
          // (($urandom() % (indata_m_i * 4))
          // indata_x_i = (64'h10C26604 * $bits(indata_m_i)) % indata_m_i;
          // already in Montgomery form for now VVVV
          // indata_x_i = 64'hA0AC29C83A77226;
          $fscanf(inp_file, "%h %h", indata_x, indata_x_i);
          #20;
          // $display("[%04t] > Set reset signal", $time);
          rst_ni = 1;
          // Wait a few cycles
          #10;

          if(indata_x != 0) begin
            // $display("[%04t] > Set start signal", $time);
            // 64'hFA02FB51BF52F459
            reference_o = indata_x % indata_m_i;
            start_i = 1;

            $display("[%04t] > Set indata_x_i: %h", $time, indata_x_i);

            #10;
            // $display("[%04t] > Reset start signal", $time);
            start_i = 0;
            $display("");

            #10;
            // $display("[%04t] < Wait for finish signal", $time);
            @(posedge finish_o)
            // $display("[%04t] > Received finish signal", $time);
            $display("");

            $display("[%04t] > Received data : %h", $time, outdata_r_o);
            $display("[%04t] > Reference data: %h", $time, reference_o);
            if (outdata_r_o == reference_o)
                $display("[%04t] > Data is VALID", $time);
            else
                $display("[%04t] > Data is INVALID", $time);
          end
        end

        $display("\n=======================================");
        $display("[%04t] > Finish montgomery test", $time);
        $display("=======================================\n");

        // Finish simulation
        #100;
        $finish;
    end

endmodule : montgomery_tb 
