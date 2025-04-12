
// import multiplier_pkg::*;

module barrett_np_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [64-1:0]              indata_x_i;      // Input data -> operand a.
    logic [64-1:0]              indata_m_i;      // Input data -> operand b.
    logic [64-1:0]              indata_mu_i;      // Input data -> operand b.
    logic [64*2-1:0]            outdata_r_o;     // Output data -> result a*b.

    logic [64*2-1:0]            reference_o;

    // Instantiate module
    barrett_np uut (
        .clk_i                  (clk_i),
        .rst_ni                 (rst_ni),
        .start_i                (start_i),    
        .x_i                    (indata_x_i),
        .m_i                    (indata_m_i),
        .mu_i                   (indata_mu_i),
        .result_o               (outdata_r_o),
        .valid_o                (finish_o)    
    );

    // Clock generation
    initial forever #5 clk_i = ~clk_i;

    // Dumpfile 
    initial begin
        $dumpfile("barrett_np.vcd");
        $dumpvars(0, barrett_np_tb);
    end

    // Stimulus generation
    initial begin
        $display("\n=======================================");
        $display("[%04t] > Start barrett_np test", $time);
        $display("=======================================\n");

        // Initialize inputs
        clk_i = 0;
        rst_ni = 0;
        start_i = 0;
        indata_m_i = 64'h0000_0000_9215_3525;
        indata_mu_i = 64'h2CDE_B2B0;


        repeat (100) begin
            rst_ni = 0;
            #20;
            // $display("[%04t] > Set reset signal", $time);
            rst_ni = 1;
            // Wait a few cycles
            #10;

            // $display("[%04t] > Set start signal", $time);
            indata_x_i = $urandom() % (indata_m_i * 4);
            reference_o = indata_x_i % indata_m_i;
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

            $display("[%04t] > Received data: %h", $time, outdata_r_o);
            $display("[%04t] > Reference data: %h", $time, reference_o);
            if (outdata_r_o == reference_o)
                $display("[%04t] > Data is VALID", $time);
            else
                $display("[%04t] > Data is INVALID", $time);
        end

        $display("\n=======================================");
        $display("[%04t] > Finish barrett_np test", $time);
        $display("=======================================\n");

        // Finish simulation
        #100;
        $finish;
    end

endmodule : barrett_np_tb 
