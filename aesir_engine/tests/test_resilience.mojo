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

    var invalid_rejected = False
    try:
        ErrorGuard.sanitize_logits(sentinel_ptr, 8)
    except:
        invalid_rejected = True
    if not invalid_rejected:
        print("FAIL: Logit sanitizer silently accepted a sentinel pointer")
        success = False

    invalid_rejected = False
    try:
        ErrorGuard.sanitize_logits(ptr, 0)
    except:
        invalid_rejected = True
    if not invalid_rejected:
        print("FAIL: Logit sanitizer silently accepted a zero count")
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
    var checkpoint = vault.save_checkpoint(128, 16)

    if not vault.is_checkpointed:
        print("FAIL: StateVault save checkpoint failed")
        success = False

    if vault.restore_checkpoint() != 128:
        print("FAIL: StateVault restore checkpoint mismatch")
        success = False
    if checkpoint.timestamp <= 0 or checkpoint.timestamp == 1000:
        print("FAIL: StateVault default timestamp was not observed from the clock")
        success = False

    # Test negative token_pos and prompt_count bounds rejection
    var neg_vault = StateVault()
    var negative_rejected = False
    try:
        _ = neg_vault.save_checkpoint(-10, 16)
    except:
        negative_rejected = True
    if not negative_rejected or neg_vault.is_checkpointed:
        print("FAIL: StateVault accepted negative token_pos")
        success = False

    negative_rejected = False
    try:
        _ = neg_vault.save_checkpoint(128, -5)
    except:
        negative_rejected = True
    if not negative_rejected or neg_vault.is_checkpointed:
        print("FAIL: StateVault accepted negative prompt_count")
        success = False

    # Test disk file checkpointing
    var tmp_path = String("/tmp/aesir_vault_test.chk")
    var _3 = vault.save_checkpoint_to_disk(tmp_path, 256, 32, 2000)
    var loaded_vault = StateVault()
    var loaded_chk = loaded_vault.load_checkpoint_from_disk(tmp_path)
    if loaded_chk.token_pos != 256 or loaded_chk.prompt_tokens_count != 32:
        print("FAIL: StateVault disk checkpoint token_pos/prompt_count mismatch")
        success = False

    # A malformed replacement must fail without replacing the last valid
    # in-memory marker in the loading vault.
    var corrupt_file = open(tmp_path, "w")
    corrupt_file.write("TOKEN_POS=999\n")
    corrupt_file.close()
    var prior = loaded_vault.active_checkpoint.copy()
    var malformed_rejected = False
    try:
        _ = loaded_vault.load_checkpoint_from_disk(tmp_path)
    except:
        malformed_rejected = True
    if (
        not malformed_rejected
        or loaded_vault.active_checkpoint.token_pos != prior.token_pos
        or loaded_vault.active_checkpoint.checksum != prior.checksum
    ):
        print("FAIL: StateVault malformed load was accepted or mutated active state")
        success = False

    if success:
        print("StateVault in-memory & disk durable checkpoint: PASS")
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
    var empty_rejected = False
    try:
        empty_bus.publish_event("", "payload")
    except:
        empty_rejected = True
    if not empty_rejected or empty_bus.event_count != 0:
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

    if pool.parallel_step() or pool.get_active_worker_count() != 0:
        print("FAIL: RuneThreadPool claimed workers without creating threads")
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


def test_supervisor_recovery_boundary() raises:
    print("--- Testing Unsupported Supervisor Recovery Boundary ---")
    var success = True
    var supervisor = SelfHealingSupervisor()
    var _ = supervisor.vault.save_checkpoint(64, 8)

    var event_count_before = supervisor.bus.event_count
    var rejected = False
    try:
        _ = supervisor.simulate_crash_and_recover()
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        print("FAIL: supervisor reported runtime recovery")
        success = False
    if not supervisor.is_healthy or supervisor.recovery_count != 0:
        print("FAIL: rejected supervisor recovery mutated health state")
        success = False
    if supervisor.bus.event_count != event_count_before:
        print("FAIL: rejected supervisor recovery published false events")
        success = False

    if success:
        print("unsupported supervisor recovery boundary: PASS")
    else:
        raise Error("SelfHealingSupervisor recovery invariant mismatch")
