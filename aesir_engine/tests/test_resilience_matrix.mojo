# tests/test_resilience_matrix.mojo
# Verification of StateVault durable checkpoints, AesirEventBus pub/sub, and RuneThreadPool worker pool

from core.state_vault import StateVault, VaultCheckpoint
from core.event_bus import AesirEventBus, EventSubscription
from core.thread_pool import RuneThreadPool, RuneTask

def test_state_vault_durable_checkpoints() raises:
    print("--- Testing StateVault Durable Checkpoints & Checksum Verification ---")
    var vault = StateVault()
    var chk = vault.save_checkpoint(128, 32, 5000)

    var restored_pos = vault.restore_checkpoint_checked(chk)
    if restored_pos != 128:
        raise Error("StateVault restore_checkpoint_checked failed to restore token pos")

    # Corrupt checksum to verify rejection guard
    var corrupt_chk = VaultCheckpoint(128, 32, 9999999, 5000, True)
    var rejected = False
    try:
        var _ = vault.restore_checkpoint_checked(corrupt_chk)
    except:
        rejected = True
    if not rejected:
        raise Error("StateVault failed to reject corrupt checksum checkpoint")

    print("StateVault durable checkpoints & checksum verification: PASS")


def test_event_bus_pub_sub() raises:
    print("--- Testing AesirEventBus Pub/Sub & Subscriptions ---")
    var bus = AesirEventBus()
    bus.subscribe("server_listener", 0xFFFF)
    bus.subscribe("cli_listener", 0x0001)

    bus.publish_event("MODEL_LOADED", "llama-3-8b.gguf")
    if bus.get_last_event() != "MODEL_LOADED":
        raise Error("AesirEventBus get_last_event mismatch")

    if len(bus.event_log) != 1:
        raise Error("AesirEventBus event log count mismatch")

    bus.unsubscribe("cli_listener")
    if len(bus.subscriptions) != 1:
        raise Error("AesirEventBus unsubscribe failed")

    print("AesirEventBus pub/sub & subscriptions: PASS")


def test_thread_pool_concurrency() raises:
    print("--- Testing RuneThreadPool Worker Pool & Cancellation ---")
    var pool = RuneThreadPool(4)
    var count1 = pool.submit_task(101, "embed_job_1")
    var count2 = pool.submit_task(102, "embed_job_2")
    if count2 != 2:
        raise Error("RuneThreadPool submit_task queue count mismatch")

    var cancelled = pool.cancel_task(102)
    if not cancelled:
        raise Error("RuneThreadPool cancel_task failed")

    var processed = pool.process_pending_tasks()
    if processed != 1:
        raise Error("RuneThreadPool process_pending_tasks should process exactly 1 un-cancelled task")

    pool.shutdown()
    if pool.is_active:
        raise Error("RuneThreadPool shutdown failed to clear active state")

    print("RuneThreadPool worker pool & cancellation: PASS")


def main() raises:
    test_state_vault_durable_checkpoints()
    test_event_bus_pub_sub()
    test_thread_pool_concurrency()
