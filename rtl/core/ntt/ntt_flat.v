// ============================================================================
// File: ntt_flat.v
// Module: ntt_flat
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
//
// Adapter: flat 3072-bit polynomial interface to address-mapped ntt core.
// Adapted for synchronous-read ntt_memory. Unload phase is 2 cycles per
// coefficient (present addr, then capture data).
// ============================================================================

`timescale 1ns/1ps

module ntt_flat #(
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,

    input  wire [(N*12)-1:0]    poly_in,
    output wire [(N*12)-1:0]    poly_out,

    output reg                  busy,
    output reg                  done
);

    // Core instance
    reg         core_start;
    reg         core_we;
    reg  [7:0]  core_addr;
    reg  [12:0] core_wdata;
    wire [12:0] core_rdata;
    wire        core_busy;
    wire        core_done;

    ntt ntt_core (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (core_start),
        .inverse   (1'b0),
        .busy      (core_busy),
        .done      (core_done),
        .mem_we    (core_we),
        .mem_addr  (core_addr),
        .mem_wdata (core_wdata),
        .mem_rdata (core_rdata)
    );

    // Output holding registers
    reg [11:0] out_mem [0:N-1];

    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_out
            assign poly_out[gi*12 +: 12] = out_mem[gi];
        end
    endgenerate

    // Sequencer
    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_LOAD      = 3'd1;
    localparam [2:0] ST_KICK      = 3'd2;
    localparam [2:0] ST_RUN       = 3'd3;
    localparam [2:0] ST_UNL_ADDR  = 3'd4;   // present read address
    localparam [2:0] ST_UNL_CAPT  = 3'd5;   // capture sync read data
    localparam [2:0] ST_FIN       = 3'd6;

    reg [2:0] state;
    reg [8:0] idx;

    wire [11:0] load_lane = poly_in[idx[7:0]*12 +: 12];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            idx        <= 9'd0;
            busy       <= 1'b0;
            done       <= 1'b0;
            core_start <= 1'b0;
            core_we    <= 1'b0;
            core_addr  <= 8'd0;
            core_wdata <= 13'd0;
        end
        else begin
            done       <= 1'b0;
            core_start <= 1'b0;
            core_we    <= 1'b0;

            case (state)

                ST_IDLE: begin
                    if (start) begin
                        busy  <= 1'b1;
                        idx   <= 9'd0;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    core_we    <= 1'b1;
                    core_addr  <= idx[7:0];
                    core_wdata <= {1'b0, load_lane};

                    if (idx == 9'd255) begin
                        idx   <= 9'd0;
                        state <= ST_KICK;
                    end
                    else begin
                        idx <= idx + 9'd1;
                    end
                end

                ST_KICK: begin
                    core_start <= 1'b1;
                    state      <= ST_RUN;
                end

                ST_RUN: begin
                    if (core_done) begin
                        idx       <= 9'd0;
                        core_addr <= 8'd0;       // present first read addr
                        state     <= ST_UNL_ADDR;
                    end
                end

                // Present read address idx
                ST_UNL_ADDR: begin
                    core_addr <= idx[7:0];
                    state     <= ST_UNL_CAPT;
                end

                // Sync read data is now valid; capture it
                ST_UNL_CAPT: begin
                    out_mem[idx[7:0]] <= core_rdata[11:0];

                    if (idx == 9'd255) begin
                        busy  <= 1'b0;
                        done  <= 1'b1;
                        state <= ST_FIN;
                    end
                    else begin
                        idx       <= idx + 9'd1;
                        core_addr <= idx[7:0] + 8'd1;   // prefetch next
                        state     <= ST_UNL_ADDR;
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
