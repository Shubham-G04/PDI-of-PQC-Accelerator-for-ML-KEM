// ============================================================================
// File: mlkem_top.v
// Module: mlkem_top
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator IP Block
// Parameter: K = 2, Q = 3329, N = 256
//
// Unified ML-KEM-512 accelerator: KeyGen, Encapsulation, Decapsulation.
//
// CHANGES vs the uploaded version:
//
//  1. A IS NOW DERIVED FROM A SEED.
//     A00..A11 used to be top-level INPUT ports, driven from a hardwired
//     ramp in the bus wrapper. They are now generated internally by
//     mlkem_matrix_gen (ExpandA) from the public seed rho, which is what
//     finally puts keccak_f1600 / SHAKE-128 / rejection_sampler into the
//     datapath instead of leaving them as unused files. A new EXPAND
//     command runs once before key generation.
//
//  2. STAGE-QUALIFIED STATUS.
//     `done` used to be kg_done | enc_done | dec_done with no indication of
//     which stage finished, so firmware polling a shared status bit could
//     not tell stages apart. done is still the OR of the stage pulses, but
//     a sticky per-stage completion vector (stage_done) is exported so the
//     CPU can confirm exactly which operations have run.
//
//  3. cmd_valid is edge-detected. It used to feed a combinational
//     `cmd_valid && !busy` decode, so a command register left asserted
//     would retrigger the core continuously.
// ============================================================================

`timescale 1ns/1ps

module mlkem_top #(
    parameter K = 2,
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 cmd_valid,
    input  wire [1:0]           cmd_type,   // 00:ExpandA 01:KeyGen 10:Encap 11:Decap

    input  wire [255:0]         rho,        // public seed for ExpandA

    input  wire [1023:0]        rand_r0,
    input  wire [1023:0]        rand_r1,
    input  wire [1023:0]        rand_e0,
    input  wire [1023:0]        rand_e1,
    input  wire [1023:0]        rand_e2,

    input  wire [255:0]         msg_in,

    output wire [(N*12)-1:0]    pk_t0,
    output wire [(N*12)-1:0]    pk_t1,
    output wire [(N*12)-1:0]    sk_s0,
    output wire [(N*12)-1:0]    sk_s1,

    output wire [(N*10)-1:0]    c_u0,
    output wire [(N*10)-1:0]    c_u1,
    output wire [(N*4)-1:0]     c_v,

    output wire [255:0]         msg_out,

    output wire                 busy,
    output wire                 done,
    output reg  [3:0]           stage_done  // sticky: [0]=ExpandA [1]=KeyGen
                                            //         [2]=Encap   [3]=Decap
);

    // ------------------------------------------------------------------
    // Command edge detection
    // ------------------------------------------------------------------
    reg  cmd_valid_d;
    wire cmd_pulse = cmd_valid & ~cmd_valid_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cmd_valid_d <= 1'b0;
        else        cmd_valid_d <= cmd_valid;
    end

    reg mg_start, kg_start, enc_start, dec_start;

    wire mg_busy,  mg_done;
    wire kg_busy,  kg_done;
    wire enc_busy, enc_done;
    wire dec_busy, dec_done;

    // ------------------------------------------------------------------
    // ExpandA
    // ------------------------------------------------------------------
    wire [(N*12)-1:0] A00, A01, A10, A11;

    mlkem_matrix_gen #(.Q(Q), .N(N)) matgen (
        .clk(clk), .rst_n(rst_n), .start(mg_start),
        .rho(rho),
        .A00(A00), .A01(A01), .A10(A10), .A11(A11),
        .busy(mg_busy), .done(mg_done)
    );

    // ------------------------------------------------------------------
    // Key generation
    // ------------------------------------------------------------------
    mlkem_keygen #(.K(K), .Q(Q), .N(N)) keygen_core (
        .clk(clk), .rst_n(rst_n), .start(kg_start),
        .rand_bits_s0(rand_r0), .rand_bits_s1(rand_r1),
        .rand_bits_e0(rand_e0), .rand_bits_e1(rand_e1),
        .A00(A00), .A01(A01), .A10(A10), .A11(A11),
        .pk_t0(pk_t0), .pk_t1(pk_t1),
        .sk_s0(sk_s0), .sk_s1(sk_s1),
        .busy(kg_busy), .done(kg_done)
    );

    // ------------------------------------------------------------------
    // Encapsulation
    // ------------------------------------------------------------------
    mlkem_enc #(.K(K), .Q(Q), .N(N)) enc_core (
        .clk(clk), .rst_n(rst_n), .start(enc_start),
        .pk_t0(pk_t0), .pk_t1(pk_t1),
        .A00(A00), .A10(A10), .A01(A01), .A11(A11),
        .rand_bits_r0(rand_r0), .rand_bits_r1(rand_r1),
        .rand_bits_e1_0(rand_e0), .rand_bits_e1_1(rand_e1),
        .rand_bits_e2(rand_e2),
        .msg(msg_in),
        .c_u0(c_u0), .c_u1(c_u1), .c_v(c_v),
        .busy(enc_busy), .done(enc_done)
    );

    // ------------------------------------------------------------------
    // Decapsulation
    // ------------------------------------------------------------------
    mlkem_dec #(.K(K), .Q(Q), .N(N)) dec_core (
        .clk(clk), .rst_n(rst_n), .start(dec_start),
        .c_u0(c_u0), .c_u1(c_u1), .c_v(c_v),
        .sk_s0(sk_s0), .sk_s1(sk_s1),
        .msg_out(msg_out),
        .busy(dec_busy), .done(dec_done)
    );

    assign busy = mg_busy  | kg_busy  | enc_busy | dec_busy;
    assign done = mg_done  | kg_done  | enc_done | dec_done;

    // ------------------------------------------------------------------
    // Command dispatch
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mg_start   <= 1'b0;
            kg_start   <= 1'b0;
            enc_start  <= 1'b0;
            dec_start  <= 1'b0;
            stage_done <= 4'd0;
        end
        else begin
            mg_start  <= 1'b0;
            kg_start  <= 1'b0;
            enc_start <= 1'b0;
            dec_start <= 1'b0;

            if (cmd_pulse && !busy) begin
                case (cmd_type)
                    2'b00: mg_start  <= 1'b1;
                    2'b01: kg_start  <= 1'b1;
                    2'b10: enc_start <= 1'b1;
                    2'b11: dec_start <= 1'b1;
                endcase
            end

            if (mg_done)  stage_done[0] <= 1'b1;
            if (kg_done)  stage_done[1] <= 1'b1;
            if (enc_done) stage_done[2] <= 1'b1;
            if (dec_done) stage_done[3] <= 1'b1;
        end
    end

endmodule
