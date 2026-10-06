###############################################################################
# mlkem_picosoc_top.sdc
# SDC constraints for Genus synthesis -- tsmc 180nm, 100 MHz target
###############################################################################

# ---- Primary clock: 10 ns (100 MHz) on pad clk ----
create_clock -name sys_clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.3 [get_clocks sys_clk]
set_clock_transition  0.2 [get_clocks sys_clk]

# ---- Reset is asynchronous -- exclude from timing ----
set_false_path -from [get_ports resetn]

# ---- SPI flash interface (async to core) ----
# Outputs: launch from clk, assume 4 ns board flight time
set_output_delay -clock sys_clk -max 4.0 [get_ports {flash_csb flash_clk}]
set_output_delay -clock sys_clk -max 4.0 [get_ports {flash_io0_oe flash_io1_oe flash_io2_oe flash_io3_oe}]
set_output_delay -clock sys_clk -max 4.0 [get_ports {flash_io0_do flash_io1_do flash_io2_do flash_io3_do}]

# Inputs: data back from flash
set_input_delay  -clock sys_clk -max 4.0 [get_ports {flash_io0_di flash_io1_di flash_io2_di flash_io3_di}]

# ---- UART (async) ----
set_input_delay  -clock sys_clk -max 4.0 [get_ports ser_rx]
set_output_delay -clock sys_clk -max 4.0 [get_ports ser_tx]

# ---- General I/O defaults ----
set_input_transition  0.2 [all_inputs]
set_load 0.05 [all_outputs]

# ---- Max fanout for synthesis guidance ----
set_max_fanout 32 [current_design]
