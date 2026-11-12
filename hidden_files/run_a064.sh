#!/bin/bash
# A-064 runner (team-04): canonical E-MASTER shape per run_a061.sh --
# shims staged into a mktemp dir, -L$staging on the link line.
cd /home/volmarr/aesir-team-04 || exit 99
export PATH=/home/volmarr/.pixi/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
{
echo "=== A-064 gate E-MASTER run (team-04) ==="
date -Is; hostname; git rev-parse HEAD; git branch --show-current
} > hidden_files/a064_gate.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a064_gate.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a064_gate.log 2>&1; echo "stub_cc=$?" >> hidden_files/a064_gate.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a064_gate.log 2>&1; echo "par_cc=$?" >> hidden_files/a064_gate.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> hidden_files/a064_gate.log 2>&1; echo "hip_cc=$?" >> hidden_files/a064_gate.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> hidden_files/a064_gate.log 2>&1; echo "vk_cc=$?" >> hidden_files/a064_gate.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> hidden_files/a064_gate.log 2>&1; echo "zc_cc=$?" >> hidden_files/a064_gate.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" >> hidden_files/a064_gate.log 2>&1; echo "aff_cc=$?" >> hidden_files/a064_gate.log
pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/tests/run_all.mojo >> hidden_files/a064_gate.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a064_gate.log
echo "=== end ===" >> hidden_files/a064_gate.log
