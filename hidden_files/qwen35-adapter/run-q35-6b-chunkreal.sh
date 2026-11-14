#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-q35-6
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
H=hidden_files/qwen35-adapter
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_hip_chunk_real_q35_6b.mojo -o $H/test_qwen35_hip_chunk_real_q35_6b > $H/q35-6b-chunkreal-build.log 2>&1; echo BUILD=$?
export LD_LIBRARY_PATH="$PWD/$SH"
./$H/test_qwen35_hip_chunk_real_q35_6b > $H/q35-6b-chunkreal.log 2>&1; echo RUN=$?
cat $H/q35-6b-chunkreal.log
