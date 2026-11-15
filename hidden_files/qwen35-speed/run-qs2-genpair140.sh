#!/usr/bin/env bash
# QS-2 long gen pair: n=4 vs n=140 (136-token difference).
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
/usr/bin/time -v $QS/${GRADEBIN:-grade_qwen35_hip_q35_6b} gen $GGUF q35-3b-tokens.txt 0 140 > $QS/qs2-gen140-${TAG:-x}.log 2>&1
echo GEN140_EXIT=$?
grep MemAvailable /proc/meminfo
echo QS2_GENPAIR140_DONE
