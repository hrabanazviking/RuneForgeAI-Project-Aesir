#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-6
H=hidden_files/qwen35-adapter
SRC=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
PROD=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q4_K_M.gguf
TOK=$H/q35-3b-tokens.txt
COMP=$H/q35-3b-comp.csv
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
# llama.cpp loads the product (its own census readback + short generation)
/home/volmarr/llama.cpp-build/build/bin/llama-cli -m $PROD -p "The capital of France is" -n 16 --temp 0 -t 8 > $H/qc-6-llama-product.log 2>&1; echo LLAMA_PROD_EXIT=$?
# source grades: RESIDENT path, comparator = banked llama.cpp rows (Q35-3b)
for p in 0 1 2 3 4 5; do
  /usr/bin/time -v $H/grade_qwen35_qc_6 grade $SRC $TOK $p $COMP $H/qc-6-grade-src-p$p.csv resident > $H/qc-6-grade-src-p$p.log 2> $H/qc-6-grade-src-p$p-time.log; echo SRC_GRADE_P$p EXIT=$?
done
cat $H/qc-6-grade-src-p0.csv $H/qc-6-grade-src-p1.csv $H/qc-6-grade-src-p2.csv $H/qc-6-grade-src-p3.csv $H/qc-6-grade-src-p4.csv $H/qc-6-grade-src-p5.csv > $H/qc-6-grade-src-all.csv
# product grades: DEFAULT packed path, comparator = the source rows above
for p in 0 1 2 3 4 5; do
  /usr/bin/time -v $H/grade_qwen35_qc_6 grade $PROD $TOK $p $H/qc-6-grade-src-all.csv $H/qc-6-grade-prod-p$p.csv default > $H/qc-6-grade-prod-p$p.log 2> $H/qc-6-grade-prod-p$p-time.log; echo PROD_GRADE_P$p EXIT=$?
done
# generation witnesses (greedy, prompt 0, 40 tokens)
/usr/bin/time -v $H/grade_qwen35_qc_6 gen $PROD $TOK 0 40 default > $H/qc-6-gen-product.log 2> $H/qc-6-gen-product-time.log; echo PROD_GEN_EXIT=$?
/usr/bin/time -v $H/grade_qwen35_qc_6 gen $SRC $TOK 0 40 resident > $H/qc-6-gen-source.log 2> $H/qc-6-gen-source-time.log; echo SRC_GEN_EXIT=$?
python3 $H/qc6_crossgrade.py "$H/qc-6-grade-src-p*.csv" "$H/qc-6-grade-prod-p*.csv" > $H/qc-6-grade-summary.log 2>&1; echo SUMMARY_EXIT=$?
cat $H/qc-6-grade-summary.log
echo QC6_GRADE_DONE
