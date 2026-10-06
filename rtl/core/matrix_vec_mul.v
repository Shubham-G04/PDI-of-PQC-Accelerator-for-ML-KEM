// ============================================================================
// File: matrix_vec_mul.v (Pipelined Version)
// Module: matrix_vec_mul
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: K = 2, Q = 3329, N = 256
//
// Synthesizable Matrix-Vector Multiplier with Intermediate Pipeline Decoupling:
//     t = A * s + e (in NTT domain)
//
// TIMING IMPROVEMENT:
// Intercepts the outputs of `poly_mul_pointwise` with registered holding buffers
// before feeding the two cascaded `poly_add` layers. This prevents the pointwise
// multiplier's final stage path from concatenating with the 256-parallel 12-bit
// adder trees.
// ============================================================================

`timescale 1ns/1ps

module matrix_vec_mul #(
    parameter K = 2,
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,

    // Matrix A (2x2 packed 3072-bit vectors)
    input  wire [(N*12)-1:0]    A00,
    input  wire [(N*12)-1:0]    A01,
    input  wire [(N*12)-1:0]    A10,
    input  wire [(N*12)-1:0]    A11,

    // Vector s
    input  wire [(N*12)-1:0]    s0,
    input  wire [(N*12)-1:0]    s1,

    // Error e
    input  wire [(N*12)-1:0]    e0,
    input  wire [(N*12)-1:0]    e1,

    // Output t
    output wire [(N*12)-1:0]    t0,
    output wire [(N*12)-1:0]    t1,

    output reg                  busy,
    output reg                  done
);

    wire [(N*12)-1:0] prod_A00_s0, prod_A01_s1, prod_A10_s0, prod_A11_s1;
    reg  [(N*12)-1:0] prod_A00_s0_r, prod_A01_s1_r;
    reg  [(N*12)-1:0] prod_A10_s0_r, prod_A11_s1_r;

    wire [(N*12)-1:0] sum0, sum1;

    reg pm_start, pm_start2;
    wire pm_busy0, pm_busy1, pm_done0, pm_done1;
    wire pm_busy2, pm_busy3, pm_done2, pm_done3;

    // Row 0 pointwise multipliers
    poly_mul_pointwise #(.Q(Q), .N(N)) mul_inst0 (
        .clk(clk), .rst_n(rst_n), .start(pm_start),
        .poly_a(A00), .poly_b(s0), .poly_c(prod_A00_s0),
        .busy(pm_busy0), .done(pm_done0)
    );

    poly_mul_pointwise #(.Q(Q), .N(N)) mul_inst1 (
        .clk(clk), .rst_n(rst_n), .start(pm_start),
        .poly_a(A01), .poly_b(s1), .poly_c(prod_A01_s1),
        .busy(pm_busy1), .done(pm_done1)
    );

    // Row 0 registered polynomial accumulation
    poly_add #(.Q(Q), .N(N)) add_inst0_mid (.poly_a(prod_A00_s0_r), .poly_b(prod_A01_s1_r), .poly_c(sum0));
    poly_add #(.Q(Q), .N(N)) add_inst0_final (.poly_a(sum0), .poly_b(e0), .poly_c(t0));

    // Row 1 pointwise multipliers
    poly_mul_pointwise #(.Q(Q), .N(N)) mul_inst2 (
        .clk(clk), .rst_n(rst_n), .start(pm_start2),
        .poly_a(A10), .poly_b(s0), .poly_c(prod_A10_s0),
        .busy(pm_busy2), .done(pm_done2)
    );

    poly_mul_pointwise #(.Q(Q), .N(N)) mul_inst3 (
        .clk(clk), .rst_n(rst_n), .start(pm_start2),
        .poly_a(A11), .poly_b(s1), .poly_c(prod_A11_s1),
        .busy(pm_busy3), .done(pm_done3)
    );

    // Row 1 registered polynomial accumulation
    poly_add #(.Q(Q), .N(N)) add_inst1_mid (.poly_a(prod_A10_s0_r), .poly_b(prod_A11_s1_r), .poly_c(sum1));
    poly_add #(.Q(Q), .N(N)) add_inst1_final (.poly_a(sum1), .poly_b(e1), .poly_c(t1));

    localparam IDLE       = 3'b000;
    localparam ROW0       = 3'b001;
    localparam LATCH_ROW0 = 3'b010;
    localparam ROW1       = 3'b011;
    localparam LATCH_ROW1 = 3'b100;
    localparam FINISH     = 3'b101;

    reg [2:0] current_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state   <= IDLE;
            busy            <= 1'b0;
            done            <= 1'b0;
            pm_start        <= 1'b0;
            pm_start2       <= 1'b0;
            prod_A00_s0_r   <= {(N*12){1'b0}};
            prod_A01_s1_r   <= {(N*12){1'b0}};
            prod_A10_s0_r   <= {(N*12){1'b0}};
            prod_A11_s1_r   <= {(N*12){1'b0}};
        end else begin
            done      <= 1'b0;
            pm_start  <= 1'b0;
            pm_start2 <= 1'b0;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        busy          <= 1'b1;
                        pm_start      <= 1'b1;
                        current_state <= ROW0;
                    end
                end

                ROW0: begin
                    if (pm_done0) begin
                        prod_A00_s0_r <= prod_A00_s0;
                        prod_A01_s1_r <= prod_A01_s1;
                        current_state <= LATCH_ROW0;
                    end
                end

                LATCH_ROW0: begin
                    pm_start2     <= 1'b1;
                    current_state <= ROW1;
                end

                ROW1: begin
                    if (pm_done2) begin
                        prod_A10_s0_r <= prod_A10_s0;
                        prod_A11_s1_r <= prod_A11_s1;
                        current_state <= LATCH_ROW1;
                    end
                end

                LATCH_ROW1: begin
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
