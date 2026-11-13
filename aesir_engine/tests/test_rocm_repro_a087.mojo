"""ROCm install reproducibility (A-087): the A-005 native install
as a scripted, pinned, native setup.

Acceptance (roadmap A-087): script re-run on the Z13 converges to
the same versions (idempotent). The machinery under test:

- core/rocm_pin.mojo holds the pin table -- all nine packages of
  the A-005 coherent install at their exact dpkg versions (the two
  direct packages alone would NOT be a reproducibility contract:
  apt would be free to re-resolve the dependency/runtime set) --
  plus the pure convergence predicate over an observed snapshot.
- scripts/install_rocm_z13.sh enforces the table on the live box
  in three modes: --check (read-only probes, the default),
  --dry-run (plus an apt simulation proving zero pending changes),
  --apply (the real pinned install; not part of the proof).

Cases:
- pin_table_exact: the table IS the A-005 set, verbatim, unique,
  and hipcc-free (A-005's deliberate exclusion).
- convergence_accepts: the pinned snapshot converges with zero
  drift, and judging it twice gives the same verdict (the
  predicate is a pure fixed point -- the logic half of
  idempotence).
- convergence_rejects_drift: the NEGATIVE controls -- a bumped
  version, a missing package, a fully wrong snapshot and a short
  snapshot each fail with the exact drift count, so the check
  provably blocks on drift instead of waving it through.
- script_contract: the script read from disk carries the three
  modes, the dpkg/rocminfo/gfx1151 probes and the CONVERGED/DRIFT
  verdict lines, and no container runtime anywhere.
- script_core_sync: every core pin argument (name=version) appears
  verbatim in the script, so script and table cannot drift apart
  without failing this suite.

The live convergence proof itself (script --check twice + one
--dry-run on purpleraider, all read-only) is filed in
hidden_files/A087_LEDGER.md; these cases pin the machinery that
proof relies on, on any host.
"""
from core.rocm_pin import (
    ROCM_PIN_COUNT,
    rocm_drift_count,
    rocm_pin_arg,
    rocm_pin_index,
    rocm_pin_name,
    rocm_pin_version,
    rocm_snapshot_converged,
    rocm_versions_equal,
)


def _read_script(name: String) raises -> String:
    try:
        with open("scripts/" + name, "r") as f:
            return f.read()
    except:
        with open("../scripts/" + name, "r") as f:
            return f.read()


def _pinned_snapshot() -> List[String]:
    var snap = List[String]()
    for i in range(ROCM_PIN_COUNT):
        snap.append(rocm_pin_version(i))
    return snap^


def test_rocm_repro_pin_table() raises:
    print("--- Testing ROCm pin table exactness (A-087) ---")
    if ROCM_PIN_COUNT != 9:
        raise Error("A087: pin count must be 9 (the A-005 coherent set)")
    var names = List[String]()
    names.append(String("rocminfo"))
    names.append(String("libamdhip64-dev"))
    names.append(String("libamd-comgr-rocm-dev"))
    names.append(String("libhiprtc-builtins7"))
    names.append(String("libhiprtc7"))
    names.append(String("libhsa-runtime-dev"))
    names.append(String("libamdhip64-7"))
    names.append(String("libhsa-runtime64-1"))
    names.append(String("libamd-comgr3-rocm"))
    var versions = List[String]()
    versions.append(String("10.0-0ubuntu2"))
    versions.append(String("10.0-0ubuntu3"))
    versions.append(String("10.0+dfsg-0ubuntu1"))
    versions.append(String("10.0-0ubuntu3"))
    versions.append(String("10.0-0ubuntu3"))
    versions.append(String("10.0+dfsg-0ubuntu2"))
    versions.append(String("10.0-0ubuntu3"))
    versions.append(String("10.0+dfsg-0ubuntu2"))
    versions.append(String("10.0+dfsg-0ubuntu1"))
    for i in range(ROCM_PIN_COUNT):
        if rocm_pin_name(i) != names[i]:
            raise Error("A087: pin name drift at index " + String(i))
        if rocm_pin_version(i) != versions[i]:
            raise Error("A087: pin version drift at index " + String(i))
        if rocm_pin_arg(i) != names[i] + String("=") + versions[i]:
            raise Error("A087: pin arg malformed at index " + String(i))
        if rocm_pin_index(names[i]) != i:
            raise Error("A087: pin index lookup broken at index " + String(i))
        for j in range(i):
            if names[j] == names[i]:
                raise Error("A087: duplicate pin name " + names[i])
    if rocm_pin_name(ROCM_PIN_COUNT) != String(""):
        raise Error("A087: out-of-range pin name must be empty")
    if rocm_pin_index(String("hipcc")) != -1:
        raise Error("A087: hipcc must stay excluded (A-005 deliberate)")
    print("pin table: 9/9 A-005 pins exact, unique, hipcc excluded")


def test_rocm_repro_convergence_accepts() raises:
    print("--- Testing ROCm convergence accepts pinned snapshot (A-087) ---")
    var snap = _pinned_snapshot()
    if not rocm_snapshot_converged(snap):
        raise Error("A087: the pinned snapshot itself must converge")
    if rocm_drift_count(snap) != 0:
        raise Error("A087: pinned snapshot drift must be 0")
    # Idempotent judging: the same snapshot verdicted again gives
    # the same result -- convergence is a fixed point.
    if not rocm_snapshot_converged(snap) or rocm_drift_count(snap) != 0:
        raise Error("A087: convergence judging is not deterministic")
    for i in range(ROCM_PIN_COUNT):
        if not rocm_versions_equal(snap[i], rocm_pin_version(i)):
            raise Error("A087: version equality broken at index " + String(i))
    print("convergence: pinned snapshot converges, drift 0, judging idempotent")


def test_rocm_repro_convergence_rejects() raises:
    print("--- Testing ROCm convergence rejects drift (A-087) ---")
    var bumped = _pinned_snapshot()
    bumped[0] = String("10.0-0ubuntu3")
    if rocm_snapshot_converged(bumped):
        raise Error("A087: a bumped rocminfo version must NOT converge")
    if rocm_drift_count(bumped) != 1:
        raise Error("A087: single bump drift count must be exactly 1")
    var missing = _pinned_snapshot()
    missing[6] = String("")
    if rocm_snapshot_converged(missing):
        raise Error("A087: a missing package must NOT converge")
    if rocm_drift_count(missing) != 1:
        raise Error("A087: single missing drift count must be exactly 1")
    var wrong = List[String]()
    for _i in range(ROCM_PIN_COUNT):
        wrong.append(String("0.0-0"))
    if rocm_snapshot_converged(wrong):
        raise Error("A087: a fully wrong snapshot must NOT converge")
    if rocm_drift_count(wrong) != ROCM_PIN_COUNT:
        raise Error("A087: fully wrong snapshot drift must be total")
    var short = List[String]()
    short.append(rocm_pin_version(0))
    if rocm_snapshot_converged(short):
        raise Error("A087: a short snapshot must NOT converge (fail-closed)")
    if rocm_drift_count(short) != ROCM_PIN_COUNT:
        raise Error("A087: short snapshot drift must be total (fail-closed)")
    print("convergence negative controls: bump/missing/wrong/short all blocked with exact drift counts")


def test_rocm_repro_script_contract() raises:
    print("--- Testing ROCm install script contract (A-087) ---")
    var script = _read_script("install_rocm_z13.sh")
    if "--check" not in script:
        raise Error("A087: script must offer the read-only --check mode")
    if "--dry-run" not in script:
        raise Error("A087: script must offer the --dry-run simulation mode")
    if "--apply" not in script:
        raise Error("A087: script must offer the explicit --apply mode")
    if "dpkg-query" not in script:
        raise Error("A087: script must probe installed versions via dpkg-query")
    if "rocminfo" not in script or "gfx1151" not in script:
        raise Error("A087: script must probe the gfx1151 agent via rocminfo")
    if "apt-get -s" not in script:
        raise Error("A087: dry-run must be an apt simulation (apt-get -s)")
    if "ROCM_REPRO CONVERGED" not in script:
        raise Error("A087: script must print the ROCM_REPRO CONVERGED verdict")
    if "ROCM_REPRO DRIFT" not in script:
        raise Error("A087: script must print the ROCM_REPRO DRIFT verdict")
    if "docker" in script or "Docker" in script:
        raise Error("A087: script must stay native-only, no container runtime")
    print("script contract: 3 modes, dpkg/rocminfo probes, verdict lines, native-only")


def test_rocm_repro_script_sync() raises:
    print("--- Testing ROCm script/core pin sync (A-087) ---")
    var script = _read_script("install_rocm_z13.sh")
    for i in range(ROCM_PIN_COUNT):
        var arg = rocm_pin_arg(i)
        if arg not in script:
            raise Error("A087: script is missing pin argument " + arg)
    if "rocm_pin.mojo" not in script:
        raise Error("A087: script must name its core-table sync partner")
    print("script sync: all 9 pin arguments verbatim in script and core table")
