#!/usr/bin/env bash
# QS-1 real-file grade + gen timing. Caller must hold HEAVY.lock.
set -x
cd /home/volmarr/aesir-qs-cpu
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
QS=hidden_files/qwen35-speed
AD=hidden_files/qwen35-adapter
GGUF=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
grep MemAvailable /proc/meminfo; uptime
for p in 0 1 2 3 4 5; do
  /usr/bin/time -v ./$QS/grade_qs1 grade $GGUF $AD/q35-3b-tokens.txt $p $AD/q35-3b-comp.csv $QS/qs1-grade-p$p.csv > $QS/qs1-grade-p$p.log 2>&1
  echo GRADE_P$p EXIT=$?
done
for p in 0 3; do
  ./$QS/grade_qs1 batch $GGUF $AD/q35-3b-tokens.txt $p > $QS/qs1-batch-p$p.log 2>&1
  echo BATCH_P$p EXIT=$?
done
/usr/bin/time -v ./$QS/grade_qs1 gen $GGUF $AD/q35-3b-tokens.txt 0 4 > $QS/qs1-gen4.log 2>&1; echo GEN4_EXIT=$?
/usr/bin/time -v ./$QS/grade_qs1 gen $GGUF $AD/q35-3b-tokens.txt 0 20 > $QS/qs1-gen20.log 2>&1; echo GEN20_EXIT=$?
grep MemAvailable /proc/meminfo
echo QS1_GRADE_RUN_DONE
