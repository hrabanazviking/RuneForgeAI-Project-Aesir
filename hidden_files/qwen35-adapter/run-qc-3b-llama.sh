#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b
H=hidden_files/qwen35-adapter
GEMMA=/home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
grep MemAvailable /proc/meminfo > $H/qc-3b-llama-mem.log
$H/qc3bstream $GEMMA $H/qc-3b-streams.txt $H/qc-3b-prompts.txt 8 > $H/qc-3b-stream-build.log 2>&1; echo STREAM_EXIT=$?
$H/qc3bgrade $GEMMA $H/qc-3b-streams.txt $H/qc-3b-prompts.txt $H/qc-3b-rows-llama-src.bin $H/qc-3b-gen-llama-src.txt 8 > $H/qc-3b-grade-src.log 2>&1; echo GRADE_SRC_EXIT=$?
$H/qc3bgrade $H/gemma-4-E2B-it-Q8_0.gguf $H/qc-3b-streams.txt $H/qc-3b-prompts.txt $H/qc-3b-rows-llama-q8.bin $H/qc-3b-gen-llama-q8.txt 8 > $H/qc-3b-grade-q8.log 2>&1; echo GRADE_Q8_EXIT=$?
python3 $H/qc3b_crossgrade.py --cand $H/qc-3b-rows-llama-q8.bin --comp $H/qc-3b-rows-llama-src.bin --streams $H/qc-3b-streams.txt --prompts $H/qc-3b-prompts.txt --label 'QC-3b llama.cpp CPU: candidate gemma-4-E2B Q8_0 (Aesir QC-3b) vs comparator gemma-4-E2B Q4_K_M source as-is' > $H/qc-3b-crossgrade.log 2>&1; echo CROSS_EXIT=$?
cat $H/qc-3b-crossgrade.log
echo QC3B_LLAMA_DONE
