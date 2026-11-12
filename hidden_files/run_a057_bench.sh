#!/bin/bash
# A-057 bench runner (team-08): build the standalone Vulkan Q4_K GEMV
# bench with all 6 shims staged, run it on the RADV device.
cd /home/volmarr/aesir-team-08 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
LOG=hidden_files/a057_bench.log
{
date -Is; hostname; git rev-parse HEAD; git branch --show-current; uptime
} > $LOG 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> $LOG
for spec in "hailo10h_stub.c libaesir_hailo10h" "thread_par.c libaesir_par" "hip_memory_shim.c libaesir_hip" "zero_copy_shim.c libaesir_zc" "affinity_shim.c libaesir_aff"; do set -- $spec; cc -std=c11 -O2 -fPIC -shared aesir_engine/$1 -o "$staging/$2.so" -ldl -lpthread >> $LOG 2>&1; echo "cc_$2=$?" >> $LOG; done
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> $LOG 2>&1; echo "cc_vulkan=$?" >> $LOG
/usr/bin/time -v pixi run --frozen mojo build -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff -o /tmp/a057_bench aesir_engine/tests/bench_vulkan_q4k_gemv_a057.mojo >> $LOG 2>&1
echo "BUILD_EXIT=$?" >> $LOG
/usr/bin/time -v env LD_LIBRARY_PATH=$staging /tmp/a057_bench >> $LOG 2>&1
echo "RUN_EXIT=$?" >> $LOG
echo DONE > hidden_files/a057_bench_done.txt
