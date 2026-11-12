#!/bin/bash
# A-013 E-MASTER gate run for team-04 (canonical shape per run_a004.sh,
# extended with the A-013 Vulkan shim staging: libaesir_vulkan.so).
cd /home/volmarr/aesir-team-04 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-013 E-MASTER run (team-04, A-013 Vulkan context wrapper) ==="
date -Is; hostname; uname -a
grep -m1 'model name' /proc/cpuinfo; nproc; free -g | head -n 2
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
ls -l /usr/lib/x86_64-linux-gnu/libvulkan.so.1
cat /usr/share/vulkan/icd.d/radeon_icd.json
} > hidden_files/a013_run_all_canonical.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a013_run_all_canonical.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a013_run_all_canonical.log 2>&1
echo "stub_cc_exit=$?" >> hidden_files/a013_run_all_canonical.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a013_run_all_canonical.log 2>&1
echo "par_cc_exit=$?" >> hidden_files/a013_run_all_canonical.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> hidden_files/a013_run_all_canonical.log 2>&1
echo "vulkan_cc_exit=$?" >> hidden_files/a013_run_all_canonical.log
echo "=== mojo run (CPU compile target sm_89, CPU execution; Vulkan cases execute on the AMD iGPU via RADV) start $(date -Is) ===" >> hidden_files/a013_run_all_canonical.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_vulkan aesir_engine/tests/run_all.mojo >> hidden_files/a013_run_all_canonical.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a013_run_all_canonical.log
echo "=== end $(date -Is) ===" >> hidden_files/a013_run_all_canonical.log
