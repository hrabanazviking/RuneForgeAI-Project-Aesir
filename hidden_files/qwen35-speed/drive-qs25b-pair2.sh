#!/usr/bin/env bash
cd /home/volmarr/aesir-qs-phase/hidden_files/qwen35-adapter
export LD_LIBRARY_PATH="/home/volmarr/aesir-qs-phase/hidden_files/hip-serve/shims"
QS=/home/volmarr/aesir-qs-phase/hidden_files/qwen35-speed
BIN=$QS/grade_qwen35_hip_q35_6b.qs25b
GGUF=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
grep MemAvailable /proc/meminfo; cat /proc/loadavg
/usr/bin/time -v $BIN gen $GGUF q35-3b-tokens.txt 0 4 > $QS/qs25b-gen4-r2.log 2>&1; echo GEN4R2=$?
/usr/bin/time -v $BIN gen $GGUF q35-3b-tokens.txt 0 140 > $QS/qs25b-gen140-r2.log 2>&1; echo GEN140R2=$?
echo PAIR2_DONE $(date)
