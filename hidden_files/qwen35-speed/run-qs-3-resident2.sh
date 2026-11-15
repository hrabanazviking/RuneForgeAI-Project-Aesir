#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-pack
export PATH="$HOME/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
H=hidden_files/qwen35-speed
python3 $H/make_k256_fixture.py > $H/qs-3-k256-fixture.log 2>&1; echo FIXTURE_EXIT=$?
./.aesir/aesir quantize $H/fixtures/qwen35_k256_q8.gguf $H/fixtures/qwen35_k256_q4km.gguf --to q4_k_m --streaming --fit legacy > $H/qs-3-k256-convert.log 2>&1; echo CONVERT_EXIT=$?
ls -l $H/fixtures/
$H/test_qwen35_resident_k_qs_3 $H/fixtures/qwen35_k256_q8.gguf $H/fixtures/qwen35_k256_q4km.gguf > $H/qs-3-resident-k-test.log 2>&1; echo K_TEST_EXIT=$?
tail -n 30 $H/qs-3-resident-k-test.log
echo QS3_RESIDENT2_DONE
