#!/bin/bash
cd /home/volmarr/aesir-team-27 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
LOG=hidden_files/a124_run_all_rerun2.log
{ echo "=== A-124 E-MASTER rerun2 (team-27) ==="; date -Is; hostname; git rev-parse HEAD; git branch --show-current; mojo --version 2>&1; } > $LOG 2>&1
staging=$(mktemp -d); echo "staging=$staging" >> $LOG
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> $LOG 2>&1; echo "stub_cc_exit=$?" >> $LOG
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> $LOG 2>&1; echo "par_cc_exit=$?" >> $LOG
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> $LOG 2>&1; echo "hip_cc_exit=$?" >> $LOG
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> $LOG 2>&1; echo "zc_cc_exit=$?" >> $LOG
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" >> $LOG 2>&1; echo "aff_cc_exit=$?" >> $LOG
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/tests/run_all.mojo >> $LOG 2>&1
echo "MOJO_EXIT=$?" >> $LOG
echo "=== end $(date -Is) ===" >> $LOG
