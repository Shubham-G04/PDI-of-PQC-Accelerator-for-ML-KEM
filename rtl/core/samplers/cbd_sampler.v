// ============================================================================
// File: cbd_sampler.v
// Module: cbd_sampler
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: N = 256, Q = 3329, ETA = 2
// Description: Synthesizable Verilog Centered Binomial Distribution (CBD) Sampler.
//              For eta = 2, takes 1024 random bits and produces 256 12-bit coefficients mod 3329.
// ============================================================================

`timescale 1ns/1ps

module cbd_sampler #(
    parameter N   = 256,
    parameter Q   = 3329,
    parameter ETA = 2
)(
    input  wire [(4*N)-1:0]  random_bits,
    output wire [(N*12)-1:0] coeff,
    output wire [(N*3)-1:0]  coeff_signed
);

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : gen_cbd
            wire signed [2:0] val;
            assign val = $signed({1'b0, random_bits[4*i]})   +
                         $signed({1'b0, random_bits[4*i+1]}) -
                         $signed({1'b0, random_bits[4*i+2]}) -
                         $signed({1'b0, random_bits[4*i+3]});

            assign coeff_signed[i*3 +: 3] = val;
            assign coeff[i*12 +: 12]      = (val < 3'sd0) ? (val + Q) : {9'd0, val};
        end
    endgenerate

endmodule
