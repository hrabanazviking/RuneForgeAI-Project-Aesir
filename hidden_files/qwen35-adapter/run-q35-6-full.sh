#!/usr/bin/env bash
# Q35-6 full driver: engine compile + HIP executor test + HIP
# session reference + CPU regressions (Q35-1, Q35-2, Q35-3a,
# Q35-3r, Q35-4a session, Q35-5 snapshot) + ripple probe.
set -x
cd /home/volmarr/aesir-q35-6
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
FX=aesir_engine/tests/fixtures
REAL=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
grep MemAvailable /proc/meminfo
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/main.mojo -o .aesir/aesir
echo ENGINE_BUILD_EXIT=$?
for t in test_qwen35_hip_q35_6 test_qwen35_hip_session_q35_6 test_qwen35_loader_q35_1 test_qwen35_registry_q35_2 test_qwen35_forward_q35_3 test_qwen35_resident_q35_3r test_qwen35_session_q35_4 test_qwen35_snapshot_q35_5 probe_qwen35_runtime_ripple_q35_2; do
  pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/$t.mojo -o hidden_files/qwen35-adapter/$t
  echo BUILD_$t=$?
done
A=hidden_files/qwen35-adapter
$A/test_qwen35_hip_q35_6 $FX/qwen35_forward.gguf > $A/q35-6-test3.log 2>&1; echo HIP_TEST_RUN=$?
$A/test_qwen35_hip_session_q35_6 $FX/qwen35_forward.gguf > $A/q35-6-hipsession.log 2>&1; echo HIP_SESSION_RUN=$?
$A/test_qwen35_loader_q35_1 $FX/qwen35_tiny.gguf $FX/qwen35_tiny_bad_qkv.gguf $FX/qwen35_tiny_type_probe.gguf > $A/q35-6-regress-q35-1.log 2>&1; echo Q351_RUN=$?
$A/test_qwen35_registry_q35_2 $REAL > $A/q35-6-regress-q35-2.log 2>&1; echo Q352_RUN=$?
$A/test_qwen35_forward_q35_3 $FX/qwen35_forward.gguf > $A/q35-6-regress-q35-3.log 2>&1; echo Q353_RUN=$?
$A/test_qwen35_resident_q35_3r $FX/qwen35_forward.gguf $FX/qwen35_forward_f16probe.gguf > $A/q35-6-regress-q35-3r.log 2>&1; echo Q353R_RUN=$?
$A/test_qwen35_session_q35_4 $FX/qwen35_forward.gguf > $A/q35-6-regress-q35-4.log 2>&1; echo Q354_RUN=$?
$A/test_qwen35_snapshot_q35_5 $FX/qwen35_forward.gguf > $A/q35-6-regress-q35-5.log 2>&1; echo Q355_RUN=$?
$A/probe_qwen35_runtime_ripple_q35_2 $REAL $FX/qwen35_forward.gguf > $A/q35-6-ripple.log 2>&1; echo RIPPLE_RUN=$?
grep MemAvailable /proc/meminfo
