#!/bin/bash
cd /home/volmarr/aesir-team-27 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
LOG=hidden_files/a106_bench.log
{
date -Is; hostname; git rev-parse HEAD; git branch --show-current; uptime
echo "=== external observation BEFORE (shell) ==="
cat /sys/class/drm/card1/device/gpu_busy_percent
cat /sys/class/drm/card1/device/mem_info_gtt_used
cat /sys/class/drm/card1/device/mem_info_vram_used
timeout 30 xrt-smi examine 2>&1 | head -20
rocminfo 2>/dev/null | grep -m2 -i 'Name:\|gfx'
df -h /home | tail -1; free -g | head -2
} > $LOG 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> $LOG
for spec in "hailo10h_stub.c libaesir_hailo10h" "thread_par.c libaesir_par" "hip_memory_shim.c libaesir_hip" "zero_copy_shim.c libaesir_zc" "affinity_shim.c libaesir_aff"; do set -- $spec; cc -std=c11 -O2 -fPIC -shared aesir_engine/$1 -o "$staging/$2.so" -ldl -lpthread >> $LOG 2>&1; echo "cc_$2=$?" >> $LOG; done
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> $LOG 2>&1; echo "cc_vulkan=$?" >> $LOG
/usr/bin/time -v pixi run --frozen mojo build -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff -o /tmp/a106_bench aesir_engine/tests/bench_telemetry_a106.mojo >> $LOG 2>&1
echo "BUILD_EXIT=$?" >> $LOG
/usr/bin/time -v env LD_LIBRARY_PATH=$staging /tmp/a106_bench >> $LOG 2>&1
echo "RUN_EXIT=$?" >> $LOG
{
echo "=== external observation AFTER (shell) ==="
cat /sys/class/drm/card1/device/gpu_busy_percent
cat /sys/class/drm/card1/device/mem_info_gtt_used
uptime
} >> $LOG 2>&1
echo DONE > hidden_files/a106_bench_done.txt
