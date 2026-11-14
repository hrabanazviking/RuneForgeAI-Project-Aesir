#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-2
H=hidden_files/qwen35-adapter
F=aesir_engine/tests/fixtures
STORIES=/home/volmarr/aesir-team-01/hidden_files/fixtures/stories260K.F16.gguf
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
$H/test_quantize_q8_0_qc_2 > $H/qc-2-test.log 2>&1; echo QC2_EXIT=$?
$H/test_gguf_writer_qc_1 $STORIES > $H/qc-2-regress-qc-1.log 2>&1; echo QC1_EXIT=$?
$H/test_qwen35_loader_q35_1 $F/qwen35_tiny.gguf $F/qwen35_tiny_bad_qkv.gguf $F/qwen35_tiny_type_probe.gguf > $H/qc-2-regress-q35-1.log 2>&1; echo Q351_EXIT=$?
echo ALL_RUNS_DONE
