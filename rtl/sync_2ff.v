`timescale 1ns/1ps
// =============================================================================
// sync_2ff.v  -  Two flip-flop synchronizer
// -----------------------------------------------------------------------------
// The first flop may go metastable when its input changes near the clock edge.
// The second flop gives it a full clock period to settle, so the output is
// stable. Safe here because the input is a Gray-code pointer (1 bit changes
// at a time), so we can never capture a "mix" of old and new values.
// =============================================================================
module sync_2ff #(
    parameter WIDTH = 5
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);

    reg [WIDTH-1:0] q1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= {WIDTH{1'b0}};
            q  <= {WIDTH{1'b0}};
        end else begin
            q1 <= d;
            q  <= q1;
        end
    end

endmodule
