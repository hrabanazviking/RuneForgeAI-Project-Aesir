#!/bin/bash
cd /home/volmarr/aesir-team-27 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{ echo "=== A-117 local gate run (team-27) ==="; date -Is; hostname; git rev-parse HEAD; git branch --show-current; } > hidden_files/a117_gate_run.log 2>&1
scripts/gate_local.sh >> hidden_files/a117_gate_run.log 2>&1
echo "GATE_EXIT=$?" >> hidden_files/a117_gate_run.log
echo "=== end $(date -Is) ===" >> hidden_files/a117_gate_run.log
