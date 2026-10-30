`timescale 1ns/1ps
// =============================================================================
// fifo_mem.v  -  Dual-port memory (write on wclk, asynchronous read)
// -----------------------------------------------------------------------------
// Synthesis tools map this to distributed RAM (LUT RAM) on an FPGA.
// =============================================================================
module fifo_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wclk,
    input  wire                  wen,
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire [ADDR_WIDTH-1:0] raddr,
    output wire [DATA_WIDTH-1:0] rdata
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge wclk) begin
        if (wen)
            mem[waddr] <= wdata;
    end

    assign rdata = mem[raddr];

endmodule
