#!/bin/bash
# A-006 E-MASTER gate run for team-06 (canonical shape per run_a005.sh,
# plus A-006 Vulkan/SPIR-V evidence header: RADV device + toolchain).
cd /home/volmarr/aesir-team-06 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-006 E-MASTER run (team-06, Vulkan compute readiness) ==="
date -Is; hostname; uname -a
grep -m1 'model name' /proc/cpuinfo; nproc; free -g | head -n 2
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
echo "--- A-006 Vulkan/SPIR-V evidence ---"
vulkaninfo --summary 2>/dev/null | grep -E 'deviceName|driverName|vendorID|deviceID' | head -n 8
glslangValidator --version | head -n 1
spirv-val --version | head -n 1
dpkg-query -W -f='${Package} ${Version}\n' glslang-tools spirv-tools vulkan-tools libvulkan-dev mesa-vulkan-drivers
grep -E 'A006_PROBE_PASS|VERDICT' hidden_files/a006_probe.log
} > hidden_files/a006_run_all_canonical.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a006_run_all_canonical.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a006_run_all_canonical.log 2>&1
echo "stub_cc_exit=$?" >> hidden_files/a006_run_all_canonical.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a006_run_all_canonical.log 2>&1
echo "par_cc_exit=$?" >> hidden_files/a006_run_all_canonical.log
echo "=== mojo run (CPU, canonical sm_89 compile-target, CPU execution) start $(date -Is) ===" >> hidden_files/a006_run_all_canonical.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par aesir_engine/tests/run_all.mojo >> hidden_files/a006_run_all_canonical.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a006_run_all_canonical.log
echo "=== end $(date -Is) ===" >> hidden_files/a006_run_all_canonical.log
