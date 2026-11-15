#!/usr/bin/env bash
# QS-2 heavy sequence (run ONLY while holding HEAVY.lock):
# gen pairs for base / gemv2 / current builds, then the
# real-file grade on the current build. Each step logs
# separately under hidden_files/qwen35-speed/.
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-heavy-driver.log 2>&1
QS=/home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed
echo "HEAVY SEQUENCE START $(date)"
grep MemAvailable /proc/meminfo; cat /proc/loadavg; uptime
export GRADEBIN=grade_qwen35_hip_q35_6b.base TAG=base
/usr/bin/bash $QS/run-qs2-genpair.sh
echo "GENPAIR_BASE_DONE $(date)"
export GRADEBIN=grade_qwen35_hip_q35_6b.gemv2 TAG=gemv2
/usr/bin/bash $QS/run-qs2-genpair.sh
echo "GENPAIR_GEMV2_DONE $(date)"
export GRADEBIN=grade_qwen35_hip_q35_6b TAG=fuse5
/usr/bin/bash $QS/run-qs2-genpair.sh
echo "GENPAIR_FUSE5_DONE $(date)"
/usr/bin/bash $QS/run-qs2-grade.sh
echo "GRADE_FUSE5_DONE $(date)"
grep MemAvailable /proc/meminfo
echo QS2_HEAVY_SEQUENCE_DONE
