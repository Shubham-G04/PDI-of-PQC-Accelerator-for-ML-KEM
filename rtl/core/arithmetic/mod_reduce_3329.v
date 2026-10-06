`timescale 1ns/1ps
module mod_reduce_3329 (
    input  wire [25:0] value,
    output wire [12:0] result
);

    localparam [12:0] Q  = 13'd3329;
    localparam [12:0] MU = 13'd5039;

    wire [38:0] reciprocal_product;

    assign reciprocal_product = value * MU;

    wire [14:0] quotient_est;

    assign quotient_est = reciprocal_product[38:24];

    wire [27:0] quotient_product;

    assign quotient_product = quotient_est * Q;

    wire [27:0] remainder_temp;

    assign remainder_temp =
        {2'b00, value} - quotient_product;

    assign result =
        (remainder_temp >= Q) ?
        (remainder_temp - Q) :
        remainder_temp[12:0];

endmodule