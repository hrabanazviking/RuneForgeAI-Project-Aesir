#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-q35-6
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
grep MemAvailable /proc/meminfo
ps aux | grep -E 'aesir|serve' | grep -v grep | head -5
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_hip_q35_6.mojo -o hidden_files/qwen35-adapter/test_qwen35_hip_q35_6
echo BUILD_HIP=$?
./hidden_files/qwen35-adapter/test_qwen35_hip_q35_6 aesir_engine/tests/fixtures/qwen35_forward.gguf
echo RUN_HIP=$?
