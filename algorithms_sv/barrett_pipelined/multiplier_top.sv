import multiplier_pkg::*;

module multiplier_top (
    input  logic                        clk_i,           // Rising edge active clk.
    input  logic                        rst_ni,          // Active low reset.
    input  logic                        start_i,         // Start signal.
    output logic                        busy_o,          // Module busy.
    output logic                        finish_o,        // Module finish.
    input  logic [DATA_LENGTH-1:0]      indata_a_i,      // Input data -> operand a.
    input  logic [DATA_LENGTH-1:0]      indata_b_i,      // Input data -> operand b.
    output logic [DATA_LENGTH*2-1:0]    outdata_r_o      // Output data -> result a*b.
);

state_t curr_state, next_state;

logic ctrl_update;

logic d_finish;

logic [DATA_LENGTH-1:0] d_operand_a [NUM_MULS-1:0];
logic [DATA_LENGTH-1:0] d_operand_b [NUM_MULS-1:0];
logic [DATA_LENGTH*2-1:0] d_result [NUM_MULS-1:0];

shiftreg #(
    .SHIFT(NUM_MULS+2), // +1 buffer delay, +1 mul delay, +1 buffer delay
    .DATA(1)
) shift_finish (
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);

logic [LENGTH-1:0] mul16_a [NUM_MULS-1:0];
logic [LENGTH-1:0] mul16_b [NUM_MULS-1:0];
logic [LENGTH*2-1:0] mul16_res [NUM_MULS-1:0];

generate
    for (genvar i=0; i<NUM_MULS; i++) begin
        
        assign mul16_a[i] = d_operand_a[i][BLOCK_LENGTH*(i%NUM_BLOCKS)+:BLOCK_LENGTH];
        assign mul16_b[i] = d_operand_b[i][BLOCK_LENGTH*(i/NUM_BLOCKS)+:BLOCK_LENGTH];

        multiplier_16x16 multiplier_16x16_i (
            .clk_i          (clk_i),
            .indata_a_i     (mul16_a[i]),
            .indata_b_i     (mul16_b[i]),
            .outdata_r_o    (mul16_res[i])
        );
    end
endgenerate

///////////////////////////////////////////////////////////////////////////////
// State logic
///////////////////////////////////////////////////////////////////////////////

always_comb begin
    ctrl_update = (curr_state == compute);
end

always_ff @(posedge clk_i) begin
    if (rst_ni == 0) begin
        curr_state <= idle;
    end 
    else begin
        curr_state <= next_state;
    end
end

always_comb begin
    next_state = curr_state; // default is to stay in current state
    case (curr_state)
        idle : begin
            if (start_i == 1) begin
                next_state = compute;
            end
        end
        compute : begin
            if (d_finish) begin
                next_state = finish;
            end
        end
        finish : begin
            next_state = finish;
        end
        default : begin
            next_state = idle;
        end
    endcase
end

///////////////////////////////////////////////////////////////////////////////
// Data logic
///////////////////////////////////////////////////////////////////////////////

generate
    for (genvar i=0; i<NUM_MULS; i++) begin
        always_ff @(posedge clk_i) begin
            // if (rst_ni == 0) begin
            //     d_operand_a[i] <= 0;
            // end 
            // else if (ctrl_update) begin
                if (i == 0) begin
                    d_operand_a[i] <= indata_a_i;
                end
                else begin
                    d_operand_a[i] <= d_operand_a[i-1];
                end
            // end
        end
    end
endgenerate

generate
    for (genvar i=0; i<NUM_MULS; i++) begin
        always_ff @(posedge clk_i) begin
            // if (rst_ni == 0) begin
            //     d_operand_b[i] <= 0;
            // end 
            // else if (ctrl_update) begin
                if (i == 0) begin
                    d_operand_b[i] <= indata_b_i;
                end
                else begin
                    d_operand_b[i] <= d_operand_b[i-1];
                end
            // end
        end
    end
endgenerate

generate
    for (genvar i=0; i<NUM_MULS; i++) begin
        always_ff @(posedge clk_i) begin
            // if (rst_ni == 0) begin
            //     d_result[i] <= 0;
            // end 
            // else if (ctrl_update) begin
                if (i == 0) begin
                    d_result[i] <= mul16_res[i];
                end
                else begin
                    d_result[i] <= d_result[i-1] + (mul16_res[i] << BLOCK_LENGTH*(i%NUM_BLOCKS + i/NUM_BLOCKS));
                end
            // end
        end
    end
endgenerate

///////////////////////////////////////////////////////////////////////////////
// Output logic
///////////////////////////////////////////////////////////////////////////////

assign busy_o       = (curr_state != idle && curr_state != finish);
assign finish_o     = d_finish;
// assign outdata_r_o  = d_result[1];
assign outdata_r_o  = d_result[NUM_MULS-1];

endmodule : multiplier_top