// ============================================================================
// File: mlkem_keygen.v
// Module: mlkem_keygen
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: K = 2, Q = 3329, N = 256
// Description: Synthesizable Verilog ML-KEM-512 Key Generation Module per FIPS 203.
//
// INTEGRATION CHANGE: ntt_256 / intt_256 (the ModelSim-tree transform cores)
// were retired in favour of the Vivado-tree ntt / intt cores, which are now
// the project's single NTT/INTT implementation. ntt_flat / intt_flat are thin
// adapters that present those address-mapped cores through the same flat
// [N*12-1:0] port list, so only the instantiated module names changed here.
// Retiring the duplicates also removed the ntt_butterfly / intt_butterfly
// module-name collision that stopped the two trees compiling together.
//
// ============================================================================

`timescale 1ns/1ps

module mlkem_keygen #(
    parameter K = 2,
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,

    input  wire [1023:0]        rand_bits_s0,
    input  wire [1023:0]        rand_bits_s1,
    input  wire [1023:0]        rand_bits_e0,
    input  wire [1023:0]        rand_bits_e1,

    input  wire [(N*12)-1:0]    A00,
    input  wire [(N*12)-1:0]    A01,
    input  wire [(N*12)-1:0]    A10,
    input  wire [(N*12)-1:0]    A11,

    output wire [(N*12)-1:0]    pk_t0,
    output wire [(N*12)-1:0]    pk_t1,

    output wire [(N*12)-1:0]    sk_s0,
    output wire [(N*12)-1:0]    sk_s1,

    output reg                  busy,
    output reg                  done
);

    wire [(N*12)-1:0] s0_spatial, s1_spatial;
    wire [(N*12)-1:0] e0_spatial, e1_spatial;

    wire [(N*3)-1:0] dummy_s0, dummy_s1, dummy_e0, dummy_e1;

    cbd_sampler #(.N(N), .Q(Q)) cbd_s0 (.random_bits(rand_bits_s0), .coeff(s0_spatial), .coeff_signed(dummy_s0));
    cbd_sampler #(.N(N), .Q(Q)) cbd_s1 (.random_bits(rand_bits_s1), .coeff(s1_spatial), .coeff_signed(dummy_s1));
    cbd_sampler #(.N(N), .Q(Q)) cbd_e0 (.random_bits(rand_bits_e0), .coeff(e0_spatial), .coeff_signed(dummy_e0));
    cbd_sampler #(.N(N), .Q(Q)) cbd_e1 (.random_bits(rand_bits_e1), .coeff(e1_spatial), .coeff_signed(dummy_e1));

    wire [(N*12)-1:0] s0_ntt, s1_ntt;
    wire [(N*12)-1:0] e0_ntt, e1_ntt;

    reg ntt_start;
    wire ntt_busy0, ntt_done0, ntt_done1, ntt_done2, ntt_done3;

    ntt_flat #(.Q(Q), .N(N)) ntt_s0 (
        .clk(clk), .rst_n(rst_n), .start(ntt_start),
        .poly_in(s0_spatial), .poly_out(s0_ntt),
        .busy(ntt_busy0), .done(ntt_done0)
    );

    ntt_flat #(.Q(Q), .N(N)) ntt_s1 (
        .clk(clk), .rst_n(rst_n), .start(ntt_start),
        .poly_in(s1_spatial), .poly_out(s1_ntt),
        .busy(), .done(ntt_done1)
    );

    ntt_flat #(.Q(Q), .N(N)) ntt_e0 (
        .clk(clk), .rst_n(rst_n), .start(ntt_start),
        .poly_in(e0_spatial), .poly_out(e0_ntt),
        .busy(), .done(ntt_done2)
    );

    ntt_flat #(.Q(Q), .N(N)) ntt_e1 (
        .clk(clk), .rst_n(rst_n), .start(ntt_start),
        .poly_in(e1_spatial), .poly_out(e1_ntt),
        .busy(), .done(ntt_done3)
    );

    reg mvm_start;
    wire mvm_busy, mvm_done;

    matrix_vec_mul #(.K(K), .Q(Q), .N(N)) mvm_inst (
        .clk(clk), .rst_n(rst_n), .start(mvm_start),
        .A00(A00), .A01(A01), .A10(A10), .A11(A11),
        .s0(s0_ntt), .s1(s1_ntt),
        .e0(e0_ntt), .e1(e1_ntt),
        .t0(pk_t0), .t1(pk_t1),
        .busy(mvm_busy), .done(mvm_done)
    );

    assign sk_s0 = s0_ntt;
    assign sk_s1 = s1_ntt;

    localparam IDLE    = 2'b00;
    localparam RUN_NTT = 2'b01;
    localparam RUN_MVM = 2'b10;
    localparam FINISH  = 2'b11;

    reg [1:0] current_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            ntt_start     <= 1'b0;
            mvm_start     <= 1'b0;
        end else begin
            done      <= 1'b0;
            ntt_start <= 1'b0;
            mvm_start <= 1'b0;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        busy          <= 1'b1;
                        ntt_start     <= 1'b1;
                        current_state <= RUN_NTT;
                    end
                end

                RUN_NTT: begin
                    if (ntt_done0) begin
                        mvm_start     <= 1'b1;
                        current_state <= RUN_MVM;
                    end
                end

                RUN_MVM: begin
                    if (mvm_done) begin
                        busy          <= 1'b0;
                        done          <= 1'b1;
                        current_state <= FINISH;
                    end
                end

                FINISH: begin
                    current_state <= IDLE;
                end

                default: current_state <= IDLE;
            endcase
        end
    end

endmodule
