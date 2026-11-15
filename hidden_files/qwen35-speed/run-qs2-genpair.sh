#!/usr/bin/env bash
# QS-2.1 deferred measurement: real-file HIP gen-timing pair
# (n=4 vs n=20; load+construction cancels in the difference).
# TAG env names the logs (base = unmodified bad65106 binaries).
set -x
cd /home/volmarr/aesir-qs-hip
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
QS=/home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed
AD=/home/volmarr/aesir-qs-hip/hidden_files/qwen35-adapter
GGUF=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
grep MemAvailable /proc/meminfo; cat /proc/loadavg; uptime
cd $AD
/usr/bin/time -v $QS/${GRADEBIN:-grade_qwen35_hip_q35_6b} gen $GGUF q35-3b-tokens.txt 0 4 > $QS/qs2-gen4-${TAG:-x}.log 2>&1
echo GEN4_EXIT=$?
/usr/bin/time -v $QS/${GRADEBIN:-grade_qwen35_hip_q35_6b} gen $GGUF q35-3b-tokens.txt 0 20 > $QS/qs2-gen20-${TAG:-x}.log 2>&1
echo GEN20_EXIT=$?
grep MemAvailable /proc/meminfo
echo QS2_GENPAIR_DONE
