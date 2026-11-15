#!/usr/bin/env bash
# QS-2 fixture run: TAG env names the log (e.g. TAG=base, TAG=gemv1).
set -x
cd /home/volmarr/aesir-qs-hip
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
QS=hidden_files/qwen35-speed
grep MemAvailable /proc/meminfo
/usr/bin/time -v ./$QS/test_qwen35_hip_q35_6 aesir_engine/tests/fixtures/qwen35_forward.gguf > $QS/qs2-fixture-${TAG:-x}.log 2>&1
echo FIXTURE_EXIT=$?
grep MemAvailable /proc/meminfo
echo QS2_FIXTURE_DONE
