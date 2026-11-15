#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-hip
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/bench_qwen35_gemv_qs2.mojo -o hidden_files/qwen35-speed/bench_qwen35_gemv_qs2
echo BUILD_BENCH=$?
