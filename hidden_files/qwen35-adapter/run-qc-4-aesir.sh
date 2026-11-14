#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-4
H=hidden_files/qwen35-adapter
STORIES=/home/volmarr/aesir-team-01/hidden_files/fixtures/stories260K.F16.gguf
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
sha256sum $STORIES > $H/qc-4-source-sha.log 2>&1; cat $H/qc-4-source-sha.log
$H/test_quantize_model_qc_3 $STORIES $H/qc-4-test-out.gguf > $H/qc-4-qc3a-test.log 2>&1; echo QC3A_TEST_EXIT=$?
.aesir/aesir quantize $STORIES $H/stories260K.Q8_0.gguf > $H/qc-4-quantize-cli.log 2>&1; echo QUANTIZE_CLI_EXIT=$?
sha256sum $H/stories260K.Q8_0.gguf > $H/qc-4-emitted-sha.log 2>&1; ls -l $H/stories260K.Q8_0.gguf >> $H/qc-4-emitted-sha.log 2>&1; cat $H/qc-4-emitted-sha.log
$H/grade_quantize_qc_3 $STORIES $H/stories260K.Q8_0.gguf $H/qc-4-regress-qc3a-grade.csv > $H/qc-4-regress-qc3a-grade.log 2>&1; echo QC3A_GRADE_RERUN_EXIT=$?
python3 $H/qc3_grade_summary.py $H/qc-4-regress-qc3a-grade.csv > $H/qc-4-regress-qc3a-summary.log 2>&1; echo SUMMARY_EXIT=$?
echo AESIR_RUNS_DONE
