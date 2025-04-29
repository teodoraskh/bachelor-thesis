module shiftreg #(
    parameter SHIFT = 1, 
    parameter DATA  = 64
)(
    input                 clk_i,
    input      [DATA-1:0] data_i,
    output reg [DATA-1:0] data_o
);

reg [DATA-1:0] shift_array [SHIFT-1:0];

always @(posedge clk_i) begin
    shift_array[0] <= data_i;
end

generate
    for(genvar shft=0; shft < SHIFT-1; shft=shft+1) begin: DELAY_BLOCK
        always @(posedge clk_i) begin
            shift_array[shft+1] <= shift_array[shft];
        end
    end
endgenerate

always @(*) begin
    data_o = (SHIFT == 0) ? data_i : shift_array[SHIFT-1];
end

endmodule