#!/bin/bash
cd /home/volmarr/aesir-team-25 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
LOG=hidden_files/a115_policy.log
{ echo "=== A-115 policy bench (team-25) ==="; date -Is; hostname; git rev-parse HEAD; } > $LOG 2>&1
pixi run --frozen mojo run -I . --target-accelerator gfx1151 aesir_engine/tests/bench_policy_a115.mojo >> $LOG 2>&1
echo "MOJO_EXIT=$?" >> $LOG
