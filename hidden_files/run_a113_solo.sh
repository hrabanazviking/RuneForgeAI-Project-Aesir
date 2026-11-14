#!/bin/bash
cd /home/volmarr/aesir-team-26 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
LOG=hidden_files/a113_solo_vault.log
{ echo "=== A-113 SOLO state_vault_rejects_growth re-run (team-26) ==="; date -Is; hostname; git rev-parse HEAD; git branch --show-current; mojo --version 2>&1; } > $LOG 2>&1
staging=$(mktemp -d); echo "staging=$staging" >> $LOG
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" >> $LOG 2>&1
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/tests/solo_a113_vault.mojo >> $LOG 2>&1
echo "MOJO_EXIT=$?" >> $LOG
echo "=== end $(date -Is) ===" >> $LOG
