// ============================================================================
// File: mlkem_dec.v
// Module: mlkem_dec
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: K = 2, Q = 3329, N = 256
// Description: Synthesizable Verilog ML-KEM-512 Decapsulation Module per FIPS 203.
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

module mlkem_dec #(
    parameter K = 2,
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,

    input  wire [(N*10)-1:0]    c_u0,
    input  wire [(N*10)-1:0]    c_u1,
    input  wire [(N*4)-1:0]     c_v,

    input  wire [(N*12)-1:0]    sk_s0,
    input  wire [(N*12)-1:0]    sk_s1,

    output wire [255:0]         msg_out,

    output reg                  busy,
    output reg                  done
);

    wire [(N*12)-1:0] u0_spatial, u1_spatial, v_spatial;

    genvar idx;
    generate
        for (idx = 0; idx < N; idx = idx + 1) begin : decomp_u_v
            poly_decompress #(.Q(Q), .D(10)) decomp_u0_inst (.compressed(c_u0[idx*10 +: 10]), .coeff(u0_spatial[idx*12 +: 12]));
            poly_decompress #(.Q(Q), .D(10)) decomp_u1_inst (.compressed(c_u1[idx*10 +: 10]), .coeff(u1_spatial[idx*12 +: 12]));
            poly_decompress #(.Q(Q), .D(4))  decomp_v_inst  (.compressed(c_v[idx*4 +: 4]),   .coeff(v_spatial[idx*12 +: 12]));
        end
    endgenerate

    wire [(N*12)-1:0] u0_ntt, u1_ntt;
    reg ntt_start;
    wire ntt_done0;

    ntt_flat #(.Q(Q), .N(N)) ntt_u0 (.clk(clk), .rst_n(rst_n), .start(ntt_start), .poly_in(u0_spatial), .poly_out(u0_ntt), .busy(), .done(ntt_done0));
    ntt_flat #(.Q(Q), .N(N)) ntt_u1 (.clk(clk), .rst_n(rst_n), .start(ntt_start), .poly_in(u1_spatial), .poly_out(u1_ntt), .busy(), .done());

    reg pm_start;
    wire pm_done0, pm_done1;
    wire [(N*12)-1:0] prod_s0_u0, prod_s1_u1;
    wire [(N*12)-1:0] sum_su;

    poly_mul_pointwise #(.Q(Q), .N(N)) mul_s0_u0 (.clk(clk), .rst_n(rst_n), .start(pm_start), .poly_a(sk_s0), .poly_b(u0_ntt), .poly_c(prod_s0_u0), .busy(), .done(pm_done0));
    poly_mul_pointwise #(.Q(Q), .N(N)) mul_s1_u1 (.clk(clk), .rst_n(rst_n), .start(pm_start), .poly_a(sk_s1), .poly_b(u1_ntt), .poly_c(prod_s1_u1), .busy(), .done(pm_done1));

    poly_add #(.Q(Q), .N(N)) add_su (.poly_a(prod_s0_u0), .poly_b(prod_s1_u1), .poly_c(sum_su));

    reg intt_start;
    wire intt_done;
    wire [(N*12)-1:0] w_spatial;
    intt_flat #(.Q(Q), .N(N)) intt_w (.clk(clk), .rst_n(rst_n), .start(intt_start), .poly_in(sum_su), .poly_out(w_spatial), .busy(), .done(intt_done));

    wire [(N*12)-1:0] diff_vw;
    poly_sub #(.Q(Q), .N(N)) sub_vw (.poly_a(v_spatial), .poly_b(w_spatial), .poly_c(diff_vw));

    generate
        for (idx = 0; idx < N; idx = idx + 1) begin : extract_msg
            wire [0:0] bit_c;
            poly_compress #(.Q(Q), .D(1)) comp_m (.coeff(diff_vw[idx*12 +: 12]), .compressed(bit_c));
            assign msg_out[idx] = bit_c[0];
        end
    endgenerate

    localparam IDLE     = 3'b000;
    localparam RUN_NTT  = 3'b001;
    localparam RUN_PM   = 3'b010;
    localparam RUN_INTT = 3'b011;
    localparam FINISH   = 3'b100;

    reg [2:0] current_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            ntt_start     <= 1'b0;
            pm_start      <= 1'b0;
            intt_start    <= 1'b0;
        end else begin
            done       <= 1'b0;
            ntt_start  <= 1'b0;
            pm_start   <= 1'b0;
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
                        pm_start      <= 1'b1;
                        current_state <= RUN_PM;
                    end
                end

                RUN_PM: begin
                    if (pm_done0) begin
                        intt_start    <= 1'b1;
                        current_state <= RUN_INTT;
                    end
                end

                RUN_INTT: begin
                    if (intt_done) begin
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
