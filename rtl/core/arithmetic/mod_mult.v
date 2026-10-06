`timescale 1ns/1ps
module mod_mult (
    input  wire [12:0] a,
    input  wire [12:0] b,
    output wire [12:0] result
);

    // 13-bit × 13-bit = 26-bit product
    wire [25:0] product;

    assign product = a * b;

    // Dedicated ML-KEM reduction modulo 3329
    mod_reduce_3329 reducer (
        .value  (product),
        .result (result)
    );

endmodule