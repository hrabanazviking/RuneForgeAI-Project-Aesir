#!/usr/bin/env bash
# QS-3.5 heavy run: searched-fit re-pack of the 27B + strict grade.
# Caller must hold HEAVY.lock and have verified the fresh-boot gate.
set -x
cd /home/volmarr/aesir-qs-pack
export PATH="$HOME/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
H=hidden_files/qwen35-speed
A=hidden_files/qwen35-adapter
SRC=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
PROD=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q4_K_M-searchedfit.gguf
TOK=$A/q35-3b-tokens.txt
COMP=$A/q35-3b-comp.csv
sha256sum $SRC > $H/qs-3-27b-source-sha.log 2>&1
/usr/bin/time -v ./.aesir/aesir quantize $SRC $PROD --to q4_k_m --streaming --fit searched > $H/qs-3-27b-convert.log 2> $H/qs-3-27b-convert-time.log; echo CONVERT_EXIT=$?
ls -l $PROD > $H/qs-3-27b-product-ls.log 2>&1
sha256sum $PROD > $H/qs-3-27b-product-sha.log 2>&1
# source grades: RESIDENT Q8 path vs banked llama.cpp comparator rows (QC-6 method, identical battery)
for p in 0 1 2 3 4 5; do
  /usr/bin/time -v $H/grade_qwen35_qs_3 grade $SRC $TOK $p $COMP $H/qs-3-grade-src-p$p.csv resident > $H/qs-3-grade-src-p$p.log 2> $H/qs-3-grade-src-p$p-time.log; echo SRC_GRADE_P$p EXIT=$?
done
cat $H/qs-3-grade-src-p0.csv $H/qs-3-grade-src-p1.csv $H/qs-3-grade-src-p2.csv $H/qs-3-grade-src-p3.csv $H/qs-3-grade-src-p4.csv $H/qs-3-grade-src-p5.csv > $H/qs-3-grade-src-all.csv
# product grades: DEFAULT packed path vs the source rows (QC-6 method)
for p in 0 1 2 3 4 5; do
  /usr/bin/time -v $H/grade_qwen35_qs_3 grade $PROD $TOK $p $H/qs-3-grade-src-all.csv $H/qs-3-grade-prod-p$p.csv default > $H/qs-3-grade-prod-p$p.log 2> $H/qs-3-grade-prod-p$p-time.log; echo PROD_GRADE_P$p EXIT=$?
done
python3 $A/qc6_crossgrade.py "$H/qs-3-grade-src-p*.csv" "$H/qs-3-grade-prod-p*.csv" > $H/qs-3-grade-summary.log 2>&1; echo SUMMARY_EXIT=$?
cat $H/qs-3-grade-summary.log
# product grades again through the K-RESIDENT path: must agree with default-path rows exactly in verdict terms
for p in 0 1 2 3 4 5; do
  $H/grade_qwen35_qs_3 grade $PROD $TOK $p $H/qs-3-grade-src-all.csv $H/qs-3-grade-prodk-p$p.csv resident_k > $H/qs-3-grade-prodk-p$p.log 2>&1; echo PRODK_GRADE_P$p EXIT=$?
done
python3 $A/qc6_crossgrade.py "$H/qs-3-grade-src-p*.csv" "$H/qs-3-grade-prodk-p*.csv" > $H/qs-3-grade-summary-residentk.log 2>&1; echo SUMMARYK_EXIT=$?
cat $H/qs-3-grade-summary-residentk.log
# generation witnesses (greedy, prompt 0, 40 tokens)
$H/grade_qwen35_qs_3 gen $PROD $TOK 0 40 default > $H/qs-3-gen-product.log 2>&1; echo PROD_GEN_EXIT=$?
$H/grade_qwen35_qs_3 gen $PROD $TOK 0 40 resident_k > $H/qs-3-gen-product-residentk.log 2>&1; echo PRODK_GEN_EXIT=$?
$H/grade_qwen35_qs_3 gen $SRC $TOK 0 40 resident > $H/qs-3-gen-source.log 2>&1; echo SRC_GEN_EXIT=$?
echo QS3_27B_DONE
