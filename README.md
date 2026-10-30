# Asynchronous FIFO for Clock Domain Crossing (Verilog)

A parameterized dual-clock FIFO that safely moves data between two unrelated clock domains, using Gray-code pointers and 2-flip-flop synchronizers. Verified with a self-checking Verilog testbench across different clock ratios.

## Why this matters

In real FPGA designs, different blocks often run on different clocks (e.g. a 100 MHz processor and a 37 MHz camera interface). Passing multi-bit data directly between them causes **metastability** and corrupted values. An async FIFO is the standard, safe way to cross clock domains.

## Architecture

```
   Write clock domain (wclk)                    Read clock domain (rclk)
 ┌────────────────────────────┐              ┌────────────────────────────┐
 │  wptr_full                 │   wptr (Gray)│  rptr_empty                │
 │  - binary + Gray pointer   │──► sync_2ff ─►  - binary + Gray pointer   │
 │  - FULL flag               │              │  - EMPTY flag              │
 │                            │ ◄─ sync_2ff ◄──                           │
 └──────────┬─────────────────┘   rptr (Gray)└──────────┬─────────────────┘
            │ waddr, wen                                │ raddr
            ▼                                           ▼
        ┌──────────────────────────────────────────────────┐
        │        fifo_mem  (dual-port RAM, 2^ADDR words)    │
        │   wdata ──► write on wclk     read ──► rdata       │
        └──────────────────────────────────────────────────┘
```

| File | Purpose |
|------|---------|
| `rtl/async_fifo.v` | Top level, connects everything |
| `rtl/fifo_mem.v`   | Dual-port memory |
| `rtl/wptr_full.v`  | Write pointer + FULL flag (write domain) |
| `rtl/rptr_empty.v` | Read pointer + EMPTY flag (read domain) |
| `rtl/sync_2ff.v`   | 2-flip-flop synchronizer |
| `tb/tb_async_fifo.v` | Self-checking testbench |

**Parameters:** `DATA_WIDTH` (default 8), `ADDR_WIDTH` (default 4 → depth 16).

## Key design ideas

- **Gray-code pointers:** only one bit changes per increment, so the synchronizer can never capture a half-updated pointer.
- **Extra pointer bit:** pointers are `ADDR_WIDTH+1` bits. Equal address bits + equal MSB = **empty**; equal address bits + different MSB = **full**.
- **FULL in Gray code:** next write pointer equals the synchronized read pointer with its top **two** bits inverted.
- **Pessimistic flags:** because the other side's pointer arrives 2 cycles late, full/empty may stay set slightly longer than necessary, but they are never wrong. No overflow or underflow is possible.

## Verification

The testbench has a write agent, a read agent, and a **scoreboard** (reference queue). Every accepted write is pushed into the queue; every accepted read is compared against it.

| # | Test | Checks |
|---|------|--------|
| 1 | Reset | empty = 1, full = 0 |
| 2 | Fill until full | exactly 16 writes accepted, extra writes ignored |
| 3 | Drain until empty | data in order, extra reads ignored, full clears |
| 4 | Random traffic, 100 MHz write / 37 MHz read | 2000 transactions, all data correct |
| 5 | Random traffic, 29 MHz write / 125 MHz read | 2000 transactions, all data correct |

```
Test 4: random traffic, wclk 100 MHz, rclk ~37 MHz
  PASS : all written data was read back correctly
Test 5: random traffic, wclk ~29 MHz, rclk 125 MHz
  PASS : all written data was read back correctly
=========================================
  ALL TESTS PASSED
=========================================
```

<!-- Add your GTKWave screenshot here: ![waveform](docs/waveform.png) -->

## How to run (macOS / Linux)

Requires [Icarus Verilog](https://github.com/steveicarus/iverilog) and GTKWave (both in the OSS CAD Suite, or `brew install icarus-verilog`).

```bash
make          # compile + run all tests
make wave     # open waveforms in GTKWave
make synth    # resource report with Yosys (optional)
make clean
```

## Possible extensions

- Almost-full / almost-empty flags
- Registered (synchronous) read output for block RAM inference
- Fill-level counters on each side
