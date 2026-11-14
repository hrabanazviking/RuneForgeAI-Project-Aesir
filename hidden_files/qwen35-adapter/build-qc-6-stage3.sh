#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qc-6
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
H=hidden_files/qwen35-adapter
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/grade_qwen35_qc_6.mojo -o $H/grade_qwen35_qc_6
echo QC6_GRADE_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_registry_q35_2.mojo -o $H/test_qwen35_registry_q35_2
echo Q352_REGISTRY_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/main.mojo -o .aesir/aesir
echo ENGINE_BUILD_EXIT=$?
echo QC6_STAGE3_BUILD_DONE
