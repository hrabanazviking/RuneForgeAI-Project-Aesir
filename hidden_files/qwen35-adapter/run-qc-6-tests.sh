#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-6
H=hidden_files/qwen35-adapter
F=aesir_engine/tests/fixtures
STORIES=/home/volmarr/aesir-team-01/hidden_files/fixtures/stories260K.F16.gguf
GEMMA=/home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
# QC-6 headline proof
$H/test_quantize_streaming_qc_6 $STORIES $H/qc-6-stories-ref.gguf $H/qc-6-stories-q4km.gguf > $H/qc-6-test.log 2>&1; echo QC6_TEST_EXIT=$?
# CLI end-to-end: streaming K tier must reproduce the test product byte for byte
.aesir/aesir quantize $STORIES $H/qc-6-stories-cli.gguf --to q4_k_m --streaming > $H/qc-6-cli.log 2>&1; echo QC6_CLI_EXIT=$?
cmp $H/qc-6-stories-cli.gguf $H/qc-6-stories-q4km.gguf; echo QC6_CLI_CMP_EXIT=$?
sha256sum $H/qc-6-stories-q4km.gguf $H/qc-6-stories-ref.gguf > $H/qc-6-stories-sha.log 2>&1
# llama.cpp loads the QC-6 stories product (fallbacks make shapes valid)
/home/volmarr/llama.cpp-build/build/bin/llama-cli -m $H/qc-6-stories-q4km.gguf -p "One day, Timmy went to" -n 16 --temp 0 -t 4 > $H/qc-6-stories-llama.log 2>&1; echo QC6_LLAMA_EXIT=$?
# --- regressions, all rerun from this tree ---
$H/test_gguf_writer_qc_1 $STORIES > $H/qc-6-regress-qc-1.log 2>&1; echo QC1_EXIT=$?
$H/test_quantize_q8_0_qc_2 > $H/qc-6-regress-qc-2.log 2>&1; echo QC2_EXIT=$?
$H/test_quantize_model_qc_3 $STORIES $H/qc-6-regress-qc3a-out.gguf > $H/qc-6-regress-qc-3a.log 2>&1; echo QC3A_TEST_EXIT=$?
.aesir/aesir quantize $STORIES $H/qc-6-regress-stories-Q8_0.gguf > $H/qc-6-regress-qc-3a-cli.log 2>&1; echo QC3A_CLI_EXIT=$?
sha256sum $H/qc-6-regress-stories-Q8_0.gguf > $H/qc-6-regress-qc-3a-sha.log 2>&1; cat $H/qc-6-regress-qc-3a-sha.log
$H/grade_quantize_qc_3 $STORIES $H/qc-6-regress-stories-Q8_0.gguf $H/qc-6-regress-qc-3-grade.csv > $H/qc-6-regress-qc-3-grade.log 2>&1; echo QC3A_GRADE_EXIT=$?
diff $H/qc-3-grade.csv $H/qc-6-regress-qc-3-grade.csv > $H/qc-6-regress-qc-3-grade-diff.log 2>&1; echo QC3A_GRADE_CSV_DIFF_EXIT=$?
$H/test_dequantize_input_qc_3b > $H/qc-6-regress-qc-3b-dequant.log 2>&1; echo QC3B_DEQUANT_EXIT=$?
$H/test_gguf_writer_streaming_qc_3b stories $STORIES $H/qc-6-regress-stream-stories.gguf > $H/qc-6-regress-qc-3b-stream.log 2>&1; echo QC3B_STREAM_EXIT=$?
.aesir/aesir quantize $GEMMA $H/qc-6-regress-gemma-Q8_0.gguf --streaming > $H/qc-6-regress-qc-3b-convert.log 2>&1; echo QC3B_CONVERT_EXIT=$?
sha256sum $H/qc-6-regress-gemma-Q8_0.gguf > $H/qc-6-regress-qc-3b-gemma-sha.log 2>&1; cat $H/qc-6-regress-qc-3b-gemma-sha.log
$H/test_quantize_gemma_qc_3b $GEMMA $H/qc-6-regress-gemma-Q8_0.gguf > $H/qc-6-regress-qc-3b-gemma.log 2>&1; echo QC3B_GEMMA_EXIT=$?
$H/test_quantize_k_qc_5 > $H/qc-6-regress-qc-5-k.log 2>&1; echo QC5_K_EXIT=$?
$H/test_quantize_model_qc_5 $STORIES $H/qc-6-regress-qc5-out.gguf > $H/qc-6-regress-qc-5-model.log 2>&1; echo QC5_MODEL_EXIT=$?
$H/test_qwen35_loader_q35_1 $F/qwen35_tiny.gguf $F/qwen35_tiny_bad_qkv.gguf $F/qwen35_tiny_type_probe.gguf > $H/qc-6-regress-q35-1.log 2>&1; echo Q351_EXIT=$?
echo QC6_TESTS_DONE
