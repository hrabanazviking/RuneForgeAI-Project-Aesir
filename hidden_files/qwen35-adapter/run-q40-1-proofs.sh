#!/usr/bin/env bash
cd /home/volmarr/aesir-q35-40b
export LD_LIBRARY_PATH=/home/volmarr/aesir-q35-40b/hidden_files/hip-serve/shims
AD=hidden_files/qwen35-adapter
F40="/mnt/vault/models/gguf/Qwen3.8-40B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf"
F27="/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf"
.aesir/aesir inspect --format json "$F40" > $AD/q40-inspect.log 2>&1; echo "INSPECT_EXIT=$?" >> $AD/q40-inspect.log
.aesir/aesir inspect --format json "$F27" > $AD/q40-inspect-27b-regress.log 2>&1; echo "INSPECT_EXIT=$?" >> $AD/q40-inspect-27b-regress.log
$AD/test_qwen35_registry_q40_1 "$F40" "$F27" > $AD/q40-1-test.log 2>&1; echo "TEST_RUN_EXIT=$?" >> $AD/q40-1-test.log
$AD/test_qwen35_registry_q35_2 "$F27" > $AD/q40-q35-2-test-regress.log 2>&1; echo "TEST_RUN_EXIT=$?" >> $AD/q40-q35-2-test-regress.log
$AD/probe_qwen35_runtime_ripple_q35_2 "$F40" > $AD/q40-ripple.log 2>&1; echo "RIPPLE_RUN_EXIT=$?" >> $AD/q40-ripple.log
echo ALL_PROOFS_DONE
