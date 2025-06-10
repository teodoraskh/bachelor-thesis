
// import multiplier_pkg::*;
`timescale 1ns / 1ps
module montgomery_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy. 
    logic                       finish_o;        // Module finish.
    logic [64-1:0]              indata_x_i;      // Input data -> operand a.
    logic [64-1:0]              indata_y_mont_i; // Input data -> operand a.
    logic [64-1:0]              indata_y_i;
    logic [64-1:0]              indata_m_i;      // Input data -> operand b.
    logic [64-1:0]              indata_m_bl_i;
    logic [64-1:0]              outdata_r_o;     // Output data -> result a*b.
    logic [64-1:0]              reference_o;

    // Instantiate module
    montgomery_serialized uut (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .start_i  (start_i),
        .x_i      (indata_x_i),
        .y_i      (indata_y_mont_i),
        .m_i      (indata_m_i),
        .m_bl_i   (indata_m_bl_i),
        .result_o (outdata_r_o), 
        .valid_o  (finish_o)
    );

    // Clock generation
    initial forever #5 clk_i = ~clk_i;

    // Dumpfile 
    initial begin
        $dumpfile("montgomery_tb.vcd");
        $dumpvars(0, montgomery_tb);
    end

    integer inp_file;
    assign indata_m_bl_i = $clog2(indata_m_i);

    initial begin
        $display("\n=======================================");
        $display("[%04t] > Start montgomery test", $time);
        $display("=======================================\n");

        clk_i = 0;
        rst_ni = 0;
        start_i = 0;

        indata_m_i = 64'h7FE001; //Dilithium
        // indata_m_i = 64'hD01; //Kyber

        inp_file = $fopen("input_dilithium_mont.txt", "r");
        if (inp_file == 0) begin
            $display("ERROR: Failed to open file.");
            $finish;
        end else begin
            $display("File opened.");
        end

        #10;
        rst_ni = 0;
        #40;
        rst_ni = 1;
        #20;

        while (!$feof(inp_file)) begin

          // Get A, B and B in Montgomery form
          $fscanf(inp_file, "%h %h %h", indata_x_i, indata_y_i, indata_y_mont_i);

          if(indata_x_i != 0) begin
            reference_o = (indata_x_i * indata_y_i) % indata_m_i;
            start_i = 1;

            $display("[%04t] > Set indata_x_i: %h", $time, indata_x_i);
            // $display("[%04t] > Set indata_y_i: %h", $time, indata_y_i);
            $display("[%04t] > Set indata_y_i: %h", $time, indata_y_mont_i);

            @(posedge clk_i);
            start_i = 1;
            @(posedge clk_i);
            start_i = 0;

            wait (finish_o == 1);

            @(posedge clk_i); 

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
        $display("[%04t] > Finish montgomery test", $time);
        $display("=======================================\n");

        // Finish simulation
        #10;
        $display("[%0t] > Calling $finish", $time);
        $finish;
    end

endmodule : montgomery_tb 