`timescale 1ns/1ps
// =============================================================================
// async_fifo.v  -  Asynchronous (dual-clock) FIFO for Clock Domain Crossing
// -----------------------------------------------------------------------------
// * Write side runs on wclk, read side runs on rclk (clocks are unrelated).
// * Read/write pointers are kept in Gray code so that only ONE bit changes per
//   increment. That makes it safe to pass them across clock domains through a
//   2-flip-flop synchronizer.
// * Pointers are ADDR_WIDTH+1 bits wide. The extra MSB tells "full" apart from
//   "empty" when the address bits are equal.
// * full  is generated in the write domain, empty in the read domain.
//   Both are "pessimistic": they may stay asserted a couple of cycles longer
//   than strictly necessary, but they are never wrong (no overflow/underflow).
// =============================================================================
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4            // depth = 2**ADDR_WIDTH = 16
)(
    // write domain
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  winc,    // write request
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire                  wfull,

    // read domain
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rinc,    // read request
    output wire [DATA_WIDTH-1:0] rdata,
    output wire                  rempty
);

    wire [ADDR_WIDTH-1:0] waddr, raddr;
    wire [ADDR_WIDTH:0]   wptr,  rptr;        // Gray-coded pointers
    wire [ADDR_WIDTH:0]   wq2_rptr, rq2_wptr; // synchronized pointers

    // Read pointer -> write clock domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_r2w (
        .clk   (wclk),
        .rst_n (wrst_n),
        .d     (rptr),
        .q     (wq2_rptr)
    );

    // Write pointer -> read clock domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_w2r (
        .clk   (rclk),
        .rst_n (rrst_n),
        .d     (wptr),
        .q     (rq2_wptr)
    );

    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem (
        .wclk  (wclk),
        .wen   (winc & ~wfull),
        .waddr (waddr),
        .wdata (wdata),
        .raddr (raddr),
        .rdata (rdata)
    );

    wptr_full #(.ADDR_WIDTH(ADDR_WIDTH)) u_wptr_full (
        .wclk     (wclk),
        .wrst_n   (wrst_n),
        .winc     (winc),
        .wq2_rptr (wq2_rptr),
        .wfull    (wfull),
        .waddr    (waddr),
        .wptr     (wptr)
    );

    rptr_empty #(.ADDR_WIDTH(ADDR_WIDTH)) u_rptr_empty (
        .rclk     (rclk),
        .rrst_n   (rrst_n),
        .rinc     (rinc),
        .rq2_wptr (rq2_wptr),
        .rempty   (rempty),
        .raddr    (raddr),
        .rptr     (rptr)
    );

endmodule
