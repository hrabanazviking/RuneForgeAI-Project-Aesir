#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-phase/hidden_files/qwen35-speed/qs25-prof3-driver.log 2>&1
cd /home/volmarr/aesir-qs-phase/hidden_files/qwen35-adapter
export LD_LIBRARY_PATH="/home/volmarr/aesir-qs-phase/hidden_files/hip-serve/shims"
QS=/home/volmarr/aesir-qs-phase/hidden_files/qwen35-speed
GGUF=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
echo "PROF3 START $(date)"; grep MemAvailable /proc/meminfo; cat /proc/loadavg
AESIR_QS_PROFILE=3 /usr/bin/time -v $QS/grade_qwen35_hip_q35_6b.qs25 gen $GGUF q35-3b-tokens.txt 0 24 > $QS/qs25-gen24-prof3.log 2>&1; echo PROF3_EXIT=$?
echo QS25_PROF3_DONE $(date)
