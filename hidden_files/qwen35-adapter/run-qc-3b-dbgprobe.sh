#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b
H=hidden_files/qwen35-adapter
export PATH="$HOME/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_quantize_gemma_qc_3b.mojo -o $H/test_quantize_gemma_qc_3b > $H/qc-3b-dbgprobe-build.log 2>&1; echo BUILD_EXIT=$?
GEMMA=/home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
$H/test_quantize_gemma_qc_3b $GEMMA $H/gemma-4-E2B-it-Q8_0.gguf > $H/qc-3b-dbgprobe.log 2>&1; echo TEST_EXIT=$?
grep DEBUG $H/qc-3b-dbgprobe.log | head -n 5
echo DBGPROBE_DONE
