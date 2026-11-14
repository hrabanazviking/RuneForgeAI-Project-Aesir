#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b
H=hidden_files/qwen35-adapter
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
GEMMA=/home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
grep MemAvailable /proc/meminfo > $H/qc-3b-aesir-attempt-mem.log
timeout 240 $H/grade_quantize_qc_3 $GEMMA $H/gemma-4-E2B-it-Q8_0.gguf $H/qc-3b-aesir-grade.csv > $H/qc-3b-aesir-attempt.log 2>&1; echo AESIR_ATTEMPT_EXIT=$?
head -n 20 $H/qc-3b-aesir-attempt.log
echo QC3B_AESIR_ATTEMPT_DONE
