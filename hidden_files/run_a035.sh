#!/bin/bash
# A-035 timed gate runs (team-06, purpleraider, 2026-11-12).
# Runs both one-command gates in sequence, each timed, logs in
# hidden_files/. Copies of the matrix suite logs are kept per tier
# (build_matrix overwrites them between tiers).
cd /home/volmarr/aesir-team-06 || exit 99
{
echo "=== A-035 gate runs ==="; date -Is; hostname; uname -a
git rev-parse HEAD; git branch --show-current
} > hidden_files/a035_gates.log 2>&1
s=$(date +%s)
scripts/gate_fast.sh > hidden_files/a035_gate_fast.log 2>&1
echo "GATE_FAST_EXIT=$?" >> hidden_files/a035_gate_fast.log
e=$(date +%s); echo "fast_wall_s=$((e-s))" >> hidden_files/a035_gates.log
cp hidden_files/build_matrix_cpu.log hidden_files/a035_fast_suite.log
s=$(date +%s)
scripts/gate_full.sh > hidden_files/a035_gate_full.log 2>&1
echo "GATE_FULL_EXIT=$?" >> hidden_files/a035_gate_full.log
e=$(date +%s); echo "full_wall_s=$((e-s))" >> hidden_files/a035_gates.log
cp hidden_files/build_matrix_cpu.log hidden_files/a035_full_cpu_suite.log
cp hidden_files/build_matrix_amd.log hidden_files/a035_full_amd_suite.log
echo "=== end $(date -Is) ===" >> hidden_files/a035_gates.log
cat hidden_files/a035_gates.log
grep -h "RESULT" hidden_files/a035_gate_fast.log hidden_files/a035_gate_full.log
