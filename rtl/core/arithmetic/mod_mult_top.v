`timescale 1ns/1ps
module mod_mult_top (
    input  wire [12:0] a,
    input  wire [12:0] b,
    output wire [12:0] result
);

    mod_mult dut (
        .a      (a),
        .b      (b),
        .result (result)
    );

endmodule