#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-pack
export PATH="$HOME/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
H=hidden_files/qwen35-speed
F=$H/fixtures/stories260K.F16.gguf
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/dequantize_model_qc_5.mojo -o $H/dequantize_model_qc_5
echo DEQUANT_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/grade_quantize_qc_3.mojo -o $H/grade_quantize_qc_3
echo GRADE_BUILD_EXIT=$?
./.aesir/aesir quantize $F $H/fixtures/stories260K.legacy-Q4_K_M.gguf --to q4_k_m --fit legacy > $H/qs-3-stories-legacy-cli.log 2>&1; echo LEGACY_CONVERT_EXIT=$?
./.aesir/aesir quantize $F $H/fixtures/stories260K.searched-Q4_K_M.gguf --to q4_k_m --fit searched > $H/qs-3-stories-searched-cli.log 2>&1; echo SEARCHED_CONVERT_EXIT=$?
ls -l $H/fixtures/
$H/dequantize_model_qc_5 $H/fixtures/stories260K.legacy-Q4_K_M.gguf $F $H/fixtures/stories260K.legacy-Q4_K_M.dequant.gguf > $H/qs-3-stories-legacy-dequant.log 2>&1; echo LEGACY_DEQUANT_EXIT=$?
$H/dequantize_model_qc_5 $H/fixtures/stories260K.searched-Q4_K_M.gguf $F $H/fixtures/stories260K.searched-Q4_K_M.dequant.gguf > $H/qs-3-stories-searched-dequant.log 2>&1; echo SEARCHED_DEQUANT_EXIT=$?
$H/grade_quantize_qc_3 $F $H/fixtures/stories260K.legacy-Q4_K_M.dequant.gguf $H/qs-3-grade-stories-legacy.csv > $H/qs-3-grade-stories-legacy.log 2>&1; echo LEGACY_GRADE_EXIT=$?
$H/grade_quantize_qc_3 $F $H/fixtures/stories260K.searched-Q4_K_M.dequant.gguf $H/qs-3-grade-stories-searched.csv > $H/qs-3-grade-stories-searched.log 2>&1; echo SEARCHED_GRADE_EXIT=$?
python3 hidden_files/qwen35-adapter/qc3_grade_summary.py $H/qs-3-grade-stories-legacy.csv > $H/qs-3-grade-stories-legacy-summary.log 2>&1; echo LEGACY_SUMMARY_EXIT=$?
python3 hidden_files/qwen35-adapter/qc3_grade_summary.py $H/qs-3-grade-stories-searched.csv > $H/qs-3-grade-stories-searched-summary.log 2>&1; echo SEARCHED_SUMMARY_EXIT=$?
echo QS3_FIXTURES_DONE
