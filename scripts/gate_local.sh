#!/usr/bin/env bash
# gate_local.sh -- A-117 LOCAL full-tier gate for Project Aesir on the Z13.
# Usage: scripts/gate_local.sh
# ONE local command. No GitHub Actions, no CI, no network gate --
# house law (manual-only workflows). The keeper runs this as the
# full-tier gate.
#
# Phases, in order, each timed:
#   1. matrix -- A-114 full matrix runner
#      (aesir_engine/tests/bench_matrix_a114.mojo): 228 cells,
#      a verdict per cell. Judged complete iff 228 MX_CELL lines,
#      the summary counts sum to 228, and the counts equal the
#      A-114 filed account (faithful 4 / near_tie 2 / divergent 2 /
#      artifact 2 / fixture_limited 9 / not_graded 209) with
#      MOJO_EXIT=0. Divergent/artifact cells are filed verdicts,
#      not gate failures (policy: aesir_engine/core/local_gate.mojo).
#   2. suite -- E-MASTER (aesir_engine/tests/run_all.mojo) under
#      the gfx1151 compile target with the seat staging shims.
#      gfx1151 is a compile target, not an execution claim.
#      Judged green-to-baseline iff a [SUMMARY] exists, counts
#      sum, skipped == 2 (pre-declared), and failed == 0 or the
#      sole failure is gguf.tensor_directory_interface (J-022).
# Preflight: refuses to start (exit 2) if another run_all or
# bench_matrix process is already running -- a full suite never
# runs concurrently with another team or a seat gate.
# Logs: hidden_files/a117_gate_matrix.log,
# hidden_files/a117_gate_suite.log, and the timed verdict in
# hidden_files/a117_gate.log (also echoed to stdout).
# Exit: 0 PASS, 1 FAIL, 2 refused (collision / staging failure).
# Integration points (honest): A-115 policy (not banked at
# A-117 build time) can refine the suite judge; on FAIL the
# keeper's next tool is A-116 first-divergence localisation.
set -u
cd "$(dirname "$0")/.." || exit 99
export PATH="$HOME/.pixi/bin:$PATH"
LOGDIR="/tmp"; [ -d hidden_files ] && LOGDIR="hidden_files"
MLOG="$LOGDIR/a117_gate_matrix.log"
SLOG="$LOGDIR/a117_gate_suite.log"
GLOG="$LOGDIR/a117_gate.log"
: > "$GLOG"
note() { echo "$*" | tee -a "$GLOG"; }
if pgrep -f 'run_all.mojo|bench_matrix_a114.mojo' > /dev/null 2>&1; then
  note "GATE_LOCAL RESULT: REFUSED (another suite/matrix run in progress)"
  exit 2
fi
staging=$(mktemp -d)
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> "$GLOG" 2>&1 || { note "GATE_LOCAL RESULT: REFUSED (stub staging failed)"; exit 2; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> "$GLOG" 2>&1 || { note "GATE_LOCAL RESULT: REFUSED (par staging failed)"; exit 2; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> "$GLOG" 2>&1 || { note "GATE_LOCAL RESULT: REFUSED (hip staging failed)"; exit 2; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> "$GLOG" 2>&1 || { note "GATE_LOCAL RESULT: REFUSED (vulkan staging failed)"; exit 2; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> "$GLOG" 2>&1 || { note "GATE_LOCAL RESULT: REFUSED (zc staging failed)"; exit 2; }
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" >> "$GLOG" 2>&1 || { note "GATE_LOCAL RESULT: REFUSED (aff staging failed)"; exit 2; }
MOJO=(pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff)
gate_start=$(date +%s)
note "GATE_LOCAL: start $(date -Is) host=$(hostname) head=$(git rev-parse HEAD 2>/dev/null)"
# Phase 1: matrix
m_start=$(date +%s)
/usr/bin/time -v "${MOJO[@]}" aesir_engine/tests/bench_matrix_a114.mojo > "$MLOG" 2>&1; m_rc=$?
m_elapsed=$(( $(date +%s) - m_start ))
cells=$(grep -c '^MX_CELL' "$MLOG" || true)
msum=$(grep -oP 'total=\K[0-9]+' "$MLOG" | head -1)
note "GATE_LOCAL: matrix rc=$m_rc cells=${cells:-0} summary_total=${msum:-none} elapsed ${m_elapsed}s log=$MLOG"
matrix_ok=0
if [ "$m_rc" -eq 0 ] && [ "${cells:-0}" = "228" ]; then
  if grep -q 'faithful=4 near_tie=2 divergent=2 artifact=2 fixture_limited=9 not_graded=209' "$MLOG" && grep -q 'A114_BENCH_DONE cells= 228' "$MLOG"; then matrix_ok=1; fi
fi
[ "$matrix_ok" -eq 1 ] && note "GATE_LOCAL: matrix COMPLETE (228 cells, filed counts)" || note "GATE_LOCAL: matrix INCOMPLETE"
# Phase 2: suite
s_start=$(date +%s)
/usr/bin/time -v "${MOJO[@]}" aesir_engine/tests/run_all.mojo > "$SLOG" 2>&1; s_rc=$?
s_elapsed=$(( $(date +%s) - s_start ))
passed=$(grep -oP '\[SUMMARY\] Passed: \K[0-9]+' "$SLOG" || true)
failed=$(grep -oP '\[SUMMARY\] Failed: \K[0-9]+' "$SLOG" || true)
skipped=$(grep -oP '\[SUMMARY\] Skipped: \K[0-9]+' "$SLOG" || true)
total=$(grep -oP '\[SUMMARY\] Total: \K[0-9]+' "$SLOG" || true)
note "GATE_LOCAL: suite rc=$s_rc summary: ${passed:-?} passed / ${failed:-?} failed / ${skipped:-?} skipped / ${total:-?} total elapsed ${s_elapsed}s log=$SLOG"
suite_ok=0
if [ -n "${passed:-}" ] && [ "$((passed + failed + skipped))" = "$total" ] && [ "$skipped" = "2" ]; then
  if [ "$failed" = "0" ]; then suite_ok=1; fi
  if [ "$failed" = "1" ] && grep -q '\[CASE FAIL\] gguf.tensor_directory_interface' "$SLOG"; then suite_ok=1; note "GATE_LOCAL: sole failure is the tolerated gguf.tensor_directory_interface (J-022 drift)"; fi
fi
[ "$suite_ok" -eq 1 ] && note "GATE_LOCAL: suite GREEN-TO-BASELINE" || note "GATE_LOCAL: suite NOT GREEN"
total_elapsed=$(( $(date +%s) - gate_start ))
note "GATE_LOCAL: timing matrix=${m_elapsed}s suite=${s_elapsed}s total=${total_elapsed}s"
if [ "$matrix_ok" -eq 1 ] && [ "$suite_ok" -eq 1 ]; then
  note "GATE_LOCAL RESULT: PASS (${total_elapsed}s)"
  exit 0
fi
note "GATE_LOCAL RESULT: FAIL (${total_elapsed}s)"
exit 1
