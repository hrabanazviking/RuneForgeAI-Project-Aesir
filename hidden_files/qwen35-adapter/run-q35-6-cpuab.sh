#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-q35-6
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
grep MemAvailable /proc/meminfo
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_forward_q35_3.mojo -o hidden_files/qwen35-adapter/test_qwen35_forward_q35_3
echo BUILD_FORWARD=$?
./hidden_files/qwen35-adapter/test_qwen35_forward_q35_3 aesir_engine/tests/fixtures/qwen35_forward.gguf
echo RUN_FORWARD=$?
