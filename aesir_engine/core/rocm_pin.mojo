# core/rocm_pin.mojo
# A-087: ROCm install reproducibility -- the pinned package table
# and the convergence predicate for the Z13's native ROCm userland.
#
# A-005 installed the ROCm userland natively (apt, Ubuntu 26.10) as
# one coherent nine-package set and proved it end to end (rocminfo
# gfx1151 agent, unversioned libamdhip64.so loadable, HIP headers,
# AMDGate PASS; hidden_files/A005_LEDGER.md). This module is the
# machine-readable form of that install: the exact pin table plus
# the pure convergence logic the reproducibility script
# (scripts/install_rocm_z13.sh) enforces on the live box.
#
# The pin set is ALL NINE packages, not only the two direct ones:
# pinning just rocminfo + libamdhip64-dev would leave apt free to
# resolve the dependencies and runtime base to whatever the archive
# holds on re-run day, silently changing the HSA/HIP pairing A-005
# proved. The coherent set is the contract.
#
# hipcc is deliberately NOT pinned and NOT installed: A-005 found
# its Ubuntu candidate on an experimental lineage mismatched with
# this ROCm 10.0 userland. The set is the smallest one satisfying
# the A-005 acceptance surface.
#
# Convergence: exact string equality of the installed dpkg version
# against each pin, positionally aligned with this table; an empty
# observed string marks a missing package and counts as drift. A
# snapshot of the wrong length is total drift (fail-closed). The
# predicate is pure and deterministic: the same snapshot judged
# twice gives the same verdict, which is what makes the script's
# re-run idempotent by construction -- convergence is a fixed
# point, and judging it changes nothing.

comptime ROCM_PIN_COUNT = 9


def rocm_pin_name(index: Int) -> String:
    """Pinned package name at `index` (0..ROCM_PIN_COUNT-1);
    empty string for an out-of-range index."""
    if index == 0:
        return String("rocminfo")
    if index == 1:
        return String("libamdhip64-dev")
    if index == 2:
        return String("libamd-comgr-rocm-dev")
    if index == 3:
        return String("libhiprtc-builtins7")
    if index == 4:
        return String("libhiprtc7")
    if index == 5:
        return String("libhsa-runtime-dev")
    if index == 6:
        return String("libamdhip64-7")
    if index == 7:
        return String("libhsa-runtime64-1")
    if index == 8:
        return String("libamd-comgr3-rocm")
    return String("")


def rocm_pin_version(index: Int) -> String:
    """Pinned full dpkg version at `index`, verbatim as A-005
    installed it (upstream + +dfsg suffix where present + Ubuntu
    revision; no epochs exist in this set)."""
    if index == 0:
        return String("10.0-0ubuntu2")
    if index == 1:
        return String("10.0-0ubuntu3")
    if index == 2:
        return String("10.0+dfsg-0ubuntu1")
    if index == 3:
        return String("10.0-0ubuntu3")
    if index == 4:
        return String("10.0-0ubuntu3")
    if index == 5:
        return String("10.0+dfsg-0ubuntu2")
    if index == 6:
        return String("10.0-0ubuntu3")
    if index == 7:
        return String("10.0+dfsg-0ubuntu2")
    if index == 8:
        return String("10.0+dfsg-0ubuntu1")
    return String("")


def rocm_pin_arg(index: Int) -> String:
    """The apt argument for one pin: `name=version`, exactly as
    scripts/install_rocm_z13.sh passes it to apt-get install."""
    return rocm_pin_name(index) + String("=") + rocm_pin_version(index)


def rocm_pin_index(name: String) -> Int:
    """Index of a pinned package by name, or -1 if the package is
    not part of the pinned set."""
    for i in range(ROCM_PIN_COUNT):
        if rocm_pin_name(i) == name:
            return i
    return -1


def rocm_versions_equal(installed: String, pinned: String) -> Bool:
    """One package converges iff its installed dpkg version is
    exactly the pinned string -- no prefix, range or archive-latest
    semantics anywhere in the comparison."""
    return installed == pinned


def rocm_drift_count(observed: List[String]) -> Int:
    """Drift in an observed snapshot aligned with the pin table
    (observed[i] = installed version of pin i, empty = missing).
    A snapshot of the wrong length is total drift (fail-closed):
    a partial probe proves nothing about convergence."""
    if len(observed) != ROCM_PIN_COUNT:
        return ROCM_PIN_COUNT
    var drift = 0
    for i in range(ROCM_PIN_COUNT):
        if not rocm_versions_equal(observed[i], rocm_pin_version(i)):
            drift += 1
    return drift


def rocm_snapshot_converged(observed: List[String]) -> Bool:
    """The reproducibility verdict: a re-run has converged iff
    judging the live snapshot against the pin table finds zero
    drift. Deterministic in the snapshot alone."""
    return rocm_drift_count(observed) == 0
