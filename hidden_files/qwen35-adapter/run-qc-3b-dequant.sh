#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b
H=hidden_files/qwen35-adapter
export PATH="$HOME/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_dequantize_input_qc_3b.mojo -o $H/test_dequantize_input_qc_3b > $H/qc-3b-dequant-build.log 2>&1; echo DEQUANT_BUILD_EXIT=$?
$H/test_dequantize_input_qc_3b > $H/qc-3b-dequant-test.log 2>&1; echo DEQUANT_TEST_EXIT=$?
cat $H/qc-3b-dequant-test.log
echo QC3B_DEQUANT_DONE
