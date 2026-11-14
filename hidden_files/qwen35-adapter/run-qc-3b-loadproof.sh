#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b
H=hidden_files/qwen35-adapter
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
GEMMA=/home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
$H/test_quantize_gemma_qc_3b $GEMMA $H/gemma-4-E2B-it-Q8_0.gguf > $H/qc-3b-loadproof.log 2>&1; echo LOADPROOF_EXIT=$?
.aesir/aesir inspect $GEMMA > $H/qc-3b-inspect-source.log 2>&1; echo INSPECT_SRC_EXIT=$?
.aesir/aesir inspect $H/gemma-4-E2B-it-Q8_0.gguf > $H/qc-3b-inspect-q8.log 2>&1; echo INSPECT_Q8_EXIT=$?
python3 /tmp/qc3b_census.py $H/gemma-4-E2B-it-Q8_0.gguf > $H/qc-3b-census-emitted.log 2>&1; echo CENSUS_EXIT=$?
grep -E '^(CENSUS|CENSUS_BYTES|DIR_END|DIM0_NOT|RANK1|TOTAL)' $H/qc-3b-census-emitted.log
echo QC3B_LOADPROOF_DONE
