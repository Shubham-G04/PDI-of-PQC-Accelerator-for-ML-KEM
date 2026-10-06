###############################################################################
# run_syn_100mhz.tcl -- Test 1 Synthesis Script (PicoRV32 Full SoC @ 100 MHz)
#
# Design : Full SoC (PicoRV32 RISC-V + PicoSoC + 2-Stage Pipelined ML-KEM)
# Target : GPDK 45nm, 100 MHz (10.0 ns)
# Features:
#   - Hierarchy Preservation (PicoRV32 visible in gui_show)
#   - Checkpointing (write_db checkpoints/01_elaborated.db ... 04_syn_opt.db)
#
# Run in Genus:
#   genus -files run_syn_100mhz.tcl -log genus_test1_100mhz.log
###############################################################################

file mkdir reports/picosoc_100mhz outputs/picosoc_100mhz checkpoints

# ------------------------------------------------------------------
# 1. SETUP & LIBRARY
# ------------------------------------------------------------------
set_db library /home/install/FOUNDRY/digital/90nm/dig/lib/slow.lib

set_db hdl_track_filename_row_col true
set_db hdl_preserve_unused_registers true
set_db auto_ungroup none

# ------------------------------------------------------------------
# 2. READ RTL FILES IN MANDATORY ORDER (picosoc.v BEFORE picorv32.v)
# ------------------------------------------------------------------
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
# 3. ELABORATE TOP DESIGN & PRESERVE PICORV32 HIERARCHY
# ------------------------------------------------------------------
elaborate mlkem_picosoc_top
current_design mlkem_picosoc_top

set_db [get_db modules picorv32] .preserve true
set_db [get_db modules picosoc] .preserve true
set_db [get_db modules mlkem_peripheral] .preserve true
set_db [get_db modules mlkem_top] .preserve true

# ------------------------------------------------------------------
# 4. READ CONSTRAINTS & CHECKPOINT 1
# ------------------------------------------------------------------
read_sdc constraints_100mhz.sdc

puts "\n [CHECKPOINT 1] Saving Post-Elaboration Database..."
write_db -all_root_attributes checkpoints/01_elaborated.db

# ------------------------------------------------------------------
# 5. SYNTHESIS & CHECKPOINTS 2-4
# ------------------------------------------------------------------
puts "\n Starting Generic Synthesis (syn_generic)..."
set_db syn_generic_effort medium
syn_generic

puts "\n [CHECKPOINT 2] Saving Post-Generic Synthesis Database..."
write_db -all_root_attributes checkpoints/02_syn_generic.db

puts "\n Starting Technology Mapping (syn_map)..."
set_db syn_map_effort medium
syn_map

puts "\n [CHECKPOINT 3] Saving Post-Mapping Database..."
write_db -all_root_attributes checkpoints/03_syn_map.db

puts "\n Starting Incremental Optimization (syn_opt)..."
set_db syn_opt_effort medium
syn_opt -incremental

puts "\n [CHECKPOINT 4] Saving Post-Optimization Final Database..."
write_db -all_root_attributes checkpoints/04_syn_opt.db

# ------------------------------------------------------------------
# 6. REPORTS & OUTPUTS
# ------------------------------------------------------------------
report_timing -max_paths 20 > reports/picosoc_100mhz/timing.rpt
report_area                 > reports/picosoc_100mhz/area.rpt
report_gates                > reports/picosoc_100mhz/gates.rpt
report_power                > reports/picosoc_100mhz/power.rpt
report_hierarchy            > reports/picosoc_100mhz/hierarchy.rpt

write_hdl > outputs/picosoc_100mhz/mlkem_picosoc_top_synth.v
write_sdc > outputs/picosoc_100mhz/mlkem_picosoc_top_synth.sdc

puts "\n====================================================="
puts " TEST 1 (100 MHz Full SoC) SYNTHESIS COMPLETE"
puts " Reports : reports/picosoc_100mhz/"
puts " Checkpoints : checkpoints/"
puts "====================================================="

gui_show
