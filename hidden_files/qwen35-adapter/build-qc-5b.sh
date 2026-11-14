#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qc-5
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
H=hidden_files/qwen35-adapter
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_quantize_model_qc_5.mojo -o $H/test_quantize_model_qc_5
echo QC5_MODEL_TEST_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_quantize_model_qc_3.mojo -o $H/test_quantize_model_qc_3
echo QC3_TEST_REBUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/main.mojo -o .aesir/aesir
echo ENGINE_REBUILD_EXIT=$?
