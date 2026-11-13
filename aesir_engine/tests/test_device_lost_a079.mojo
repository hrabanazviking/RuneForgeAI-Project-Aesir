"""Device-lost recovery (A-079): injected Vulkan device-lost
mid-run - engine fails over to CPU or fails closed with state
intact, never hangs, never corrupts the conversation state.

The recovery coordinator (core/device_lost) snapshots the
canonical serialized conversation state after every committed
token; a scripted VK_ERROR_DEVICE_LOST at a decode step discards
the in-flight token (never committed), verifies the snapshot
byte-for-byte, and then either fails over to the CPU oracle -
whose recovered final state must equal the uninterrupted
control run BYTE-FOR-BYTE - or fails closed with the A-013
taxonomy error (GPU-001, VkResult -4) and the state frozen at
exactly the last committed snapshot. Every iteration is charged
against a pre-fixed watchdog budget, so termination is a loop
bound, not a hope; the A-079 harness additionally runs the
scenarios under an external `timeout` watchdog.

The live case drives the REAL A-013 shim forced-failure hook:
a conversation is in progress on a real VulkanContext (AMD
Radeon 8060S, RADV STRIX_HALO), the shim is armed with
VK_ERROR_DEVICE_LOST at the device stage, and the recovery
device bring-up fails closed with the taxonomy error while the
conversation state stays byte-identical and the original
context still closes cleanly. Injection is shim-level only -
no driver reset, no sysfs, nothing that can wedge the shared
GPU (A-079 safety review, filed in the ledger). llvmpipe is
refused by identity, as in A-076.
"""
from core.device_lost import (
    OUTCOME_COMPLETED_GPU,
    OUTCOME_FAILED_CLOSED,
    OUTCOME_FAILED_OVER_CPU,
    VK_ERROR_DEVICE_LOST,
    ConversationState,
    DeviceLostRecovery,
    RecoveryConfig,
    bytes_equal,
    control_run,
    oracle_next_token,
    outcome_name,
    state_digest,
)
from core.vulkan_buffers import VulkanBuffers
from core.vulkan_context import (
    INJECT_STAGE_DEVICE,
    VulkanContext,
    taxonomy_code_for_vk_result,
)


def _prompt() -> List[Int]:
    var p = List[Int]()
    p.append(11)
    p.append(4)
    p.append(23)
    p.append(7)
    return p^


def _cfg(failover: Bool, budget: Int) -> RecoveryConfig:
    return RecoveryConfig(failover, 64, 4, budget, False)


def _loss(step: Int) -> List[Int]:
    var l = List[Int]()
    l.append(step)
    return l^


def _vk_present() -> Bool:
    if not VulkanBuffers.runtime_available():
        return False
    if not VulkanBuffers.dispatch_available():
        return False
    try:
        var info = VulkanBuffers.device_info()
        if info.vendor_id != 0x1002:
            return False
        if info.device_type == 4:
            return False
        return VulkanBuffers.device_name_is_radv()
    except:
        return False


def test_device_lost_taxonomy() raises:
    print("--- Testing device-lost taxonomy + outcome names (A-079) ---")
    if VK_ERROR_DEVICE_LOST != -4:
        raise Error("VK_ERROR_DEVICE_LOST must be -4")
    if taxonomy_code_for_vk_result(VK_ERROR_DEVICE_LOST) != String("GPU-001"):
        raise Error("device-lost must map to GPU-001 (A-013 taxonomy)")
    if outcome_name(OUTCOME_COMPLETED_GPU) != String("COMPLETED_GPU"):
        raise Error("outcome name drift: COMPLETED_GPU")
    if outcome_name(OUTCOME_FAILED_OVER_CPU) != String("FAILED_OVER_CPU"):
        raise Error("outcome name drift: FAILED_OVER_CPU")
    if outcome_name(OUTCOME_FAILED_CLOSED) != String("FAILED_CLOSED"):
        raise Error("outcome name drift: FAILED_CLOSED")
    # Integrity primitives: a single flipped byte must break both
    # byte equality and the digest.
    var a = List[UInt8]()
    a.append(UInt8(1))
    a.append(UInt8(2))
    a.append(UInt8(3))
    var b = a.copy()
    if not bytes_equal(a, b):
        raise Error("identical bytes must compare equal")
    b[1] = UInt8(9)
    if bytes_equal(a, b):
        raise Error("a flipped byte must break byte equality")
    if state_digest(a) == state_digest(b):
        raise Error("a flipped byte must change the digest")


def test_device_lost_control_parity() raises:
    print("--- Testing no-loss control parity (A-079) ---")
    var rec = DeviceLostRecovery(_cfg(True, 1000))
    var report = rec.run(5, _prompt(), 16, List[Int]())
    if report.outcome != OUTCOME_COMPLETED_GPU:
        raise Error("no-loss run must complete on GPU")
    if report.losses != 0 or report.discarded != 0:
        raise Error("no-loss run must record no loss / discard")
    if report.committed_count != 16:
        raise Error("no-loss run must commit all 16 tokens")
    if not report.control_match:
        raise Error("no-loss final state must equal control bytes")
    if not report.state_intact:
        raise Error("no-loss run must report state intact")
    if report.iterations != 16:
        raise Error("no-loss run must charge exactly 16 iterations")


def test_device_lost_failover_midrun() raises:
    print("--- Testing mid-run device-lost failover to CPU (A-079) ---")
    # Loss at step 5, step 0, and the final step: in every case
    # the run fails over and the recovered final state equals
    # the uninterrupted control run byte-for-byte.
    var points = List[Int]()
    points.append(5)
    points.append(0)
    points.append(15)
    for pi in range(len(points)):
        var at = points[pi]
        var rec = DeviceLostRecovery(_cfg(True, 1000))
        var report = rec.run(5, _prompt(), 16, _loss(at))
        if report.outcome != OUTCOME_FAILED_OVER_CPU:
            raise Error(
                "loss at step " + String(at) + " must fail over to CPU"
            )
        if report.losses != 1 or report.discarded != 1:
            raise Error("exactly one loss + one discarded in-flight token")
        if report.committed_count != 16:
            raise Error("failover must still commit all 16 tokens")
        if not report.control_match:
            raise Error(
                "failover final state must equal control bytes "
                "byte-for-byte (loss at step " + String(at) + ")"
            )
        if not report.state_intact:
            raise Error("failover must report state intact")
        if report.error != String(""):
            raise Error("failover must not carry a fail-closed error")
        # Iterations: loss step + all 16 steps (the discarded step
        # is recomputed on CPU) = 17, inside budget.
        if report.iterations != 17:
            raise Error("failover iteration accounting must be exact")


def test_device_lost_fail_closed_state_intact() raises:
    print("--- Testing device-lost fail-closed, state intact (A-079) ---")
    var rec = DeviceLostRecovery(_cfg(False, 1000))
    var report = rec.run(5, _prompt(), 16, _loss(5))
    if report.outcome != OUTCOME_FAILED_CLOSED:
        raise Error("no-failover policy must fail closed")
    if report.committed_count != 5:
        raise Error("fail-closed must freeze at the 5 committed tokens")
    if not report.state_intact:
        raise Error("fail-closed state must be intact")
    if not bytes_equal(report.final_state, report.snapshot_state):
        raise Error(
            "fail-closed final state must equal the last committed "
            "snapshot byte-for-byte"
        )
    # The frozen state must equal the control run truncated to
    # the same committed prefix - byte-for-byte.
    var prefix = control_run(5, _prompt(), 5, 64, 4)
    if not bytes_equal(report.final_state, prefix.serialize()):
        raise Error("fail-closed state must equal the 5-token control prefix")
    if report.control_match:
        raise Error("a 5-of-16 state must not claim control match")
    if String("GPU-001") not in report.error:
        raise Error("fail-closed error must carry GPU-001")
    if String("-4") not in report.error:
        raise Error("fail-closed error must carry VkResult -4")
    if String("failover_not_permitted") not in report.error:
        raise Error("fail-closed error must name its reason")


def test_device_lost_edges_and_repeat() raises:
    print("--- Testing loss edges: second loss + torn snapshot (A-079) ---")
    # A loss scripted at consecutive steps: the first loss ends
    # device work; with failover disabled the run closes at the
    # first loss - the second scripted loss is never consumed
    # by a retry (no retry loop exists to consume it).
    var two = List[Int]()
    two.append(3)
    two.append(4)
    var rec = DeviceLostRecovery(_cfg(False, 1000))
    var report = rec.run(5, _prompt(), 16, two^)
    if report.outcome != OUTCOME_FAILED_CLOSED:
        raise Error("repeated loss must fail closed")
    if report.losses != 1:
        raise Error("device work must end at the first loss (no retries)")
    if report.committed_count != 3:
        raise Error("repeated-loss run must freeze at 3 committed tokens")
    if not report.state_intact:
        raise Error("repeated-loss state must be intact")
    # Torn snapshot (loss during checkpoint readback): failover
    # is permitted but verification fails, so the run must fail
    # closed with the verification reason - never continue on
    # unverified state.
    var torn_cfg = RecoveryConfig(True, 64, 4, 1000, True)
    var rec2 = DeviceLostRecovery(torn_cfg)
    var report2 = rec2.run(5, _prompt(), 16, _loss(5))
    if report2.outcome != OUTCOME_FAILED_CLOSED:
        raise Error("torn snapshot must fail closed even with failover on")
    if report2.state_intact:
        raise Error("torn snapshot must be reported as not intact")
    if String("snapshot_verification_failed") not in report2.error:
        raise Error("torn-snapshot error must name the verification reason")
    if report2.committed_count != 5:
        raise Error("torn-snapshot run must freeze at 5 committed tokens")


def test_device_lost_watchdog_bound() raises:
    print("--- Testing watchdog iteration bound (A-079) ---")
    # Budget smaller than the run: the coordinator must end the
    # run FAILED_CLOSED with a watchdog reason at the budget,
    # never iterate past it - termination by construction.
    var rec = DeviceLostRecovery(_cfg(True, 4))
    var report = rec.run(5, _prompt(), 16, List[Int]())
    if report.outcome != OUTCOME_FAILED_CLOSED:
        raise Error("budget-exhausted run must fail closed")
    if report.iterations != 5:
        raise Error("iterations must stop at budget + 1 detection charge")
    if String("watchdog") not in report.error:
        raise Error("budget exhaustion must name the watchdog")
    if not report.state_intact:
        raise Error("watchdog-terminated state must equal its snapshot")
    # A loss storm inside a generous budget still terminates in
    # exactly the bounded failover accounting (17 iterations).
    var storm = List[Int]()
    for s in range(16):
        storm.append(s)
    var rec2 = DeviceLostRecovery(_cfg(True, 1000))
    var report2 = rec2.run(5, _prompt(), 16, storm^)
    if report2.outcome != OUTCOME_FAILED_OVER_CPU:
        raise Error("loss storm must end in the single permitted failover")
    if report2.losses != 1:
        raise Error("loss storm must consume exactly one device loss")
    if report2.iterations != 17 or report2.iterations > report2.budget:
        raise Error("loss storm iterations must stay inside the budget")
    if not report2.control_match or not report2.state_intact:
        raise Error("loss storm failover must land on control bytes intact")


def test_device_lost_live_shim_fail_closed() raises:
    print("--- Testing REAL shim device-lost fail-closed (A-079) ---")
    if not _vk_present():
        print("  Vulkan/RADV absent on this host - honest-absent, skipping")
        return
    # Conversation in progress on a real context.
    var ctx = VulkanContext.create()
    var state = ConversationState(5, _prompt(), 4)
    for _ in range(5):
        state.commit(oracle_next_token(state, 64))
    var before = state.serialize()
    # Arm the A-013 forced-failure hook: the recovery device
    # bring-up returns VK_ERROR_DEVICE_LOST. Shim-level only.
    VulkanContext.inject_failure(INJECT_STAGE_DEVICE, VK_ERROR_DEVICE_LOST)
    var raised = String("")
    try:
        var ctx2 = VulkanContext.create()
        ctx2.close()
        raised = String("NO-ERROR")
    except e:
        raised = String(e)
    VulkanContext.clear_injection()
    if raised == String("NO-ERROR"):
        raise Error("injected device-lost must raise, not create a context")
    if String("GPU-001") not in raised:
        raise Error("injected device-lost must surface GPU-001, got: " + raised)
    if String("-4") not in raised:
        raise Error("injected device-lost must carry VkResult -4")
    var after = state.serialize()
    if not bytes_equal(before, after):
        raise Error("conversation state changed across the failed recovery")
    if state_digest(before) != state_digest(after):
        raise Error("conversation digest changed across the failed recovery")
    # The original context is untouched by the failed bring-up
    # and still closes cleanly; a fresh context can be created
    # once the one-shot injection is consumed.
    ctx.close()
    var ctx3 = VulkanContext.create()
    ctx3.close()
    print("  live device-lost fail-closed proven on RADV; state byte-intact")
