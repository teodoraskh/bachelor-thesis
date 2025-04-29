
// import multipler_pkg::*;

module barrett_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic                       ready_o;         // First multiplication is valid
    logic [63:0]     indata_x_i;      // Input data -> operand a.
    logic [63:0]     indata_m_i;      // Input data -> operand b.
    logic [63:0]     indata_mu_i;      // Input data -> operand b.
    logic [63:0]   outdata_r_o;     // Output data -> result a*b.

    localparam NUM_DATA = 3;
    logic signed [127:0]   reference_o [NUM_DATA-1:0];

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

      logic [127:0] tmp;
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
        indata_m_i = 64'h0000_0000_9215_3525;
        indata_mu_i = 64'h2CDE_B2B0;

        #20;
        $display("[%04t] > Set reset signal", $time);
        rst_ni = 1;
        for (integer i=0; i<NUM_DATA; i++) begin
            #10;
            $display("[%04t] > Set start signal", $time);
            indata_x_i = $urandom() % (indata_m_i * 4);  // x < 4m (Barrett requirement)
            reference_o[i] = indata_x_i % indata_m_i;
            start_i = 1;
            $display("[%04t] > Set A  : %h", $time, indata_x_i);
            $display("[%04t] > Set B  : %h", $time, indata_m_i);
            $display("[%04t] > Set REF: %h", $time, reference_o[i]);

        end

        #10;
        $display("[%04t] > Reset start signal", $time);
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
        $display("[%04t] > Finish barrett test", $time);
        $display("=======================================\n");

        // Finish simulation
        #100;
        $finish;

    end

endmodule : barrett_tb 