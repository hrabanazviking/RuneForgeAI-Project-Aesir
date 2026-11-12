#!/usr/bin/env bash
# gate_full.sh -- A-035 FULL test battery for Project Aesir on the Z13.
# Usage: scripts/gate_full.sh
# One command. The full battery is the repo's existing
# scripts/build_matrix.sh "all": BOTH E-MASTER suite entries plus the
# engine build + --help smoke:
#   cpu -- run_all.mojo with NO --target-accelerator flag (CPU path)
#   amd -- aesir_engine/main.mojo built with the host AMD ROCm compile
#          target gfx1151 (Radeon 8060S, Strix Halo), --help smoke,
#          then run_all.mojo under the same target. Host code executes
#          on CPU; gfx1151 is a compile target, not an execution claim
#          (the suite's gpu.mojo_native_* cases may use a HIP device
#          when present -- inherited suite behaviour, not claimed by
#          this gate). No other accelerator execution is claimed.
#
# Pass rule (strict, honest tolerance -- exactly the established
# baseline shape, applied to EACH suite log, nothing else tolerated):
#   * a [SUMMARY] block exists and passed+failed+skipped == total
#   * skipped == 2 (the 2 pre-declared skips)
#   * failed == 0, OR failed == 1 and the sole [CASE FAIL] is
#     gguf.tensor_directory_interface (pre-existing J-022 loader/test
#     drift; roads A-165 primary / A-121)
# Any other failure, any other skip count, a missing summary, a
# failed engine build, or a failed --help smoke FAILS the battery
# (exit 1). The raw suite exits 1 whenever any case fails --
# including the tolerated one -- so this gate judges the logs
# itself; it never swallows the suite's output.
set -u
cd "$(dirname "$0")/.." || exit 99
export PATH="$HOME/.pixi/bin:$PATH"
LOGDIR="/tmp"; [ -d hidden_files ] && LOGDIR="hidden_files"

judge_suite_log() {
  # $1 = log file. Returns 0 iff the run matches the baseline shape.
  local log="$1" passed failed skipped total
  [ -f "$log" ] || { echo "GATE_FULL: FAIL (suite log $log missing)"; return 1; }
  grep -q '\[SUMMARY\]' "$log" || { echo "GATE_FULL: FAIL (no [SUMMARY] in $log)"; return 1; }
  passed=$(grep -oP '\[SUMMARY\] Passed: \K[0-9]+' "$log")
  failed=$(grep -oP '\[SUMMARY\] Failed: \K[0-9]+' "$log")
  skipped=$(grep -oP '\[SUMMARY\] Skipped: \K[0-9]+' "$log")
  total=$(grep -oP '\[SUMMARY\] Total: \K[0-9]+' "$log")
  echo "GATE_FULL: $log summary: $passed passed / $failed failed / $skipped skipped / $total total"
  [ "$((passed + failed + skipped))" = "$total" ] || { echo "GATE_FULL: FAIL ($log counts do not sum to total)"; return 1; }
  [ "$skipped" = "2" ] || { echo "GATE_FULL: FAIL ($log skipped=$skipped, expected the 2 pre-declared skips)"; return 1; }
  if [ "$failed" = "0" ]; then return 0; fi
  if [ "$failed" = "1" ] && grep -q '\[CASE FAIL\] gguf.tensor_directory_interface' "$log"; then
    echo "GATE_FULL: $log sole failure is the tolerated gguf.tensor_directory_interface (J-022 drift)"
    return 0
  fi
  echo "GATE_FULL: FAIL ($log has unexplained failures)"
  return 1
}

start=$(date +%s)
echo "GATE_FULL: full battery (build_matrix all: cpu suite + amd build/smoke/suite)"
scripts/build_matrix.sh all
matrix_rc=$?
elapsed=$(( $(date +%s) - start ))
echo "GATE_FULL: elapsed ${elapsed}s, build_matrix rc=$matrix_rc"
[ "$matrix_rc" -eq 0 ] || { echo "GATE_FULL RESULT: FAIL (build_matrix all failed)"; exit 1; }
judge_suite_log "$LOGDIR/build_matrix_cpu.log" || { echo "GATE_FULL RESULT: FAIL (cpu entry strict judge)"; exit 1; }
judge_suite_log "$LOGDIR/build_matrix_amd.log" || { echo "GATE_FULL RESULT: FAIL (amd entry strict judge)"; exit 1; }
echo "GATE_FULL RESULT: PASS (${elapsed}s)"
exit 0
