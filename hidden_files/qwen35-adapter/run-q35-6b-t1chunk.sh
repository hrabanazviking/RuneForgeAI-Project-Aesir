#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-q35-6
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
H=hidden_files/qwen35-adapter
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_hip_t1chunk_q35_6b.mojo -o $H/test_qwen35_hip_t1chunk_q35_6b > $H/q35-6b-t1chunk-build.log 2>&1; echo BUILD=$?
export LD_LIBRARY_PATH="$PWD/$SH"
/usr/bin/time -v ./$H/test_qwen35_hip_t1chunk_q35_6b > $H/q35-6b-t1chunk.log 2>&1; echo RUN=$?
cat $H/q35-6b-t1chunk.log
