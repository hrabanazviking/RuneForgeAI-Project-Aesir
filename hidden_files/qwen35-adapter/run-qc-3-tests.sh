#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3
H=hidden_files/qwen35-adapter
F=aesir_engine/tests/fixtures
STORIES=/home/volmarr/aesir-team-01/hidden_files/fixtures/stories260K.F16.gguf
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
sha256sum $STORIES > $H/qc-3-source-sha.log 2>&1; cat $H/qc-3-source-sha.log
$H/test_quantize_model_qc_3 $STORIES $H/qc-3-test-out.gguf > $H/qc-3-test.log 2>&1; echo QC3_TEST_EXIT=$?
.aesir/aesir quantize $STORIES $H/stories260K.Q8_0.gguf > $H/qc-3-cli.log 2>&1; echo QC3_CLI_EXIT=$?
sha256sum $H/stories260K.Q8_0.gguf > $H/qc-3-emitted-sha.log 2>&1; ls -l $H/stories260K.Q8_0.gguf >> $H/qc-3-emitted-sha.log 2>&1; cat $H/qc-3-emitted-sha.log
.aesir/aesir inspect $STORIES > $H/qc-3-inspect-source.log 2>&1; echo INSPECT_SRC_EXIT=$?
.aesir/aesir inspect $H/stories260K.Q8_0.gguf > $H/qc-3-inspect-q8.log 2>&1; echo INSPECT_Q8_EXIT=$?
$H/grade_quantize_qc_3 $STORIES $H/stories260K.Q8_0.gguf $H/qc-3-grade.csv > $H/qc-3-grade.log 2>&1; echo QC3_GRADE_EXIT=$?
python3 $H/qc3_grade_summary.py $H/qc-3-grade.csv > $H/qc-3-grade-summary.log 2>&1; echo QC3_SUMMARY_EXIT=$?
$H/test_quantize_q8_0_qc_2 > $H/qc-3-regress-qc-2.log 2>&1; echo QC2_EXIT=$?
$H/test_gguf_writer_qc_1 $STORIES > $H/qc-3-regress-qc-1.log 2>&1; echo QC1_EXIT=$?
$H/test_qwen35_loader_q35_1 $F/qwen35_tiny.gguf $F/qwen35_tiny_bad_qkv.gguf $F/qwen35_tiny_type_probe.gguf > $H/qc-3-regress-q35-1.log 2>&1; echo Q351_EXIT=$?
echo ALL_RUNS_DONE
