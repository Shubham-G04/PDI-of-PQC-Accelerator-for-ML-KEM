// ============================================================================
// File: poly_compress.v
// Module: poly_compress
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: Q = 3329, D = 10 (or 4, 1, 5, 11)
// Description: Synthesizable polynomial compression module:
//                Compress_q(x, d) = floor((2^d * x + floor(q/2)) / q) mod 2^d
//              Uses reciprocal multiplication with Barrett-style correction.
//              Bit widths tightened for Genus/ASIC synthesis.
// ============================================================================

`timescale 1ns/1ps

module poly_compress #(
    parameter Q = 3329,
    parameter D = 10
)(
    input  wire [11:0]  coeff,
    output reg  [D-1:0] compressed
);

    // ceil(2^22 / 3329) = 1254 fits in 11 bits.
    // Max numerator = 2^D * 3328 + 1664 < 2^(D+12+1) < 2^24 for D<=11.
    // product = numerator * RECIP < 2^24 * 2^11 = 2^35, quotient < 2^13.
    localparam [10:0] RECIP = 11'd1254;   // ceil(2^22 / 3329)

    reg [23:0] numerator;
    reg [34:0] product;
    reg [12:0] quotient;
    reg [25:0] check;

    always @(*) begin
        numerator = ({12'd0, coeff} << D) + (Q >> 1);
        product   = numerator * RECIP;
        quotient  = product[34:22];

        check = quotient * Q;

        if (check > {2'b00, numerator})
            quotient = quotient - 13'd1;

        compressed = quotient[D-1:0];
    end

endmodule
