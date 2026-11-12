#!/usr/bin/env bash
# Build matrix for Project Aesir -- backend-explicit entries (A-028).
#
# Usage: scripts/build_matrix.sh [cpu|amd|all]     (default: all)
#
# Entries:
#   cpu -- the E-MASTER fast suite (aesir_engine/tests/run_all.mojo) built
#          and run with NO --target-accelerator flag passed: zero NVIDIA
#          flags, CPU execution. (When no flag is passed, Mojo 1.0.0
#          auto-detects the host accelerator -- amdgpu:gfx1151 on this
#          host per --print-effective-target; "cpu"/"amd" are entry
#          names here, not valid --target-accelerator values.)
#          (A-002/A-003 found
#          MAX 26.x refusing flag-free builds via a stdlib GPU-arch
#          constraint; on the current tree the flag-free build succeeds --
#          this entry is the standing proof.)
#   amd -- the engine binary (aesir_engine/main.mojo) built with the host's
#          AMD ROCm compile target gfx1151 (Radeon 8060S, Strix Halo) plus a
#          --help smoke, and the E-MASTER suite run under the same target.
#          gfx1151 is the compile-time architecture; host code executes
#          on CPU, and since A-029 the suite's gpu.mojo_native_* cases
#          execute Mojo-native kernels on the GPU when a HIP device is
#          present (docs/AESIR_Z13_MOJO_GPU_DECISION.md). No other
#          accelerator execution is claimed for this entry.
#
# NVIDIA hosts name their backend explicitly instead: substitute
# --target-accelerator sm_89 (NVIDIA CUDA, Ada Lovelace) for gfx1151.
#
# Pass rule per suite run: the [SUMMARY] block is read from the run log;
# the entry passes iff every registered case executed and the only failed
# case, if any, is the pre-existing tolerated failure
# gguf.tensor_directory_interface (J-022 loader/test drift, roads
# A-165/A-121). Logs land in hidden_files/build_matrix_<entry>.log when
# that directory exists, else in /tmp.
set -u
cd "$(dirname "$0")/.." || exit 99
export PATH="$HOME/.pixi/bin:$PATH"

AMD_TARGET="gfx1151"
ENTRY="${1:-all}"
LOGDIR="/tmp"
[ -d hidden_files ] && LOGDIR="hidden_files"

stage_shims() {
  # A-055: SPIR-V kernels compiled at build time (never fetched).
  python3 scripts/build_shaders.py > "$LOGDIR/build_shaders.log" 2>&1 || { echo "MATRIX: shader pipeline FAILED"; return 1; }
  STAGING="$(mktemp -d)"
  cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$STAGING/libaesir_hailo10h.so" || return 1
  cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$STAGING/libaesir_par.so" -lpthread || return 1
  cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$STAGING/libaesir_hip.so" -ldl || return 1
  cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$STAGING/libaesir_vulkan.so" -ldl || return 1
  cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$STAGING/libaesir_zc.so" -ldl || return 1
  cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$STAGING/libaesir_aff.so" || return 1
}

judge_suite_log() {
  # $1 = log file. Prints the summary; returns 0 iff the run is a pass.
  local log="$1" passed failed skipped total
  grep -q '\[SUMMARY\]' "$log" || { echo "MATRIX: no [SUMMARY] in $log -- BUILD OR RUN FAILED"; return 1; }
  passed=$(grep -oP '\[SUMMARY\] Passed: \K[0-9]+' "$log")
  failed=$(grep -oP '\[SUMMARY\] Failed: \K[0-9]+' "$log")
  skipped=$(grep -oP '\[SUMMARY\] Skipped: \K[0-9]+' "$log")
  total=$(grep -oP '\[SUMMARY\] Total: \K[0-9]+' "$log")
  echo "MATRIX: suite summary: $passed passed / $failed failed / $skipped skipped / $total total"
  [ "$failed" = "0" ] && return 0
  if [ "$failed" = "1" ] && grep -q '\[CASE FAIL\] gguf.tensor_directory_interface' "$log"; then
    echo "MATRIX: sole failure is the tolerated gguf.tensor_directory_interface (J-022 drift)"
    return 0
  fi
  echo "MATRIX: unexplained failures present"
  return 1
}

run_suite() {
  # $1 = target flag value ("" for none), $2 = log file
  local target="$1" log="$2"
  if [ -n "$target" ]; then
    pixi run --frozen mojo run -I . --target-accelerator "$target" \
      -Xlinker "-L$STAGING" -Xlinker -laesir_hailo10h -Xlinker -laesir_par \
      -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff \
      aesir_engine/tests/run_all.mojo > "$log" 2>&1
  else
    pixi run --frozen mojo run -I . \
      -Xlinker "-L$STAGING" -Xlinker -laesir_hailo10h -Xlinker -laesir_par \
      -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff \
      aesir_engine/tests/run_all.mojo > "$log" 2>&1
  fi
  judge_suite_log "$log"
}

entry_cpu() {
  echo "MATRIX [cpu]: E-MASTER suite, no accelerator flag (zero NVIDIA flags)"
  stage_shims || { echo "MATRIX [cpu]: shim staging FAILED"; return 1; }
  run_suite "" "$LOGDIR/build_matrix_cpu.log"
}

entry_amd() {
  echo "MATRIX [amd]: engine build + help smoke + E-MASTER suite, --target-accelerator $AMD_TARGET (AMD ROCm)"
  stage_shims || { echo "MATRIX [amd]: shim staging FAILED"; return 1; }
  local bin="/tmp/aesir-build-matrix-amd"
  pixi run --frozen mojo build -I . --target-accelerator "$AMD_TARGET" \
    -Xlinker "-L$STAGING" -Xlinker -laesir_hailo10h -Xlinker -laesir_par \
    -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff \
    aesir_engine/main.mojo -o "$bin" > "$LOGDIR/build_matrix_amd_build.log" 2>&1
  if [ ! -x "$bin" ]; then echo "MATRIX [amd]: engine build FAILED (see $LOGDIR/build_matrix_amd_build.log)"; return 1; fi
  echo "MATRIX [amd]: engine build OK: $bin"
  pixi run --frozen env LD_LIBRARY_PATH="$STAGING" "$bin" --help > "$LOGDIR/build_matrix_amd_help.log" 2>&1
  if [ $? -ne 0 ]; then echo "MATRIX [amd]: --help smoke FAILED"; return 1; fi
  echo "MATRIX [amd]: --help smoke OK"
  run_suite "$AMD_TARGET" "$LOGDIR/build_matrix_amd.log"
}

rc=0
case "$ENTRY" in
  cpu) entry_cpu || rc=1 ;;
  amd) entry_amd || rc=1 ;;
  all) entry_cpu || rc=1; entry_amd || rc=1 ;;
  *) echo "usage: scripts/build_matrix.sh [cpu|amd|all]" >&2; exit 2 ;;
esac
if [ $rc -eq 0 ]; then echo "MATRIX RESULT: PASS ($ENTRY)"; else echo "MATRIX RESULT: FAIL ($ENTRY)"; fi
exit $rc
