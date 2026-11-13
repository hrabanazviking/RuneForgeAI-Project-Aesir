#!/usr/bin/env bash
# gate_equivalence.sh -- A-080 GPU<->CPU EQUIVALENCE gate.
# Usage: scripts/gate_equivalence.sh [--verify-blocking]
#
# Runs the standalone A-080 driver (aesir_engine/a080_driver.mojo)
# on the real GPU path: VulkanSampling greedy vs the CPU oracle
# (dispatch-counter evidence) and the A-067 real-model GPU decode
# vs the CPU engine's teacher-forcing rows, every position
# verdicted through core/equivalence_gate.mojo (the A-078
# classifier on the A-045 parity band; pass <=> real == 0 AND
# invalid == 0). Device identity is enforced inside the cases:
# AMD Radeon 8060S (RADV STRIX_HALO) only, llvmpipe refused.
# On a host without that device/fixture the device sections
# report honest-absent and the gate passes on the host sections
# alone, claiming no equivalence evidence for that host.
#
# Judge (strict): the driver log must contain A080_DRIVER_ALL_PASS
# and an EQUIV_REAL line with real=0; the process exit must be 0.
# Any real divergence raises inside the driver (no pass line) and
# FAILS this gate with exit 1 -- that is the banking block the
# roadmap requires, enforced again by the keeper at the seat.
#
# --verify-blocking: judge self-check. Feeds the judge a synthetic
# PASS log and a synthetic REGRESSION log (real=1, no pass line)
# and requires PASS then FAIL. Proves the block without touching
# the engine.
set -u
cd "$(dirname "$0")/.." || exit 99
export PATH="$HOME/.pixi/bin:$PATH"
LOGDIR="/tmp"; [ -d hidden_files ] && LOGDIR="hidden_files"
DRIVER_LOG="$LOGDIR/gate_equiv_driver.log"

judge_driver_log() {
  local log="$1"
  [ -f "$log" ] || { echo "EQUIV: FAIL (driver log $log missing)"; return 1; }
  grep -q 'A080_DRIVER_ALL_PASS' "$log" || { echo "EQUIV: FAIL (no A080_DRIVER_ALL_PASS in $log)"; return 1; }
  grep -q 'EQUIV_REAL' "$log" || { echo "EQUIV: FAIL (no EQUIV_REAL line in $log)"; return 1; }
  grep 'EQUIV_REAL' "$log" | grep -q 'real=0' || { echo "EQUIV: FAIL (EQUIV_REAL does not report real=0)"; return 1; }
  grep 'EQUIV_REAL' "$log" | grep -q 'invalid=0' || { echo "EQUIV: FAIL (EQUIV_REAL does not report invalid=0)"; return 1; }
  return 0
}

if [ "${1:-}" = "--verify-blocking" ]; then
  ok_log=$(mktemp); bad_log=$(mktemp)
  printf 'EQUIV_REAL absent=0 positions=7 real=0 invalid=0 gate=PASS\nA080_DRIVER_ALL_PASS\n' > "$ok_log"
  printf 'EQUIV_REAL absent=0 positions=7 real=1 invalid=0 gate=FAIL\n' > "$bad_log"
  judge_driver_log "$ok_log" >/dev/null || { echo "EQUIV VERIFY-BLOCKING: FAIL (clean log rejected)"; rm -f "$ok_log" "$bad_log"; exit 1; }
  if judge_driver_log "$bad_log" >/dev/null; then echo "EQUIV VERIFY-BLOCKING: FAIL (regression log ACCEPTED -- gate does not block)"; rm -f "$ok_log" "$bad_log"; exit 1; fi
  rm -f "$ok_log" "$bad_log"
  echo "EQUIV VERIFY-BLOCKING: PASS (clean log passes, regression log blocked)"
  exit 0
fi

start=$(date +%s)
echo "GATE_EQUIV: A-080 driver (gfx1151, 6 canonical shims staged)"
python3 scripts/build_shaders.py > "$LOGDIR/gate_equiv_shaders.log" 2>&1 || { echo "GATE_EQUIV RESULT: FAIL (shader pipeline)"; exit 1; }
STAGING="$(mktemp -d)"
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$STAGING/libaesir_hailo10h.so" || { echo "GATE_EQUIV RESULT: FAIL (hailo shim)"; exit 1; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$STAGING/libaesir_par.so" -lpthread || { echo "GATE_EQUIV RESULT: FAIL (par shim)"; exit 1; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$STAGING/libaesir_hip.so" -ldl || { echo "GATE_EQUIV RESULT: FAIL (hip shim)"; exit 1; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$STAGING/libaesir_vulkan.so" -ldl || { echo "GATE_EQUIV RESULT: FAIL (vulkan shim)"; exit 1; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$STAGING/libaesir_zc.so" -ldl || { echo "GATE_EQUIV RESULT: FAIL (zc shim)"; exit 1; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$STAGING/libaesir_aff.so" || { echo "GATE_EQUIV RESULT: FAIL (aff shim)"; exit 1; }
timeout 600 pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$STAGING" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff aesir_engine/a080_driver.mojo > "$DRIVER_LOG" 2>&1
mojo_rc=$?
elapsed=$(( $(date +%s) - start ))
echo "GATE_EQUIV: driver rc=$mojo_rc elapsed ${elapsed}s; log $DRIVER_LOG"
grep 'EQUIV_' "$DRIVER_LOG" || true
[ "$mojo_rc" -eq 0 ] || { echo "GATE_EQUIV RESULT: FAIL (driver exit $mojo_rc -- regression or harness failure; banking BLOCKED)"; exit 1; }
judge_driver_log "$DRIVER_LOG" || { echo "GATE_EQUIV RESULT: FAIL (judge -- banking BLOCKED)"; exit 1; }
echo "GATE_EQUIV RESULT: PASS (${elapsed}s)"
exit 0
