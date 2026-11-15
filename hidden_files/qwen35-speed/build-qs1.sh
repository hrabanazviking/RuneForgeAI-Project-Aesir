#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-cpu
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
mkdir -p "$SH" .aesir hidden_files/qwen35-speed
if [ ! -f "$SH/libaesir_par.so" ]; then
  python3 scripts/build_shaders.py > hidden_files/qwen35-speed/build_shaders.log 2>&1
  cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$SH/libaesir_hailo10h.so"
  cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$SH/libaesir_par.so" -lpthread
  cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$SH/libaesir_hip.so" -ldl
  cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$SH/libaesir_vulkan.so" -ldl
  cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$SH/libaesir_zc.so" -ldl
  cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$SH/libaesir_aff.so"
fi
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/bench_qs1_gemm.mojo -o hidden_files/qwen35-speed/bench_qs1_gemm
echo BENCH_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/grade_qwen35_oracle_q35_3b.mojo -o hidden_files/qwen35-speed/grade_qs1
echo GRADE_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/main.mojo -o .aesir/aesir
echo ENGINE_BUILD_EXIT=$?
echo QS1_BUILD_DONE
