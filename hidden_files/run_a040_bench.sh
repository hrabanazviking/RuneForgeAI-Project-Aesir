#!/bin/bash
cd /home/volmarr/aesir-team-08 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
TAG=$1; LOG=hidden_files/a040_bench_${TAG}.log
{ date -Is; hostname; git rev-parse HEAD; uptime; } > $LOG 2>&1
staging=$(mktemp -d)
for spec in "hailo10h_stub.c libaesir_hailo10h" "thread_par.c libaesir_par" "hip_memory_shim.c libaesir_hip" "zero_copy_shim.c libaesir_zc" "affinity_shim.c libaesir_aff"; do set -- $spec; cc -std=c11 -O2 -fPIC -shared aesir_engine/$1 -o "$staging/$2.so" -ldl -lpthread >> $LOG 2>&1; done
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> $LOG 2>&1
pixi run --frozen mojo build -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff -o /tmp/a040_bench_$TAG aesir_engine/tests/bench_k_gemv_a040.mojo >> $LOG 2>&1
echo BUILD_EXIT=$? >> $LOG
LD_LIBRARY_PATH=$staging /tmp/a040_bench_$TAG >> $LOG 2>&1
echo RUN_EXIT=$? >> $LOG; uptime >> $LOG; echo DONE > hidden_files/a040_bench_${TAG}_done.txt
