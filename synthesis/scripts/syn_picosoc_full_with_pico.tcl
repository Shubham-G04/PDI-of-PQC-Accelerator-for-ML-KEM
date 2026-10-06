###############################################################################
# syn_picosoc_full_with_pico.tcl (With Checkpointing)
# Cadence Genus Synthesis Script for Full SoC (PicoRV32 + PicoSoC + ML-KEM)
#
# Features:
#   - PRESERVES HIERARCHY so PicoRV32 appears clearly in GUI schematic (`gui_show`)
#   - SAVES DATABASE CHECKPOINTS (`write_db`) after each major synthesis step:
#       1. checkpoints/01_elaborated.db
#       2. checkpoints/02_syn_generic.db
#       3. checkpoints/03_syn_map.db
#       4. checkpoints/04_syn_opt.db
#
# Target : GPDK 45nm (slow.lib), 100 MHz (10 ns)
# Top    : mlkem_picosoc_top
#
# Run in Genus:
#   genus -files syn_picosoc_full_with_pico.tcl -log genus_pico_full.log
###############################################################################

file mkdir reports/picosoc_full outputs/picosoc_full checkpoints

# ------------------------------------------------------------------
# 1. TECHNOLOGY LIBRARY (GPDK 45nm)
# ------------------------------------------------------------------
set_db library /home/install/FOUNDRY/digital/45nm/dig/lib/slow.lib

# ------------------------------------------------------------------
# 2. HIERARCHY PRESERVATION & TRACKING SETTINGS
# ------------------------------------------------------------------
set_db hdl_track_filename_row_col true
set_db hdl_preserve_unused_registers true

# Prevent Genus from dissolving/ungrouping modules into a flat netlist
set_db auto_ungroup none

# ------------------------------------------------------------------
# 3. READ RTL FILES IN STRICT MANDATORY ORDER
# ------------------------------------------------------------------
# CRITICAL: picosoc.v MUST be read BEFORE picorv32.v.
# picosoc.v defines `PICORV32_REGS macro as picosoc_regs.
read_hdl -v2001 { \
    rtl/picosoc.v            \
    rtl/picorv32.v           \
    rtl/simpleuart.v         \
    rtl/spimemio.v           \
    rtl/mlkem_picosoc_top.v   \
    rtl/mlkem_peripheral.v    \
    rtl/mlkem_top.v           \
    rtl/mlkem_keygen.v        \
    rtl/mlkem_enc.v           \
    rtl/mlkem_dec.v           \
    rtl/mlkem_matrix_gen.v    \
    rtl/matrix_vec_mul.v      \
    rtl/ntt.v                 \
    rtl/ntt_flat.v            \
    rtl/ntt_butterfly.v       \
    rtl/ntt_memory.v          \
    rtl/ntt_zetas_rom.v       \
    rtl/intt.v                \
    rtl/intt_flat.v           \
    rtl/intt_butterfly.v      \
    rtl/intt_scheduler.v      \
    rtl/intt_zetas_rom.v      \
    rtl/keccak_f1600.v        \
    rtl/shake128_xof.v        \
    rtl/poly_mul_pointwise.v  \
    rtl/poly_add.v            \
    rtl/poly_sub.v            \
    rtl/poly_compress.v       \
    rtl/poly_decompress.v     \
    rtl/poly_encode.v         \
    rtl/poly_decode.v         \
    rtl/poly_uniform.v        \
    rtl/rejection_sampler.v   \
    rtl/cbd_sampler.v         \
    rtl/mod_add.v             \
    rtl/mod_sub.v             \
    rtl/mod_mult.v            \
    rtl/mod_mult_top.v        \
    rtl/mod_reduce_3329.v     \
}

# ------------------------------------------------------------------
# 4. ELABORATE TOP SOC DESIGN
# ------------------------------------------------------------------
elaborate mlkem_picosoc_top
current_design mlkem_picosoc_top

# ------------------------------------------------------------------
# 5. PRESERVE PICORV32 & SOC MODULE BOUNDARIES FOR SCHEMATIC VISUALIZATION
# ------------------------------------------------------------------
set_db [get_db modules picorv32] .preserve true
set_db [get_db modules picosoc] .preserve true
set_db [get_db modules mlkem_peripheral] .preserve true
set_db [get_db modules mlkem_top] .preserve true

# ------------------------------------------------------------------
# 6. READ SDC TIMING CONSTRAINTS & SAVE CHECKPOINT 1
# ------------------------------------------------------------------
read_sdc mlkem_picosoc_top.sdc

puts "\n [CHECKPOINT 1] Saving Elaborated Design Database..."
write_db -all_root_attributes checkpoints/01_elaborated.db

# ------------------------------------------------------------------
# 7. GENERIC SYNTHESIS & SAVE CHECKPOINT 2
# ------------------------------------------------------------------
puts "\n Starting Generic Synthesis (syn_generic)..."
set_db syn_generic_effort medium
syn_generic

puts "\n [CHECKPOINT 2] Saving Post-Generic Synthesis Database..."
write_db -all_root_attributes checkpoints/02_syn_generic.db

# ------------------------------------------------------------------
# 8. TECHNOLOGY MAPPING & SAVE CHECKPOINT 3
# ------------------------------------------------------------------
puts "\n Starting Technology Mapping (syn_map)..."
set_db syn_map_effort high
syn_map

puts "\n [CHECKPOINT 3] Saving Post-Technology Mapping Database..."
write_db -all_root_attributes checkpoints/03_syn_map.db

# ------------------------------------------------------------------
# 9. INCREMENTAL OPTIMIZATION & SAVE CHECKPOINT 4
# ------------------------------------------------------------------
puts "\n Starting Incremental Optimization (syn_opt)..."
set_db syn_opt_effort high
syn_opt -incremental

puts "\n [CHECKPOINT 4] Saving Post-Optimization Final Database..."
write_db -all_root_attributes checkpoints/04_syn_opt.db

# ------------------------------------------------------------------
# 10. GENERATE REPORTS
# ------------------------------------------------------------------
report_timing -max_paths 20 > reports/picosoc_full/timing.rpt
report_area                 > reports/picosoc_full/area.rpt
report_gates                > reports/picosoc_full/gates.rpt
report_power                > reports/picosoc_full/power.rpt
report_hierarchy            > reports/picosoc_full/hierarchy.rpt

# ------------------------------------------------------------------
# 11. WRITE NETLIST & SDC OUTPUTS
# ------------------------------------------------------------------
write_hdl > outputs/picosoc_full/mlkem_picosoc_top_synth.v
write_sdc > outputs/picosoc_full/mlkem_picosoc_top_synth.sdc

puts "\n====================================================="
puts " FULL SOC SYNTHESIS COMPLETE (PicoRV32 + ML-KEM)"
puts " Checkpoints saved in : checkpoints/"
puts " Reports stored in    : reports/picosoc_full/"
puts " Netlist              : outputs/picosoc_full/mlkem_picosoc_top_synth.v"
puts "====================================================="

# Launch GUI schematic viewer so PicoRV32 is visible
gui_show
