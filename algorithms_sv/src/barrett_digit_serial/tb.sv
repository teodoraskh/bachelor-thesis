
import multiplier_pkg::*;
import params_pkg::*;

module barrett_ds_tb;

    logic                       clk_i;           // Rising edge active clk.
    logic                       rst_ni;          // Active low reset.
    logic                       start_i;         // Start signal.
    logic                       busy_o;          // Module busy.
    logic                       finish_o;        // Module finish.
    logic [DATA_LENGTH-1:0]     indata_x_i;      // Input data -> operand a.
    logic [DATA_LENGTH-1:0]     indata_q_i;      // Input data -> operand b.
    logic [DATA_LENGTH-1:0]     indata_q_bl_i;   // Input data -> operand b.
    logic [DATA_LENGTH-1:0]     indata_mu_i;     // Input data -> operand b.
    logic [DATA_LENGTH-1:0]     outdata_r_o;     // Output data -> result a*b.

    logic [DATA_LENGTH-1:0]     reference_o;

    barrett_ds uut (
        .CLK_pci_sys_clk_p      (clk_i),
        .rst_ni                 (rst_ni),
        .start_i                (start_i),
        .x_i                    (indata_x_i),
        .q_i                    (indata_q_i),
        .q_bl_i                 (indata_q_bl_i),
        .mu_i                   (indata_mu_i),
        .result_o               (outdata_r_o),
        .valid_o                (finish_o)
    );

    initial forever #5 clk_i = ~clk_i;

    initial begin
        $dumpfile("barrett_ds_tb.vcd");
        $dumpvars(0, barrett_ds_tb);
    end

    integer inp_file;


    initial begin
    $display("\n=======================================");
    $display("[%04t] > Start barrett_ds_tb test", $time);
    $display("=======================================\n");

    clk_i     = 0;
    rst_ni    = 0;
    start_i   = 0;

    assign indata_q_bl_i = MODULUS_LENGTH;
    assign indata_q_i    = MODULUS;
    assign indata_mu_i   = MU;

    inp_file = $fopen("dilithium_input.txt", "r");
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
        $fscanf(inp_file, "%h", indata_x_i);

        if (indata_x_i != 0) begin
          $display("[%04t] > Input data    : %h", $time, indata_x_i);
          reference_o = indata_x_i % indata_q_i;

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
    $display("[%04t] > Finish barrett_ds_tb test", $time);
    $display("=======================================\n");

    #100;
    $finish;
end

endmodule : barrett_ds_tb
