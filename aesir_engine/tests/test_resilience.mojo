# tests/test_resilience.mojo
# Verification of Resilience, Self-Healing & Multi-Threading Matrix (Slice 12)

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.mimir_well import Scalar, f16
from core.error_guard import ErrorGuard
from core.state_vault import StateVault
from core.event_bus import AesirEventBus
from core.thread_pool import RuneThreadPool
from core.supervisor import SelfHealingSupervisor

def test_error_guard() raises:
    print("--- Testing ErrorGuard (Pointer & Logit Sanitization) ---")
    var success = True
    var ptr = alloc(Layout[Scalar[f16]](count=8)).unsafe_leak()

    if not ErrorGuard.validate_pointer(ptr):
        print("FAIL: ErrorGuard.validate_pointer failed")
        success = False

    if not ErrorGuard.bounds_check(3, 8):
        print("FAIL: ErrorGuard.bounds_check valid index failed")
        success = False

    if ErrorGuard.bounds_check(10, 8):
        print("FAIL: ErrorGuard.bounds_check invalid index failed")
        success = False

    # Store Inf/NaN and test sanitization
    ptr.unsafe_store(0, Scalar[f16](70000.0))
    ErrorGuard.sanitize_logits(ptr, 8)
    if ptr.unsafe_load(0) != Scalar[f16](-65504.0):
        print("FAIL: Logit sanitization failed")
        success = False

    ptr.unsafe_free()

    if success:
        print("ErrorGuard: PASS")
    else:
        raise Error("ErrorGuard scaffold invariant mismatch")


def test_state_vault() raises:
    print("--- Testing StateVault (Autoregressive Checkpointing) ---")
    var success = True
    var vault = StateVault()
    vault.save_checkpoint(128, 16)

    if not vault.is_checkpointed:
        print("FAIL: StateVault save checkpoint failed")
        success = False

    if vault.restore_checkpoint() != 128:
        print("FAIL: StateVault restore checkpoint mismatch")
        success = False

    if success:
        print("StateVault: PASS")
    else:
        raise Error("StateVault scaffold invariant mismatch")


def test_event_bus() raises:
    print("--- Testing AesirEventBus (Inter-Module Messaging) ---")
    var success = True
    var bus = AesirEventBus()
    bus.publish_event("MODEL_LOADED", "llama3:latest")

    if bus.get_last_event() != "MODEL_LOADED":
        print("FAIL: AesirEventBus event publish mismatch")
        success = False

    if success:
        print("AesirEventBus: PASS")
    else:
        raise Error("AesirEventBus marker invariant mismatch")


def test_thread_pool() raises:
    print("--- Testing RuneThreadPool (Parallel Worker Execution) ---")
    var success = True
    var pool = RuneThreadPool(8)

    if not pool.parallel_step():
        print("FAIL: RuneThreadPool parallel_step failed")
        success = False

    if success:
        print("RuneThreadPool: PASS")
    else:
        raise Error("RuneThreadPool scaffold invariant mismatch")


def test_supervisor_crash_recovery() raises:
    print("--- Testing SelfHealingSupervisor (Panic Recovery & Self-Healing) ---")
    var success = True
    var supervisor = SelfHealingSupervisor()
    supervisor.vault.save_checkpoint(64, 8)

    if not supervisor.simulate_crash_and_recover():
        print("FAIL: SelfHealingSupervisor crash recovery failed")
        success = False

    if not supervisor.is_healthy:
        print("FAIL: Supervisor status not healthy after recovery")
        success = False

    if supervisor.recovery_count != 1:
        print("FAIL: Recovery count mismatch")
        success = False

    if success:
        print("SelfHealingSupervisor Crash Recovery: PASS")
    else:
        raise Error("SelfHealingSupervisor simulation invariant mismatch")
