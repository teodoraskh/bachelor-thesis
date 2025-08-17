import multiplier_pkg::*;
module bp_multiplier_64x64(
    input  logic [DATA_LENGTH-1:0] a,
    input  logic [DATA_LENGTH-1:0] b,
    output logic [(2*DATA_LENGTH)-1:0] product
);

    logic [(2*DATA_LENGTH)-1:0] partial_products [DATA_LENGTH-1:0];
    logic [(2*DATA_LENGTH)-1:0] sum [DATA_LENGTH-1:0];


    integer i;
    integer j;
    always_comb begin
        // Initialize all partial products to 0
        for (i = 0; i < DATA_LENGTH; i++) begin
            partial_products[i] = '0;
            for (j = 0; j < DATA_LENGTH; j++) begin
                partial_products[i][j] = a[j] & b[i];
            end
        end

        // Sum partial products (shifted by weight)
        sum[0] = partial_products[0] << 0;
        for (i = 1; i < DATA_LENGTH; i++) begin
            sum[i] = sum[i-1] + (partial_products[i] << i);
        end

        product = sum[DATA_LENGTH-1];
    end
endmodule : bp_multiplier_64x64