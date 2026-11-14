#!/usr/bin/env bash
cd /home/volmarr/aesir-q35-3r
H=hidden_files/qwen35-adapter
F=aesir_engine/tests/fixtures
REAL27=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
REAL40=/mnt/vault/models/gguf/Qwen3.8-40B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
$H/test_qwen35_resident_q35_3r $F/qwen35_forward.gguf $F/qwen35_forward_f16probe.gguf > $H/q35-3r-test.log 2>&1; echo RESIDENT_TEST_EXIT=$?
$H/test_qwen35_loader_q35_1 $F/qwen35_tiny.gguf $F/qwen35_tiny_bad_qkv.gguf $F/qwen35_tiny_type_probe.gguf > $H/q35-3r-regress-q35-1.log 2>&1; echo Q351_EXIT=$?
$H/test_qwen35_registry_q35_2 $REAL27 > $H/q35-3r-regress-q35-2.log 2>&1; echo Q352_EXIT=$?
$H/test_qwen35_forward_q35_3 $F/qwen35_forward.gguf > $H/q35-3r-regress-q35-3.log 2>&1; echo Q353_EXIT=$?
$H/test_qwen35_session_q35_4 $F/qwen35_forward.gguf > $H/q35-3r-session-test.log 2>&1; echo Q354_SESSION_EXIT=$?
$H/test_qwen35_snapshot_q35_5 $F/qwen35_forward.gguf > $H/q35-3r-regress-q35-5.log 2>&1; echo Q355_SNAPSHOT_EXIT=$?
$H/probe_qwen35_runtime_ripple_q35_2 $REAL27 $F/qwen35_forward.gguf > $H/q35-3r-ripple.log 2>&1; echo RIPPLE_EXIT=$?
/usr/bin/time -v $H/bench_qwen35_resident_footprint_q35_3r $F/qwen35_large.gguf default > $H/q35-3r-footprint-default.log 2>&1; echo FP_DEFAULT_EXIT=$?
/usr/bin/time -v $H/bench_qwen35_resident_footprint_q35_3r $F/qwen35_large.gguf resident > $H/q35-3r-footprint-resident.log 2>&1; echo FP_RESIDENT_EXIT=$?
/usr/bin/time -v $H/bench_qwen35_resident_footprint_q35_3r $F/qwen35_large.gguf materialize > $H/q35-3r-footprint-materialize.log 2>&1; echo FP_MATERIALIZE_EXIT=$?
/usr/bin/time -v $H/probe_qwen35_resident_realfile_q35_3r $REAL27 > $H/q35-3r-realfile-27b.log 2>&1; echo PROBE27_EXIT=$?
/usr/bin/time -v $H/probe_qwen35_resident_realfile_q35_3r $REAL40 > $H/q35-3r-realfile-40b.log 2>&1; echo PROBE40_EXIT=$?
echo ALL_RUNS_DONE
