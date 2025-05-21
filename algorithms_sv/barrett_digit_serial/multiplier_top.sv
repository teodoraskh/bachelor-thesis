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

counter_t a_counter;
counter_t b_counter;
counter_t r_counter;

logic [DATA_LENGTH-1:0] operand_a;
logic [DATA_LENGTH-1:0] operand_b;
logic [DATA_LENGTH*2-1:0] result;

logic [BLOCK_LENGTH-1:0] operand_a_block [NUM_BLOCKS-1:0];
logic [BLOCK_LENGTH-1:0] operand_b_block [NUM_BLOCKS-1:0];

// iverilog: sorry: Streaming concatenation not supported.
// always_comb begin
//     operand_a_block = {>>{operand_a}};
//     operand_b_block = {>>{operand_b}};
// end
// lets to it manually
generate
    for (genvar i=0; i<NUM_BLOCKS; i++) begin
        assign operand_a_block[i] = operand_a[BLOCK_LENGTH*i+:BLOCK_LENGTH];
        assign operand_b_block[i] = operand_b[BLOCK_LENGTH*i+:BLOCK_LENGTH];
    end
endgenerate

logic ctrl_update_operands;
logic ctrl_update_a_counter;
logic ctrl_update_b_counter;
logic ctrl_update_r_counter;
logic ctrl_update_result;

// Instantiate sub-module

// logic                       mul16_start_i;     // Start signal.
// logic                       mul16_busy_o;      // Module busy.
// logic                       mul16_finish_o;    // Module finish.
logic [BLOCK_LENGTH-1:0]    mul16_indata_a_i;  // Input data -> operand a.
logic [BLOCK_LENGTH-1:0]    mul16_indata_b_i;  // Input data -> operand b.
logic [BLOCK_LENGTH*2-1:0]  mul16_outdata_r_o; // Output data -> result a*b.

// multipler_16x16 multipler_16x16_i (
//     // .clk_i          (clk_i),
//     // .rst_ni         (rst_ni),
//     // .start_i        (mul16_start_i),
//     // .busy_o         (mul16_busy_o),
//     // .finish_o       (mul16_finish_o),
//     .indata_a_i     (mul16_indata_a_i),
//     .indata_b_i     (mul16_indata_b_i),
//     .outdata_r_o    (mul16_outdata_r_o)
// );

multiplier_16x16 multipler_16x16_i (
    .clk_i          (clk_i),
    // .rst_ni         (rst_ni),
    // .start_i        (mul16_start_i),
    // .busy_o         (mul16_busy_o),
    // .finish_o       (mul16_finish_o),
    .indata_a_i     (mul16_indata_a_i),
    .indata_b_i     (mul16_indata_b_i),
    .outdata_r_o    (mul16_outdata_r_o)
);

always_comb begin
    mul16_indata_a_i = operand_a_block[a_counter];
    mul16_indata_b_i = operand_b_block[b_counter];
end

///////////////////////////////////////////////////////////////////////////////
// State logic
///////////////////////////////////////////////////////////////////////////////

always_comb begin
    ctrl_update_operands = (curr_state == init);
    ctrl_update_a_counter = (curr_state == compute_chk);
    ctrl_update_b_counter = (curr_state == compute_chk);
    ctrl_update_r_counter = (curr_state == compute_chk);
    ctrl_update_result = (curr_state == compute_acc);
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
                next_state = init;
            end
        end
        init : begin
            next_state = compute_mul;
        end
        compute_mul : begin
            next_state = compute_acc;
        end
        compute_acc : begin
            next_state = compute_chk;
        end
        compute_chk : begin
            // next_state = (r_counter == NUM_MULS-1) ? finish : compute_mul; // does not work with iverilog
            if (r_counter == NUM_MULS-1) 
                next_state = finish;
            else 
                next_state = compute_mul;
        end
        finish : begin
            next_state = idle;
        end
        default : begin
            next_state = idle;
        end
    endcase
end

///////////////////////////////////////////////////////////////////////////////
// Data logic
///////////////////////////////////////////////////////////////////////////////

// || ctrl_update_operands
always_ff @(posedge clk_i) begin
    if (rst_ni == 0 ) begin
        operand_a <= 0;
    end 
    else if (ctrl_update_operands) begin
        operand_a <= indata_a_i;
    end
end

//  || ctrl_update_operands
always_ff @(posedge clk_i) begin
    if (rst_ni == 0 ) begin
        operand_b <= 0;
    end 
    else if (ctrl_update_operands) begin
        operand_b <= indata_b_i;
    end
end

//  || ctrl_update_operands
always_ff @(posedge clk_i) begin
    if (rst_ni == 0 || ctrl_update_operands) begin
        a_counter <= 0;
    end 
    else if (ctrl_update_a_counter) begin
        a_counter <= (a_counter == NUM_BLOCKS-1) ? 0 : a_counter + 1;
    end
end

always_ff @(posedge clk_i) begin
    // || ctrl_update_operands
    if (rst_ni == 0 || ctrl_update_operands) begin
        b_counter <= 0;
    end 
    else if (ctrl_update_b_counter) begin
        b_counter <= (a_counter == NUM_BLOCKS-1) ? b_counter + 1 : b_counter;
    end
end

always_ff @(posedge clk_i) begin
    if (rst_ni == 0 || ctrl_update_operands) begin
        r_counter <= 0;
    end 
    else if (ctrl_update_r_counter) begin
        r_counter <= r_counter + 1;
    end
end

// || ctrl_update_operands
always_ff @(posedge clk_i) begin
    if (rst_ni == 0 || ctrl_update_operands) begin
        result <= 0;
    end 
    else if (ctrl_update_result) begin
        result <= result + (mul16_outdata_r_o << (b_counter + a_counter)*BLOCK_LENGTH);
    end
end

///////////////////////////////////////////////////////////////////////////////
// Output logic
///////////////////////////////////////////////////////////////////////////////

assign busy_o = (curr_state != idle && curr_state != finish);
assign finish_o = (curr_state == finish);

assign outdata_r_o = result;

endmodule : multiplier_top