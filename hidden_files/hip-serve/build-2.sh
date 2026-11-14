#!/usr/bin/env bash
cd /home/volmarr/aesir-hipserve
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I aesir_engine -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_hip_prompt_prefix.mojo -o hidden_files/hip-serve/test_hip_prompt_prefix
echo TEST_BUILD_EXIT=$?
