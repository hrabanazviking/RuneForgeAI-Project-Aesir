#!/bin/bash
# A-020 runner (team-06): real-fixture weight residency proof.
# Fixture pinned by sha256 before and after (A-004 ledger pin).
# Runs the A-020 standalone proof and the A-004 E-REAL binary.
cd /home/volmarr/aesir-team-06 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
FIXTURE=/home/volmarr/aesir-team-04/hidden_files/fixtures/stories260K.F16.gguf
LOG=hidden_files/a020_real.log
{
echo "=== A-020 real-fixture run ==="
date -Is; hostname; uname -a
git rev-parse HEAD; git branch --show-current
sha256sum "$FIXTURE"
} > "$LOG" 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> "$LOG"
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> "$LOG" 2>&1; echo "stub_cc_exit=$?" >> "$LOG"
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> "$LOG" 2>&1; echo "par_cc_exit=$?" >> "$LOG"
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> "$LOG" 2>&1; echo "hip_cc_exit=$?" >> "$LOG"
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> "$LOG" 2>&1; echo "vulkan_cc_exit=$?" >> "$LOG"
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan aesir_engine/tests/test_weight_residency_real.mojo "$FIXTURE" >> "$LOG" 2>&1
echo "RESIDENCY_MOJO_EXIT=$?" >> "$LOG"
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan aesir_engine/tests/test_real_gguf.mojo "$FIXTURE" >> "$LOG" 2>&1
echo "EREAL_MOJO_EXIT=$?" >> "$LOG"
sha256sum "$FIXTURE" >> "$LOG"
echo "=== end $(date -Is) ===" >> "$LOG"
