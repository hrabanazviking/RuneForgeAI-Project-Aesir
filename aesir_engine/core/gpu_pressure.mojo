# core/gpu_pressure.mojo
# A-076: GPU memory pressure - graceful spill to CPU paths.
#
# On Strix Halo the GPU has no pool of its own: the Radeon 8060S,
# the CPU and the NPU all draw from the one 128 GB unified pool,
# which the OS and every other workload on the machine share too.
# When that pool is squeezed - by the desktop, by another campaign,
# by anything - an engine that keeps demanding GPU residency either
# crashes inside the driver or pushes the whole machine toward the
# OOM killer. This module is the pressure contract that sits
# between the A-064 GPU weight residency gateway and the A-023
# memory budget governor:
#
#   1. Pressure is MEASURED, never guessed: live_pressure() reads
#      MemTotal and MemAvailable from /proc/meminfo at runtime and
#      classifies the squeeze into NONE / MODERATE / HIGH /
#      CRITICAL by the available fraction of the total pool. An
#      unreadable source reports unknown (-1) and the configured
#      caps alone govern - the same discipline as A-023.
#   2. Routing is decided BEFORE any GPU allocation exists:
#      GpuPressureGovernor.route admits a weight to GPU residency
#      only when it fits BOTH the configured GPU cap and the live
#      effective room (MemAvailable - reserve, A-023 semantics).
#      A spillable weight that does not fit is routed to the CPU
#      path (ROUTE_SPILL_CPU) and accounted on the spill ledger -
#      the identical bytes, computed by the CPU path, never a
#      second-class copy (A-008 zero-copy rule: on the unified
#      pool the spilled placement is the same physical pages the
#      CPU already maps).
#   3. Degradation is BOUNDED: the spill ledger has its own cap.
#      A spillable request that would exceed the spill cap, and
#      every non-spillable request that does not fit the GPU room,
#      is REFUSED (ROUTE_REFUSE, MEM-003 taxonomy) - an explicit
#      logged refusal, never silent corruption, never a crash.
#   4. Degradation is LOGGED: every routing decision appends one
#      entry naming the route, the byte count, the pressure level
#      and the live availability it was decided under. The log is
#      itself bounded (LOG_MAX entries retained, the remainder
#      counted in log_dropped) so the cure cannot become a second
#      memory problem under a decision storm.
#   5. Recovery is exact: releasing GPU and spilled bytes returns
#      both ledgers to baseline (checked release, A-023 style), so
#      when external pressure lifts, fresh weights route to the GPU
#      again - degradation is a state, not a ratchet.
#
# Accelerator-first (A-017) is preserved: GPU residency is always
# the first route tried; the CPU path is spillover under measured
# pressure, and every spill names the pressure that caused it.
#
# NOTE (A-076 build): a previous lead's write of this file was
# cancelled mid-write and left a 4,200-byte truncated partial on
# disk (cut mid-token inside classify_pressure). Per campaign
# precedent (A-010) the partial was discarded after first-hand
# tail verification and this file was written cleanly from its
# evident design; the header above is that design, preserved.

from core.memory_budget import mem_available_bytes
from core.observation_integer import bounded_decimal

comptime PRESSURE_NONE = 0
comptime PRESSURE_MODERATE = 1
comptime PRESSURE_HIGH = 2
comptime PRESSURE_CRITICAL = 3
comptime PRESSURE_UNKNOWN = -1

comptime ROUTE_GPU = 0
comptime ROUTE_SPILL_CPU = 1
comptime ROUTE_REFUSE = 2

comptime LOG_MAX = 128


def pressure_name(level: Int) -> String:
    if level == PRESSURE_NONE:
        return String("NONE")
    if level == PRESSURE_MODERATE:
        return String("MODERATE")
    if level == PRESSURE_HIGH:
        return String("HIGH")
    if level == PRESSURE_CRITICAL:
        return String("CRITICAL")
    return String("UNKNOWN")


def route_name(route: Int) -> String:
    if route == ROUTE_GPU:
        return String("GPU")
    if route == ROUTE_SPILL_CPU:
        return String("SPILL_CPU")
    return String("REFUSE")


def classify_pressure(available_bytes: Int, total_bytes: Int) -> Int:
    """Pure pressure classification by available fraction of the
    total pool: >= 1/2 NONE, >= 1/4 MODERATE, >= 1/8 HIGH, below
    that CRITICAL. Unknown figures (non-positive) classify as
    UNKNOWN - pressure is never invented."""
    if available_bytes < 0 or total_bytes <= 0:
        return PRESSURE_UNKNOWN
    if available_bytes * 2 >= total_bytes:
        return PRESSURE_NONE
    if available_bytes * 4 >= total_bytes:
        return PRESSURE_MODERATE
    if available_bytes * 8 >= total_bytes:
        return PRESSURE_HIGH
    return PRESSURE_CRITICAL


def parse_meminfo_total_bytes(text: String) raises -> Int:
    """Parse the MemTotal line of /proc/meminfo text into bytes.
    Pure parser (fixture-testable), the twin of A-023's
    parse_meminfo_available_bytes. Raises on a missing or
    malformed field - an unknown total is never guessed."""
    for line in text.split("\n"):
        var entry = String(line)
        if entry.startswith("MemTotal:"):
            var parts = entry.split(":")
            if len(parts) != 2:
                raise Error("GpuPressure: malformed MemTotal line")
            var fields = String(parts[1]).strip().split(" ")
            var number = String("")
            for field in fields:
                if String(field) != "":
                    number = String(field)
                    break
            if number == "":
                raise Error("GpuPressure: empty MemTotal value")
            return bounded_decimal(number) * 1024
    raise Error("GpuPressure: no MemTotal field in meminfo text")


def mem_total_bytes() -> Int:
    """Live MemTotal in bytes, READ from /proc/meminfo.
    Returns -1 when the file or field cannot be read."""
    try:
        var text: String
        with open("/proc/meminfo", "r") as source:
            text = source.read()
        return parse_meminfo_total_bytes(text)
    except:
        return -1


struct PressureReading(Copyable, ImplicitlyCopyable):
    """One measured snapshot of the unified pool."""

    var total_bytes: Int
    var available_bytes: Int
    var level: Int

    def __init__(out self, total_bytes: Int, available_bytes: Int, level: Int):
        self.total_bytes = total_bytes
        self.available_bytes = available_bytes
        self.level = level


def live_pressure() -> PressureReading:
    """Measure the pool NOW: MemTotal + MemAvailable read from
    /proc/meminfo at runtime, classified by classify_pressure.
    An unreadable source yields -1 figures and PRESSURE_UNKNOWN -
    the configured caps alone then govern (A-023 discipline)."""
    var available = mem_available_bytes()
    var total = mem_total_bytes()
    return PressureReading(total, available, classify_pressure(available, total))


struct GpuPressureConfig(Copyable, ImplicitlyCopyable):
    """Pressure governor configuration.

    gpu_cap_bytes: maximum live GPU-resident bytes the governor
    will admit. spill_cap_bytes: maximum live spilled (CPU-path)
    bytes - degradation is bounded, so the spill ledger is capped
    too. reserve_bytes: bytes of live MemAvailable treated as
    untouchable (the desktop / other-work guard) when computing
    the effective GPU room. The reserve is measured against the
    machine pool, not against the GPU cap, so it may legitimately
    exceed gpu_cap_bytes (the bench fixes it near the whole
    pool to squeeze the room to a known figure)."""

    var gpu_cap_bytes: Int
    var spill_cap_bytes: Int
    var reserve_bytes: Int

    def __init__(out self, gpu_cap_bytes: Int, spill_cap_bytes: Int, reserve_bytes: Int):
        self.gpu_cap_bytes = gpu_cap_bytes
        self.spill_cap_bytes = spill_cap_bytes
        self.reserve_bytes = reserve_bytes

    def validate(self) raises:
        if self.gpu_cap_bytes <= 0:
            raise Error("GpuPressure: gpu_cap_bytes must be positive")
        if self.spill_cap_bytes < 0:
            raise Error("GpuPressure: spill_cap_bytes must be nonnegative")
        if self.reserve_bytes < 0:
            raise Error("GpuPressure: reserve_bytes must be nonnegative")

    def effective_gpu_room(self, available_bytes: Int, gpu_live_bytes: Int) -> Int:
        """Room for one more GPU admission: min(configured GPU
        cap, available - reserve) minus bytes already GPU-live,
        floored at zero. An unknown availability (-1) leaves the
        configured cap alone in force."""
        var cap = self.gpu_cap_bytes
        if available_bytes >= 0:
            var usable = available_bytes - self.reserve_bytes
            if usable < 0:
                usable = 0
            if usable < cap:
                cap = usable
        var room = cap - gpu_live_bytes
        if room < 0:
            room = 0
        return room


struct GpuPressureGovernor(Copyable):
    """Stateful pressure governor: pre-dispatch routing with
    exact byte accounting on two ledgers (GPU-resident, spilled).

    Pure and deterministic given the availability figures it is
    handed (same request + pressure sequence in, same routes,
    counters and log out), so the E-MASTER cases prove the
    routing arithmetic exactly; the A-076 bench then drives the
    same governor with REAL external pressure (a separate balloon
    process squeezing the shared pool) and live_pressure()
    readings. route() never raises and never allocates: refusal
    is a returned, logged verdict (ROUTE_REFUSE, MEM-003 class),
    decided before any GPU allocation exists."""

    var config: GpuPressureConfig
    var gpu_live_bytes: Int
    var spilled_live_bytes: Int
    var peak_gpu_bytes: Int
    var gpu_admit_count: Int
    var spill_count: Int
    var refusal_count: Int
    var log: List[String]
    var log_dropped: Int

    def __init__(out self, config: GpuPressureConfig):
        self.config = config.copy()
        self.gpu_live_bytes = 0
        self.spilled_live_bytes = 0
        self.peak_gpu_bytes = 0
        self.gpu_admit_count = 0
        self.spill_count = 0
        self.refusal_count = 0
        self.log = List[String]()
        self.log_dropped = 0

    def at_baseline(self) -> Bool:
        return self.gpu_live_bytes == 0 and self.spilled_live_bytes == 0

    def _record(mut self, entry: String):
        if len(self.log) >= LOG_MAX:
            self.log_dropped += 1
            return
        self.log.append(entry)

    def route(
        mut self,
        size_bytes: Int,
        spillable: Bool,
        available_bytes: Int,
        total_bytes: Int,
    ) -> Int:
        """The routing verdict for one weight, decided BEFORE
        any GPU allocation exists. GPU when it fits both the cap
        and the live effective room; SPILL_CPU when a spillable
        weight does not fit the GPU room but fits the bounded
        spill ledger; REFUSE otherwise (and for any non-positive
        size). Every verdict is charged to its ledger and logged
        with the pressure it was decided under."""
        var level = classify_pressure(available_bytes, total_bytes)
        var verdict: Int
        if size_bytes <= 0:
            verdict = ROUTE_REFUSE
            self.refusal_count += 1
        elif size_bytes <= self.config.effective_gpu_room(
            available_bytes, self.gpu_live_bytes
        ):
            verdict = ROUTE_GPU
            self.gpu_live_bytes += size_bytes
            self.gpu_admit_count += 1
            if self.gpu_live_bytes > self.peak_gpu_bytes:
                self.peak_gpu_bytes = self.gpu_live_bytes
        elif spillable and size_bytes <= self.config.spill_cap_bytes - self.spilled_live_bytes:
            verdict = ROUTE_SPILL_CPU
            self.spilled_live_bytes += size_bytes
            self.spill_count += 1
        else:
            verdict = ROUTE_REFUSE
            self.refusal_count += 1
        self._record(
            String("route=") + route_name(verdict)
            + String(" bytes=") + String(size_bytes)
            + String(" pressure=") + pressure_name(level)
            + String(" avail=") + String(available_bytes)
            + String(" gpu_live=") + String(self.gpu_live_bytes)
            + String(" spilled_live=") + String(self.spilled_live_bytes)
        )
        return verdict

    def release_gpu(mut self, size_bytes: Int) raises:
        """Return GPU-resident bytes. Checked (A-023 style): a
        non-positive size or more than is live raises - the
        ledger never underflows."""
        if size_bytes <= 0:
            raise Error("GpuPressure.release_gpu: size_bytes must be positive")
        if size_bytes > self.gpu_live_bytes:
            raise Error(
                "GpuPressure.release_gpu: cannot release "
                + String(size_bytes) + " bytes with only "
                + String(self.gpu_live_bytes) + " GPU-live (accounting bug)"
            )
        self.gpu_live_bytes -= size_bytes

    def release_spilled(mut self, size_bytes: Int) raises:
        """Return spilled (CPU-path) bytes. Checked, as release_gpu."""
        if size_bytes <= 0:
            raise Error("GpuPressure.release_spilled: size_bytes must be positive")
        if size_bytes > self.spilled_live_bytes:
            raise Error(
                "GpuPressure.release_spilled: cannot release "
                + String(size_bytes) + " spilled bytes with only "
                + String(self.spilled_live_bytes) + " spilled"
            )
        self.spilled_live_bytes -= size_bytes
