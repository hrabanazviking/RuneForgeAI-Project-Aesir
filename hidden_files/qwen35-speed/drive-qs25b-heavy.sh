#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-phase/hidden_files/qwen35-speed/qs25b-heavy-driver.log 2>&1
cd /home/volmarr/aesir-qs-phase/hidden_files/qwen35-adapter
export LD_LIBRARY_PATH="/home/volmarr/aesir-qs-phase/hidden_files/hip-serve/shims"
QS=/home/volmarr/aesir-qs-phase/hidden_files/qwen35-speed
BIN=$QS/grade_qwen35_hip_q35_6b.qs25b
GGUF=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
echo "HEAVY QS25B START $(date)"; grep MemAvailable /proc/meminfo; cat /proc/loadavg
/usr/bin/time -v $BIN grade $GGUF q35-3b-tokens.txt 0 q35-3b-v2-p0.csv $QS/qs25b-p0.csv > $QS/qs25b-grade-p0.log 2>&1; echo GRADE_P0=$?
/usr/bin/time -v $BIN grade $GGUF q35-3b-tokens.txt 1 q35-3b-v2-p1.csv $QS/qs25b-p1.csv > $QS/qs25b-grade-p1.log 2>&1; echo GRADE_P1=$?
/usr/bin/time -v $BIN grade $GGUF q35-3b-tokens.txt 5 q35-3b-v2-p5.csv $QS/qs25b-p5.csv > $QS/qs25b-grade-p5.log 2>&1; echo GRADE_P5=$?
/usr/bin/time -v $BIN gen $GGUF q35-3b-tokens.txt 0 4 > $QS/qs25b-gen4.log 2>&1; echo GEN4=$?
/usr/bin/time -v $BIN gen $GGUF q35-3b-tokens.txt 0 140 > $QS/qs25b-gen140.log 2>&1; echo GEN140=$?
AESIR_QS_PROFILE=3 /usr/bin/time -v $BIN gen $GGUF q35-3b-tokens.txt 0 24 > $QS/qs25b-gen24-prof3.log 2>&1; echo PROF3=$?
grep MemAvailable /proc/meminfo; cat /proc/loadavg
echo QS25B_HEAVY_DONE $(date)
