// ============================================================================
// File: poly_encode.v
// Module: poly_encode
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: N = 256, D = 12
// Description: Converts 256 12-bit coefficients into a 3072-bit packed bitstream.
// ============================================================================

`timescale 1ns/1ps

module poly_encode #(
    parameter N = 256,
    parameter D = 12
)(
    input  wire [(N*D)-1:0] coeff,
    output wire [(N*D)-1:0] encoded
);

    assign encoded = coeff;

endmodule
