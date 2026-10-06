// ============================================================================
// File: shake128_xof.v
// Module: shake128_xof
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
//
// SHAKE-128 extendable output function, used as the XOF for ExpandA.
//
// REPLACES the uploaded shake.v. That module was named "shake" but performed
// no sponge construction at all: it loaded a raw 1600-bit state, ran one
// Keccak permutation, and returned the low OUT_BITS. There was no rate /
// capacity split, no domain separator, no padding and no squeeze loop, so it
// could not produce more than one block and did not implement FIPS 202.
//
// This module implements the real thing for the single-block-absorb case,
// which is all ExpandA needs:
//
//   input block = seed[0..31] || idx0 || idx1        (34 bytes)
//   padding     = 0x1F at byte 34, 0x80 at byte 167  (pad10*1, rate 168)
//   absorb      = XOR block into rate, permute
//   squeeze     = emit rate bytes 0..167, then permute again for the next
//                 168 bytes, indefinitely
//
// Output is delivered three bytes at a time because that is exactly what the
// rejection sampler consumes (2 twelve-bit candidates per 3 bytes). The rate
// is 168 bytes = 56 groups of 3, so groups never straddle a block boundary.
//
// Handshake:
//   bytes_valid  goes high when byte0/1/2 hold a fresh group
//   bytes_ack    pulsed by the consumer to advance to the next group
// ============================================================================

`timescale 1ns/1ps

module shake128_xof (
    input  wire         clk,
    input  wire         rst_n,

    input  wire         start,          // begin a fresh absorb
    input  wire [255:0] seed,           // 32-byte seed (rho)
    input  wire [7:0]   idx0,           // first  domain index byte
    input  wire [7:0]   idx1,           // second domain index byte

    output reg  [7:0]   byte0,
    output reg  [7:0]   byte1,
    output reg  [7:0]   byte2,
    output reg          bytes_valid,
    input  wire         bytes_ack,

    output reg          busy
);

    localparam [7:0] RATE = 8'd168;     // SHAKE-128 rate in bytes

    // ---------------- Keccak permutation ----------------
    reg  [1599:0] state_reg;
    reg           kec_start;
    wire [1599:0] kec_out;
    wire          kec_busy;
    wire          kec_done;

    keccak_f1600 kec (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (kec_start),
        .state_in  (state_reg),
        .busy      (kec_busy),
        .done      (kec_done),
        .state_out (kec_out)
    );

    // ---------------- padded absorb block ----------------
    // Byte p of the sponge state lives at state[p*8 +: 8].
    // Bytes 0..33 carry the message, byte 34 is the SHAKE domain separator
    // 0x1F, byte 167 is the final pad bit 0x80, everything else is zero.
    wire [1599:0] absorb_block;

    assign absorb_block = { {(1600 - 168*8){1'b0}},        // capacity, zero
                            8'h80,                          // byte 167
                            {(166-35+1)*8{1'b0}},           // bytes 35..166 (132 bytes)
                            8'h1F,                          // byte 34
                            idx1,                           // byte 33
                            idx0,                           // byte 32
                            seed };                         // bytes 0..31

    // ---------------- sequencer ----------------
    localparam [1:0] ST_IDLE    = 2'd0;
    localparam [1:0] ST_PERMUTE = 2'd1;
    localparam [1:0] ST_SQUEEZE = 2'd2;

    reg [1:0] state;
    reg [7:0] ptr;                       // byte offset inside the rate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            state_reg   <= 1600'd0;
            ptr         <= 8'd0;
            kec_start   <= 1'b0;
            bytes_valid <= 1'b0;
            busy        <= 1'b0;
            byte0       <= 8'd0;
            byte1       <= 8'd0;
            byte2       <= 8'd0;
        end
        else begin
            kec_start <= 1'b0;

            case (state)

                ST_IDLE: begin
                    bytes_valid <= 1'b0;
                    busy        <= 1'b0;

                    if (start) begin
                        // absorb: state is all zero, so XOR reduces to load
                        state_reg <= absorb_block;
                        kec_start <= 1'b1;
                        busy      <= 1'b1;
                        ptr       <= 8'd0;
                        state     <= ST_PERMUTE;
                    end
                end

                ST_PERMUTE: begin
                    if (kec_done) begin
                        state_reg   <= kec_out;
                        ptr         <= 8'd0;
                        byte0       <= kec_out[0*8 +: 8];
                        byte1       <= kec_out[1*8 +: 8];
                        byte2       <= kec_out[2*8 +: 8];
                        bytes_valid <= 1'b1;
                        state       <= ST_SQUEEZE;
                    end
                end

                ST_SQUEEZE: begin
                    if (bytes_ack) begin
                        if (ptr + 8'd3 >= RATE) begin
                            // rate exhausted: permute again to squeeze more
                            bytes_valid <= 1'b0;
                            kec_start   <= 1'b1;
                            state       <= ST_PERMUTE;
                        end
                        else begin
                            ptr   <= ptr + 8'd3;
                            byte0 <= state_reg[(ptr + 8'd3)*8 +: 8];
                            byte1 <= state_reg[(ptr + 8'd4)*8 +: 8];
                            byte2 <= state_reg[(ptr + 8'd5)*8 +: 8];
                        end
                    end
                end

                default: state <= ST_IDLE;

            endcase
        end
    end

endmodule
