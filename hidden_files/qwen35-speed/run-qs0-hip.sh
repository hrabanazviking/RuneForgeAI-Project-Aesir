#!/usr/bin/env bash
# QS-0.6 HIP profile: fixture harness (phase timings) + real-file
# gen-timing pair (n=4 vs n=20; load cancels in the difference).
set -x
cd /home/volmarr/aesir-hipserve
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
QS=hidden_files/qwen35-speed
AD=hidden_files/qwen35-adapter
GGUF=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
grep MemAvailable /proc/meminfo
./$QS/test_qwen35_hip_q35_6 aesir_engine/tests/fixtures/qwen35_forward.gguf
echo FIXTURE_HIP_EXIT=$?
cd $AD
/usr/bin/time -v /home/volmarr/aesir-hipserve/$QS/grade_qwen35_hip_q35_6b gen $GGUF q35-3b-tokens.txt 0 4 > /home/volmarr/aesir-hipserve/$QS/qs0-hip-gen4.log 2>&1
echo GEN4_EXIT=$?
/usr/bin/time -v /home/volmarr/aesir-hipserve/$QS/grade_qwen35_hip_q35_6b gen $GGUF q35-3b-tokens.txt 0 20 > /home/volmarr/aesir-hipserve/$QS/qs0-hip-gen20.log 2>&1
echo GEN20_EXIT=$?
grep MemAvailable /proc/meminfo
echo QS0_HIP_RUN_DONE
