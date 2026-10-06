###############################################################################
# syn.tcl  --  Genus DFT flow for mlkem_picosoc_top (tsmc18 180nm)
#
# Design : ML-KEM-512 accelerator + PicoRV32 SoC
# Top    : mlkem_picosoc_top
# Process: tsmc 180nm
# Target : 100 MHz (10 ns)
#
# Run:   genus -f syn.tcl -log genus_dft
#
# NOTE: always run in a FRESH genus session. Re-sourcing into a live
#       session hits DFT-134 because define_test_clock cannot claim
#       clk twice.
###############################################################################

file mkdir reports outputs

#------------------------------------------------------------------
# 1. SETUP
#------------------------------------------------------------------
set_db library /home/install/FOUNDRY/digital/90nm/dig/lib/slow.lib

# map DFT violations back to source line numbers
set_db hdl_track_filename_row_col true

# don't let the mapper use scan flops as ordinary functional flops
set_db use_scan_seqs_for_non_dft false

#------------------------------------------------------------------
# 2. READ RTL + ELABORATE
#------------------------------------------------------------------
# CRITICAL: picosoc.v MUST be read before picorv32.v.
# picosoc.v defines the `PICORV32_REGS macro as picosoc_regs.
# If picorv32.v is read first, it uses its own internal register
# file containing an initial block that Genus would warn about.

read_hdl { \
    picosoc.v        \
    picorv32.v       \
    simpleuart.v     \
    spimemio.v       \
    mlkem_picosoc_top.v \
    mlkem_peripheral.v  \
    mlkem_top.v         \
    mlkem_keygen.v      \
    mlkem_enc.v         \
    mlkem_dec.v         \
    mlkem_matrix_gen.v  \
    matrix_vec_mul.v    \
    ntt.v               \
    ntt_flat.v          \
    ntt_butterfly.v     \
    ntt_memory.v        \
    ntt_zetas_rom.v     \
    intt.v              \
    intt_flat.v         \
    intt_butterfly.v    \
    intt_scheduler.v    \
    intt_zetas_rom.v    \
    keccak_f1600.v      \
    shake128_xof.v      \
    poly_mul_pointwise.v \
    poly_add.v          \
    poly_sub.v          \
    poly_compress.v     \
    poly_decompress.v   \
    poly_encode.v       \
    poly_decode.v       \
    poly_uniform.v      \
    rejection_sampler.v \
    cbd_sampler.v       \
    mod_add.v           \
    mod_sub.v           \
    mod_mult.v          \
    mod_mult_top.v      \
    mod_reduce_3329.v   \
}

elaborate mlkem_picosoc_top
current_design mlkem_picosoc_top

check_design -unresolved
check_design -undriven        > reports/undriven.rpt
check_design -multiple_driver > reports/multidriver.rpt

read_sdc mlkem_picosoc_top.sdc

#------------------------------------------------------------------
# 3. DFT SETUP  (must be BEFORE syn_generic)
#------------------------------------------------------------------
set_db dft_scan_style muxed_scan
set_db dft_prefix     DFT_

set_db dft_identify_top_level_test_clocks true
set_db dft_identify_test_signals          true
set_db dft_identify_internal_test_clocks  false

set_db [current_design] .dft_scan_map_mode                        tdrc_pass
set_db [current_design] .dft_scan_output_preference               auto
set_db [current_design] .dft_connect_scan_data_pins_during_mapping loopback
set_db [current_design] .dft_connect_shift_enable_during_mapping   tie_off

# --- test signals -------------------------------------------------
# -period is in PICOSECONDS.  Shift clock at 20 ns (50 MHz).
define_test_clock   -name test_clk -period 20000 [get_ports clk]
define_shift_enable -name se -active high -create_port scan_en
define_test_mode    -name tm -active high -create_port test_mode

# --- async reset control ------------------------------------------
# 14 ML-KEM sub-blocks use async active-low reset (negedge rst_n).
# resetn at the top feeds all of them through mlkem_peripheral.
# During scan shift resetn must be held high (inactive) so the
# async reset does not corrupt the scan chain state.
# fix_dft_violations below handles this, but we also tell Genus
# that resetn is under test_mode control.

#------------------------------------------------------------------
# 4. DFT RULE CHECK (pre-synthesis)
#------------------------------------------------------------------
check_dft_rules

report_dft_violations > reports/dft_violations_pre.rpt
report_scan_registers > reports/scan_registers_pre.rpt
report_scan_setup     > reports/scan_setup_pre.rpt

#------------------------------------------------------------------
# 5. FIX DFT VIOLATIONS
#------------------------------------------------------------------
# -async_reset : mux resetn with test_mode so it stays inactive
#                during shift (covers all 14 async-reset modules)
# -async_set   : same treatment for any set lines
# -clock       : fix gated-clock violations if any
# -test_control: gate through the tm port
fix_dft_violations -async_set -async_reset -clock -test_control tm
report_dft_violations > reports/dft_violations_fixed.rpt

#------------------------------------------------------------------
# 6. SYNTHESIZE
#------------------------------------------------------------------
set_db syn_generic_effort medium
syn_generic

check_dft_rules
report_dft_violations > reports/dft_violations_generic.rpt

set_db syn_map_effort medium
syn_map

check_dft_rules -advanced
report_dft_violations > reports/dft_violations_map.rpt
report_scan_registers > reports/scan_registers_map.rpt

#------------------------------------------------------------------
# 7. SCAN CHAIN CONFIGURATION + PREVIEW
#------------------------------------------------------------------
# Expected flop count is large (~40k+) because picosoc_mem,
# picosoc_regs and ntt_memory all flatten to register arrays
# at 180nm (no SRAM macros).
#
#   8 chains x ~5000 flops = manageable chain lengths
#   Adjust if scan_registers_map.rpt shows a different count.

set_db [current_design] .dft_min_number_of_scan_chains 8
set_db [current_design] .dft_max_length_of_scan_chains 6000
set_db [current_design] .dft_mix_clock_edges_in_scan_chains true
set_db [current_design] .dft_lockup_element_type preferred_level_sensitive

# connect_scan_chains does NOT support ">" redirection.
# Use the redirect command instead.
redirect reports/scan_preview.rpt {connect_scan_chains -preview -auto_create_chains}

#------------------------------------------------------------------
# 8. CONNECT CHAINS  --  ONE PASS ONLY for muxed scan
#------------------------------------------------------------------
connect_scan_chains -auto_create_chains

report_scan_chains > reports/scan_chains.rpt
report_scan_setup  > reports/scan_setup_final.rpt

#------------------------------------------------------------------
# 9. INCREMENTAL OPT
#------------------------------------------------------------------
set_db syn_opt_effort medium
syn_opt -incremental

report_timing -max_paths 20 > reports/timing.rpt
report_area                 > reports/area.rpt
report_gates                > reports/gates.rpt
report_power                > reports/power.rpt

#------------------------------------------------------------------
# 10. EXPORT
#------------------------------------------------------------------
write_hdl                             > outputs/mlkem_picosoc_top_scan.v
write_sdc                             > outputs/mlkem_picosoc_top_scan.sdc
write_scandef                         > outputs/mlkem_picosoc_top.scandef
write_script -analyze_all_scan_chains > outputs/mlkem_picosoc_top_chains.tcl

puts "\n====================================================="
puts " DFT DONE -- mlkem_picosoc_top"
puts " Netlist : outputs/mlkem_picosoc_top_scan.v"
puts " SDC     : outputs/mlkem_picosoc_top_scan.sdc"
puts " SCANDEF : outputs/mlkem_picosoc_top.scandef"
puts " Chains  : reports/scan_chains.rpt"
puts "====================================================="
