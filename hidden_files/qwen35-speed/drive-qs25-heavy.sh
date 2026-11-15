#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-phase/hidden_files/qwen35-speed/qs25-heavy-driver.log 2>&1
cd /home/volmarr/aesir-qs-phase
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims"
QS=$PWD/hidden_files/qwen35-speed
AD=$PWD/hidden_files/qwen35-adapter
GGUF=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
echo "HEAVY QS25 START $(date)"; grep MemAvailable /proc/meminfo; cat /proc/loadavg
cd $AD
/usr/bin/time -v $QS/grade_qwen35_hip_q35_6b.qs25 gen $GGUF q35-3b-tokens.txt 0 40 > $QS/qs25-gen40-prof1.log 2>&1; echo PROF1_GEN_EXIT=$?
AESIR_QS_PROFILE=1 /usr/bin/time -v $QS/grade_qwen35_hip_q35_6b.qs25 gen $GGUF q35-3b-tokens.txt 0 40 > $QS/qs25-gen40-prof1on.log 2>&1; echo PROF1ON_GEN_EXIT=$?
AESIR_QS_PROFILE=2 /usr/bin/time -v $QS/grade_qwen35_hip_q35_6b.qs25 gen $GGUF q35-3b-tokens.txt 0 24 > $QS/qs25-gen24-prof2.log 2>&1; echo PROF2_GEN_EXIT=$?
grep MemAvailable /proc/meminfo; cat /proc/loadavg
echo QS25_HEAVY_DONE $(date)
