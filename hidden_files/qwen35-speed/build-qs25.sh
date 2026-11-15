#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-phase
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
mkdir -p "$SH" hidden_files/qwen35-speed
if [ ! -f "$SH/libaesir_hip.so" ]; then
  cp /home/volmarr/aesir-hipserve/hidden_files/hip-serve/shims/*.so "$SH"/
fi
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
for t in test_qwen35_hip_q35_6 grade_qwen35_hip_q35_6b test_qwen35_hip_session_q35_6; do
  pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/$t.mojo -o hidden_files/qwen35-speed/$t.qs25
  echo BUILD_$t=$?
done
echo QS25_BUILD_DONE
