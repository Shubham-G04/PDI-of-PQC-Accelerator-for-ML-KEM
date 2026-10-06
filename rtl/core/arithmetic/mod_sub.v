`timescale 1ns/1ps
module mod_sub #(
    parameter integer Q = 3329
)(
    input  wire [12:0] a,
    input  wire [12:0] b,
    output wire [12:0] result
);

    assign result = (a >= b) ?
                    (a - b) :
                    (a + Q - b);

endmodule