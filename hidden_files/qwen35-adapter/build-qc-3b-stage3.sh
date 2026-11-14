#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qc-3b
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/main.mojo -o .aesir/aesir
echo ENGINE_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_quantize_gemma_qc_3b.mojo -o hidden_files/qwen35-adapter/test_quantize_gemma_qc_3b
echo GEMMA_TEST_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_quantize_model_qc_3.mojo -o hidden_files/qwen35-adapter/test_quantize_model_qc_3
echo QC3_TEST_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/grade_quantize_qc_3.mojo -o hidden_files/qwen35-adapter/grade_quantize_qc_3
echo QC3_GRADE_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_quantize_q8_0_qc_2.mojo -o hidden_files/qwen35-adapter/test_quantize_q8_0_qc_2
echo QC2_TEST_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_loader_q35_1.mojo -o hidden_files/qwen35-adapter/test_qwen35_loader_q35_1
echo Q351_BUILD_EXIT=$?
echo QC3B_STAGE3_BUILD_DONE
