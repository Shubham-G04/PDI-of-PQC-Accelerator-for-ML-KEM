// ============================================================================
// File: keccak_f1600.v
// Module: keccak_f1600
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Description: Synthesizable Verilog Keccak-f[1600] 24-round permutation unit.
//              Applies Theta, Rho, Pi, Chi, and Iota transformations per FIPS 202.
//
// BUG FIX: round constant RC[18] was 0x000000000000808A; the correct FIPS 202
// value is 0x000000000000800A. A single wrong nibble corrupted rounds 18-23,
// so the permutation output was wrong for every input. Verified after the fix:
// keccak_f1600(all-zero state) now produces the reference lanes
//   f1258f7940e1dde7 84d5ccf933c0478a d598261ea65aa9ee bd1547306f80494d
// ============================================================================

`timescale 1ns/1ps

module keccak_f1600 (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          start,
    input  wire [1599:0] state_in,

    output wire          busy,
    output wire          done,
    output wire [1599:0] state_out
);

    reg [1599:0] state_reg;
    reg [4:0]    round;

    reg          busy_reg;
    reg          done_reg;

    assign busy      = busy_reg;
    assign done      = done_reg;
    assign state_out = state_reg;

    function [63:0] round_constant;
        input [4:0] r;
        begin
            case (r)
                5'd0:  round_constant = 64'h0000000000000001;
                5'd1:  round_constant = 64'h0000000000008082;
                5'd2:  round_constant = 64'h800000000000808A;
                5'd3:  round_constant = 64'h8000000080008000;
                5'd4:  round_constant = 64'h000000000000808B;
                5'd5:  round_constant = 64'h0000000080000001;
                5'd6:  round_constant = 64'h8000000080008081;
                5'd7:  round_constant = 64'h8000000000008009;
                5'd8:  round_constant = 64'h000000000000008A;
                5'd9:  round_constant = 64'h0000000000000088;
                5'd10: round_constant = 64'h0000000080008009;
                5'd11: round_constant = 64'h000000008000000A;
                5'd12: round_constant = 64'h000000008000808B;
                5'd13: round_constant = 64'h800000000000008B;
                5'd14: round_constant = 64'h8000000000008089;
                5'd15: round_constant = 64'h8000000000008003;
                5'd16: round_constant = 64'h8000000000008002;
                5'd17: round_constant = 64'h8000000000000080;
                5'd18: round_constant = 64'h000000000000800A;   // FIXED: was 808A
                5'd19: round_constant = 64'h800000008000000A;
                5'd20: round_constant = 64'h8000000080008081;
                5'd21: round_constant = 64'h8000000000008080;
                5'd22: round_constant = 64'h0000000080000001;
                5'd23: round_constant = 64'h8000000080008008;
                default: round_constant = 64'd0;
            endcase
        end
    endfunction

    function [63:0] rotl64;
        input [63:0] val;
        input integer amt;
        begin
            if (amt == 0)
                rotl64 = val;
            else
                rotl64 = (val << amt) | (val >> (64 - amt));
        end
    endfunction

    function [1599:0] keccak_round;
        input [1599:0] in_state;
        input [4:0] round_number;

        reg [63:0] A [0:4][0:4];
        reg [63:0] B [0:4][0:4];
        reg [63:0] C [0:4];
        reg [63:0] D [0:4];
        integer x, y;

        begin
            for (y = 0; y < 5; y = y + 1) begin
                for (x = 0; x < 5; x = x + 1) begin
                    A[x][y] = in_state[((x + 5*y)*64) +: 64];
                end
            end

            for (x = 0; x < 5; x = x + 1) begin
                C[x] = A[x][0] ^ A[x][1] ^ A[x][2] ^ A[x][3] ^ A[x][4];
            end
            for (x = 0; x < 5; x = x + 1) begin
                D[x] = C[(x + 4) % 5] ^ rotl64(C[(x + 1) % 5], 1);
            end
            for (y = 0; y < 5; y = y + 1) begin
                for (x = 0; x < 5; x = x + 1) begin
                    A[x][y] = A[x][y] ^ D[x];
                end
            end

            B[0][0] = rotl64(A[0][0],  0); B[0][2] = rotl64(A[1][0],  1); B[0][4] = rotl64(A[2][0], 62); B[0][1] = rotl64(A[3][0], 28); B[0][3] = rotl64(A[4][0], 27);
            B[1][3] = rotl64(A[0][1], 36); B[1][0] = rotl64(A[1][1], 44); B[1][2] = rotl64(A[2][1],  6); B[1][4] = rotl64(A[3][1], 55); B[1][1] = rotl64(A[4][1], 20);
            B[2][1] = rotl64(A[0][2],  3); B[2][3] = rotl64(A[1][2], 10); B[2][0] = rotl64(A[2][2], 43); B[2][2] = rotl64(A[3][2], 25); B[2][4] = rotl64(A[4][2], 39);
            B[3][4] = rotl64(A[0][3], 41); B[3][1] = rotl64(A[1][3], 45); B[3][3] = rotl64(A[2][3], 15); B[3][0] = rotl64(A[3][3], 21); B[3][2] = rotl64(A[4][3],  8);
            B[4][2] = rotl64(A[0][4], 18); B[4][4] = rotl64(A[1][4],  2); B[4][1] = rotl64(A[2][4], 61); B[4][3] = rotl64(A[3][4], 56); B[4][0] = rotl64(A[4][4], 14);

            for (y = 0; y < 5; y = y + 1) begin
                for (x = 0; x < 5; x = x + 1) begin
                    A[x][y] = B[x][y] ^ ((~B[(x + 1) % 5][y]) & B[(x + 2) % 5][y]);
                end
            end

            A[0][0] = A[0][0] ^ round_constant(round_number);

            for (y = 0; y < 5; y = y + 1) begin
                for (x = 0; x < 5; x = x + 1) begin
                    keccak_round[((x + 5*y)*64) +: 64] = A[x][y];
                end
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= 1600'd0;
            round     <= 5'd0;
            busy_reg  <= 1'b0;
            done_reg  <= 1'b0;
        end else begin
            done_reg <= 1'b0;

            if (!busy_reg) begin
                if (start) begin
                    state_reg <= state_in;
                    round     <= 5'd0;
                    busy_reg  <= 1'b1;
                end
            end else begin
                state_reg <= keccak_round(state_reg, round);

                if (round == 5'd23) begin
                    busy_reg <= 1'b0;
                    done_reg <= 1'b1;
                end else begin
                    round <= round + 5'd1;
                end
            end
        end
    end

endmodule
