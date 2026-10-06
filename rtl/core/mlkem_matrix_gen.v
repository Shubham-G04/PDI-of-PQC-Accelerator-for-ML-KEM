// ============================================================================
// File: mlkem_matrix_gen.v
// Module: mlkem_matrix_gen
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
//
// ExpandA: derives the public 2x2 matrix A (already in the NTT domain) from
// the 256-bit public seed rho, per FIPS 203.
//
//     A[i][j] = SampleNTT( XOF(rho, j, i) )
//
// Replaces the hardwired dummy matrix that the uploaded
// mlkem_picorv32_wrapper used (A00[i] = i+1, A01[i] = i+2, ...), which meant
// the "public matrix" was a fixed ramp with no relation to any seed.
//
// A single poly_uniform instance is time-shared across the four entries,
// which keeps the Keccak core count at one.
// ============================================================================

`timescale 1ns/1ps

module mlkem_matrix_gen #(
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,

    input  wire [255:0]         rho,

    output reg  [(N*12)-1:0]    A00,
    output reg  [(N*12)-1:0]    A01,
    output reg  [(N*12)-1:0]    A10,
    output reg  [(N*12)-1:0]    A11,

    output reg                  busy,
    output reg                  done
);

    reg        pu_start;
    reg  [7:0] pu_idx0;      // j
    reg  [7:0] pu_idx1;      // i
    wire [(N*12)-1:0] pu_poly;
    wire       pu_busy;
    wire       pu_done;

    poly_uniform #(.Q(Q), .N(N)) pu (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (pu_start),
        .seed     (rho),
        .idx0     (pu_idx0),
        .idx1     (pu_idx1),
        .poly_out (pu_poly),
        .busy     (pu_busy),
        .done     (pu_done)
    );

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_KICK = 3'd1;
    localparam [2:0] ST_WAIT = 3'd2;
    localparam [2:0] ST_FIN  = 3'd3;

    reg [2:0] state;
    reg [1:0] entry;         // 0:A00  1:A01  2:A10  3:A11

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= ST_IDLE;
            entry    <= 2'd0;
            busy     <= 1'b0;
            done     <= 1'b0;
            pu_start <= 1'b0;
            pu_idx0  <= 8'd0;
            pu_idx1  <= 8'd0;
            A00      <= {(N*12){1'b0}};
            A01      <= {(N*12){1'b0}};
            A10      <= {(N*12){1'b0}};
            A11      <= {(N*12){1'b0}};
        end
        else begin
            done     <= 1'b0;
            pu_start <= 1'b0;

            case (state)

                ST_IDLE: begin
                    if (start) begin
                        busy  <= 1'b1;
                        entry <= 2'd0;
                        state <= ST_KICK;
                    end
                end

                ST_KICK: begin
                    // entry n = (i,j):  0=(0,0) 1=(0,1) 2=(1,0) 3=(1,1)
                    pu_idx0  <= {7'd0, entry[0]};   // j
                    pu_idx1  <= {7'd0, entry[1]};   // i
                    pu_start <= 1'b1;
                    state    <= ST_WAIT;
                end

                ST_WAIT: begin
                    if (pu_done) begin
                        case (entry)
                            2'd0: A00 <= pu_poly;
                            2'd1: A01 <= pu_poly;
                            2'd2: A10 <= pu_poly;
                            2'd3: A11 <= pu_poly;
                        endcase

                        if (entry == 2'd3) begin
                            busy  <= 1'b0;
                            done  <= 1'b1;
                            state <= ST_FIN;
                        end
                        else begin
                            entry <= entry + 2'd1;
                            state <= ST_KICK;
                        end
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
