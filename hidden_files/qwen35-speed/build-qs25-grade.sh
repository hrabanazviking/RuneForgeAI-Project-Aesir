#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-phase
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/grade_qwen35_hip_q35_6b.mojo -o hidden_files/qwen35-speed/grade_qwen35_hip_q35_6b.qs25
echo BUILD_GRADE=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_hip_q35_6.mojo -o hidden_files/qwen35-speed/test_qwen35_hip_q35_6.qs25
echo BUILD_FIXTURE=$?
echo QS25_BUILD2_DONE
