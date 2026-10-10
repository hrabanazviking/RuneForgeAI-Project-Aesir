# VÖRÐR transient-error correction: retry with backoff (H156).
#
# The first line of self-healing. Bounded retries with exponential
# backoff and jitter, per data/vordr/retry_policy.json. A transient
# fault injected 3 times in a row is absorbed: the operation succeeds
# on a retry and the log carries the observable annotation
# `recovered_after_retries: N` (correction is observable, never
# silent). Exceeding max retries escalates to PERSISTENT handling
# (6 consecutive transient faults -> reset path engaged).

from hailbru.syscall import os_clock_ms, os_sleep_ms, read_file_str
from hailbru.errors import herror
from vordr.events import event_emit_slice


struct RetryPolicy:
    var max_retries: Int
    var base_ms: Int64
    var factor: Int64
    var jitter_pct: Int64

    def __init__(
        out self, max_retries: Int, base_ms: Int64, factor: Int64,
        jitter_pct: Int64,
    ):
        self.max_retries = max_retries
        self.base_ms = base_ms
        self.factor = factor
        self.jitter_pct = jitter_pct

    fn nominal_ms(self, attempt: Int) -> Int64:
        # attempt is 1-based (delay BEFORE retry #attempt).
        var d = self.base_ms
        var k = 1
        while k < attempt:
            d *= self.factor
            k += 1
        return d


def load_retry_policy(arch: String, path: String) raises -> RetryPolicy:
    # Integers in order: max_retries, base_ms, factor, jitter_pct.
    var raw = read_file_str(arch, path, 4096)
    var vals = List[Int64]()
    var v = Int64(0)
    var in_num = False
    for b in raw.bytes():
        var c = Int(b)
        if c >= 48 and c <= 57:
            v = v * 10 + Int64(c - 48)
            in_num = True
        else:
            if in_num:
                vals.append(v)
                v = 0
                in_num = False
    if in_num:
        vals.append(v)
    if len(vals) < 4:
        raise herror(
            "BadPolicy",
            "expected 4 integers in " + path + ", found " + String(len(vals)),
        )
    return RetryPolicy(Int(vals[0]), vals[1], vals[2], vals[3])


fn jittered_delay(policy: RetryPolicy, attempt: Int, rng_state: UInt64) -> Int64:
    # Deterministic jitter: xorshift one step, uniform in
    # [-jitter_pct, +jitter_pct] of the nominal delay.
    var x = rng_state
    x ^= x << 13
    x ^= x >> 7
    x ^= x << 17
    var span = 2 * policy.jitter_pct + 1
    var off = Int64(x % UInt64(span)) - policy.jitter_pct
    var nom = policy.nominal_ms(attempt)
    var d = nom + nom * off // 100
    if d < 0:
        d = 0
    return d


struct RetryDriver:
    # Test vehicle for the retry policy (the production integration is
    # the H149 recovery machine calling should_retry). The transient
    # fault is injected via the fail_times hook: the op fails that
    # many times, then succeeds — proving absorption is real.
    var policy: RetryPolicy

    def __init__(out self, policy: RetryPolicy):
        self.policy = policy

    def should_retry(self, attempt: Int) -> Bool:
        return attempt <= self.policy.max_retries

    def execute(
        mut self,
        arch: String,
        log_path: String,
        op_name: String,
        fail_times: Int,
        rng_seed: UInt64,
    ) raises -> Int:
        # Returns the retry count N at which the op succeeded
        # (0 = first try). Raises RetryExhausted (PERSISTENT handling
        # takes over) when the fault outlives max_retries.
        var attempt = 0
        var rng = rng_seed
        while True:
            attempt += 1
            var t0 = os_clock_ms(arch)
            if attempt > fail_times:
                # The op succeeds.
                var n = attempt - 1
                event_emit_slice(
                    arch, log_path, "H156", "OpRecovered",
                    "\"op\": \"" + op_name + "\", \"recovered_after_retries\": "
                    + String(n),
                )
                return n
            # Transient fault on this attempt.
            event_emit_slice(
                arch, log_path, "H156", "TransientFault",
                "\"op\": \"" + op_name + "\", \"attempt\": "
                + String(attempt),
            )
            if not self.should_retry(attempt):
                event_emit_slice(
                    arch, log_path, "H156", "RetryExhausted",
                    "\"op\": \"" + op_name + "\", \"attempts\": "
                    + String(attempt) + ", \"escalation\": "
                    "\"PERSISTENT handling (reset path)\"",
                )
                raise herror(
                    "RetryExhausted",
                    "op '" + op_name + "' failed " + String(attempt)
                    + " times; escalating to PERSISTENT handling",
                )
            var delay = jittered_delay(self.policy, attempt, rng)
            rng = rng + UInt64(0x9E3779B97F4A7C15)
            var nom = self.policy.nominal_ms(attempt)
            event_emit_slice(
                arch, log_path, "H156", "RetryScheduled",
                "\"op\": \"" + op_name + "\", \"attempt\": "
                + String(attempt) + ", \"delay_ms\": " + String(delay)
                + ", \"nominal_ms\": " + String(nom),
            )
            os_sleep_ms(arch, delay)
            var actual = os_clock_ms(arch) - t0
            event_emit_slice(
                arch, log_path, "H156", "RetryFired",
                "\"op\": \"" + op_name + "\", \"attempt\": "
                + String(attempt) + ", \"actual_delay_ms\": "
                + String(actual) + ", \"nominal_ms\": " + String(nom),
            )
