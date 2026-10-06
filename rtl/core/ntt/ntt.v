// ============================================================================
// File: ntt.v
// Module: ntt
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Description: Forward NTT engine. Uses synchronous-read ntt_memory for SRAM
//              inference on ASIC (Genus) and BRAM on FPGA. Each read has a
//              1-cycle latency, so WAIT states follow READ address setup.
// ============================================================================

`timescale 1ns/1ps

module ntt (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire        inverse,

    output wire        busy,
    output wire        done,

    input  wire        mem_we,
    input  wire [7:0]  mem_addr,
    input  wire [12:0] mem_wdata,
    output wire [12:0] mem_rdata
);

    // States
    localparam STATE_IDLE    = 3'd0;
    localparam STATE_READ_A  = 3'd1;   // drive address j
    localparam STATE_WAIT_A  = 3'd2;   // latch mem[j]
    localparam STATE_READ_B  = 3'd3;   // drive address j+len
    localparam STATE_WAIT_B  = 3'd4;   // latch mem[j+len]
    localparam STATE_CALC    = 3'd5;   // butterfly combinational
    localparam STATE_WRITE_A = 3'd6;
    localparam STATE_WRITE_B = 3'd7;

    reg [2:0] state;

    reg [7:0] len;
    reg [7:0] start_addr;
    reg [7:0] j;
    reg [6:0] zeta_addr;
    reg [12:0] a_reg;
    reg [12:0] b_reg;
    reg inverse_reg;

    reg        mem_we_int;
    reg [7:0]  mem_addr_int;
    reg [12:0] mem_wdata_int;

    reg busy_reg;
    reg done_reg;

    assign busy = busy_reg;
    assign done = done_reg;

    wire external_mem_access = !busy_reg;

    wire        memory_we    = busy_reg ? mem_we_int    : (external_mem_access ? mem_we : 1'b0);
    wire [7:0]  memory_addr  = busy_reg ? mem_addr_int  : mem_addr;
    wire [12:0] memory_wdata = busy_reg ? mem_wdata_int : mem_wdata;
    wire [12:0] memory_rdata;

    ntt_memory memory_inst (
        .clk     (clk),
        .raddr_a (memory_addr),
        .rdata_a (memory_rdata),
        .raddr_b (8'd0),
        .rdata_b (),
        .we_a    (memory_we),
        .waddr_a (memory_addr),
        .wdata_a (memory_wdata),
        .we_b    (1'b0),
        .waddr_b (8'd0),
        .wdata_b (13'd0)
    );

    assign mem_rdata = memory_rdata;

    // Zeta ROM
    wire [12:0] zeta;

    ntt_zetas_rom zeta_rom (
        .addr (zeta_addr),
        .zeta (zeta)
    );

    // Butterfly
    wire [12:0] butterfly_a_out;
    wire [12:0] butterfly_b_out;

    ntt_butterfly butterfly_inst (
        .a      (a_reg),
        .b      (b_reg),
        .zeta   (zeta),
        .a_out  (butterfly_a_out),
        .b_out  (butterfly_b_out)
    );

    // Memory control
    always @(*) begin
        mem_we_int    = 1'b0;
        mem_addr_int  = 8'd0;
        mem_wdata_int = 13'd0;

        case (state)
            STATE_READ_A: mem_addr_int = j;
            STATE_WAIT_A: mem_addr_int = j;              // hold address for capture
            STATE_READ_B: mem_addr_int = j + len;
            STATE_WAIT_B: mem_addr_int = j + len;
            STATE_CALC:   mem_addr_int = j;              // don't care
            STATE_WRITE_A: begin
                mem_we_int    = 1'b1;
                mem_addr_int  = j;
                mem_wdata_int = butterfly_a_out;
            end
            STATE_WRITE_B: begin
                mem_we_int    = 1'b1;
                mem_addr_int  = j + len;
                mem_wdata_int = butterfly_b_out;
            end
            default: begin
                mem_we_int    = 1'b0;
                mem_addr_int  = 8'd0;
                mem_wdata_int = 13'd0;
            end
        endcase
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= STATE_IDLE;
            len         <= 8'd0;
            start_addr  <= 8'd0;
            j           <= 8'd0;
            zeta_addr   <= 7'd0;
            a_reg       <= 13'd0;
            b_reg       <= 13'd0;
            inverse_reg <= 1'b0;
            busy_reg    <= 1'b0;
            done_reg    <= 1'b0;
        end
        else begin
            done_reg <= 1'b0;

            case (state)

                STATE_IDLE: begin
                    busy_reg <= 1'b0;
                    if (start && !inverse) begin
                        busy_reg    <= 1'b1;
                        inverse_reg <= 1'b0;
                        len        <= 8'd128;
                        start_addr <= 8'd0;
                        j          <= 8'd0;
                        zeta_addr  <= 7'd1;
                        state      <= STATE_READ_A;
                    end
                end

                // Drive addr = j, data appears next cycle
                STATE_READ_A: begin
                    state <= STATE_WAIT_A;
                end

                // Capture mem[j]
                STATE_WAIT_A: begin
                    a_reg <= memory_rdata;
                    state <= STATE_READ_B;
                end

                // Drive addr = j+len, data appears next cycle
                STATE_READ_B: begin
                    state <= STATE_WAIT_B;
                end

                // Capture mem[j+len]
                STATE_WAIT_B: begin
                    b_reg <= memory_rdata;
                    state <= STATE_CALC;
                end

                // Butterfly is combinational, results ready
                STATE_CALC: begin
                    state <= STATE_WRITE_A;
                end

                STATE_WRITE_A: begin
                    state <= STATE_WRITE_B;
                end

                STATE_WRITE_B: begin
                    if (j != start_addr + len - 1) begin
                        j     <= j + 1'b1;
                        state <= STATE_READ_A;
                    end
                    else begin
                        if ({1'b0, start_addr} + ({1'b0, len} << 1) < 9'd256) begin
                            start_addr <= start_addr + (len << 1);
                            j          <= start_addr + (len << 1);
                            zeta_addr  <= zeta_addr + 1'b1;
                            state      <= STATE_READ_A;
                        end
                        else begin
                            if (len > 8'd2) begin
                                len        <= len >> 1;
                                start_addr <= 8'd0;
                                j          <= 8'd0;
                                zeta_addr  <= zeta_addr + 1'b1;
                                state      <= STATE_READ_A;
                            end
                            else begin
                                busy_reg <= 1'b0;
                                done_reg <= 1'b1;
                                state    <= STATE_IDLE;
                            end
                        end
                    end
                end

                default: begin
                    state    <= STATE_IDLE;
                    busy_reg <= 1'b0;
                end

            endcase
        end
    end

endmodule
