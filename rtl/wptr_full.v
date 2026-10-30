`timescale 1ns/1ps
// =============================================================================
// wptr_full.v  -  Write pointer logic and FULL flag (write clock domain)
// -----------------------------------------------------------------------------
// FULL condition (Gray code): the next write pointer equals the synchronized
// read pointer with its TWO most significant bits inverted.
//   - MSB differs  -> writer has wrapped around once more than the reader
//   - 2nd MSB      -> must also be inverted because of how Gray code mirrors
//   - other bits   -> equal
// =============================================================================
module wptr_full #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                wclk,
    input  wire                wrst_n,
    input  wire                winc,
    input  wire [ADDR_WIDTH:0] wq2_rptr,
    output reg                 wfull,
    output wire [ADDR_WIDTH-1:0] waddr,
    output reg  [ADDR_WIDTH:0] wptr       // Gray code
);

    reg  [ADDR_WIDTH:0] wbin;             // binary pointer
    wire [ADDR_WIDTH:0] wbin_next;
    wire [ADDR_WIDTH:0] wgray_next;
    wire                wfull_next;

    assign wbin_next  = wbin + {{ADDR_WIDTH{1'b0}}, (winc & ~wfull)};
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;      // binary -> Gray
    assign waddr      = wbin[ADDR_WIDTH-1:0];

    assign wfull_next = (wgray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1],
                                         wq2_rptr[ADDR_WIDTH-2:0]});

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin  <= {(ADDR_WIDTH+1){1'b0}};
            wptr  <= {(ADDR_WIDTH+1){1'b0}};
            wfull <= 1'b0;
        end else begin
            wbin  <= wbin_next;
            wptr  <= wgray_next;
            wfull <= wfull_next;
        end
    end

endmodule
