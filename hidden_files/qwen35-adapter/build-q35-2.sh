#!/usr/bin/env bash
# Q35-2 build, following hidden_files/hip-serve/build-1.sh's pattern:
# full engine binary (inspect proof) + the Q35-2 policy test binary.
set -x
cd /home/volmarr/aesir-hipserve
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
mkdir -p "$SH" .aesir hidden_files/qwen35-adapter
if [ ! -f "$SH/libaesir_hip.so" ]; then
  python3 scripts/build_shaders.py > hidden_files/qwen35-adapter/build_shaders.log 2>&1
  cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$SH/libaesir_hailo10h.so"
  cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$SH/libaesir_par.so" -lpthread
  cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$SH/libaesir_hip.so" -ldl
  cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$SH/libaesir_vulkan.so" -ldl
  cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$SH/libaesir_zc.so" -ldl
  cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$SH/libaesir_aff.so"
fi
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/main.mojo -o .aesir/aesir
echo ENGINE_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_registry_q35_2.mojo -o hidden_files/qwen35-adapter/test_qwen35_registry_q35_2
echo TEST_BUILD_EXIT=$?
