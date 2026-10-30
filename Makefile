# Async FIFO - simulation with Icarus Verilog
#   make        -> compile and run the testbench
#   make wave   -> open the waveform in GTKWave
#   make clean  -> remove generated files

RTL = rtl/sync_2ff.v rtl/fifo_mem.v rtl/wptr_full.v rtl/rptr_empty.v rtl/async_fifo.v
TB  = tb/tb_async_fifo.v

sim:
	mkdir -p build
	iverilog -g2005 -Wall -o build/tb.out $(RTL) $(TB)
	cd build && vvp tb.out

wave:
	gtkwave build/async_fifo.vcd &

synth:
	yosys -p "read_verilog $(RTL); synth -top async_fifo; stat"

clean:
	rm -rf build

.PHONY: sim wave synth clean
