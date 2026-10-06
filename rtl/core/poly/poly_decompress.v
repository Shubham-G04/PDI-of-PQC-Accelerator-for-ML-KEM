// ============================================================================
// File: poly_decompress.v
// Module: poly_decompress
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: Q = 3329, D = 10 (or 4, 1, 5, 11)
// Description: Synthesizable polynomial decompression module:
//                Decompress_q(y, d) = round(q * y / 2^d)
//                                   = floor((q * y + 2^(d-1)) / 2^d)
//              Bit widths tightened for Genus/ASIC synthesis.
// ============================================================================

`timescale 1ns/1ps

module poly_decompress #(
    parameter Q = 3329,
    parameter D = 10
)(
    input  wire [D-1:0] compressed,
    output reg  [11:0]  coeff
);

    // Q * compressed < 3329 * 2^D < 2^(D+12).
    // Adding 2^(D-1) keeps it under 2^(D+12)+1.
    // After >>D the result fits in 12 bits.
    localparam [12:0] Q13 = Q;

    reg [22:0] numerator;
    reg [22:0] result;

    always @(*) begin
        numerator = (Q13 * compressed) + (23'd1 << (D - 1));
        result    = numerator >> D;
        coeff     = result[11:0];
    end

endmodule
