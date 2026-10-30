`timescale 1ns/1ps
// =============================================================================
// rptr_empty.v  -  Read pointer logic and EMPTY flag (read clock domain)
// -----------------------------------------------------------------------------
// EMPTY condition: the next read pointer equals the synchronized write
// pointer (all bits identical, including the wrap bit).
// =============================================================================
module rptr_empty #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                rclk,
    input  wire                rrst_n,
    input  wire                rinc,
    input  wire [ADDR_WIDTH:0] rq2_wptr,
    output reg                 rempty,
    output wire [ADDR_WIDTH-1:0] raddr,
    output reg  [ADDR_WIDTH:0] rptr       // Gray code
);

    reg  [ADDR_WIDTH:0] rbin;
    wire [ADDR_WIDTH:0] rbin_next;
    wire [ADDR_WIDTH:0] rgray_next;
    wire                rempty_next;

    assign rbin_next   = rbin + {{ADDR_WIDTH{1'b0}}, (rinc & ~rempty)};
    assign rgray_next  = (rbin_next >> 1) ^ rbin_next;
    assign raddr       = rbin[ADDR_WIDTH-1:0];
    assign rempty_next = (rgray_next == rq2_wptr);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= {(ADDR_WIDTH+1){1'b0}};
            rptr   <= {(ADDR_WIDTH+1){1'b0}};
            rempty <= 1'b1;                  // FIFO starts empty
        end else begin
            rbin   <= rbin_next;
            rptr   <= rgray_next;
            rempty <= rempty_next;
        end
    end

endmodule
