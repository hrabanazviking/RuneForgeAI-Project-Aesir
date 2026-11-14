#!/usr/bin/env bash
# Q35-3 build, following build-q35-1.sh / build-q35-2.sh pattern:
# full engine binary (compile proof) + Q35-3 forward test + the banked
# Q35-1 loader test and Q35-2 registry test rebuilt for regression.
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
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_forward_q35_3.mojo -o hidden_files/qwen35-adapter/test_qwen35_forward_q35_3
echo TEST_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_loader_q35_1.mojo -o hidden_files/qwen35-adapter/test_qwen35_loader_q35_1
echo Q351_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_registry_q35_2.mojo -o hidden_files/qwen35-adapter/test_qwen35_registry_q35_2
echo Q352_BUILD_EXIT=$?
