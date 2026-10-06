// ============================================================================
// File: rejection_sampler.v
// Module: rejection_sampler
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Parameter: N = 256, Q = 3329
// Description: Synthesizable Verilog Rejection Sampler converting SHAKE bytes
//              into uniformly distributed polynomial coefficients modulo q = 3329.
// ============================================================================

`timescale 1ns/1ps

module rejection_sampler #(
    parameter N = 256,
    parameter Q = 3329
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,

    input  wire [7:0]  byte0,
    input  wire [7:0]  byte1,
    input  wire [7:0]  byte2,
    input  wire        bytes_valid,

    output reg         ready,

    output reg  [11:0] coeff,
    output reg         coeff_valid,

    output reg  [8:0]  coeff_count,

    output reg         done,
    output reg         busy
);

    reg [8:0] count;

    reg [11:0] candidate_buffer0;
    reg [11:0] candidate_buffer1;

    reg buffer_valid0;
    reg buffer_valid1;

    reg [11:0] candidate0;
    reg [11:0] candidate1;

    reg accept0;
    reg accept1;

    always @(*) begin
        candidate0 = {byte1[3:0], byte0};
        candidate1 = {byte2, byte1[7:4]};
        accept0    = (candidate0 < Q);
        accept1    = (candidate1 < Q);

        if (count == N-1) begin
            if (accept0)
                accept1 = 1'b0;
        end

        ready = busy && !buffer_valid0 && !buffer_valid1 && (count < N);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count             <= 9'd0;
            coeff             <= 12'd0;
            coeff_count       <= 9'd0;
            buffer_valid0     <= 1'b0;
            buffer_valid1     <= 1'b0;
            candidate_buffer0 <= 12'd0;
            candidate_buffer1 <= 12'd0;
            coeff_valid       <= 1'b0;
            done              <= 1'b0;
            busy              <= 1'b0;
        end else begin
            coeff_valid <= 1'b0;
            done        <= 1'b0;

            if (start && !busy) begin
                count         <= 9'd0;
                coeff_count   <= 9'd0;
                buffer_valid0 <= 1'b0;
                buffer_valid1 <= 1'b0;
                busy          <= 1'b1;
            end else if (busy && buffer_valid0) begin
                coeff       <= candidate_buffer0;
                coeff_valid <= 1'b1;
                count       <= count + 1'b1;
                coeff_count <= count + 1'b1;

                if (buffer_valid1) begin
                    candidate_buffer0 <= candidate_buffer1;
                    buffer_valid0     <= 1'b1;
                    buffer_valid1     <= 1'b0;
                end else begin
                    buffer_valid0 <= 1'b0;
                end

                if (count == N-1) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end else if (busy && buffer_valid1) begin
                coeff       <= candidate_buffer1;
                coeff_valid <= 1'b1;
                count       <= count + 1'b1;
                coeff_count <= count + 1'b1;
                buffer_valid1 <= 1'b0;

                if (count == N-1) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end else if (busy && ready && bytes_valid) begin
                if (accept0 && accept1) begin
                    candidate_buffer0 <= candidate0;
                    buffer_valid0     <= 1'b1;
                    candidate_buffer1 <= candidate1;
                    buffer_valid1     <= 1'b1;
                end else if (accept0) begin
                    candidate_buffer0 <= candidate0;
                    buffer_valid0     <= 1'b1;
                end else if (accept1) begin
                    candidate_buffer0 <= candidate1;
                    buffer_valid0     <= 1'b1;
                end
            end
        end
    end

endmodule
