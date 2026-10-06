// ============================================================================
// File: intt_scheduler.v
// Module: intt_scheduler
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Description: INTT address scheduler. Runs Gentleman-Sande butterfly
//              addressing for 7 stages (len = 2,4,8,...,128), 128 blocks
//              per stage, with 2 cycles per butterfly for synchronous memory.
//              Phase 0: present addresses. Phase 1: data is ready, write back.
// ============================================================================

`timescale 1ns/1ps

module intt_scheduler (

    input  wire        clk,
    input  wire        reset,
    input  wire        start,

    output reg         schedule_busy,
    output reg         schedule_done,
    output reg         schedule_valid,   // high on phase 1 (write-back)

    output reg [7:0]   a_addr,
    output reg [7:0]   b_addr,

    output reg [6:0]   zeta_addr
);

    reg [7:0] len;
    reg [7:0] block_start;
    reg [7:0] j;

    localparam IDLE  = 2'd0;
    localparam PHASE0 = 2'd1;   // present addresses, wait for sync read
    localparam PHASE1 = 2'd2;   // data ready, do write-back + advance
    localparam DONE  = 2'd3;

    reg [1:0] state;

    // Combinational address generation
    always @(*) begin
        a_addr = block_start + j;
        b_addr = block_start + j + len;
    end

    always @(posedge clk) begin
        if (reset) begin
            state          <= IDLE;
            schedule_busy  <= 1'b0;
            schedule_done  <= 1'b0;
            schedule_valid <= 1'b0;
            len            <= 8'd2;
            block_start    <= 8'd0;
            j              <= 8'd0;
            zeta_addr      <= 7'd127;
        end
        else begin
            case (state)

                IDLE: begin
                    schedule_busy  <= 1'b0;
                    schedule_done  <= 1'b0;
                    schedule_valid <= 1'b0;
                    if (start) begin
                        state          <= PHASE0;
                        schedule_busy  <= 1'b1;
                        schedule_valid <= 1'b0;
                        len            <= 8'd2;
                        block_start    <= 8'd0;
                        j              <= 8'd0;
                        zeta_addr      <= 7'd127;
                    end
                end

                // Phase 0: addresses are presented, memory reads are
                // registered inside ntt_memory and will be available
                // on the next posedge.
                PHASE0: begin
                    schedule_valid <= 1'b0;
                    state          <= PHASE1;
                end

                // Phase 1: memory read data is now valid. The butterfly
                // output is combinationally ready. Assert schedule_valid
                // so intt.v writes the results, then advance the schedule.
                PHASE1: begin
                    schedule_valid <= 1'b1;

                    if (j < (len - 1'b1)) begin
                        j     <= j + 1'b1;
                        state <= PHASE0;
                    end
                    else begin
                        j <= 8'd0;
                        if (({1'b0, block_start} + ({1'b0, len} << 1)) < 9'd256) begin
                            block_start <= block_start + (len << 1);
                            zeta_addr   <= zeta_addr - 1'b1;
                            state       <= PHASE0;
                        end
                        else begin
                            if (len == 8'd128) begin
                                state          <= DONE;
                                schedule_busy  <= 1'b0;
                                schedule_done  <= 1'b1;
                                schedule_valid <= 1'b0;
                            end
                            else begin
                                len         <= len << 1;
                                block_start <= 8'd0;
                                zeta_addr   <= zeta_addr - 1'b1;
                                state       <= PHASE0;
                            end
                        end
                    end
                end

                DONE: begin
                    schedule_busy  <= 1'b0;
                    schedule_done  <= 1'b1;
                    schedule_valid <= 1'b0;
                    if (!start) begin
                        state         <= IDLE;
                        schedule_done <= 1'b0;
                    end
                end

                default: begin
                    state          <= IDLE;
                    schedule_busy  <= 1'b0;
                    schedule_done  <= 1'b0;
                    schedule_valid <= 1'b0;
                    len            <= 8'd2;
                    block_start    <= 8'd0;
                    j              <= 8'd0;
                    zeta_addr      <= 7'd127;
                end

            endcase
        end
    end

endmodule
