// ============================================================================
// File: poly_sub.v
// Module: poly_sub
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: Q = 3329, N = 256
// Description: Synthesizable Verilog Polynomial Subtraction Module modulo q = 3329:
//                c[i] = (a[i] - b[i]) mod 3329
// ============================================================================

`timescale 1ns/1ps

module poly_sub #(
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire [(N*12)-1:0] poly_a,
    input  wire [(N*12)-1:0] poly_b,
    output wire [(N*12)-1:0] poly_c
);

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : gen_sub
            wire [11:0] a_val = poly_a[i*12 +: 12];
            wire [11:0] b_val = poly_b[i*12 +: 12];
            assign poly_c[i*12 +: 12] = (a_val < b_val) ?
                                        (a_val + Q - b_val) :
                                        (a_val - b_val);
        end
    endgenerate

endmodule
