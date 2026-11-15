#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-pack
export PATH="$HOME/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
H=hidden_files/qwen35-speed
python3 $H/make_k256_fixture.py > $H/qs-3-k256-fixture.log 2>&1; echo FIXTURE_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_resident_k_qs_3.mojo -o $H/test_qwen35_resident_k_qs_3
echo K_TEST_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_qwen35_resident_q35_3r.mojo -o $H/test_qwen35_resident_q35_3r
echo Q353R_BUILD_EXIT=$?
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/main.mojo -o .aesir/aesir
echo ENGINE_BUILD_EXIT=$?
./.aesir/aesir quantize $H/fixtures/qwen35_k256_q8.gguf $H/fixtures/qwen35_k256_q4km.gguf --to q4_k_m --streaming --fit legacy > $H/qs-3-k256-convert.log 2>&1; echo CONVERT_EXIT=$?
ls -l $H/fixtures/
$H/test_qwen35_resident_k_qs_3 $H/fixtures/qwen35_k256_q8.gguf $H/fixtures/qwen35_k256_q4km.gguf > $H/qs-3-resident-k-test.log 2>&1; echo K_TEST_EXIT=$?
mkdir -p aesir_engine/tests/fixtures
cp /home/volmarr/aesir-q35-3r/aesir_engine/tests/fixtures/qwen35_forward.gguf aesir_engine/tests/fixtures/ 2>/dev/null
cp /home/volmarr/aesir-q35-3r/aesir_engine/tests/fixtures/qwen35_forward_f16probe.gguf aesir_engine/tests/fixtures/ 2>/dev/null
$H/test_qwen35_resident_q35_3r aesir_engine/tests/fixtures/qwen35_forward.gguf aesir_engine/tests/fixtures/qwen35_forward_f16probe.gguf > $H/qs-3-regress-q35-3r.log 2>&1; echo Q353R_REGRESS_EXIT=$?
echo QS3_RESIDENT_DONE
