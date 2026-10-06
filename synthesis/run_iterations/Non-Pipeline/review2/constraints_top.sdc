# ==============================================================================
# File: constraints_top.sdc
# Design: mlkem_picosoc_top
# Library: GPDK 45nm slow corner
# Target: 100 MHz (10 ns period)
# ==============================================================================

# ------------------------------------------------------------------------------
# Clock definition: 100 MHz, 50% duty cycle
# ------------------------------------------------------------------------------
create_clock -name clk -period 10 -waveform {0 5} [get_ports "clk"]

# Clock network properties (scaled for 45nm)
set_clock_transition -rise 0.05 [get_clocks "clk"]
set_clock_transition -fall 0.05 [get_clocks "clk"]
set_clock_uncertainty 0.1 [get_clocks "clk"]

# ------------------------------------------------------------------------------
# Async reset: false path
# resetn is asynchronous and not launched/captured by clk.
# Without this, Genus traces reset fanout through every flop in the
# design and reports an impossibly long timing path.
# ------------------------------------------------------------------------------
set_false_path -from [get_ports "resetn"]

# ------------------------------------------------------------------------------
# Input delays (relative to clk)
# ------------------------------------------------------------------------------
set_input_delay -max 1.0 [get_ports "ser_rx"]       -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "flash_io0_di"] -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "flash_io1_di"] -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "flash_io2_di"] -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "flash_io3_di"] -clock [get_clocks "clk"]

# ------------------------------------------------------------------------------
# Output delays (relative to clk)
# ------------------------------------------------------------------------------
set_output_delay -max 1.0 [get_ports "ser_tx"]       -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_csb"]    -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_clk"]    -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_io0_oe"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_io1_oe"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_io2_oe"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_io3_oe"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_io0_do"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_io1_do"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_io2_do"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "flash_io3_do"] -clock [get_clocks "clk"]
