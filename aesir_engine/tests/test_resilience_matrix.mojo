# tests/test_resilience_matrix.mojo
# Verification of durable checkpoints, local event records, and task descriptors

from core.state_vault import StateVault, VaultCheckpoint
from core.event_bus import AesirEventBus, EventSubscription
from core.thread_pool import RuneThreadPool, RuneTask

def test_state_vault_durable_checkpoints() raises:
    print("--- Testing StateVault Marker Checkpoints & Corruption Detection ---")
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

    var invalid_fields = VaultCheckpoint(-1, 32, chk.checksum, 5000, True)
    rejected = False
    try:
        _ = vault.restore_checkpoint_checked(invalid_fields)
    except:
        rejected = True
    if not rejected:
        raise Error("StateVault accepted a negative marker position")

    print("StateVault marker checkpoints & corruption detection: PASS")


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

    if bus.pending_count("server_listener") != 1:
        raise Error("AesirEventBus failed to deliver to matching subscriber")
    if bus.pending_count("cli_listener") != 0:
        raise Error("AesirEventBus ignored the subscriber event mask")

    bus.publish_event("HEARTBEAT", "local marker")
    if bus.pending_count("server_listener") != 2 or bus.pending_count("cli_listener") != 1:
        raise Error("AesirEventBus mailbox counts are incorrect")
    var cli_events = bus.drain_events("cli_listener")
    if len(cli_events) != 1 or cli_events[0] != "HEARTBEAT:local marker":
        raise Error("AesirEventBus drain lost event order or payload")
    if bus.pending_count("cli_listener") != 0:
        raise Error("AesirEventBus drain failed to clear mailbox")

    if not bus.unsubscribe("cli_listener"):
        raise Error("AesirEventBus unsubscribe failed")
    if len(bus.subscriptions) != 1:
        raise Error("AesirEventBus unsubscribe failed")

    print("AesirEventBus pub/sub & subscriptions: PASS")


def test_task_descriptor_queue() raises:
    print("--- Testing Bounded Task Descriptors & Unsupported Workers ---")
    var pool = RuneThreadPool(4)
    var count1 = pool.submit_task(101, "embed_job_1")
    var count2 = pool.submit_task(102, "embed_job_2")
    if count2 != 2:
        raise Error("RuneThreadPool submit_task queue count mismatch")

    var cancelled = pool.cancel_task(102)
    if not cancelled:
        raise Error("RuneThreadPool cancel_task failed")

    var completed_before = pool.completed_count
    var execution_rejected = False
    try:
        _ = pool.process_pending_tasks()
    except error:
        execution_rejected = "no worker" in String(error)
    if not execution_rejected or pool.completed_count != completed_before:
        raise Error("RuneThreadPool fabricated payload completion")
    if pool.task_queue[0].is_completed:
        raise Error("RuneThreadPool marked an unexecuted task complete")

    var duplicate_rejected = False
    try:
        _ = pool.submit_task(101, "duplicate")
    except:
        duplicate_rejected = True
    if not duplicate_rejected or len(pool.task_queue) != 2:
        raise Error("RuneThreadPool accepted a duplicate task id")

    pool.shutdown()
    if pool.is_active:
        raise Error("RuneThreadPool shutdown failed to clear active state")

    print("Bounded task descriptors & unsupported workers: PASS")


def main() raises:
    test_state_vault_durable_checkpoints()
    test_event_bus_pub_sub()
    test_task_descriptor_queue()
