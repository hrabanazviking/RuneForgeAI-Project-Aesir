#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b
H=hidden_files/qwen35-adapter
export PATH="$HOME/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_quantize_gemma_qc_3b.mojo -o $H/test_quantize_gemma_qc_3b > $H/qc-3b-loadproof-build.log 2>&1; echo BUILD_EXIT=$?
/bin/bash $H/run-qc-3b-loadproof.sh > $H/qc-3b-loadproof-run.log 2>&1
cat $H/qc-3b-loadproof-run.log
echo QC3B_LOADPROOF2_DONE
