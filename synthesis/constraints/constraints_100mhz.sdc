###############################################################################
# constraints_100mhz.sdc -- Test 1 Constraints (100 MHz Target)
#
# Target Frequency : 100 MHz
# Clock Period     : 10.0 ns
# Process Node     : GPDK 45nm
###############################################################################

# 1. Primary Clock Definition
create_clock -name sys_clk -period 10.0 -waveform {0 5.0} [get_ports clk]

# 2. Clock Transition & Uncertainty
set_clock_transition 0.1 [get_clocks sys_clk]
set_clock_uncertainty 0.01 [get_clocks sys_clk]

# 3. Asynchronous Reset False Path (Prevents unnecessary setup buffering on reset)
set_false_path -from [get_ports resetn]

# 4. Input & Output Delays
set_input_delay -max 1.0 -clock sys_clk [remove_from_collection [all_inputs] [get_ports {clk resetn}]]
set_output_delay -max 1.0 -clock sys_clk [all_outputs]

# 5. Drive and Load
set_input_transition 0.2 [all_inputs]
set_load 0.05 [all_outputs]
