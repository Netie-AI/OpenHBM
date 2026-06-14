#!/usr/bin/env bash
# Mutation sim wrapper for MCY ($SCRIPTS, $PRJDIR set by mcy).
set -euo pipefail
bash "$SCRIPTS/create_mutated.sh"
iverilog -g2012 -Wall -o sim_task \
  mutated.v \
  "$PRJDIR/../../../rtl/ecc_pkg.sv" \
  "$PRJDIR/../../../rtl/gf_tables.inc.sv" \
  "$PRJDIR/../../../rtl/ecc_encode.sv" \
  "$PRJDIR/../../../rtl/ecc_decode.sv" \
  "$PRJDIR/../../../rtl/ecc.sv" \
  "$PRJDIR/stim_ecc.sv"
if vvp sim_task | tee sim_task.log | grep -q "PASS: stim_ecc"; then
  echo "1 PASS" > output.txt
else
  echo "1 FAIL" > output.txt
fi
