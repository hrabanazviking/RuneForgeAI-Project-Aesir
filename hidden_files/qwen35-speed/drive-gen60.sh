#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-gen60-driver.log 2>&1
QS=/home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed
echo "GEN60 START $(date)"
export GRADEBIN=grade_qwen35_hip_q35_6b TAG=v7s
/usr/bin/bash $QS/run-qs2-genpair60.sh
echo "GEN60_DONE $(date)"
