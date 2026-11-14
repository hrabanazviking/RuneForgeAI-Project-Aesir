#!/usr/bin/env bash
# Q40-1 build, following build-q35-2.sh's pattern but for THIS tree
# (/home/volmarr/aesir-q35-40b): full engine binary + the Q40-1
# policy test + the banked Q35-2 policy test (regression re-run,
# unchanged) + the Q35-2 ripple probe (regression re-run, unchanged
# source, driven against the 40B file).
set -x
cd /home/volmarr/aesir-q35-40b
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
mkdir -p "$SH" .aesir hidden_files/qwen35-adapter
if [ ! -f "$SH/libaesir_hip.so" ]; then
  python3 scripts/build_shaders.py > hidden_files/qwen35-adapter/q40-1-build_shaders.log 2>&1
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
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_registry_q40_1.mojo -o hidden_files/qwen35-adapter/test_qwen35_registry_q40_1
echo Q40_1_TEST_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_registry_q35_2.mojo -o hidden_files/qwen35-adapter/test_qwen35_registry_q35_2
echo Q35_2_TEST_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/probe_qwen35_runtime_ripple_q35_2.mojo -o hidden_files/qwen35-adapter/probe_qwen35_runtime_ripple_q35_2
echo RIPPLE_BUILD_EXIT=$?
