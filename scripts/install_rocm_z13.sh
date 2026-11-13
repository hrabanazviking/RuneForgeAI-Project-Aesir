#!/usr/bin/env bash
# install_rocm_z13.sh -- A-087 ROCm install reproducibility for the Z13.
#
# Turns the A-005 native install (hidden_files/A005_LEDGER.md) into a
# scripted, pinned, native setup: the exact nine-package ROCm 10.0
# userland set that A-005 proved on purpleraider (Ubuntu 26.10),
# pinned to full dpkg versions. Native apt packages only -- no
# container runtime, ever. hipcc is deliberately NOT part of the set
# (A-005: its Ubuntu candidate is an experimental lineage mismatched
# with this pinned userland).
#
# Modes:
#   --check    (default) Read-only convergence probe: dpkg-query for
#              every pin, rocminfo for the gfx1151 agent, the
#              unversioned libamdhip64.so symlink, ldconfig and the
#              HIP headers. Changes nothing. Exit 0 iff the live
#              system matches every pin exactly (CONVERGED).
#   --dry-run  --check plus an apt simulation
#              (apt-get -s install <pins>): proves a re-run would
#              change nothing (0 upgraded, 0 newly installed,
#              0 to remove). Still changes nothing.
#   --apply    The real install: apt-get install of the nine pinned
#              pkg=version arguments with --allow-downgrades, then
#              the --check probes again. On a converged machine this
#              is a no-op; on a drifted machine it converges exactly
#              those nine packages and nothing else. NOT part of the
#              A-087 proof runs -- the proof is --check twice plus
#              --dry-run, filed in hidden_files/A087_LEDGER.md.
#
# Convergence contract: exact string equality of the installed dpkg
# version against each pin below. Any missing package, any version
# drift, a missing gfx1151 agent, or a missing soname/header is a
# fail-closed DRIFT verdict naming every offender.
set -u
cd "$(dirname "$0")/.." || exit 99

# The pinned set (A-005 coherent install, all nine: 2 direct,
# 4 dependencies, 3 runtime base). Keep in sync with
# aesir_engine/core/rocm_pin.mojo -- the suite enforces the sync
# (tests/test_rocm_repro_a087.mojo, case rocm_repro.script_core_sync).
PINS=(
  "rocminfo=10.0-0ubuntu2"
  "libamdhip64-dev=10.0-0ubuntu3"
  "libamd-comgr-rocm-dev=10.0+dfsg-0ubuntu1"
  "libhiprtc-builtins7=10.0-0ubuntu3"
  "libhiprtc7=10.0-0ubuntu3"
  "libhsa-runtime-dev=10.0+dfsg-0ubuntu2"
  "libamdhip64-7=10.0-0ubuntu3"
  "libhsa-runtime64-1=10.0+dfsg-0ubuntu2"
  "libamd-comgr3-rocm=10.0+dfsg-0ubuntu1"
)

run_check() {
  local drift=0 pin name want got
  for pin in "${PINS[@]}"; do
    name="${pin%%=*}"; want="${pin#*=}"
    got="$(dpkg-query -W -f='${Version}' "$name" 2>/dev/null || true)"
    if [ "$got" = "$want" ]; then
      echo "PIN OK $name $got"
    else
      echo "PIN DRIFT $name want=$want got=${got:-MISSING}"
      drift=$((drift + 1))
    fi
  done
  # Runtime probes (the A-005 acceptance surface).
  if command -v rocminfo >/dev/null 2>&1 && rocminfo 2>/dev/null | grep -q 'gfx1151'; then
    echo "PROBE OK rocminfo gfx1151 agent present"
  else
    echo "PROBE DRIFT rocminfo gfx1151 agent NOT found"
    drift=$((drift + 1))
  fi
  if [ -e /usr/lib/x86_64-linux-gnu/libamdhip64.so ]; then
    echo "PROBE OK libamdhip64.so (unversioned) present"
  else
    echo "PROBE DRIFT libamdhip64.so (unversioned) MISSING"
    drift=$((drift + 1))
  fi
  if ldconfig -p 2>/dev/null | grep -q 'libamdhip64.so'; then
    echo "PROBE OK ldconfig resolves libamdhip64.so"
  else
    echo "PROBE DRIFT ldconfig does not resolve libamdhip64.so"
    drift=$((drift + 1))
  fi
  if [ -f /usr/include/hip/hip_runtime.h ]; then
    echo "PROBE OK HIP headers present (/usr/include/hip/hip_runtime.h)"
  else
    echo "PROBE DRIFT HIP headers MISSING"
    drift=$((drift + 1))
  fi
  if [ "$drift" -eq 0 ]; then
    echo "ROCM_REPRO CONVERGED pins=${#PINS[@]} drift=0"
    return 0
  fi
  echo "ROCM_REPRO DRIFT pins=${#PINS[@]} drift=$drift"
  return 1
}

MODE="${1:---check}"
case "$MODE" in
  --check)
    run_check
    exit $?
    ;;
  --dry-run)
    run_check || { echo "ROCM_REPRO DRY-RUN: FAIL (system drifted, see PIN DRIFT lines)"; exit 1; }
    sim="$(apt-get -s install "${PINS[@]}" 2>&1)"
    sim_rc=$?
    echo "$sim" | grep -E '^[0-9]+ upgraded, [0-9]+ newly installed, [0-9]+ to remove' || true
    [ "$sim_rc" -eq 0 ] || { echo "ROCM_REPRO DRY-RUN: FAIL (apt simulation rc=$sim_rc)"; exit 1; }
    if echo "$sim" | grep -q '^0 upgraded, 0 newly installed, 0 to remove'; then
      echo "ROCM_REPRO DRY-RUN: PASS (re-run would change nothing)"
      exit 0
    fi
    echo "ROCM_REPRO DRY-RUN: FAIL (simulation shows pending changes)"
    exit 1
    ;;
  --apply)
    echo "ROCM_REPRO APPLY: installing the nine pinned packages (native apt)"
    sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades "${PINS[@]}"
    apply_rc=$?
    [ "$apply_rc" -eq 0 ] || { echo "ROCM_REPRO APPLY: FAIL (apt rc=$apply_rc)"; exit 1; }
    run_check || { echo "ROCM_REPRO APPLY: FAIL (post-install check drifted)"; exit 1; }
    echo "ROCM_REPRO APPLY: PASS (converged after install)"
    exit 0
    ;;
  --help|-h)
    echo "Usage: scripts/install_rocm_z13.sh [--check|--dry-run|--apply]"
    exit 0
    ;;
  *)
    echo "ROCM_REPRO: unknown mode '$MODE' (want --check, --dry-run or --apply)" >&2
    exit 2
    ;;
esac
