#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-q35-6
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
A=hidden_files/qwen35-adapter
REAL=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
grep MemAvailable /proc/meminfo
ps aux | grep -E 'aesir|serve' | grep -v grep | head -5
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/grade_qwen35_hip_q35_6b.mojo -o $A/grade_qwen35_hip_q35_6b
echo BUILD_GRADE=$?
cd $A
/usr/bin/time -v ./grade_qwen35_hip_q35_6b gen $REAL q35-3b-tokens.txt 0 40 > q35-6b-gen-p0.log 2>&1; echo GEN_P0=$?
/usr/bin/time -v ./grade_qwen35_hip_q35_6b grade $REAL q35-3b-tokens.txt 0 q35-3b-v2-p0.csv q35-6b-p0.csv > q35-6b-grade-p0.log 2>&1; echo GRADE_P0=$?
grep MemAvailable /proc/meminfo
