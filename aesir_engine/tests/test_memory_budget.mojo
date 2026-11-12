"""Memory budget governor (A-023): a configurable cap keeps the
engine from starving the desktop/other work on the shared 128 GB.

The governor (core/memory_budget) is enforced in code: reserve is
checked through checked_span against the cap BEFORE any backing
allocation, refusal raises the MEM-003 taxonomy error and charges
nothing, and spillable requests degrade onto the spill ledger
instead of pushing the machine toward OOM.

Measured evidence, not arithmetic alone: the cap-honoured case
allocates real A-019 HIP managed buffers through allocate_governed
and compares the governor ledger against the zero-copy shim own
live-byte counter (aesir_zc_live_bytes) - two independent accounts
of the same bytes, read on this machine. Present/absent discipline
matches A-019: without a HIP device the governed path must fail
closed (backend error, reservation rolled back, ledger at
baseline) and the case passes as honest-absent.
"""
from core.memory_budget import (
    DECISION_ADMIT,
    DECISION_REFUSE,
    DECISION_SPILL,
    MemoryBudgetConfig,
    MemoryBudgetGovernor,
    allocate_governed,
    free_governed,
    mem_available_bytes,
    parse_meminfo_available_bytes,
)
from core.zero_copy import ZeroCopy, BACKEND_HIP_MANAGED
from core.hip_memory import HipMemory


def _hip_present() -> Bool:
    if not ZeroCopy.hip_available():
        return False
    try:
        return HipMemory.device_count() >= 1
    except:
        return False


def _expect_reserve_raises(
    mut governor: MemoryBudgetGovernor, size_bytes: Int, label: String
) raises:
    var rejected = False
    try:
        governor.reserve(size_bytes)
    except:
        rejected = True
    if not rejected:
        raise Error("expected reserve refusal: " + label)


def test_budget_cap_honoured_measured() raises:
    print("--- Testing budget cap honoured in measured bytes (A-023) ---")
    var config = MemoryBudgetConfig(4 * 1024 * 1024, 0)
    config.validate()
    var governor = MemoryBudgetGovernor(config)
    if not _hip_present():
        var c0 = ZeroCopy.counters()
        var rejected = False
        try:
            var b = allocate_governed(governor, 1024 * 1024, BACKEND_HIP_MANAGED)
            free_governed(governor, b)
        except:
            rejected = True
        if not rejected:
            raise Error("HIP unavailable but governed allocate succeeded")
        if governor.live_bytes != 0:
            raise Error("rollback left the ledger charged after backend failure")
        var c1 = ZeroCopy.counters()
        if c1.hip_live_bytes != c0.hip_live_bytes:
            raise Error("shim live bytes moved on a failed governed allocate")
        print("HIP UNAVAILABLE: governed allocate fail-closed, ledger rolled back: PASS (honest-absent)")
        return
    var c0 = ZeroCopy.counters()
    var b1 = allocate_governed(governor, 1024 * 1024, BACKEND_HIP_MANAGED)
    var b2 = allocate_governed(governor, 2 * 1024 * 1024, BACKEND_HIP_MANAGED)
    var b3 = allocate_governed(governor, 512 * 1024, BACKEND_HIP_MANAGED)
    var expected_live = 1024 * 1024 + 2 * 1024 * 1024 + 512 * 1024
    if governor.live_bytes != expected_live:
        raise Error("governor ledger does not equal the allocated bytes")
    var c1 = ZeroCopy.counters()
    var shim_delta = c1.hip_live_bytes - c0.hip_live_bytes
    if shim_delta != governor.live_bytes:
        raise Error(
            "cap not honoured in measurements: shim live delta "
            + String(shim_delta) + " != governor live "
            + String(governor.live_bytes)
        )
    if governor.live_bytes > config.cap_bytes:
        raise Error("live bytes exceeded the configured cap")
    print(
        "MEASURED cap honoured: governor live " + String(governor.live_bytes)
        + " == shim live delta " + String(shim_delta) + " under cap "
        + String(config.cap_bytes)
    )
    free_governed(governor, b2)
    var c2 = ZeroCopy.counters()
    if c2.hip_live_bytes - c0.hip_live_bytes != governor.live_bytes:
        raise Error("shim/governor accounts diverged after a governed free")
    free_governed(governor, b1)
    free_governed(governor, b3)
    if governor.live_bytes != 0:
        raise Error("ledger did not return to baseline after governed frees")
    var c3 = ZeroCopy.counters()
    if c3.hip_live_bytes != c0.hip_live_bytes:
        raise Error("shim live bytes did not return to baseline")
    print("PASS: measured accounts agree and return to baseline")


def test_budget_refusal_fail_closed() raises:
    print("--- Testing budget refusal is fail-closed (A-023) ---")
    var governor = MemoryBudgetGovernor(MemoryBudgetConfig(1024 * 1024, 0))
    governor.reserve(512 * 1024)
    _expect_reserve_raises(governor, 600 * 1024, "beyond remaining")
    if governor.live_bytes != 512 * 1024:
        raise Error("a refused reserve charged the ledger")
    if governor.refusal_count != 1:
        raise Error("refusal was not counted")
    _expect_reserve_raises(governor, 2 * 1024 * 1024, "single request over cap")
    _expect_reserve_raises(governor, 0, "zero size")
    _expect_reserve_raises(governor, -4096, "negative size")
    if governor.refusal_count != 4:
        raise Error("refusal counter mismatch")
    # Governed path: refusal happens before allocation, proved by the
    # independent shim counters not moving at all.
    var c0 = ZeroCopy.counters()
    var rejected = False
    try:
        var b = allocate_governed(governor, 4 * 1024 * 1024, BACKEND_HIP_MANAGED)
        free_governed(governor, b)
    except:
        rejected = True
    if not rejected:
        raise Error("governed allocate beyond cap was not refused")
    var c1 = ZeroCopy.counters()
    if c1.hip_allocs != c0.hip_allocs or c1.hip_live_bytes != c0.hip_live_bytes:
        raise Error("a refused governed allocate reached the backend")
    if governor.decide(4 * 1024 * 1024, False) != DECISION_REFUSE:
        raise Error("decide did not refuse an over-cap non-spillable request")
    governor.release(512 * 1024)
    if governor.live_bytes != 0:
        raise Error("ledger not at baseline at end of refusal case")
    print("PASS: refusals raise MEM-003, charge nothing, allocate nothing")


def test_budget_spill_degradation() raises:
    print("--- Testing budget spill degradation under pressure (A-023) ---")
    var governor = MemoryBudgetGovernor(MemoryBudgetConfig(2 * 1024 * 1024, 0))
    var admitted = 0
    var spilled = 0
    for _ in range(12):
        var verdict = governor.admit_or_spill(256 * 1024, True)
        if verdict == DECISION_ADMIT:
            admitted += 1
        elif verdict == DECISION_SPILL:
            spilled += 1
        else:
            raise Error("spillable request was refused instead of degrading")
    if admitted != 8 or spilled != 4:
        raise Error("pressure split mismatch: admitted/spilled")
    if governor.live_bytes != 2 * 1024 * 1024:
        raise Error("live bytes do not equal the cap under pressure")
    if governor.spilled_live_bytes != 4 * 256 * 1024:
        raise Error("spill ledger mismatch under pressure")
    _expect_reserve_raises(governor, 1024, "non-spillable under pressure")
    var big = governor.admit_or_spill(8 * 1024 * 1024, True)
    if big != DECISION_SPILL:
        raise Error("single over-cap spillable request did not spill")
    governor.release_spilled(8 * 1024 * 1024)
    governor.release_spilled(4 * 256 * 1024)
    if governor.spilled_live_bytes != 0:
        raise Error("spill ledger did not return to baseline")
    print("PASS: engine degrades by spilling/refusing, never OOMs, never crashes")


def test_budget_configurability() raises:
    print("--- Testing budget configurability (A-023) ---")
    var tight = MemoryBudgetGovernor(MemoryBudgetConfig(1024 * 1024, 0))
    var roomy = MemoryBudgetGovernor(MemoryBudgetConfig(8 * 1024 * 1024, 0))
    tight.reserve(768 * 1024)
    roomy.reserve(768 * 1024)
    _expect_reserve_raises(tight, 512 * 1024, "tight cap refuses")
    roomy.reserve(512 * 1024)
    if roomy.live_bytes != 768 * 1024 + 512 * 1024:
        raise Error("roomy cap did not admit what the tight cap refused")
    # Invalid configurations are refused at validation, fail-closed.
    var bad_configs = 0
    try:
        MemoryBudgetConfig(0, 0).validate()
    except:
        bad_configs += 1
    try:
        MemoryBudgetConfig(1024, 1024).validate()
    except:
        bad_configs += 1
    try:
        MemoryBudgetConfig(1024, -1).validate()
    except:
        bad_configs += 1
    if bad_configs != 3:
        raise Error("invalid budget configurations were accepted")
    # Effective cap under a known availability figure (pure function).
    var config = MemoryBudgetConfig(1000, 200)
    if config.effective_cap_bytes(10000) != 1000:
        raise Error("effective cap should be the configured cap when roomy")
    if config.effective_cap_bytes(900) != 700:
        raise Error("effective cap should be available minus reserve")
    if config.effective_cap_bytes(100) != 0:
        raise Error("effective cap should floor at zero under pressure")
    if config.effective_cap_bytes(-1) != 1000:
        raise Error("unknown availability must leave the configured cap")
    var defaults = MemoryBudgetConfig.default_config()
    defaults.validate()
    if defaults.cap_bytes <= defaults.reserve_bytes:
        raise Error("default config is not self-consistent")
    print("PASS: caps are configurable; invalid configs fail closed")


def test_budget_accounting_baseline() raises:
    print("--- Testing budget accounting returns to baseline (A-023) ---")
    var governor = MemoryBudgetGovernor(MemoryBudgetConfig(4 * 1024 * 1024, 0))
    governor.reserve(1024 * 1024)
    governor.reserve(512 * 1024)
    if governor.utilisation_ppm() != (1536 * 1024 * 1000000) // (4 * 1024 * 1024):
        raise Error("utilisation ppm mismatch")
    governor.release(512 * 1024)
    _ = governor.admit_or_spill(2 * 1024 * 1024, True)
    if governor.peak_bytes != 3 * 1024 * 1024:
        raise Error("peak accounting mismatch")
    var over_release = False
    try:
        governor.release(4 * 1024 * 1024)
    except:
        over_release = True
    if not over_release:
        raise Error("over-release was not refused")
    if governor.live_bytes != 3 * 1024 * 1024:
        raise Error("a refused over-release changed the ledger")
    governor.release(1024 * 1024)
    governor.release(2 * 1024 * 1024)
    if governor.live_bytes != 0 or governor.spilled_live_bytes != 0:
        raise Error("accounting did not return to baseline after frees")
    if governor.alloc_count != 3 or governor.free_count != 3:
        raise Error("alloc/free counters are not balanced at baseline")
    if governor.total_reserved_bytes != 1024 * 1024 + 512 * 1024 + 2 * 1024 * 1024:
        raise Error("total reserved accounting mismatch")
    print("PASS: accounting exact, checked, and back at baseline")


def test_budget_live_meminfo_pressure() raises:
    print("--- Testing budget live MemAvailable pressure (A-023) ---")
    var fixture = String("MemTotal:       127396532 kB\nMemFree:        107833404 kB\nMemAvailable:   123626384 kB\nSwapTotal:      131072000 kB\n")
    var parsed = parse_meminfo_available_bytes(fixture)
    if parsed != 123626384 * 1024:
        raise Error("meminfo fixture parse mismatch")
    var malformed = 0
    try:
        _ = parse_meminfo_available_bytes(String("MemTotal: 1 kB\n"))
    except:
        malformed += 1
    try:
        _ = parse_meminfo_available_bytes(String("MemAvailable: plenty kB\n"))
    except:
        malformed += 1
    if malformed != 2:
        raise Error("malformed meminfo was not refused")
    var live_available = mem_available_bytes()
    if live_available <= 0:
        raise Error("live MemAvailable could not be read on this machine")
    if live_available < 1024 * 1024 * 1024:
        raise Error("live MemAvailable implausibly small on this machine")
    var config = MemoryBudgetConfig(200 * 1024 * 1024 * 1024, 0)
    var effective = config.effective_cap_bytes(live_available)
    if effective != live_available:
        raise Error("effective cap does not honour the live availability")
    var governor = MemoryBudgetGovernor(MemoryBudgetConfig(effective, 0))
    governor.reserve(1024 * 1024)
    _expect_reserve_raises(governor, effective, "live-pressure cap refusal")
    governor.release(1024 * 1024)
    print(
        "MEASURED live MemAvailable bytes: " + String(live_available)
        + " ; effective cap honoured at that figure"
    )
    print("PASS: live pressure reading is real and the cap honours it")
