# tests/test_resilience.mojo
# Verification of local resilience scaffold markers

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

    var sentinel_ptr = Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1)
    if ErrorGuard.validate_pointer(sentinel_ptr):
        print("FAIL: ErrorGuard.validate_pointer accepted sentinel address 1")
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
    print("--- Testing StateVault in-memory marker ---")
    var success = True
    var vault = StateVault()
    vault.save_checkpoint(128, 16)

    if not vault.is_checkpointed:
        print("FAIL: StateVault save checkpoint failed")
        success = False

    if vault.restore_checkpoint() != 128:
        print("FAIL: StateVault restore checkpoint mismatch")
        success = False

    # Test negative token_pos and prompt_count bounds rejection
    var neg_vault = StateVault()
    neg_vault.save_checkpoint(-10, 16)
    if neg_vault.is_checkpointed:
        print("FAIL: StateVault accepted negative token_pos")
        success = False

    neg_vault.save_checkpoint(128, -5)
    if neg_vault.is_checkpointed:
        print("FAIL: StateVault accepted negative prompt_count")
        success = False

    if success:
        print("StateVault in-memory marker: PASS")
    else:
        raise Error("StateVault scaffold invariant mismatch")


def test_event_bus() raises:
    print("--- Testing AesirEventBus last-event marker ---")
    var success = True
    var bus = AesirEventBus()
    bus.publish_event("MODEL_LOADED", "llama3:latest")

    if bus.get_last_event() != "MODEL_LOADED":
        print("FAIL: AesirEventBus event publish mismatch")
        success = False

    # Test empty string event_type rejection
    var empty_bus = AesirEventBus()
    empty_bus.publish_event("", "payload")
    if empty_bus.event_count != 0:
        print("FAIL: AesirEventBus accepted empty event_type")
        success = False

    if success:
        print("AesirEventBus last-event marker: PASS")
    else:
        raise Error("AesirEventBus marker invariant mismatch")


def test_thread_pool() raises:
    print("--- Testing RuneThreadPool state scaffold ---")
    var success = True
    var pool = RuneThreadPool(8)

    if not pool.parallel_step():
        print("FAIL: RuneThreadPool parallel_step failed")
        success = False

    # Test non-positive num_threads clamping safety
    var zero_pool = RuneThreadPool(0)
    var neg_pool = RuneThreadPool(-4)
    if zero_pool.num_threads != 1 or neg_pool.num_threads != 1:
        print("FAIL: RuneThreadPool failed to clamp non-positive num_threads to 1")
        success = False

    if success:
        print("RuneThreadPool state scaffold: PASS")
    else:
        raise Error("RuneThreadPool scaffold invariant mismatch")


def test_supervisor_crash_recovery() raises:
    print("--- Testing explicit supervisor simulation marker ---")
    var success = True
    var supervisor = SelfHealingSupervisor()
    supervisor.vault.save_checkpoint(64, 8)

    if not supervisor.simulate_crash_and_recover():
        print("FAIL: supervisor simulation marker did not complete")
        success = False

    if not supervisor.is_healthy:
        print("FAIL: supervisor local state did not reset after simulation")
        success = False

    if supervisor.recovery_count != 1:
        print("FAIL: Recovery count mismatch")
        success = False
    if supervisor.bus.get_last_event() != "RECOVERY_COMPLETE":
        print("FAIL: supervisor simulation omitted completion marker")
        success = False

    if success:
        print("supervisor simulation marker: PASS")
    else:
        raise Error("SelfHealingSupervisor simulation invariant mismatch")
