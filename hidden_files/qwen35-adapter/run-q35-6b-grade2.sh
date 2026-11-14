#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-q35-6/hidden_files/qwen35-adapter
export LD_LIBRARY_PATH="/home/volmarr/aesir-q35-6/hidden_files/hip-serve/shims"
REAL=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
grep MemAvailable /proc/meminfo
ps aux | grep -E 'mojo|cc1|clang' | grep -v grep | head -5
/usr/bin/time -v ./grade_qwen35_hip_q35_6b grade $REAL q35-3b-tokens.txt 1 q35-3b-v2-p1.csv q35-6b-p1.csv > q35-6b-grade-p1.log 2>&1; echo GRADE_P1=$?
/usr/bin/time -v ./grade_qwen35_hip_q35_6b grade $REAL q35-3b-tokens.txt 5 q35-3b-v2-p5.csv q35-6b-p5.csv > q35-6b-grade-p5.log 2>&1; echo GRADE_P5=$?
grep MemAvailable /proc/meminfo
