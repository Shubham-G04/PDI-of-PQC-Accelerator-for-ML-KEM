// ============================================================================
// File: ntt_memory.v
// Module: ntt_memory
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
// Description: True dual-port synchronous memory (256x13). Synchronous reads
//              infer SRAM on ASIC (Genus) and BRAM on FPGA (Vivado).
// ============================================================================

`timescale 1ns/1ps

module ntt_memory (

    input  wire        clk,

    // Read port A
    input  wire [7:0]  raddr_a,
    output reg  [12:0] rdata_a,

    // Read port B
    input  wire [7:0]  raddr_b,
    output reg  [12:0] rdata_b,

    // Write port A
    input  wire        we_a,
    input  wire [7:0]  waddr_a,
    input  wire [12:0] wdata_a,

    // Write port B
    input  wire        we_b,
    input  wire [7:0]  waddr_b,
    input  wire [12:0] wdata_b
);

    reg [12:0] mem [0:255];

    // Synchronous read + write, read-first behaviour
    always @(posedge clk) begin
        rdata_a <= mem[raddr_a];
        if (we_a)
            mem[waddr_a] <= wdata_a;
    end

    always @(posedge clk) begin
        rdata_b <= mem[raddr_b];
        if (we_b)
            mem[waddr_b] <= wdata_b;
    end

endmodule
