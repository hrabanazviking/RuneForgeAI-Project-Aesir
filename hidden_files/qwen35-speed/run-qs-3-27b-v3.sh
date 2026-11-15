#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-pack
export PATH="$HOME/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
H=hidden_files/qwen35-speed
A=hidden_files/qwen35-adapter
SRC=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
PROD=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q4_K_M-searchedfit3.gguf
TOK=$A/q35-3b-tokens.txt
/usr/bin/time -v ./.aesir/aesir quantize $SRC $PROD --to q4_k_m --streaming --fit searched > $H/qs-3-v3-convert.log 2> $H/qs-3-v3-convert-time.log; echo CONVERT_EXIT=$?
ls -l $PROD; sha256sum $PROD
python3 $H/qs3_census.py $PROD /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q4_K_M-llamacontrol.gguf > $H/qs-3-v3-census.log 2>&1; cat $H/qs-3-v3-census.log
for p in 0 1 2 3 4 5; do
  $H/grade_qwen35_qs_3 grade $PROD $TOK $p $H/qs-3-grade-src-all.csv $H/qs-3-grade-v3-p$p.csv default > $H/qs-3-grade-v3-p$p.log 2>&1; echo V3_GRADE_P$p EXIT=$?
done
python3 $A/qc6_crossgrade.py "$H/qs-3-grade-src-p*.csv" "$H/qs-3-grade-v3-p*.csv" > $H/qs-3-grade-summary-v3.log 2>&1; echo SUMMARY_EXIT=$?
cat $H/qs-3-grade-summary-v3.log
for p in 0 1 2 3 4 5; do
  $H/grade_qwen35_qs_3 grade $PROD $TOK $p $H/qs-3-grade-src-all.csv $H/qs-3-grade-v3k-p$p.csv resident_k > $H/qs-3-grade-v3k-p$p.log 2>&1; echo V2K_GRADE_P$p EXIT=$?
done
python3 $A/qc6_crossgrade.py "$H/qs-3-grade-src-p*.csv" "$H/qs-3-grade-v3k-p*.csv" > $H/qs-3-grade-summary-v3-residentk.log 2>&1; echo SUMMARYK_EXIT=$?
cat $H/qs-3-grade-summary-v3-residentk.log
echo QS3_27B_V3_DONE
