#!/usr/bin/env bash
# Mutation sim wrapper for MCY ($SCRIPTS, $PRJDIR set by mcy).
set -euo pipefail
bash "$SCRIPTS/create_mutated.sh"
iverilog -g2012 -Wall -o sim_task \
  mutated.v \
  "$PRJDIR/../../../rtl/refresh_mgr_pkg.sv" \
  "$PRJDIR/stim_refresh.sv"
if vvp sim_task | tee sim_task.log | grep -q "PASS: stim_refresh"; then
  echo "1 PASS" > output.txt
else
  echo "1 FAIL" > output.txt
fi
