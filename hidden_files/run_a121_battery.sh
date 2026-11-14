#!/bin/bash
cd /home/volmarr/aesir-team-27 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
LOG=hidden_files/a121_battery.log
{ echo "=== A-121 MoE battery run (team-27) ==="; date -Is; hostname; git rev-parse HEAD; git branch --show-current; mojo --version 2>&1; } > $LOG 2>&1
pixi run --frozen mojo run -I . --target-accelerator gfx1151 aesir_engine/tests/bench_moe_battery_a121.mojo >> $LOG 2>&1
echo "MOJO_EXIT=$?" >> $LOG
echo "=== end $(date -Is) ===" >> $LOG
