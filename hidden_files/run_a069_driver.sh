#!/bin/bash
# A-069 team-01 standalone driver: compile + run only the A-069
# cases (fast iteration before the full E-MASTER gate).
cd /home/volmarr/aesir-team-02 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
staging=$(mktemp -d)
echo "staging=$staging"
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" 2>&1; echo "hailo_cc_exit=$?"
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread 2>&1; echo "par_cc_exit=$?"
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl 2>&1; echo "hip_cc_exit=$?"
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl 2>&1; echo "vulkan_cc_exit=$?"
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl 2>&1; echo "zc_cc_exit=$?"
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" -ldl 2>&1; echo "aff_cc_exit=$?"
timeout 600 pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/a069_driver.mojo 2>&1
echo "MOJO_EXIT=$?"
