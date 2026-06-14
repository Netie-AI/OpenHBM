#!/usr/bin/env bash
set -eu
export PATH="/tmp/oss-cad-suite/bin:${PATH:-}"
export PYTHONUNBUFFERED=1
cd "$(dirname "$0")"
source /mnt/c/Users/oojia/OpenHBM/.venv/bin/activate
make SIM=verilator "COCOTB_TEST_FILTER=${1}" 2>&1 | tail -30
