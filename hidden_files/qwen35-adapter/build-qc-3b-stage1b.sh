#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qc-3b
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_gguf_writer_streaming_qc_3b.mojo -o hidden_files/qwen35-adapter/test_gguf_writer_streaming_qc_3b
echo STREAM_TEST_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_dequantize_input_qc_3b.mojo -o hidden_files/qwen35-adapter/test_dequantize_input_qc_3b
echo DEQUANT_TEST_BUILD_EXIT=$?
echo QC3B_STAGE1B_BUILD_DONE
