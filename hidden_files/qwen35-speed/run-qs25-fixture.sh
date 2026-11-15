#!/usr/bin/env bash
cd /home/volmarr/aesir-qs-phase
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims"
QS=hidden_files/qwen35-speed
./$QS/test_qwen35_hip_q35_6.qs25 aesir_engine/tests/fixtures/qwen35_forward.gguf > $QS/qs25-fixture-off.log 2>&1; echo OFF=$?
AESIR_QS_PROFILE=1 ./$QS/test_qwen35_hip_q35_6.qs25 aesir_engine/tests/fixtures/qwen35_forward.gguf > $QS/qs25-fixture-prof1.log 2>&1; echo PROF1=$?
AESIR_QS_PROFILE=2 ./$QS/test_qwen35_hip_q35_6.qs25 aesir_engine/tests/fixtures/qwen35_forward.gguf > $QS/qs25-fixture-prof2.log 2>&1; echo PROF2=$?
./$QS/test_qwen35_hip_session_q35_6.qs25 > $QS/qs25-session-off.log 2>&1; echo SESS=$?
echo QS25_FIXTURE_DONE
