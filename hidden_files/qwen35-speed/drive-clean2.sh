#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-clean2-driver.log 2>&1
QS=/home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed
echo "CLEAN2 START $(date)"; cat /proc/loadavg
export GRADEBIN=grade_qwen35_hip_q35_6b.v8 TAG=v8warm
/usr/bin/bash $QS/run-qs2-genpair140.sh
echo "CLEAN2_PAIR_DONE $(date)"; cat /proc/loadavg
echo QS2_CLEAN2_DONE
