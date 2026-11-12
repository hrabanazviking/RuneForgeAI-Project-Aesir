#!/bin/bash
# A-062 gate driver (team-06, 2026-11-12): canonical E-MASTER suite via
# scripts/build_matrix.sh cpu entry (stages all shims incl. the merged
# libaesir_vulkan.so from vulkan_context_shim.c + vulkan_buffer_shim.c).
# Run detached: the device invoke node caps at ~125 s while the suite
# takes ~3-4 min. Final run: PASS, 465/1/2/468 (see A062_LEDGER.md).
cd /home/volmarr/aesir-team-06 || exit 99
nohup bash scripts/build_matrix.sh cpu > hidden_files/a062_gate.log 2>&1 &
echo "gate pid=$!"
