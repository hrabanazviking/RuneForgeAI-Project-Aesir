#!/bin/bash
# A-034 deterministic replay battery driver: build once, run the
# battery TWICE as separate processes, diff full outputs, file hashes.
cd /home/volmarr/aesir-team-02 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-034 replay battery ==="
date -Is; hostname; uname -a
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
} > hidden_files/a034_battery.log 2>&1
# A-034 fix (restart lead): stage the 6 native shims and link them, exactly as the E-MASTER gate scripts do -- the original build line linked nothing, so aesir_par_*/aesir_cpu_vnni were undefined at link time.
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a034_battery.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a034_battery.log 2>&1; echo "hailo_cc_exit=$?" >> hidden_files/a034_battery.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a034_battery.log 2>&1; echo "par_cc_exit=$?" >> hidden_files/a034_battery.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> hidden_files/a034_battery.log 2>&1; echo "hip_cc_exit=$?" >> hidden_files/a034_battery.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> hidden_files/a034_battery.log 2>&1; echo "vulkan_cc_exit=$?" >> hidden_files/a034_battery.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> hidden_files/a034_battery.log 2>&1; echo "zc_cc_exit=$?" >> hidden_files/a034_battery.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" -ldl >> hidden_files/a034_battery.log 2>&1; echo "aff_cc_exit=$?" >> hidden_files/a034_battery.log
export LD_LIBRARY_PATH="$staging"
pixi run --frozen mojo build -I aesir_engine -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/tests/replay_a034.mojo -o hidden_files/replay_a034 >> hidden_files/a034_battery.log 2>&1
echo "BUILD_EXIT=$?" >> hidden_files/a034_battery.log
./hidden_files/replay_a034 hidden_files/fixtures/stories260K.F16.gguf > hidden_files/a034_run1.log 2>&1
echo "RUN1_EXIT=$?" >> hidden_files/a034_battery.log
./hidden_files/replay_a034 hidden_files/fixtures/stories260K.F16.gguf > hidden_files/a034_run2.log 2>&1
echo "RUN2_EXIT=$?" >> hidden_files/a034_battery.log
diff hidden_files/a034_run1.log hidden_files/a034_run2.log >> hidden_files/a034_battery.log 2>&1
echo "DIFF_EXIT=$?" >> hidden_files/a034_battery.log
sha256sum hidden_files/a034_run1.log hidden_files/a034_run2.log >> hidden_files/a034_battery.log
grep -h 'A034_.*HASH\|A034_REPLAY' hidden_files/a034_run1.log >> hidden_files/a034_battery.log
echo "=== end $(date -Is) ===" >> hidden_files/a034_battery.log
echo DONE > hidden_files/a034_battery_done.txt
