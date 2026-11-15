#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-heavy-v8-driver.log 2>&1
QS=/home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed
echo "HEAVY V8 START $(date)"
grep MemAvailable /proc/meminfo; cat /proc/loadavg
export GRADEBIN=grade_qwen35_hip_q35_6b TAG=v8
/usr/bin/bash $QS/run-qs2-genpair.sh
echo "GENPAIR_V8_DONE $(date)"
export TAG=v8
/usr/bin/bash $QS/run-qs2-grade.sh
echo "GRADE_V8_DONE $(date)"
echo QS2_HEAVY_V8_DONE
