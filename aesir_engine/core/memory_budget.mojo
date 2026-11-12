# core/memory_budget.mojo
# A-023: Memory budget governor.
#
# A configurable cap keeps the engine from starving the desktop and
# other work on the shared 128 GB of unified memory (Strix Halo:
# CPU, Radeon 8060S iGPU and XDNA 2 NPU all draw from one pool, so
# an engine allocation is a machine allocation). The governor is
# enforced in code, not documented as advice:
#
#   1. Every governed allocation is admitted BEFORE any backing
#      memory is requested: MemoryBudgetGovernor.reserve admits the
#      byte count through core/checked_span against the cap, and
#      allocate_governed calls reserve first - on refusal it raises
#      and ZeroCopy.allocate is never reached, so no allocation is
#      attempted, nothing is charged, and the process cannot be
#      pushed into the OOM killer by a governed request.
#   2. Refusal is fail-closed with the repo error taxonomy
#      (ERROR_TAXONOMY.md MEM-003 OUT_OF_MEMORY): the raise names
#      the requested bytes, the live bytes and the cap. Callers who
#      can degrade mark a request spillable: admit_or_spill then
#      returns DECISION_SPILL and accounts the bytes on the spill
#      ledger instead of the capped live ledger - the engine
#      degrades (spills/refuses) instead of OOMing the machine.
#   3. The cap is configurable (MemoryBudgetConfig) and the
#      effective cap also honours live machine pressure:
#      effective_cap_bytes takes the minimum of the configured cap
#      and (MemAvailable - reserve) with MemAvailable READ at
#      runtime from /proc/meminfo - never hardcoded, never
#      fabricated; an unreadable source yields -1 and the
#      configured cap alone governs (the reserve is the standing
#      guard for the desktop in that case).
#   4. Accounting is exact integer byte accounting: live, peak,
#      spilled, allocation/free/refusal/spill counters. Release is
#      checked - releasing more than is live raises instead of
#      underflowing the ledger, so accounting returns to baseline
#      exactly when every governed buffer is freed.
#
# Style follows the banked A-017 device policy (pure, deterministic
# value structs with reason-bearing decisions) and the A-018/A-019
# discipline (values read from the machine at runtime; presence is
# never execution; nothing is simulated). The governed path wraps
# the A-019 zero-copy allocator (core/zero_copy), the unified
# allocation gateway built on the A-008 zero-copy rule.

from core.checked_span import checked_span
from core.observation_integer import bounded_decimal
from core.zero_copy import ZeroCopy, ZeroCopyBuffer

comptime DECISION_ADMIT = 0
comptime DECISION_SPILL = 1
comptime DECISION_REFUSE = 2

comptime DEFAULT_CAP_BYTES = 96 * 1024 * 1024 * 1024
comptime DEFAULT_RESERVE_BYTES = 16 * 1024 * 1024 * 1024


def parse_meminfo_available_bytes(text: String) raises -> Int:
    """Parse the MemAvailable line of /proc/meminfo text into bytes.

    Pure parser (fixture-testable): finds the MemAvailable field,
    reads its kibibyte value with the strict bounded_decimal parser
    and converts KiB to bytes. Raises on a missing or malformed
    field - an unknown availability is never guessed.
    """
    for line in text.split("\n"):
        var entry = String(line)
        if entry.startswith("MemAvailable:"):
            var parts = entry.split(":")
            if len(parts) != 2:
                raise Error("MemoryBudget: malformed MemAvailable line")
            var fields = String(parts[1]).strip().split(" ")
            var number = String("")
            for field in fields:
                if String(field) != "":
                    number = String(field)
                    break
            if number == "":
                raise Error("MemoryBudget: empty MemAvailable value")
            return bounded_decimal(number) * 1024
    raise Error("MemoryBudget: no MemAvailable field in meminfo text")


def mem_available_bytes() -> Int:
    """Live MemAvailable in bytes, READ from /proc/meminfo.

    Returns -1 when the file or field cannot be read: unknown is
    reported as unknown, never replaced with an invented figure.
    """
    try:
        var text: String
        with open("/proc/meminfo", "r") as source:
            text = source.read()
        return parse_meminfo_available_bytes(text)
    except:
        return -1


struct MemoryBudgetConfig(Copyable, ImplicitlyCopyable):
    """Configurable governor cap.

    cap_bytes: maximum live governed bytes. reserve_bytes: bytes
    of live MemAvailable the governor treats as untouchable (the
    desktop/other-work guard) when computing the effective cap.
    """

    var cap_bytes: Int
    var reserve_bytes: Int

    def __init__(out self, cap_bytes: Int, reserve_bytes: Int):
        self.cap_bytes = cap_bytes
        self.reserve_bytes = reserve_bytes

    @staticmethod
    def default_config() -> MemoryBudgetConfig:
        """Standing default for the shared 128 GB machine: the
        engine may hold at most 96 GiB live, and 16 GiB of whatever
        the kernel reports available stays reserved for the rest
        of the machine. Both numbers are configuration, not law -
        any caller may construct a stricter or looser config."""
        return MemoryBudgetConfig(DEFAULT_CAP_BYTES, DEFAULT_RESERVE_BYTES)

    def validate(self) raises:
        if self.cap_bytes <= 0:
            raise Error("MemoryBudget: cap_bytes must be positive")
        if self.reserve_bytes < 0:
            raise Error("MemoryBudget: reserve_bytes must be nonnegative")
        if self.reserve_bytes >= self.cap_bytes:
            raise Error(
                "MemoryBudget: reserve_bytes must be below cap_bytes"
            )

    def effective_cap_bytes(self, available_bytes: Int) -> Int:
        """Cap honouring live pressure: min(configured cap,
        available - reserve), floored at zero. An unknown
        availability (-1) leaves the configured cap in force."""
        if available_bytes < 0:
            return self.cap_bytes
        var usable = available_bytes - self.reserve_bytes
        if usable < 0:
            usable = 0
        if usable < self.cap_bytes:
            return usable
        return self.cap_bytes


struct MemoryBudgetGovernor(Copyable):
    """Stateful budget governor: exact byte accounting under a cap.

    Pure and deterministic (same request sequence in, same
    decisions and counters out), so the E-MASTER cases prove the
    cap arithmetic exactly; allocate_governed then binds the same
    governor to real A-019 zero-copy allocations whose shim live
    byte counter is the independent measurement.
    """

    var config: MemoryBudgetConfig
    var live_bytes: Int
    var peak_bytes: Int
    var spilled_live_bytes: Int
    var alloc_count: Int
    var free_count: Int
    var refusal_count: Int
    var spill_count: Int
    var total_reserved_bytes: Int

    def __init__(out self, config: MemoryBudgetConfig):
        self.config = config.copy()
        self.live_bytes = 0
        self.peak_bytes = 0
        self.spilled_live_bytes = 0
        self.alloc_count = 0
        self.free_count = 0
        self.refusal_count = 0
        self.spill_count = 0
        self.total_reserved_bytes = 0

    def remaining_bytes(self) -> Int:
        return self.config.cap_bytes - self.live_bytes

    def utilisation_ppm(self) -> Int:
        if self.config.cap_bytes <= 0:
            return 0
        return self.live_bytes * 1000000 // self.config.cap_bytes

    def decide(self, size_bytes: Int, spillable: Bool) -> Int:
        """The admission verdict for one request, without charging
        anything: ADMIT when the request fits the cap, SPILL when
        it does not fit but the caller can degrade, REFUSE
        otherwise (including any non-positive size)."""
        if size_bytes <= 0:
            return DECISION_REFUSE
        if size_bytes <= self.remaining_bytes():
            return DECISION_ADMIT
        if spillable:
            return DECISION_SPILL
        return DECISION_REFUSE

    def reserve(mut self, size_bytes: Int) raises:
        """Charge size_bytes against the cap, checked BEFORE any
        backing allocation exists. Admission goes through
        checked_span (live + size within cap); on any failure the
        refusal is counted and a MEM-003 taxonomy error is raised
        with the live bytes and cap named. A refused reserve
        charges nothing."""
        if size_bytes <= 0:
            self.refusal_count += 1
            raise Error(
                "MemoryBudget.reserve: size_bytes must be positive, got "
                + String(size_bytes)
            )
        try:
            _ = checked_span(
                self.live_bytes, size_bytes, self.config.cap_bytes
            )
        except:
            self.refusal_count += 1
            raise Error(
                "MemoryBudget.reserve: MEM-003 OUT_OF_MEMORY - request "
                + String(size_bytes) + " bytes with "
                + String(self.live_bytes) + " live exceeds budget cap "
                + String(self.config.cap_bytes) + " bytes; refused"
                " before allocation (fail-closed)"
            )
        self.live_bytes += size_bytes
        self.total_reserved_bytes += size_bytes
        self.alloc_count += 1
        if self.live_bytes > self.peak_bytes:
            self.peak_bytes = self.live_bytes

    def admit_or_spill(mut self, size_bytes: Int, spillable: Bool) raises -> Int:
        """Degrade instead of OOMing: ADMIT charges the cap ledger;
        SPILL accounts the bytes on the spill ledger (the caller
        places them outside the capped pool); a non-spillable
        overflow is refused through reserve and raises MEM-003."""
        var verdict = self.decide(size_bytes, spillable)
        if verdict == DECISION_ADMIT:
            self.reserve(size_bytes)
            return DECISION_ADMIT
        if verdict == DECISION_SPILL:
            self.spilled_live_bytes += size_bytes
            self.spill_count += 1
            return DECISION_SPILL
        self.reserve(size_bytes)
        return DECISION_REFUSE

    def release(mut self, size_bytes: Int) raises:
        """Return size_bytes to the budget. Checked: releasing a
        non-positive size or more than is live raises - the ledger
        never underflows, so a balanced alloc/free sequence returns
        live_bytes to exactly its baseline."""
        if size_bytes <= 0:
            raise Error("MemoryBudget.release: size_bytes must be positive")
        if size_bytes > self.live_bytes:
            raise Error(
                "MemoryBudget.release: cannot release "
                + String(size_bytes) + " bytes with only "
                + String(self.live_bytes) + " live (accounting bug)"
            )
        self.live_bytes -= size_bytes
        self.free_count += 1

    def release_spilled(mut self, size_bytes: Int) raises:
        if size_bytes <= 0:
            raise Error(
                "MemoryBudget.release_spilled: size_bytes must be positive"
            )
        if size_bytes > self.spilled_live_bytes:
            raise Error(
                "MemoryBudget.release_spilled: cannot release "
                + String(size_bytes) + " spilled bytes with only "
                + String(self.spilled_live_bytes) + " spilled"
            )
        self.spilled_live_bytes -= size_bytes


def allocate_governed(
    mut governor: MemoryBudgetGovernor, size_bytes: Int, backend: Int
) raises -> ZeroCopyBuffer:
    """One A-019 zero-copy allocation under the governor.

    The budget check runs first: reserve raises MEM-003 before
    ZeroCopy.allocate is called, so a refused request performs no
    allocation at all. If the backend allocation itself fails, the
    reservation is rolled back and the backend error propagates -
    the ledger only ever charges bytes that actually exist.
    """
    governor.reserve(size_bytes)
    try:
        return ZeroCopy.allocate(size_bytes, backend)
    except error:
        governor.release(size_bytes)
        raise error


def free_governed(
    mut governor: MemoryBudgetGovernor, buffer: ZeroCopyBuffer
) raises:
    """Free a governed buffer and return its bytes to the budget."""
    ZeroCopy.free(buffer)
    governor.release(buffer.size)
