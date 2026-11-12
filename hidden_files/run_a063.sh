#!/bin/bash
# A-063 gate driver (team-03, 2026-11-12): canonical E-MASTER shape
# per run_a061.sh / run_seat_gate_a062.sh -- shims staged manually
# (NO build_shaders.py run: the seat pipeline artefacts are the
# committed ones), ONE merged libaesir_vulkan.so from both Vulkan
# shims. Run detached: the device invoke node caps at ~125 s while
# the suite takes ~3-4 min.
cd /home/volmarr/aesir-team-03 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-063 E-MASTER run (Vulkan sampling) ==="
date -Is; hostname; uname -a
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
} > hidden_files/a063_run_all.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a063_run_all.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a063_run_all.log 2>&1
echo "stub_cc_exit=$?" >> hidden_files/a063_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a063_run_all.log 2>&1
echo "par_cc_exit=$?" >> hidden_files/a063_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> hidden_files/a063_run_all.log 2>&1
echo "hip_cc_exit=$?" >> hidden_files/a063_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> hidden_files/a063_run_all.log 2>&1
echo "vulkan_cc_exit=$?" >> hidden_files/a063_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> hidden_files/a063_run_all.log 2>&1
echo "zc_cc_exit=$?" >> hidden_files/a063_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" >> hidden_files/a063_run_all.log 2>&1
echo "aff_cc_exit=$?" >> hidden_files/a063_run_all.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/tests/run_all.mojo >> hidden_files/a063_run_all.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a063_run_all.log
echo "=== end $(date -Is) ===" >> hidden_files/a063_run_all.log
