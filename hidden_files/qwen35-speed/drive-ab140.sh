#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-ab140-driver.log 2>&1
QS=/home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed
echo "AB140 START $(date)"; cat /proc/loadavg
export GRADEBIN=grade_qwen35_hip_q35_6b.v8 TAG=v8L
/usr/bin/bash $QS/run-qs2-genpair140.sh
echo "PAIR_V8L_DONE $(date)"; cat /proc/loadavg
export GRADEBIN=grade_qwen35_hip_q35_6b.v7 TAG=v7L
/usr/bin/bash $QS/run-qs2-genpair140.sh
echo "PAIR_V7L_DONE $(date)"; cat /proc/loadavg
echo QS2_AB140_DONE
