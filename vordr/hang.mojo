# VÖRÐR inference-hang detection (H143).
#
# Every op (CPU pipeline stage in the NO-GO branch — prefill chunk,
# decode step, weight staging, shadow verify) must complete within its
# budgeted time. Budgets come from data/vordr/hang_budgets.json and are
# DERIVED from measured p99 latencies × 3 (derivation documented in the
# JSON). A missed heartbeat emits a structured HangDetected event naming
# the in-flight op. The detector is polled — no threads — so it composes
# with the single-threaded monitor.

from hailbru.syscall import os_clock_ms
from hailbru.errors import herror
from vordr.events import event_emit_slice, json_str


struct OpBudget(Copyable, Movable):
    var op_id: String
    var budget_ms: Int64

    def __init__(out self, op_id: String, budget_ms: Int64):
        self.op_id = op_id
        self.budget_ms = budget_ms


struct HeartbeatMonitor:
    # op_id -> (deadline_ms, budget_ms); parallel lists (Mojo 1.1.0
    # has no stdlib Dict with String keys we can rely on here).
    var ids: List[String]
    var deadlines: List[Int64]
    var budgets: List[Int64]

    def __init__(out self):
        self.ids = List[String]()
        self.deadlines = List[Int64]()
        self.budgets = List[Int64]()

    def _find(self, op_id: String) -> Int:
        for i in range(len(self.ids)):
            if self.ids[i] == op_id:
                return i
        return -1

    def begin_op(mut self, arch: String, op_id: String, budget_ms: Int64) raises:
        if self._find(op_id) >= 0:
            raise herror(
                "HeartbeatViolation",
                "begin_op on already-in-flight op " + json_str(op_id),
            )
        var now = os_clock_ms(arch)
        self.ids.append(op_id)
        self.budgets.append(budget_ms)
        self.deadlines.append(now + budget_ms)

    def complete_op(mut self, op_id: String) raises:
        var i = self._find(op_id)
        if i < 0:
            raise herror(
                "HeartbeatViolation",
                "complete_op on unknown op " + json_str(op_id),
            )
        _ = self.ids.pop(i)
        _ = self.budgets.pop(i)
        _ = self.deadlines.pop(i)

    def overdue(mut self, arch: String, log_path: String) raises -> List[String]:
        # Poll: returns ids whose deadline passed; emits one
        # HangDetected event per overdue op (naming the op) and clears
        # it from the in-flight set (the fault is now owned by the
        # recovery state machine, H149 — no double-reporting).
        var now = os_clock_ms(arch)
        var out = List[String]()
        var i = len(self.ids) - 1
        while i >= 0:
            if now > self.deadlines[i]:
                var oid = self.ids[i]
                var bms = self.budgets[i]
                event_emit_slice(
                    arch, log_path, "H143", "HangDetected",
                    "\"op\": " + json_str(oid)
                    + ", \"budget_ms\": " + String(bms)
                    + ", \"overdue_ms\": " + String(now - self.deadlines[i]),
                )
                out.append(oid)
                _ = self.ids.pop(i)
                _ = self.budgets.pop(i)
                _ = self.deadlines.pop(i)
            i -= 1
        return out^

    def in_flight_count(self) -> Int:
        return len(self.ids)


def load_budgets(arch: String, path: String) raises -> List[OpBudget]:
    # Parses {"budgets": [{"op": "...", "budget_ms": N}, ...]} by hand.
    from hailbru.syscall import read_file_str

    var raw = read_file_str(arch, path, 8192)
    var out = List[OpBudget]()
    var tb = List[UInt8]()
    for b in raw.bytes():
        tb.append(b)
    var i = 0
    var n = len(tb)
    while i < n:
        # Find "\"op\"" then the quoted id, then "budget_ms" then int.
        if _at_key(tb, i, "op"):
            var j = i + 4
            while j < n and tb[j] != 34:
                j += 1
            j += 1
            var oid = String("")
            while j < n and tb[j] != 34:
                oid += String(chr(Int(tb[j])))
                j += 1
            # find budget_ms after this point
            var k = j
            var bms = Int64(-1)
            while k < n and not _at_key(tb, k, "budget_ms"):
                k += 1
            if k < n:
                var m = k + 11
                while m < n and tb[m] != 58:
                    m += 1
                m += 1
                var v = Int64(0)
                var got = False
                while m < n:
                    var c = Int(tb[m])
                    if c >= 48 and c <= 57:
                        v = v * 10 + Int64(c - 48)
                        got = True
                    elif got:
                        break
                    m += 1
                if got:
                    bms = v
            if bms >= 0:
                out.append(OpBudget(oid, bms))
            i = j
        i += 1
    if len(out) == 0:
        raise herror("BadBudgets", "no budgets parsed from " + path)
    return out^


def _at_key(tb: List[UInt8], i: Int, key: String) -> Bool:
    # tb[i] == '"' and key follows, then '"'.
    var kn = 0
    for b in key.bytes():
        kn += 1
    if i + kn + 1 >= len(tb):
        return False
    if tb[i] != 34:
        return False
    var k = 0
    for b in key.bytes():
        if tb[i + 1 + k] != b:
            return False
        k += 1
    return tb[i + 1 + kn] == 34
