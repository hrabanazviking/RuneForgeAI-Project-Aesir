#!/usr/bin/env bash
# QS-2 real-file grade: gen-40 witness (P0) + teacher-forcing
# grades P0/P1/P5 vs the banked Q35-3b v2 CPU CSVs (the Q35-6b
# standard: 71/71 rank 1 gap 0.0). TAG env names logs/CSVs.
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
/usr/bin/time -v $QS/${GRADEBIN:-grade_qwen35_hip_q35_6b} gen $GGUF q35-3b-tokens.txt 0 40 > $QS/qs2-gen40-${TAG:-x}.log 2>&1
echo GEN40_EXIT=$?
/usr/bin/time -v $QS/${GRADEBIN:-grade_qwen35_hip_q35_6b} grade $GGUF q35-3b-tokens.txt 0 q35-3b-v2-p0.csv $QS/qs2-${TAG:-x}-p0.csv > $QS/qs2-grade-p0-${TAG:-x}.log 2>&1
echo GRADE_P0=$?
/usr/bin/time -v $QS/${GRADEBIN:-grade_qwen35_hip_q35_6b} grade $GGUF q35-3b-tokens.txt 1 q35-3b-v2-p1.csv $QS/qs2-${TAG:-x}-p1.csv > $QS/qs2-grade-p1-${TAG:-x}.log 2>&1
echo GRADE_P1=$?
/usr/bin/time -v $QS/${GRADEBIN:-grade_qwen35_hip_q35_6b} grade $GGUF q35-3b-tokens.txt 5 q35-3b-v2-p5.csv $QS/qs2-${TAG:-x}-p5.csv > $QS/qs2-grade-p5-${TAG:-x}.log 2>&1
echo GRADE_P5=$?
grep MemAvailable /proc/meminfo
echo QS2_GRADE_DONE
