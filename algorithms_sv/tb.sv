
// import multipler_pkg::*;

module barrett_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [63:0]     indata_x_i;      // Input data -> operand a.
    logic [63:0]     indata_m_i;      // Input data -> operand b.
    logic [63:0]     indata_mu_i;      // Input data -> operand b.
    logic [127:0]   outdata_r_o;     // Output data -> result a*b.

    localparam NUM_DATA = 3;
    logic [127:0]   reference_o [NUM_DATA-1:0];

    // Instantiate module
    barrett_pipelined uut (
        .clk_i                  (clk_i),           // Rising edge active clk.
        .rst_ni                 (rst_ni),          // Active low reset.
        .start_i                (start_i),         // Start signal.
        .x_i                    (indata_x_i),          // Module busy. 
        .m_i                    (indata_m_i),        // Module finish.
        .mu_i                   (indata_mu_i),      // Input data -> operand a.
        .result_o               (outdata_r_o),
        .valid_o                (finish_o)
    );

    // Clock generation
    initial forever #5 clk_i = ~clk_i;

    // Dumpfile 
    initial begin
        $dumpfile("barrett.vcd");
        $dumpvars(0, barrett_tb);
    end

    // Stimulus generation
    initial begin

        $display("\n=======================================");
        $display("[%04t] > Start barrett test", $time);
        $display("=======================================\n");

        // Initialize inputs
        clk_i = 0;
        rst_ni = 1;
        start_i = 0;
        indata_x_i = 0;
        indata_m_i = 0;
        indata_mu_i = 0;

        #20;
        $display("[%04t] > Set reset signal", $time);
        rst_ni = 1;

        // #50;
        // $display("> Reset reset signal");
        // rst_ni = 1;

        // 4 input pairs are generated.
        // each input is split into 4 blocks of 16 bytes each
        // in multiplication_pipeline, we instantiate 16 flipflops
        // each tuple of 4 flipflops belongs to a multiplication.
        // each tuple of 4 16x16 multipliers belongs to a multiplication.
        for (integer i=0; i<NUM_DATA; i++) begin
            #10;
            $display("[%04t] > Set start signal", $time);
            indata_x_i = $random; // 64'h0003_0002_0001_0000;
            indata_m_i = $random; // 64'h0000_0000_0000_0002;
            indata_mu_i = (1 / indata_m_i) >> $bits(indata_m_i);
            reference_o[i] = indata_x_i % indata_m_i;
            start_i = 1;

            $display("[%04t] > Set A  : %h", $time, indata_x_i);
            $display("[%04t] > Set B  : %h", $time, indata_m_i);
            $display("[%04t] > Set REF: %h", $time, reference_o[i]);

        end

        #10;
        $display("[%04t] > Reset start signal", $time);
        start_i = 0;
        $display("");
    end

    initial begin
        #10;
        $display("[%04t] < Wait for finish signal", $time);
        @(posedge finish_o)
        $display("[%04t] > Received finish signal", $time);
        // $display("");
        #1;

        for (integer i=0; i<NUM_DATA; i++) begin
            $display("[%04t] > OUT data: %h", $time, outdata_r_o);
            $display("[%04t] > REF data: %h", $time, reference_o[i]);
            if (outdata_r_o == reference_o[i]) begin
                $display("[%04t] > Data is VALID", $time);
            end
            else begin
                $display("[%04t] > Data is INVALID", $time);
            end

            @(posedge clk_i);
            #1;
        end

        $display("\n=======================================");
        $display("[%04t] > Finish multipler test", $time);
        $display("=======================================\n");

        // Finish simulation
        #100;
        $finish;

    end

endmodule : barrett_tb 

// module barrett_pipelined_tb;

//     // Parameters
//     localparam K = 32;          // Bit-width of modulus (change if needed)
//     localparam NUM_DATA = 4;    
//     localparam CLK_PERIOD = 10; // 100MHz clock

//     // DUT Signals
//     logic        clk_i;
//     logic        rst_ni;
//     logic        start_i;
//     logic [63:0] x_i;
//     logic [63:0] m_i;       // Actual modulus in lower K bits
//     logic [63:0] mu_i;
//     logic [127:0] result_o;
//     logic        valid_o;

//     // Testbench Signals
//     logic [63:0] reference[NUM_DATA];
//     int error_count = 0;

//     // Instantiate DUT
//     barrett_pipelined uut (
//         .*
//     );

//     // Clock generation
//     initial begin
//         clk_i = 0;
//         forever #(CLK_PERIOD/2) clk_i = ~clk_i;
//     end

//     // VCD dumping
//     initial begin
//         $dumpfile("barrett.vcd");
//         $dumpvars(0, barrett_pipelined_tb);
//     end

//     // Main test sequence
//     initial begin
//         initialize();
//         reset_dut();
//         run_tests();
//         report_results();
//         $finish;
//     end

//     task initialize();
//         rst_ni = 1;
//         start_i = 0;
//         x_i = 0;
//         m_i = 0;
//         mu_i = 0;
//         #100;
//     endtask

//     task reset_dut();
//         $display("[%0t] Resetting DUT", $time);
//         rst_ni = 0;
//         #(CLK_PERIOD*2);
//         rst_ni = 1;
//         #(CLK_PERIOD);
//     endtask

//     task run_tests();
//         for(int i=0; i<NUM_DATA; i++) begin
//             generate_test_case(i);
//             apply_inputs();
//             wait_for_result(i);
//             verify_result(i);
//         end
//     endtask

//     task generate_test_case(int idx);
//         // Generate valid modulus (32-bit)
//         m_i[31:0] = $urandom_range(2, (1<<K)-1);
//         m_i[63:32] = 0;  // Upper bits unused
        
//         // Compute μ = floor(2^(2K)/m)
//         mu_i = (2**(2*K)) / m_i[31:0];
        
//         // Generate input x (64-bit)
//         x_i = $urandom();
//         x_i = x_i % (4*m_i[31:0]); // Keep in meaningful range
        
//         // Compute reference
//         reference[idx] = x_i % m_i[31:0];
//     endtask

//     task apply_inputs();
//         $display("[%0t] Applying inputs: x=%h, m=%h, μ=%h",
//                 $time, x_i, m_i, mu_i);
//         start_i = 1;
//         @(posedge clk_i);
//         start_i = 0;
//     endtask

//     task wait_for_result(int idx);
//         // Wait for pipeline latency (4 cycles)
//         repeat(4) @(posedge clk_i);
//     endtask

//     task verify_result(int idx);
//         $display("[%0t] Received result: %h (Expected: %h)",
//                 $time, result_o[63:0], reference[idx]);
        
//         if(result_o[63:0] !== reference[idx]) begin
//             $error("Mismatch detected!");
//             error_count++;
//         end
//     endtask

//     task report_results();
//         $display("\nTest Summary:");
//         $display("Total tests: %0d", NUM_DATA);
//         $display("Errors:      %0d", error_count);
//         $display("Success Rate: %0d%%", (100*(NUM_DATA-error_count))/NUM_DATA);
//     endtask

// endmodule
