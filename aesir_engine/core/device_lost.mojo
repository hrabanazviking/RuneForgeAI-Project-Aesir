# core/device_lost.mojo
# A-079: Device-lost recovery - injected Vulkan device-lost mid-run.
#
# Acceptance (roadmap A-079): the engine fails over to CPU or fails
# closed with state intact - never hangs, never corrupts the
# conversation state.
#
# The failure this guards against is VK_ERROR_DEVICE_LOST (-4)
# surfacing in the middle of a decode run: the device is gone, every
# further Vulkan call on it is meaningless, and the only things that
# matter are (a) the conversation state committed so far and (b) a
# bounded, honest ending. An engine that retries the dead device
# forever hangs; an engine that keeps writing into state it can no
# longer verify corrupts the conversation; an engine that presents
# a truncated run as finished lies. This module is the recovery
# contract that sits over the A-065/A-066 Vulkan layer + decode
# loop, in the A-076 governor pattern (accounting BEFORE
# integration, bounded log, checked verdicts, never a raise out of
# the routing path):
#
#   1. SNAPSHOT PER COMMIT: after every committed token the
#      coordinator records the canonical serialized conversation
#      state and its digest. A token is committed only when its
#      step completed; the in-flight token of a lost step is
#      DISCARDED (counted, logged) and never enters the state.
#   2. LOSS IS TERMINAL FOR THE DEVICE: the first device-lost
#      ends all GPU work in the run. There is no re-probe, no
#      retry loop, no silent Vulkan re-init in the same run -
#      so a repeated-loss storm cannot loop: at most one
#      failover is ever attempted per run.
#   3. FAILOVER ONLY ON A VERIFIED SNAPSHOT: failover to the CPU
#      path is permitted only when the snapshot taken at the last
#      commit still verifies byte-for-byte (digest + length)
#      at the moment of loss, the loss is the first in the run,
#      and failover is enabled. The CPU path then recomputes the
#      discarded step and continues from exactly the committed
#      prefix; the recovered final state must equal the
#      uninterrupted CPU-oracle control state BYTE-FOR-BYTE or
#      the run reports corruption instead of success.
#   4. FAIL CLOSED OTHERWISE: no failover permission, a second
#      loss, or a snapshot that does not verify -> the run ends
#      FAILED_CLOSED with the A-013 taxonomy error for -4
#      (GPU-001 GPU_INIT_FAILED, VkResult -4) surfaced, and the
#      conversation state is exactly the last committed snapshot,
#      byte-for-byte.
#   5. WATCHDOG BY CONSTRUCTION: every loop iteration - GPU
#      step, loss handling, CPU step - is charged against a
#      fixed iteration budget fixed BEFORE the run. Exhausting
#      the budget ends the run FAILED_CLOSED with a watchdog
#      reason; the coordinator cannot iterate past the budget,
#      so "never hangs" is a property of the loop bound, and the
#      A-079 harness additionally runs every scenario under an
#      external `timeout` watchdog (see the A-079 ledger).
#
# Determinism: the step model is the campaign's greedy discipline
# (A-066): the GPU path and the CPU oracle produce the SAME token
# for the same committed prefix (proven token-exact on the real
# device in A-066/A-067), modelled here by one shared deterministic
# step function over the committed state. The coordinator itself
# is pure - scripted VkResults in, verdicts and state bytes out -
# so the E-MASTER cases prove the recovery arithmetic exactly;
# the live case in tests/test_device_lost_a079.mojo drives the
# REAL A-013 shim forced-failure hook (INJECT_STAGE_DEVICE,
# VK_ERROR_DEVICE_LOST) on the real device and proves the
# fail-closed taxonomy path end to end. Injection is shim-level
# only: nothing in this slice touches the driver, sysfs, or any
# real device reset (A-079 safety review, filed in the ledger).
#
# Conversation state (canonical serialization, fixed field order,
# little-endian, no timestamps / pointers / addresses):
#   seed, prompt length + prompt token ids, committed length +
#   committed token ids, kv length + kv payload bytes.
# The kv payload is the deterministic per-position byte pattern
# the fixture decode carries; integrity is graded on the FULL
# serialized bytes (byte equality), with the digest as the
# at-loss verification shortcut - never on the digest alone.

from core.vulkan_context import taxonomy_code_for_vk_result

comptime VK_ERROR_DEVICE_LOST = -4

comptime OUTCOME_COMPLETED_GPU = 0
comptime OUTCOME_FAILED_OVER_CPU = 1
comptime OUTCOME_FAILED_CLOSED = 2

comptime LOG_MAX = 64


def outcome_name(outcome: Int) -> String:
    if outcome == OUTCOME_COMPLETED_GPU:
        return String("COMPLETED_GPU")
    if outcome == OUTCOME_FAILED_OVER_CPU:
        return String("FAILED_OVER_CPU")
    if outcome == OUTCOME_FAILED_CLOSED:
        return String("FAILED_CLOSED")
    return String("UNKNOWN")


def state_digest(data: List[UInt8]) -> Int:
    """Rolling digest over the canonical state bytes (modular
    polynomial, two interleaved lanes folded into one Int).
    Evidence-grade shortcut only: integrity verdicts in this
    module always ALSO compare the bytes themselves."""
    var h1: Int = 5381
    var h2: Int = 52711
    for i in range(len(data)):
        var b = Int(data[i])
        h1 = ((h1 * 33) + b) % 1000000007
        h2 = ((h2 * 31) + b + i) % 998244353
    return h1 * 1000003 + h2


def bytes_equal(a: List[UInt8], b: List[UInt8]) -> Bool:
    """Byte-for-byte equality - the graded integrity check."""
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def _append_i64_le(mut out: List[UInt8], value: Int):
    var v = UInt64(value)
    for i in range(8):
        out.append(UInt8((v >> UInt64(8 * i)) & UInt64(0xFF)))


struct ConversationState(Copyable):
    """The conversation state A-079 protects: seed, the raw
    prompt token ids, the committed generated token ids, and the
    KV payload bytes carried for the committed prefix."""

    var seed: Int
    var prompt: List[Int]
    var committed: List[Int]
    var kv: List[UInt8]
    var kv_channels: Int

    def __init__(
        out self, seed: Int, prompt: List[Int], kv_channels: Int
    ):
        self.seed = seed
        self.prompt = prompt.copy()
        self.committed = List[Int]()
        self.kv = List[UInt8]()
        self.kv_channels = kv_channels

    def position(self) -> Int:
        return len(self.prompt) + len(self.committed)

    def commit(mut self, token: Int):
        """Append one completed token and extend the KV payload
        deterministically for its position."""
        var pos = self.position()
        self.committed.append(token)
        for c in range(self.kv_channels):
            self.kv.append(UInt8((token * 7 + pos * 13 + c * 3) & 0xFF))

    def serialize(self) -> List[UInt8]:
        var out = List[UInt8]()
        _append_i64_le(out, self.seed)
        _append_i64_le(out, len(self.prompt))
        for i in range(len(self.prompt)):
            _append_i64_le(out, self.prompt[i])
        _append_i64_le(out, len(self.committed))
        for i in range(len(self.committed)):
            _append_i64_le(out, self.committed[i])
        _append_i64_le(out, len(self.kv))
        for i in range(len(self.kv)):
            out.append(self.kv[i])
        return out^


def oracle_next_token(state: ConversationState, vocab: Int) -> Int:
    """The shared deterministic greedy step: the next token as a
    pure function of the committed state. The GPU path and the
    CPU oracle agree on it by the A-066 token-exact discipline;
    the failover proof is that a run recovered onto this function
    lands on the same bytes as the uninterrupted control run."""
    var last = state.seed
    if len(state.committed) > 0:
        last = state.committed[len(state.committed) - 1]
    elif len(state.prompt) > 0:
        last = state.prompt[len(state.prompt) - 1]
    var v = (state.seed * 131 + last * 31 + state.position() * 17 + 7) % vocab
    if v < 0:
        v += vocab
    return v


def control_run(
    seed: Int, prompt: List[Int], total_steps: Int, vocab: Int,
    kv_channels: Int,
) -> ConversationState:
    """The uninterrupted CPU-oracle control run: total_steps
    tokens committed from the raw prompt, no device involved."""
    var state = ConversationState(seed, prompt, kv_channels)
    for _ in range(total_steps):
        state.commit(oracle_next_token(state, vocab))
    return state^


struct RecoveryConfig(Copyable, ImplicitlyCopyable):
    """failover_allowed: policy permission to fail over to CPU.
    vocab / kv_channels: the fixture decode shape. max_iterations:
    the watchdog budget, fixed before the run - every GPU step,
    loss handling and CPU step charges one iteration.
    corrupt_snapshot_at_loss: TEST HOOK modelling a torn
    snapshot (loss during checkpoint readback): the recorded
    snapshot is damaged before verification, so verification
    must fail and the run must fail closed."""

    var failover_allowed: Bool
    var vocab: Int
    var kv_channels: Int
    var max_iterations: Int
    var corrupt_snapshot_at_loss: Bool

    def __init__(
        out self,
        failover_allowed: Bool,
        vocab: Int,
        kv_channels: Int,
        max_iterations: Int,
        corrupt_snapshot_at_loss: Bool,
    ):
        self.failover_allowed = failover_allowed
        self.vocab = vocab
        self.kv_channels = kv_channels
        self.max_iterations = max_iterations
        self.corrupt_snapshot_at_loss = corrupt_snapshot_at_loss


struct RecoveryReport(Copyable):
    """The graded result of one run. final_state / snapshot_state
    are canonical serialized bytes, compared byte-for-byte by
    the tests - integrity is checked, never asserted."""

    var outcome: Int
    var losses: Int
    var discarded: Int
    var iterations: Int
    var budget: Int
    var committed_count: Int
    var state_intact: Bool
    var control_match: Bool
    var error: String
    var final_state: List[UInt8]
    var snapshot_state: List[UInt8]
    var log: List[String]
    var log_dropped: Int

    def __init__(
        out self,
        outcome: Int,
        losses: Int,
        discarded: Int,
        iterations: Int,
        budget: Int,
        committed_count: Int,
        state_intact: Bool,
        control_match: Bool,
        error: String,
        final_state: List[UInt8],
        snapshot_state: List[UInt8],
        log: List[String],
        log_dropped: Int,
    ):
        self.outcome = outcome
        self.losses = losses
        self.discarded = discarded
        self.iterations = iterations
        self.budget = budget
        self.committed_count = committed_count
        self.state_intact = state_intact
        self.control_match = control_match
        self.error = error
        self.final_state = final_state.copy()
        self.snapshot_state = snapshot_state.copy()
        self.log = log.copy()
        self.log_dropped = log_dropped


struct DeviceLostRecovery(Copyable):
    """Stateful recovery coordinator (A-076 pattern): accounting
    before integration - snapshot, digest, loss, discard and
    iteration ledgers are all charged BEFORE any continuation is
    produced, and every verdict is logged on a bounded log."""

    var config: RecoveryConfig
    var log: List[String]
    var log_dropped: Int

    def __init__(out self, config: RecoveryConfig):
        self.config = config.copy()
        self.log = List[String]()
        self.log_dropped = 0

    def _record(mut self, entry: String):
        if len(self.log) >= LOG_MAX:
            self.log_dropped += 1
            return
        self.log.append(entry)

    def run(
        mut self,
        seed: Int,
        prompt: List[Int],
        total_steps: Int,
        loss_steps: List[Int],
    ) -> RecoveryReport:
        """Run total_steps decode steps starting on the device.
        loss_steps scripts the injection: the GPU step whose
        index appears in loss_steps returns VK_ERROR_DEVICE_LOST
        (consumed once per entry) instead of committing. See the
        file header for the full contract."""
        var cfg = self.config
        var state = ConversationState(seed, prompt, cfg.kv_channels)
        var snapshot = state.serialize()
        var snapshot_digest = state_digest(snapshot)
        var control = control_run(
            seed, prompt, total_steps, cfg.vocab, cfg.kv_channels
        )
        var control_bytes = control.serialize()
        var losses = 0
        var discarded = 0
        var iterations = 0
        var outcome = OUTCOME_COMPLETED_GPU
        var error = String("")
        var state_intact = True
        var finished = False
        var step = 0
        var pending_loss = loss_steps.copy()

        while step < total_steps and not finished:
            iterations += 1
            if iterations > cfg.max_iterations:
                outcome = OUTCOME_FAILED_CLOSED
                error = String(
                    "DeviceLost.watchdog: iteration budget "
                ) + String(cfg.max_iterations) + String(
                    " exhausted before step "
                ) + String(step) + String(
                    " - run terminated, not hung"
                )
                self._record(String("watchdog_budget_exhausted"))
                finished = True
                break
            var is_loss = False
            for i in range(len(pending_loss)):
                if pending_loss[i] == step:
                    is_loss = True
                    break
            if not is_loss:
                state.commit(oracle_next_token(state, cfg.vocab))
                snapshot = state.serialize()
                snapshot_digest = state_digest(snapshot)
                step += 1
                continue
            # --- device-lost at this step: account BEFORE acting.
            losses += 1
            discarded += 1
            var remaining = List[Int]()
            var consumed = False
            for i in range(len(pending_loss)):
                if pending_loss[i] == step and not consumed:
                    consumed = True
                else:
                    remaining.append(pending_loss[i])
            pending_loss = remaining^
            self._record(
                String("device_lost step=") + String(step)
                + String(" vk_result=") + String(VK_ERROR_DEVICE_LOST)
                + String(" committed=") + String(len(state.committed))
                + String(" discarded_total=") + String(discarded)
            )
            # Verify the snapshot of the last commit, byte-for-byte.
            var snap_now = snapshot.copy()
            if cfg.corrupt_snapshot_at_loss and len(snap_now) > 0:
                snap_now[0] = snap_now[0] ^ UInt8(0xFF)
            var verified = bytes_equal(snap_now, state.serialize()) and (
                state_digest(snap_now) == snapshot_digest
            )
            if not verified:
                state_intact = False
            var code = taxonomy_code_for_vk_result(VK_ERROR_DEVICE_LOST)
            if verified and cfg.failover_allowed and losses == 1:
                # Fail over: CPU recomputes the discarded step and
                # continues from exactly the committed prefix.
                self._record(
                    String("failover_to_cpu from_step=") + String(step)
                )
                var cpu_ok = True
                while step < total_steps:
                    iterations += 1
                    if iterations > cfg.max_iterations:
                        cpu_ok = False
                        break
                    state.commit(oracle_next_token(state, cfg.vocab))
                    step += 1
                if cpu_ok:
                    outcome = OUTCOME_FAILED_OVER_CPU
                    error = String("")
                else:
                    outcome = OUTCOME_FAILED_CLOSED
                    error = String(
                        "DeviceLost.watchdog: iteration budget "
                    ) + String(cfg.max_iterations) + String(
                        " exhausted during CPU failover"
                    )
                finished = True
                break
            # Fail closed: state stays exactly at the last commit.
            outcome = OUTCOME_FAILED_CLOSED
            var reason = String("failover_not_permitted")
            if not verified:
                reason = String("snapshot_verification_failed")
            elif losses > 1:
                reason = String("second_device_loss")
            error = String("DeviceLost.fail_closed: ") + code + String(
                " GPU_INIT_FAILED (VkResult "
            ) + String(VK_ERROR_DEVICE_LOST) + String(") reason=") + reason
            self._record(
                String("fail_closed reason=") + reason
                + String(" code=") + code
            )
            finished = True
            break

        var final_bytes = state.serialize()
        var control_match = bytes_equal(final_bytes, control_bytes)
        if outcome == OUTCOME_FAILED_OVER_CPU and not control_match:
            # A failover that lands anywhere but the control bytes
            # is corruption, reported as such - never success.
            state_intact = False
        if outcome == OUTCOME_FAILED_CLOSED:
            state_intact = state_intact and bytes_equal(
                final_bytes, snapshot
            )
        return RecoveryReport(
            outcome,
            losses,
            discarded,
            iterations,
            cfg.max_iterations,
            len(state.committed),
            state_intact,
            control_match,
            error,
            final_bytes,
            snapshot,
            self.log,
            self.log_dropped,
        )
