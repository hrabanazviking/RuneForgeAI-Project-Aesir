#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-1
H=hidden_files/qwen35-adapter
F=aesir_engine/tests/fixtures
STORIES=/home/volmarr/aesir-team-01/hidden_files/fixtures/stories260K.F16.gguf
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
$H/test_gguf_writer_qc_1 $STORIES > $H/qc-1-test.log 2>&1; echo QC1_EXIT=$?
$H/test_gguf_writer_qc_1_gemma_probe /home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf > $H/qc-1-gemma-probe.log 2>&1; echo GEMMA_EXIT=$?
$H/test_qwen35_loader_q35_1 $F/qwen35_tiny.gguf $F/qwen35_tiny_bad_qkv.gguf $F/qwen35_tiny_type_probe.gguf > $H/qc-1-regress-q35-1.log 2>&1; echo Q351_EXIT=$?
$H/test_gguf_metadata_types > $H/qc-1-regress-meta.log 2>&1; echo META_EXIT=$?
echo ALL_RUNS_DONE
