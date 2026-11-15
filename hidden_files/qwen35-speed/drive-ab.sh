#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-ab-driver.log 2>&1
QS=/home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed
echo "AB START $(date)"; cat /proc/loadavg
export GRADEBIN=grade_qwen35_hip_q35_6b.v8 TAG=v8a
/usr/bin/bash $QS/run-qs2-genpair.sh
echo "PAIR_V8A_DONE $(date)"; cat /proc/loadavg
export GRADEBIN=grade_qwen35_hip_q35_6b.v7 TAG=v7b
/usr/bin/bash $QS/run-qs2-genpair.sh
echo "PAIR_V7B_DONE $(date)"; cat /proc/loadavg
export GRADEBIN=grade_qwen35_hip_q35_6b.v8 TAG=v8b
/usr/bin/bash $QS/run-qs2-genpair.sh
echo "PAIR_V8B_DONE $(date)"; cat /proc/loadavg
echo QS2_AB_DONE
