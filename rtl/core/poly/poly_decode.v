// ============================================================================
// File: poly_decode.v
// Module: poly_decode
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: N = 256, D = 12
// Description: Converts a 3072-bit packed bitstream back into 256 12-bit coefficients.
// ============================================================================

`timescale 1ns/1ps

module poly_decode #(
    parameter N = 256,
    parameter D = 12
)(
    input  wire [(N*D)-1:0] encoded,
    output wire [(N*D)-1:0] coeff
);

    assign coeff = encoded;

endmodule
