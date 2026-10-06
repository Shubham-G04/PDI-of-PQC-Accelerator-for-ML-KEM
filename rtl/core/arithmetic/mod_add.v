`timescale 1ns/1ps
module mod_add #(
    parameter integer Q = 3329
)(
    input  wire [12:0] a,
    input  wire [12:0] b,
    output wire [12:0] result
);

    wire [13:0] sum;

    assign sum = {1'b0, a} + {1'b0, b};

    assign result = (sum >= Q) ?
                    (sum - Q) :
                    sum[12:0];

endmodule