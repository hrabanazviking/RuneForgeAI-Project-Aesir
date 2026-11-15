#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-pack
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
H=hidden_files/qwen35-speed
A=hidden_files/qwen35-adapter
SRC=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
PROD=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q4_K_M-llamacontrol.gguf
TOK=$A/q35-3b-tokens.txt
/usr/bin/time -v ~/llama.cpp-build/build/bin/llama-quantize --allow-requantize $SRC $PROD Q4_K_M > $H/qs-3-llama-convert.log 2> $H/qs-3-llama-convert-time.log; echo LLAMA_CONVERT_EXIT=$?
ls -l $PROD; sha256sum $PROD
for p in 0 1 2 3 4 5; do
  $H/grade_qwen35_qs_3 grade $PROD $TOK $p $H/qs-3-grade-src-all.csv $H/qs-3-grade-llama-p$p.csv default > $H/qs-3-grade-llama-p$p.log 2>&1; echo LLAMA_GRADE_P$p EXIT=$?
done
python3 $A/qc6_crossgrade.py "$H/qs-3-grade-src-p*.csv" "$H/qs-3-grade-llama-p*.csv" > $H/qs-3-grade-summary-llama.log 2>&1; echo SUMMARY_EXIT=$?
cat $H/qs-3-grade-summary-llama.log
echo QS3_LLAMA_CONTROL_DONE
