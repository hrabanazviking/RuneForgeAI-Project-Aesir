#!/bin/bash
# A-049 bench runner (team-08): pin the oversized fixture sha256
# before/after, build the standalone bench with all 6 shims staged,
# run it against the 43 GB fixture.
cd /home/volmarr/aesir-team-08 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
LOG=hidden_files/a049_bench.log
FIXTURE=hidden_files/fixtures/oversized_a049.gguf
{
date -Is; hostname; git rev-parse HEAD; git branch --show-current; uptime
echo "=== fixture sha256 BEFORE ==="
sha256sum hidden_files/fixtures/stories260K.F16.gguf "$FIXTURE"
df -h /home | tail -1; free -g | head -2
} > $LOG 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> $LOG
for spec in "hailo10h_stub.c libaesir_hailo10h" "thread_par.c libaesir_par" "hip_memory_shim.c libaesir_hip" "zero_copy_shim.c libaesir_zc" "affinity_shim.c libaesir_aff"; do set -- $spec; cc -std=c11 -O2 -fPIC -shared aesir_engine/$1 -o "$staging/$2.so" -ldl -lpthread >> $LOG 2>&1; echo "cc_$2=$?" >> $LOG; done
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> $LOG 2>&1; echo "cc_vulkan=$?" >> $LOG
/usr/bin/time -v pixi run --frozen mojo build -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff -o /tmp/a049_bench aesir_engine/tests/bench_oversized_streaming_a049.mojo >> $LOG 2>&1
echo "BUILD_EXIT=$?" >> $LOG
/usr/bin/time -v env LD_LIBRARY_PATH=$staging /tmp/a049_bench "$FIXTURE" >> $LOG 2>&1
echo "RUN_EXIT=$?" >> $LOG
{
echo "=== fixture sha256 AFTER ==="
sha256sum hidden_files/fixtures/stories260K.F16.gguf "$FIXTURE"
uptime
} >> $LOG 2>&1
echo DONE > hidden_files/a049_bench_done.txt
