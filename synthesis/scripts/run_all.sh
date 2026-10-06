#!/bin/bash
# ============================================================================
# run_all.sh -- full layered verification ladder for the ML-KEM PicoRV32 project
#
#   Requires only Icarus Verilog (iverilog / vvp). No RISC-V toolchain,
#   no C compiler, no Python at simulation time.
#
#   Usage:  ./run_all.sh
# ============================================================================
set -u
RTL="rtl"
CORE=$(ls $RTL/*.v | grep -v -E "picorv32.v|picosoc.v|simpleuart.v|spimemio.v")
ALL=$(ls $RTL/*.v)
mkdir -p build
pass=0; fail=0

run () {  # run <name> <top> <sources...>
    local name=$1; shift
    local top=$1;  shift
    printf "\n>>> %s\n" "$name"
    if ! iverilog -g2012 -o build/$top.out -s $top "$@" 2>build/$top.log; then
        echo "    COMPILE ERROR"; cat build/$top.log; fail=$((fail+1)); return
    fi
    out=$(timeout 3600 vvp build/$top.out 2>&1)
    echo "$out"
    if echo "$out" | grep -q "FAILED\|COMPILE ERROR"; then fail=$((fail+1));
    elif echo "$out" | grep -q "PASSED";            then pass=$((pass+1));
    else fail=$((fail+1)); echo "    NO VERDICT"; fi
}

echo "############################################################"
echo "#  ML-KEM-512 / PicoRV32  -- LAYERED VERIFICATION"
echo "############################################################"

# B. arithmetic primitives and butterflies
run "B. Arithmetic primitives + butterflies" tb_arith_butterfly \
    sim/tb_arith_butterfly.v $RTL/mod_add.v $RTL/mod_sub.v $RTL/mod_mult.v \
    $RTL/mod_reduce_3329.v $RTL/ntt_butterfly.v $RTL/intt_butterfly.v

# E. zeta ROMs
run "E. Zeta ROMs (derived expectations)" tb_zetas_rom \
    sim/tb_zetas_rom.v $RTL/ntt_zetas_rom.v $RTL/intt_zetas_rom.v

# D. INTT scheduler sequence
run "D. INTT scheduler sequence" tb_intt_scheduler \
    sim/tb_intt_scheduler.v $RTL/intt_scheduler.v

# G. NTT/INTT round trip on the address-mapped cores
run "G1. NTT/INTT round trip (core)" tb_ntt_intt_roundtrip \
    sim/tb_ntt_intt_roundtrip.v $CORE

# G2. round trip through the flat adapters
run "G2. NTT/INTT round trip (flat adapters)" tb_flat_roundtrip \
    sim/tb_flat_roundtrip.v $CORE

# B2. pointwise basemul vs golden model
run "B2. Pointwise basemul vs golden" tb_poly_mul_pointwise \
    sim/tb_poly_mul_pointwise.v $RTL/poly_mul_pointwise.v $RTL/mod_mult.v \
    $RTL/mod_add.v $RTL/mod_reduce_3329.v

# F. hashing and sampling chain
run "F. Keccak / SHAKE-128 / SampleNTT" tb_hash_chain \
    sim/tb_hash_chain.v $RTL/keccak_f1600.v $RTL/shake128_xof.v \
    $RTL/poly_uniform.v $RTL/rejection_sampler.v

# H. ML-KEM core subsystem
run "H. ML-KEM core subsystem (direct)" tb_mlkem_core \
    sim/tb_mlkem_core.v $CORE

# J. processor-driven end to end
run "J. FINAL end-to-end (PicoRV32 driven)" tb_mlkem_e2e \
    sim/tb_mlkem_e2e.v $ALL

# K. SoC demonstration: testbench supplies stimulus, CPU runs ML-KEM
run "K. SoC DEMO (testbench-supplied messages)" tb_mlkem_soc_demo \
    sim/tb_mlkem_soc_demo.v $ALL

echo ""
echo "############################################################"
echo "#  SUMMARY:  $pass passed, $fail failed"
echo "############################################################"
[ $fail -eq 0 ] || exit 1
