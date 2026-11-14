#!/usr/bin/env bash
# Q35-6a build: full engine compile + Q35-6 HIP trajectory test +
# regression rebuilds (Q35-1, Q35-2, Q35-3a, Q35-3r, Q35-4 session,
# Q35-5 snapshot) + the runtime admission ripple probe.
set -x
cd /home/volmarr/aesir-q35-6
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
for t in test_qwen35_hip_q35_6 test_qwen35_hip_session_q35_6 test_qwen35_loader_q35_1 test_qwen35_registry_q35_2 test_qwen35_forward_q35_3 test_qwen35_resident_q35_3r test_qwen35_session_q35_4 test_qwen35_snapshot_q35_5 probe_qwen35_runtime_ripple_q35_2; do
  pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/$t.mojo -o hidden_files/qwen35-adapter/$t
  echo BUILD_$t=$?
done
