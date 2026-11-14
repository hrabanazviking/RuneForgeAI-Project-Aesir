#!/bin/bash
# Seat gate after banking-A-121 (2026-11-12): canonical E-MASTER
# shape per run_a011.sh/run_a013.sh, unioned - HIP shim staged as
# libaesir_hip.so; ONE merged libaesir_vulkan.so from both Vulkan
# shims (convergence rename applied in the A-019 banking commit).
cd /home/volmarr/aesir-forge || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== Seat gate E-MASTER run (banking-A-121) ==="
date -Is; hostname; uname -a
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
} > hidden_files/seat_gate_a121.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/seat_gate_a121.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/seat_gate_a121.log 2>&1
echo "stub_cc_exit=$?" >> hidden_files/seat_gate_a121.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/seat_gate_a121.log 2>&1
echo "par_cc_exit=$?" >> hidden_files/seat_gate_a121.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> hidden_files/seat_gate_a121.log 2>&1
echo "hip_cc_exit=$?" >> hidden_files/seat_gate_a121.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> hidden_files/seat_gate_a121.log 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> hidden_files/seat_gate_a121.log 2>&1
echo "zc_cc_exit=$?" >> hidden_files/seat_gate_a121.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" >> hidden_files/seat_gate_a121.log 2>&1
echo "vulkan_cc_exit=$?" >> hidden_files/seat_gate_a121.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/tests/run_all.mojo >> hidden_files/seat_gate_a121.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/seat_gate_a121.log
echo "=== end $(date -Is) ===" >> hidden_files/seat_gate_a121.log
