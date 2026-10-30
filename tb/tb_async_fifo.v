// =============================================================================
// tb_async_fifo.v  -  Self-checking testbench for async_fifo
// -----------------------------------------------------------------------------
// Structure (all plain Verilog):
//   * Write agent  : drives winc/wdata on the write clock
//   * Read agent   : drives rinc on the read clock
//   * Scoreboard   : a reference queue. Every accepted write is pushed,
//                    every accepted read is popped and compared with rdata.
//
// Tests
//   1. Reset values      (empty = 1, full = 0)
//   2. Fill until full   (exactly DEPTH writes accepted, extra writes ignored)
//   3. Drain until empty (data comes out in order, extra reads ignored)
//   4. Random traffic, fast writer / slow reader
//   5. Random traffic, slow writer / fast reader
// =============================================================================
`timescale 1ns/1ps

module tb_async_fifo;

    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;
    localparam DEPTH      = 1 << ADDR_WIDTH;
    localparam RANDOM_N   = 2000;           // transactions per random test

    // ------------------------------------------------------------------
    // Clocks (half periods can be changed between tests)
    // ------------------------------------------------------------------
    reg  wclk = 0, rclk = 0;
    real w_half = 5.0;                      // 100 MHz
    real r_half = 13.5;                     // ~37 MHz (unrelated to wclk)

    always #(w_half) wclk = ~wclk;
    always #(r_half) rclk = ~rclk;

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    reg                   wrst_n = 0, rrst_n = 0;
    reg                   winc = 0, rinc = 0;
    reg  [DATA_WIDTH-1:0] wdata = 0;
    wire [DATA_WIDTH-1:0] rdata;
    wire                  wfull, rempty;

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty)
    );

    // ------------------------------------------------------------------
    // Scoreboard: reference queue
    // ------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] model [0:1023];
    integer head = 0, tail = 0, count = 0;
    integer errors = 0;
    integer writes_done = 0, reads_done = 0;

    // ------------------------------------------------------------------
    // Agent controls
    // ------------------------------------------------------------------
    reg     wr_active = 0, rd_active = 0;
    integer wr_prob = 100, rd_prob = 100;   // % chance of a request per cycle
    integer wr_target = 0, rd_target = 0;

    // Write agent: change inputs on the falling edge (no race with DUT)
    always @(negedge wclk) begin
        if (wr_active && writes_done < wr_target && ($urandom % 100) < wr_prob) begin
            winc  <= 1'b1;
            wdata <= $urandom;
        end else begin
            winc  <= 1'b0;
        end
    end

    // Read agent
    always @(negedge rclk) begin
        if (rd_active && reads_done < rd_target && ($urandom % 100) < rd_prob)
            rinc <= 1'b1;
        else
            rinc <= 1'b0;
    end

    // Monitor: accepted write -> push into model
    always @(posedge wclk) begin
        if (wrst_n && winc && !wfull) begin
            model[tail] = wdata;
            tail        = (tail + 1) % 1024;
            count       = count + 1;
            writes_done = writes_done + 1;
            if (count > DEPTH) begin
                $display("[%0t] ERROR: overflow - %0d items in a %0d deep FIFO",
                         $time, count, DEPTH);
                errors = errors + 1;
            end
        end
    end

    // Monitor: accepted read -> pop from model and compare
    always @(posedge rclk) begin
        if (rrst_n && rinc && !rempty) begin
            if (count == 0) begin
                $display("[%0t] ERROR: underflow - read while model is empty", $time);
                errors = errors + 1;
            end else begin
                if (rdata !== model[head]) begin
                    $display("[%0t] ERROR: data mismatch, expected %h got %h",
                             $time, model[head], rdata);
                    errors = errors + 1;
                end
                head  = (head + 1) % 1024;
                count = count - 1;
            end
            reads_done = reads_done + 1;
        end
    end

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    task check;
        input        cond;
        input [8*60:1] msg;
        begin
            if (cond) $display("  PASS : %0s", msg);
            else begin
                $display("  FAIL : %0s", msg);
                errors = errors + 1;
            end
        end
    endtask

    task reset_all;
        begin
            wr_active = 0; rd_active = 0;
            wrst_n = 0; rrst_n = 0;
            repeat (3) @(posedge wclk);
            repeat (3) @(posedge rclk);
            head = 0; tail = 0; count = 0;
            writes_done = 0; reads_done = 0;
            wrst_n = 1; rrst_n = 1;
            repeat (3) @(posedge wclk);
            repeat (3) @(posedge rclk);
        end
    endtask

    task random_traffic;
        input integer wp;
        input integer rp;
        begin
            writes_done = 0; reads_done = 0;
            wr_target = RANDOM_N; rd_target = RANDOM_N;
            wr_prob = wp; rd_prob = rp;
            wr_active = 1; rd_active = 1;
            wait (reads_done == RANDOM_N);
            wr_active = 0; rd_active = 0;
            repeat (4) @(posedge rclk);
        end
    endtask

    // ------------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);

        $display("\n=== Async FIFO testbench (depth %0d) ===", DEPTH);

        // ---- Test 1: reset values
        $display("\nTest 1: reset values");
        reset_all;
        check(rempty == 1'b1, "FIFO is empty after reset");
        check(wfull  == 1'b0, "FIFO is not full after reset");

        // ---- Test 2: fill until full, then keep trying to write
        $display("\nTest 2: fill until full");
        wr_target = 100; wr_prob = 100; wr_active = 1;
        wait (wfull == 1'b1);
        repeat (10) @(posedge wclk);           // extra write attempts while full
        wr_active = 0;
        @(posedge wclk);
        check(writes_done == DEPTH, "exactly DEPTH writes accepted");
        check(wfull == 1'b1,        "full stays high, extra writes ignored");

        // ---- Test 3: drain until empty, then keep trying to read
        $display("\nTest 3: drain until empty");
        rd_target = 100; rd_prob = 100; rd_active = 1;
        wait (rempty == 1'b1);
        repeat (10) @(posedge rclk);           // extra read attempts while empty
        rd_active = 0;
        @(posedge rclk);
        check(reads_done == DEPTH, "exactly DEPTH reads accepted, in order");
        check(rempty == 1'b1,      "empty stays high, extra reads ignored");
        repeat (5) @(posedge wclk);
        check(wfull == 1'b0,       "full clears after draining");

        // ---- Test 4: fast writer (100 MHz) / slow reader (37 MHz)
        $display("\nTest 4: random traffic, wclk 100 MHz, rclk ~37 MHz");
        reset_all;
        random_traffic(80, 70);
        check(count == 0, "all written data was read back correctly");

        // ---- Test 5: slow writer / fast reader
        $display("\nTest 5: random traffic, wclk ~29 MHz, rclk 125 MHz");
        w_half = 17.0; r_half = 4.0;
        reset_all;
        random_traffic(70, 80);
        check(count == 0, "all written data was read back correctly");

        // ---- Summary
        $display("\n=========================================");
        if (errors == 0) $display("  ALL TESTS PASSED");
        else             $display("  TESTS FAILED: %0d error(s)", errors);
        $display("=========================================\n");
        $finish;
    end

    // Watchdog
    initial begin
        #5_000_000;
        $display("ERROR: timeout");
        $finish;
    end

endmodule
