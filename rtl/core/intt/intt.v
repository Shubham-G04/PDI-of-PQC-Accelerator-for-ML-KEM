// ============================================================================
// File: intt.v
// Module: intt
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
//
// 256-point inverse NTT over Z_3329, Gentleman-Sande decimation-in-frequency.
// Adapted for synchronous-read ntt_memory (SRAM/BRAM inference).
//
// The scaling phase now runs 2 cycles per coefficient:
//   cycle 0: present read address
//   cycle 1: read data available, multiply, write back
//
// Reset convention: `reset` is SYNCHRONOUS ACTIVE HIGH, matching
// intt_scheduler. Wrappers are responsible for inverting picosoc's resetn.
// ============================================================================

`timescale 1ns/1ps

module intt (

    input  wire        clk,
    input  wire        reset,

    input  wire        start,

    // Polynomial loading interface (accepted while the core is idle).
    input  wire        load_we,
    input  wire [7:0]  load_addr,
    input  wire [12:0] load_data,

    // Result read interface (valid one cycle after result_addr presented).
    input  wire [7:0]  result_addr,
    output wire [12:0] result_data,

    // Status.
    output wire        busy,
    output wire        done
);

    localparam [12:0] N_INV = 13'd3303;   // 128^-1 mod 3329

    // ------------------------------------------------------------------
    // Scheduler
    // ------------------------------------------------------------------
    reg         sched_start;

    wire        schedule_busy;
    wire        schedule_done;
    wire        schedule_valid;

    wire [7:0]  a_addr;
    wire [7:0]  b_addr;
    wire [6:0]  zeta_addr;

    intt_scheduler scheduler_inst (
        .clk            (clk),
        .reset          (reset),
        .start          (sched_start),
        .schedule_busy  (schedule_busy),
        .schedule_done  (schedule_done),
        .schedule_valid (schedule_valid),
        .a_addr         (a_addr),
        .b_addr         (b_addr),
        .zeta_addr      (zeta_addr)
    );

    // ------------------------------------------------------------------
    // Top-level control FSM
    //
    //   IDLE -> BUTTERFLY -> SCALE_RD -> SCALE_WR -> ... -> DONE_PULSE -> IDLE
    // ------------------------------------------------------------------
    localparam [2:0] ST_IDLE     = 3'd0;
    localparam [2:0] ST_BFLY     = 3'd1;
    localparam [2:0] ST_SCALE_RD = 3'd2;   // present read address
    localparam [2:0] ST_SCALE_WR = 3'd3;   // data ready, multiply, write
    localparam [2:0] ST_DONE     = 3'd4;

    reg [2:0] state;
    reg [8:0] scale_idx;
    reg       done_reg;

    wire scaling_rd = (state == ST_SCALE_RD);
    wire scaling_wr = (state == ST_SCALE_WR);
    wire scaling    = scaling_rd | scaling_wr;

    assign busy = (state != ST_IDLE);
    assign done = done_reg;

    always @(posedge clk) begin
        if (reset) begin
            state       <= ST_IDLE;
            scale_idx   <= 9'd0;
            sched_start <= 1'b0;
            done_reg    <= 1'b0;
        end
        else begin
            done_reg <= 1'b0;

            case (state)

                ST_IDLE: begin
                    sched_start <= 1'b0;
                    if (start) begin
                        sched_start <= 1'b1;
                        state       <= ST_BFLY;
                    end
                end

                ST_BFLY: begin
                    sched_start <= 1'b0;
                    if (schedule_done) begin
                        scale_idx <= 9'd0;
                        state     <= ST_SCALE_RD;
                    end
                end

                // Present read address for scale_idx
                ST_SCALE_RD: begin
                    state <= ST_SCALE_WR;
                end

                // Data available from sync read. Multiply and write back.
                ST_SCALE_WR: begin
                    if (scale_idx == 9'd255) begin
                        state    <= ST_DONE;
                        done_reg <= 1'b1;
                    end
                    else begin
                        scale_idx <= scale_idx + 9'd1;
                        state     <= ST_SCALE_RD;
                    end
                end

                ST_DONE: begin
                    if (!start)
                        state <= ST_IDLE;
                end

                default: state <= ST_IDLE;

            endcase
        end
    end

    // ------------------------------------------------------------------
    // Zeta ROM  (INTT table)
    // ------------------------------------------------------------------
    wire [12:0] zeta;

    intt_zetas_rom zeta_rom_inst (
        .addr (zeta_addr),
        .zeta (zeta)
    );

    // ------------------------------------------------------------------
    // Butterfly
    // ------------------------------------------------------------------
    wire [12:0] a_data;
    wire [12:0] b_data;
    wire [12:0] a_result;
    wire [12:0] b_result;

    intt_butterfly butterfly_inst (
        .a      (a_data),
        .b      (b_data),
        .zeta   (zeta),
        .a_out  (a_result),
        .b_out  (b_result)
    );

    // ------------------------------------------------------------------
    // Final scaling multiplier: coeff * 3303 mod q
    // ------------------------------------------------------------------
    wire [12:0] scaled_data;

    mod_mult scale_mult (
        .a      (a_data),
        .b      (N_INV),
        .result (scaled_data)
    );

    // ------------------------------------------------------------------
    // Polynomial memory
    //
    // Read addresses are registered inside ntt_memory (sync read).
    // Data appears 1 cycle after the address is presented.
    //
    // Port A:
    //   butterfly phase : a_addr (scheduler drives during PHASE0 and PHASE1)
    //   scaling phase   : scale_idx
    //   idle            : result_addr (host read-back)
    //
    // Write port A:
    //   butterfly phase : a_addr  <- a_result  (when schedule_valid)
    //   scaling phase   : scale_idx <- scaled_data (during ST_SCALE_WR)
    //   idle            : load_addr <- load_data (host load)
    //
    // Write port B: butterfly phase only.
    // ------------------------------------------------------------------
    ntt_memory memory_inst (
        .clk      (clk),

        .raddr_a  (schedule_busy    ? a_addr         :
                   scaling          ? scale_idx[7:0] :
                                      result_addr),
        .rdata_a  (a_data),

        .raddr_b  (b_addr),
        .rdata_b  (b_data),

        .we_a     (schedule_valid  |
                   scaling_wr      |
                   (load_we & ~busy)),

        .waddr_a  (schedule_valid  ? a_addr         :
                   scaling_wr      ? scale_idx[7:0] :
                                     load_addr),

        .wdata_a  (schedule_valid  ? a_result       :
                   scaling_wr      ? scaled_data    :
                                     load_data),

        .we_b     (schedule_valid),
        .waddr_b  (b_addr),
        .wdata_b  (b_result)
    );

    // ------------------------------------------------------------------
    // Result output
    // ------------------------------------------------------------------
    assign result_data = a_data;

endmodule
