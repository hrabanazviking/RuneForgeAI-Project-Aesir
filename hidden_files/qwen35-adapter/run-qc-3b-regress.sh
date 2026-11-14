#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b
H=hidden_files/qwen35-adapter
F=aesir_engine/tests/fixtures
STORIES=/home/volmarr/aesir-team-01/hidden_files/fixtures/stories260K.F16.gguf
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
$H/test_quantize_model_qc_3 $STORIES $H/qc-3b-regress-qc3a-out.gguf > $H/qc-3b-regress-qc-3a.log 2>&1; echo QC3A_TEST_EXIT=$?
.aesir/aesir quantize $STORIES $H/qc-3b-regress-stories-Q8_0.gguf > $H/qc-3b-regress-qc-3a-cli.log 2>&1; echo QC3A_CLI_EXIT=$?
sha256sum $H/qc-3b-regress-stories-Q8_0.gguf > $H/qc-3b-regress-qc-3a-sha.log 2>&1; cat $H/qc-3b-regress-qc-3a-sha.log
$H/grade_quantize_qc_3 $STORIES $H/qc-3b-regress-stories-Q8_0.gguf $H/qc-3b-regress-qc-3-grade.csv > $H/qc-3b-regress-qc-3-grade.log 2>&1; echo QC3A_GRADE_EXIT=$?
diff $H/qc-3-grade.csv $H/qc-3b-regress-qc-3-grade.csv > $H/qc-3b-regress-qc-3-grade-diff.log 2>&1; echo QC3A_GRADE_CSV_DIFF_EXIT=$?
python3 $H/qc3_grade_summary.py $H/qc-3b-regress-qc-3-grade.csv > $H/qc-3b-regress-qc-3-grade-summary.log 2>&1; echo QC3A_SUMMARY_EXIT=$?
$H/test_quantize_q8_0_qc_2 > $H/qc-3b-regress-qc-2.log 2>&1; echo QC2_EXIT=$?
$H/test_gguf_writer_qc_1 $STORIES > $H/qc-3b-regress-qc-1.log 2>&1; echo QC1_EXIT=$?
$H/test_qwen35_loader_q35_1 $F/qwen35_tiny.gguf $F/qwen35_tiny_bad_qkv.gguf $F/qwen35_tiny_type_probe.gguf > $H/qc-3b-regress-q35-1.log 2>&1; echo Q351_EXIT=$?
$H/test_gguf_writer_streaming_qc_3b stories $STORIES $H/qc-3b-regress-stream-stories.gguf > $H/qc-3b-regress-stream.log 2>&1; echo QC3B_STREAM_EXIT=$?
$H/test_dequantize_input_qc_3b > $H/qc-3b-regress-dequant.log 2>&1; echo QC3B_DEQUANT_EXIT=$?
echo QC3B_REGRESS_DONE
