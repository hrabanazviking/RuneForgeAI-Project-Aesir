#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-hipserve
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
for t in test_qwen35_hip_q35_6 grade_qwen35_hip_q35_6b; do
  pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/$t.mojo -o hidden_files/qwen35-speed/$t
  echo BUILD_$t=$?
done
echo QS0_HIP_BUILD_DONE
