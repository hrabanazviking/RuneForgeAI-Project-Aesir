#!/bin/bash
cd /home/volmarr/aesir-team-26 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
cp hidden_files/solo_a113_vault.mojo aesir_engine/tests/solo_vault_a126_tmp.mojo
LOG=hidden_files/a126_vault_solo.log
{ echo "=== A-126 solo vault intermittent check (driver: A-113 solo pattern) ==="; date -Is; } > $LOG 2>&1
staging=$(mktemp -d)
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" >> $LOG 2>&1
for i in 1 2 3; do echo "--- solo run $i ---" >> $LOG 2>&1; timeout 300 pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/tests/solo_vault_a126_tmp.mojo >> $LOG 2>&1; echo "SOLO_EXIT_$i=$?" >> $LOG; done
rm -f aesir_engine/tests/solo_vault_a126_tmp.mojo
echo "=== end $(date -Is) ===" >> $LOG
