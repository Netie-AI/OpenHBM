#!/usr/bin/env bash
set -euo pipefail
bash "$SCRIPTS/create_mutated.sh"
iverilog -g2012 -Wall -o sim_task \
  mutated.v \
  "$PRJDIR/../../../rtl/addr_map_pkg.sv" \
  "$PRJDIR/stim_addr_map_xor.sv"
if vvp sim_task | tee sim_task.log | grep -q "PASS: stim_addr_map_xor"; then
  echo "1 PASS" > output.txt
else
  echo "1 FAIL" > output.txt
fi
