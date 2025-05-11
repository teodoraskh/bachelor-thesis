
// import multiplier_pkg::*;

module shiftadd_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [64-1:0]              indata_x_i;      // Input data -> operand a.
    logic [32-1:0]              indata_m_i;      // Input data -> operand b.
    logic [32-1:0]              indata_m_bl_i;      // Input data -> operand b.
    logic [64-1:0]              outdata_r_o;     // Output data -> result a*b.

    logic [64-1:0]              reference_o;

    // Instantiate module
    shiftadd_serialized uut (
        .clk_i                  (clk_i),
        .rst_ni                 (rst_ni),
        .start_i                (start_i),    
        .x_i                    (indata_x_i),
        .m_i                    (indata_m_i),
        .m_bl_i                 (indata_m_bl_i),
        .result_o               (outdata_r_o),
        .valid_o                (finish_o)    
    );

    // Clock generation
    initial forever #5 clk_i = ~clk_i;

    // Dumpfile 
    initial begin
        $dumpfile("shiftadd_tb.vcd");
        $dumpvars(0, shiftadd_tb);
    end

    integer inp_file;
    logic [63:0] indata_x;

    assign indata_m_bl_i = $clog2(indata_m_i);

    // Stimulus generation
    initial begin
        $display("\n=======================================");
        $display("[%04t] > Start shiftadd test", $time);
        $display("=======================================\n");

        // Initialize inputs
        clk_i = 0;
        rst_ni = 0;
        start_i = 0;
        // indata_m_i = 64'h3A32E4C4C7A8C21B;
        // Mersenne:
        // indata_m_i = 32'h7FFFFFFF;
        indata_m_i = 32'h7FFFFF;

        // Fermat:
        // indata_m_i = 32'h80000001;
        // indata_m_i = 32'h21;
        // indata_m_i = 32'h2001;
        indata_x_i = 64'h1;

        inp_file  = $fopen("input.txt", "r");

        while (indata_x_i != 0) begin
          rst_ni = 0;
          $fscanf(inp_file, "%h", indata_x_i);
          #20;

          rst_ni = 1;

          #10;

          if(indata_x_i != 0) begin
            reference_o = indata_x_i % indata_m_i;
            start_i = 1;

            $display("[%04t] > Set indata_x_i: %h", $time, indata_x_i);

            #10;

            start_i = 0;

            #10;
            @(posedge finish_o)

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
        $display("[%04t] > Finish shiftadd serialized test", $time);
        $display("=======================================\n");

        // Finish simulation
        #100;
        $finish;
    end

endmodule : shiftadd_tb 
