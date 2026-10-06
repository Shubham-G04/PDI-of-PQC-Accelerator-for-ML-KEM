// ============================================================================
// File: poly_uniform.v
// Module: poly_uniform
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
//
// Samples one uniformly random polynomial in the NTT domain from a public
// seed, i.e. FIPS 203 SampleNTT (Algorithm 7) driven by SHAKE-128.
//
// This is the module that finally puts keccak_f1600, the SHAKE XOF and
// rejection_sampler into the actual datapath. In the uploaded project all
// three were orphans: nothing instantiated them, and the A matrix was a
// hardwired ramp (A00[i] = i+1, ...) in mlkem_picorv32_wrapper.
//
//   seed, idx0, idx1  ->  SHAKE-128  ->  3 bytes at a time
//                                    ->  rejection_sampler
//                                    ->  256 coefficients < 3329
//
// Each 3-byte group yields two 12-bit candidates; candidates >= q are
// rejected. Output is the flat 12-bit-per-lane bus used by the pipeline.
// ============================================================================

`timescale 1ns/1ps

module poly_uniform #(
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,

    input  wire [255:0]         seed,
    input  wire [7:0]           idx0,
    input  wire [7:0]           idx1,

    output wire [(N*12)-1:0]    poly_out,

    output reg                  busy,
    output reg                  done
);

    // ---------------- XOF ----------------
    reg        xof_start;
    wire [7:0] xof_b0, xof_b1, xof_b2;
    wire       xof_valid;
    wire       xof_busy;
    wire       xof_ack;

    shake128_xof xof (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (xof_start),
        .seed        (seed),
        .idx0        (idx0),
        .idx1        (idx1),
        .byte0       (xof_b0),
        .byte1       (xof_b1),
        .byte2       (xof_b2),
        .bytes_valid (xof_valid),
        .bytes_ack   (xof_ack),
        .busy        (xof_busy)
    );

    // ---------------- rejection sampler ----------------
    reg         rej_start;
    wire        rej_ready;
    wire [11:0] rej_coeff;
    wire        rej_coeff_valid;
    wire [8:0]  rej_count;
    wire        rej_done;
    wire        rej_busy;

    rejection_sampler #(.N(N), .Q(Q)) rej (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (rej_start),
        .byte0       (xof_b0),
        .byte1       (xof_b1),
        .byte2       (xof_b2),
        .bytes_valid (xof_valid),
        .ready       (rej_ready),
        .coeff       (rej_coeff),
        .coeff_valid (rej_coeff_valid),
        .coeff_count (rej_count),
        .done        (rej_done),
        .busy        (rej_busy)
    );

    /*
     * The sampler latches a byte group exactly on the cycles where it is
     * asserting ready and the XOF is presenting valid data, so that same
     * condition is the XOF's advance strobe. Keeping the two in lockstep
     * this way means no byte can be consumed twice or skipped.
     */
    assign xof_ack = rej_ready & xof_valid;

    // ---------------- coefficient collection ----------------
    reg [11:0] mem [0:N-1];
    reg [8:0]  wr_idx;

    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_out
            assign poly_out[gi*12 +: 12] = mem[gi];
        end
    endgenerate

    // ---------------- sequencer ----------------
    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_RUN  = 2'd1;
    localparam [1:0] ST_FIN  = 2'd2;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            busy      <= 1'b0;
            done      <= 1'b0;
            xof_start <= 1'b0;
            rej_start <= 1'b0;
            wr_idx    <= 9'd0;
        end
        else begin
            done      <= 1'b0;
            xof_start <= 1'b0;
            rej_start <= 1'b0;

            // capture every accepted coefficient
            if (rej_coeff_valid && (wr_idx < N)) begin
                mem[wr_idx] <= rej_coeff;
                wr_idx      <= wr_idx + 9'd1;
            end

            case (state)

                ST_IDLE: begin
                    if (start) begin
                        busy      <= 1'b1;
                        wr_idx    <= 9'd0;
                        xof_start <= 1'b1;
                        rej_start <= 1'b1;
                        state     <= ST_RUN;
                    end
                end

                ST_RUN: begin
                    if (rej_done) begin
                        busy  <= 1'b0;
                        done  <= 1'b1;
                        state <= ST_FIN;
                    end
                end

                ST_FIN: begin
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;

            endcase
        end
    end

endmodule
