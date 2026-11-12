#!/bin/bash
cd /home/volmarr/aesir-team-08 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{ echo "=== A-040 team gate E-MASTER run (gfx1151, 6 shims) ==="; date -Is; hostname; git rev-parse HEAD; git branch --show-current; } > hidden_files/a040_run_all.log 2>&1
staging=$(mktemp -d); echo staging=$staging >> hidden_files/a040_run_all.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a040_run_all.log 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a040_run_all.log 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> hidden_files/a040_run_all.log 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> hidden_files/a040_run_all.log 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> hidden_files/a040_run_all.log 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" -ldl >> hidden_files/a040_run_all.log 2>&1
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/tests/run_all.mojo >> hidden_files/a040_run_all.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a040_run_all.log
echo "=== end $(date -Is) ===" >> hidden_files/a040_run_all.log
echo DONE > hidden_files/a040_suite_done.txt
