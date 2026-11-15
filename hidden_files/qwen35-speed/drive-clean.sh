#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-clean-driver.log 2>&1
QS=/home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed
echo "CLEAN START $(date)"; cat /proc/loadavg; grep MemAvailable /proc/meminfo
export GRADEBIN=grade_qwen35_hip_q35_6b.v8 TAG=v8clean
/usr/bin/bash $QS/run-qs2-genpair140.sh
echo "CLEAN_PAIR_DONE $(date)"; cat /proc/loadavg
/usr/bin/bash $QS/drive-bench20.sh
echo "CLEAN_BENCH_DONE $(date)"
echo QS2_CLEAN_DONE
