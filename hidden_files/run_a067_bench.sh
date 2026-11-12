#!/bin/bash
cd /home/volmarr/aesir-team-03 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
staging=$(mktemp -d)
for spec in 'hailo10h_stub.c libaesir_hailo10h' 'thread_par.c libaesir_par' 'hip_memory_shim.c libaesir_hip' 'zero_copy_shim.c libaesir_zc' 'affinity_shim.c libaesir_aff'; do set -- $spec; cc -std=c11 -O2 -fPIC -shared aesir_engine/$1 -o "$staging/$2.so" -ldl 2>&1; done
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl 2>&1
/usr/bin/time -v pixi run --frozen mojo run -I . -I aesir_engine --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/tests/bench_real_model_gpu_a067.mojo /home/volmarr/aesir-team-03/hidden_files/fixtures/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf 2>&1
echo "MOJO_EXIT=$?"
