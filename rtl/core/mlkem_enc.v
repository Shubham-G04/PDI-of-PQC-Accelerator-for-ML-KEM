// ============================================================================
// File: mlkem_enc.v (Pipelined Version)
// Module: mlkem_enc
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: K = 2, Q = 3329, N = 256
//
// K-PKE.Encrypt (FIPS 203) with Pipelined Compression Isolation Stage.
//
// TIMING IMPROVEMENT:
// Added a pipeline register stage (RUN_COMPRESS) after the spatial INTT and
// message addition phase.
// Instead of chaining INTT -> poly_add(e2) -> poly_add(msg) -> 768 parallel
// poly_compress units in a single clock cycle, the spatial vectors are latched
// first into holding registers (u0_spatial_r, u1_spatial_r, v_final_r).
// Compression then executes in its own clean clock cycle, eliminating ~5 ns
// of combinational logic from the INTT critical path.
// ============================================================================

`timescale 1ns/1ps

module mlkem_enc #(
    parameter K = 2,
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,

    input  wire [(N*12)-1:0]    pk_t0,
    input  wire [(N*12)-1:0]    pk_t1,

    input  wire [(N*12)-1:0]    A00,
    input  wire [(N*12)-1:0]    A10,
    input  wire [(N*12)-1:0]    A01,
    input  wire [(N*12)-1:0]    A11,

    input  wire [1023:0]        rand_bits_r0,
    input  wire [1023:0]        rand_bits_r1,
    input  wire [1023:0]        rand_bits_e1_0,
    input  wire [1023:0]        rand_bits_e1_1,
    input  wire [1023:0]        rand_bits_e2,

    input  wire [255:0]         msg,

    output wire [(N*10)-1:0]    c_u0,   // du = 10
    output wire [(N*10)-1:0]    c_u1,   // du = 10
    output wire [(N*4)-1:0]     c_v,    // dv = 4

    output reg                  busy,
    output reg                  done
);

    // ------------------------------------------------------------------
    // Noise sampling
    // ------------------------------------------------------------------
    wire [(N*12)-1:0] r0_spatial, r1_spatial;
    wire [(N*12)-1:0] e1_0_spatial, e1_1_spatial, e2_spatial;
    wire [(N*3)-1:0]  d_r0, d_r1, d_e10, d_e11, d_e2;

    cbd_sampler #(.N(N), .Q(Q)) cbd_r0
        (.random_bits(rand_bits_r0),   .coeff(r0_spatial),   .coeff_signed(d_r0));
    cbd_sampler #(.N(N), .Q(Q)) cbd_r1
        (.random_bits(rand_bits_r1),   .coeff(r1_spatial),   .coeff_signed(d_r1));
    cbd_sampler #(.N(N), .Q(Q)) cbd_e1_0
        (.random_bits(rand_bits_e1_0), .coeff(e1_0_spatial), .coeff_signed(d_e10));
    cbd_sampler #(.N(N), .Q(Q)) cbd_e1_1
        (.random_bits(rand_bits_e1_1), .coeff(e1_1_spatial), .coeff_signed(d_e11));
    cbd_sampler #(.N(N), .Q(Q)) cbd_e2
        (.random_bits(rand_bits_e2),   .coeff(e2_spatial),   .coeff_signed(d_e2));

    // ------------------------------------------------------------------
    // Forward transforms
    // ------------------------------------------------------------------
    wire [(N*12)-1:0] r0_ntt, r1_ntt, e1_0_ntt, e1_1_ntt;

    reg  ntt_start;
    wire ntt_done0;

    ntt_flat #(.Q(Q), .N(N)) ntt_r0
        (.clk(clk), .rst_n(rst_n), .start(ntt_start),
         .poly_in(r0_spatial),   .poly_out(r0_ntt),   .busy(), .done(ntt_done0));
    ntt_flat #(.Q(Q), .N(N)) ntt_r1
        (.clk(clk), .rst_n(rst_n), .start(ntt_start),
         .poly_in(r1_spatial),   .poly_out(r1_ntt),   .busy(), .done());
    ntt_flat #(.Q(Q), .N(N)) ntt_e10
        (.clk(clk), .rst_n(rst_n), .start(ntt_start),
         .poly_in(e1_0_spatial), .poly_out(e1_0_ntt), .busy(), .done());
    ntt_flat #(.Q(Q), .N(N)) ntt_e11
        (.clk(clk), .rst_n(rst_n), .start(ntt_start),
         .poly_in(e1_1_spatial), .poly_out(e1_1_ntt), .busy(), .done());

    // ------------------------------------------------------------------
    // u_hat = A^T o r_hat + e1_hat
    // ------------------------------------------------------------------
    reg  mvm_start;
    wire mvm_done;
    wire [(N*12)-1:0] u0_ntt, u1_ntt;

    matrix_vec_mul #(.K(K), .Q(Q), .N(N)) mvm_u (
        .clk(clk), .rst_n(rst_n), .start(mvm_start),
        .A00(A00), .A01(A10), .A10(A01), .A11(A11),
        .s0(r0_ntt), .s1(r1_ntt),
        .e0(e1_0_ntt), .e1(e1_1_ntt),
        .t0(u0_ntt), .t1(u1_ntt),
        .busy(), .done(mvm_done)
    );

    // ------------------------------------------------------------------
    // v_hat = t^T o r_hat
    // ------------------------------------------------------------------
    wire [(N*12)-1:0] prod_t0r0, prod_t1r1, v_ntt;
    wire pm_done_v;

    poly_mul_pointwise #(.Q(Q), .N(N)) mul_t0r0 (
        .clk(clk), .rst_n(rst_n), .start(mvm_start),
        .poly_a(pk_t0), .poly_b(r0_ntt), .poly_c(prod_t0r0),
        .busy(), .done(pm_done_v)
    );

    poly_mul_pointwise #(.Q(Q), .N(N)) mul_t1r1 (
        .clk(clk), .rst_n(rst_n), .start(mvm_start),
        .poly_a(pk_t1), .poly_b(r1_ntt), .poly_c(prod_t1r1),
        .busy(), .done()
    );

    poly_add #(.Q(Q), .N(N)) add_v_ntt
        (.poly_a(prod_t0r0), .poly_b(prod_t1r1), .poly_c(v_ntt));

    // ------------------------------------------------------------------
    // Inverse transforms
    // ------------------------------------------------------------------
    reg  intt_start;
    wire intt_done;
    wire [(N*12)-1:0] u0_spatial, u1_spatial, v_spatial_raw;

    intt_flat #(.Q(Q), .N(N)) intt_u0
        (.clk(clk), .rst_n(rst_n), .start(intt_start),
         .poly_in(u0_ntt), .poly_out(u0_spatial), .busy(), .done(intt_done));
    intt_flat #(.Q(Q), .N(N)) intt_u1
        (.clk(clk), .rst_n(rst_n), .start(intt_start),
         .poly_in(u1_ntt), .poly_out(u1_spatial), .busy(), .done());
    intt_flat #(.Q(Q), .N(N)) intt_v
        (.clk(clk), .rst_n(rst_n), .start(intt_start),
         .poly_in(v_ntt),  .poly_out(v_spatial_raw), .busy(), .done());

    // ------------------------------------------------------------------
    // v = INTT(t^T o r_hat) + e2 + Decompress_1(m)
    // ------------------------------------------------------------------
    wire [(N*12)-1:0] msg_decompressed;
    wire [(N*12)-1:0] v_plus_e2;
    wire [(N*12)-1:0] v_final;

    genvar idx;
    generate
        for (idx = 0; idx < N; idx = idx + 1) begin : gen_msg_decomp
            poly_decompress #(.Q(Q), .D(1)) decomp_msg_inst (
                .compressed (msg[idx]),
                .coeff      (msg_decompressed[idx*12 +: 12])
            );
        end
    endgenerate

    poly_add #(.Q(Q), .N(N)) add_e2
        (.poly_a(v_spatial_raw), .poly_b(e2_spatial), .poly_c(v_plus_e2));

    poly_add #(.Q(Q), .N(N)) add_msg
        (.poly_a(v_plus_e2), .poly_b(msg_decompressed), .poly_c(v_final));

    // ------------------------------------------------------------------
    // PIPELINE REGISTERS FOR COMPRESSION ISOLATION
    // ------------------------------------------------------------------
    reg [(N*12)-1:0] u0_spatial_r;
    reg [(N*12)-1:0] u1_spatial_r;
    reg [(N*12)-1:0] v_final_r;

    // ------------------------------------------------------------------
    // Ciphertext compression (Drives from pipeline registers)
    // ------------------------------------------------------------------
    generate
        for (idx = 0; idx < N; idx = idx + 1) begin : comp_c
            poly_compress #(.Q(Q), .D(10)) comp_u0_inst
                (.coeff(u0_spatial_r[idx*12 +: 12]), .compressed(c_u0[idx*10 +: 10]));
            poly_compress #(.Q(Q), .D(10)) comp_u1_inst
                (.coeff(u1_spatial_r[idx*12 +: 12]), .compressed(c_u1[idx*10 +: 10]));
            poly_compress #(.Q(Q), .D(4))  comp_v_inst
                (.coeff(v_final_r[idx*12 +: 12]),    .compressed(c_v[idx*4 +: 4]));
        end
    endgenerate

    // ------------------------------------------------------------------
    // Control State Machine
    // ------------------------------------------------------------------
    localparam [2:0] IDLE         = 3'b000;
    localparam [2:0] RUN_NTT      = 3'b001;
    localparam [2:0] RUN_MVM      = 3'b010;
    localparam [2:0] RUN_INTT     = 3'b011;
    localparam [2:0] RUN_COMPRESS = 3'b100;
    localparam [2:0] FINISH       = 3'b101;

    reg [2:0] current_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            ntt_start     <= 1'b0;
            mvm_start     <= 1'b0;
            intt_start    <= 1'b0;
            u0_spatial_r  <= { (N*12){1'b0} };
            u1_spatial_r  <= { (N*12){1'b0} };
            v_final_r     <= { (N*12){1'b0} };
        end
        else begin
            done       <= 1'b0;
            ntt_start  <= 1'b0;
            mvm_start  <= 1'b0;
            intt_start <= 1'b0;

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
                        intt_start    <= 1'b1;
                        current_state <= RUN_INTT;
                    end
                end

                RUN_INTT: begin
                    if (intt_done) begin
                        // Latch spatial outputs into pipeline registers to isolate poly_compress
                        u0_spatial_r  <= u0_spatial;
                        u1_spatial_r  <= u1_spatial;
                        v_final_r     <= v_final;
                        current_state <= RUN_COMPRESS;
                    end
                end

                RUN_COMPRESS: begin
                    busy          <= 1'b0;
                    done          <= 1'b1;
                    current_state <= FINISH;
                end

                FINISH: begin
                    current_state <= IDLE;
                end

                default: current_state <= IDLE;

            endcase
        end
    end

endmodule
