`timescale 1ns/1ps
module intt_butterfly (
    input  wire [12:0] a,
    input  wire [12:0] b,
    input  wire [12:0] zeta,

    output wire [12:0] a_out,
    output wire [12:0] b_out
);

    wire [12:0] add_result;
    wire [12:0] sub_result;

    /*
     * a_out = a + b mod 3329
     */
    mod_add add_inst (
        .a      (a),
        .b      (b),
        .result (add_result)
    );

    /*
     * Difference:
     *
     * sub_result = a - b mod 3329
     */
    mod_sub sub_inst (
        .a      (a),
        .b      (b),
        .result (sub_result)
    );

    /*
     * b_out = (a - b) * zeta mod 3329
     */
    mod_mult mult_inst (
        .a      (sub_result),
        .b      (zeta),
        .result (b_out)
    );

    assign a_out = add_result;

endmodule