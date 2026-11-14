#!/usr/bin/env bash
cd /home/volmarr/aesir-q8-1
H=hidden_files/qwen35-adapter
F=aesir_engine/tests/fixtures
REAL27=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
$H/test_q8_1_fix_q8_1 > $H/q8-1-test.log 2>&1; echo Q81_EXIT=$?
$H/run_q8_fp8_q8_1 > $H/q8-1-q8fp8.log 2>&1; echo Q8FP8_EXIT=$?
$H/test_qwen35_loader_q35_1 $F/qwen35_tiny.gguf $F/qwen35_tiny_bad_qkv.gguf $F/qwen35_tiny_type_probe.gguf > $H/q8-1-regress-q35-1.log 2>&1; echo Q351_EXIT=$?
$H/test_qwen35_registry_q35_2 $REAL27 > $H/q8-1-regress-q35-2.log 2>&1; echo Q352_EXIT=$?
$H/test_gguf_metadata_types > $H/q8-1-regress-meta.log 2>&1; echo META_EXIT=$?
echo ALL_RUNS_DONE
