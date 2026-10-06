`timescale 1ns/1ps
module ntt_butterfly (
    input  wire [12:0] a,
    input  wire [12:0] b,
    input  wire [12:0] zeta,

    output wire [12:0] a_out,
    output wire [12:0] b_out
);

    wire [12:0] t;

    // t = b * zeta mod 3329
    mod_mult mult_inst (
        .a      (b),
        .b      (zeta),
        .result (t)
    );

    // a_out = a + t mod 3329
    mod_add add_inst (
        .a      (a),
        .b      (t),
        .result (a_out)
    );

    // b_out = a - t mod 3329
    mod_sub sub_inst (
        .a      (a),
        .b      (t),
        .result (b_out)
    );

endmodule