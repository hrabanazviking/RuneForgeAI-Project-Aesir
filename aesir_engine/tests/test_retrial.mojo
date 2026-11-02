"""Re-trials (J-045): the bounded cadence as a pure function of
an injected clock and opens counter (age trigger at 30 days,
opens trigger at 25 opens past an absolute 7-day floor, never
due per-open or under clock skew), machine/model key drift
named as not-a-re-trial, manual supremacy (a MANUAL-FIXED kind
is never re-trialled; an all-manual entry is never due),
adoption (a changed verdict replaces the kind through J-044's
store path with the change logged old -> new; a reproduced
verdict keeps the choice and refreshes the measured-at stamp;
a fresh refusal makes the kind absent, and an all-absent
re-trial erases the entry), J-044's ABSENT discipline on the
disk surface (missing/corrupt learned states skip clean and
write nothing), and a live re-trial on this machine's real
facts through the real J-040 chooser.

No number in this suite is a placement verdict: the fixtures'
choices are the choosers' record shapes, and the live group's
outcome (KEPT or ADOPTED) is whichever the contended VM's
chooser honestly returns -- the suite asserts the re-trial
machinery around it, not the choice.
"""
from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.device_inventory import CpuFacts, GpuFacts, observe_device_inventory
from core.learned_file import (
    LOAD_LOADED,
    LOAD_MISSING,
    LearnedEntry,
    LearnedPassChoice,
    MachineKey,
    ModelShape,
    erase_learned_file,
    learned_now_seconds,
    learned_pass_from_choice,
    load_learned_file,
    lookup_learned,
    machine_key_from_facts,
    model_shape,
    store_learned_entry,
    LOOKUP_APPLIED,
)
from core.placement_harness import HarnessConfig
from core.placement_options import DEVICE_CPU, DEVICE_GPU
from core.retrial import (
    KIND_CARRIED_MANUAL,
    KIND_CHANGED,
    KIND_NOT_PRESENT,
    KIND_REFUSED_ABSENT,
    KIND_REPRODUCED,
    OUT_ADOPTED,
    OUT_ERASED,
    OUT_KEPT,
    OUT_SKIPPED,
    PLAN_DUE,
    PLAN_KEEP,
    PLAN_KEY_DRIFT,
    PLAN_MANUAL_ONLY,
    RETRIAL_AGE_S,
    RETRIAL_MIN_AGE_S,
    RETRIAL_OPENS,
    TRIGGER_AGE,
    TRIGGER_AGE_OPENS,
    TRIGGER_OPENS,
    RetrialOutcome,
    adopt_retrial,
    append_retrial_log,
    apply_retrial,
    kind_retriable,
    plan_retrial,
    retrial_log_path,
    run_retrial,
)
from core.thread_topology import observe_cpu_facts


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "Retrial "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_eq64(actual: Int64, expected: Int64, what: String) raises:
    if actual != expected:
        raise Error(
            "Retrial "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("Retrial " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "Retrial "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


def _env_value(name: String) -> Tuple[Bool, String]:
    var buf = InlineArray[Int8, 32](fill=0)
    var bytes = name.as_bytes()
    if len(bytes) >= 32:
        return (False, String(""))
    for i in range(len(bytes)):
        buf[i] = Int8(bytes[i])
    var raw = external_call["getenv", Pointer[UInt8, MutUntrackedOrigin]](
        buf.unsafe_ptr()
    )
    if Int(raw) == 0:
        return (False, String(""))
    var value = String("")
    var i = 0
    while i < 1024:
        var c = raw.unsafe_load(i)
        if c == 0:
            break
        value += chr(Int(c))
        i += 1
    return (True, value)


def _test_dir() -> String:
    var env = _env_value("J045_TEST_DIR")
    if env[0] and env[1].byte_length() > 0:
        return env[1]
    return String("/tmp/j045-retrial-") + String(
        external_call["getpid", Int32]()
    )


def _write_text(path: String, text: String) raises:
    var handle = open(path, "w")
    handle.write(text)
    handle.close()


def _read_text(path: String) raises -> String:
    var text: String
    with open(path, "r") as source:
        text = source.read()
    return text


def _exists(path: String) -> Bool:
    try:
        _ = _read_text(path)
        return True
    except:
        return False


# --- fixtures (the J-044 fixture shapes, restated) -------------------------

comptime T0 = Int64(1760000000)
comptime DAY = Int64(86400)


def _machine_a() -> MachineKey:
    var cpu = CpuFacts()
    cpu.model = String("Fixture CPU 9000")
    cpu.logical = 8
    cpu.physical_cores = 4
    cpu.packages = 1
    var gpu = GpuFacts()
    gpu.name = String("Fixture GPU X")
    gpu.vram_total_bytes = 8589934592
    gpu.vram_free_bytes = 4294967296
    gpu.count = 1
    return machine_key_from_facts(cpu, gpu)


def _machine_b() -> MachineKey:
    var key = _machine_a()
    key.cpu_model = String("Other CPU 100")
    key.logical = 16
    key.physical_cores = 8
    return key


def _shape_moe() -> ModelShape:
    return model_shape("olmoe", 2048, 16, 16, 16, 11008, 8192, 64, 8)


def _shape_dense() -> ModelShape:
    return model_shape("llama", 4096, 32, 32, 8, 14336, 131072, 0, 0)


def _entry_measured() -> LearnedEntry:
    """Prompt + reply measured under auto; drafts absent."""
    var entry = LearnedEntry()
    entry.machine = _machine_a()
    entry.model = _shape_moe()
    entry.measured_at = T0
    entry.prompt = learned_pass_from_choice(
        "auto", "cpu threads=2", DEVICE_CPU, 2, "MEASURED-WIN", True
    )
    entry.reply = learned_pass_from_choice(
        "auto", "cpu threads=1", DEVICE_CPU, 1, "DEFAULT-CONFIRMED", True
    )
    return entry^


def _entry_mixed_manual() -> LearnedEntry:
    """Prompt manual (gpu), reply measured under auto."""
    var entry = LearnedEntry()
    entry.machine = _machine_a()
    entry.model = _shape_moe()
    entry.measured_at = T0
    entry.prompt = learned_pass_from_choice(
        "gpu", "gpu", DEVICE_GPU, 0, "MANUAL-FIXED", True
    )
    entry.reply = learned_pass_from_choice(
        "auto", "cpu threads=1", DEVICE_CPU, 1, "DEFAULT-CONFIRMED", True
    )
    return entry^


def _entry_all_manual() -> LearnedEntry:
    var entry = LearnedEntry()
    entry.machine = _machine_a()
    entry.model = _shape_moe()
    entry.measured_at = T0
    entry.prompt = learned_pass_from_choice(
        "gpu", "gpu", DEVICE_GPU, 0, "MANUAL-FIXED", True
    )
    entry.reply = learned_pass_from_choice(
        "cpu", "cpu threads=1", DEVICE_CPU, 1, "MANUAL-FIXED", True
    )
    return entry^


def _absent() -> LearnedPassChoice:
    return learned_pass_from_choice(
        "auto", "", DEVICE_CPU, 0, "REFUSAL", False
    )


# --- groups ------------------------------------------------------------------


def test_cadence_age() raises:
    var entry = _entry_measured()
    var young = plan_retrial(entry, T0 + DAY, 0, _machine_a(), _shape_moe())
    expect_eq(young.state, PLAN_KEEP, "one day old is not due")
    expect_eq64(young.age_seconds, DAY, "the plan states the injected age")
    var almost = plan_retrial(
        entry, T0 + Int64(RETRIAL_AGE_S) - 1, 0, _machine_a(), _shape_moe()
    )
    expect_eq(almost.state, PLAN_KEEP, "one second under the age trigger keeps")
    var exact = plan_retrial(
        entry, T0 + Int64(RETRIAL_AGE_S), 0, _machine_a(), _shape_moe()
    )
    expect_eq(exact.state, PLAN_DUE, "exactly at the age trigger is due")
    expect_eq(exact.trigger, TRIGGER_AGE, "the age trigger is named")
    expect_true(exact.due_prompt and exact.due_reply, "both measured kinds due")
    expect_true(not exact.due_drafts, "an absent kind is never due")
    var old = plan_retrial(
        entry, T0 + 400 * DAY, 0, _machine_a(), _shape_moe()
    )
    expect_eq(old.state, PLAN_DUE, "a very old entry is due on age alone")
    print("PASS: cadence age -- 30d trigger, exact boundary, absent kind not due")


def test_cadence_opens_bounded() raises:
    var entry = _entry_measured()
    var under = plan_retrial(
        entry, T0 + 10 * DAY, RETRIAL_OPENS - 1, _machine_a(), _shape_moe()
    )
    expect_eq(under.state, PLAN_KEEP, "24 opens at 10 days is not due")
    var fired = plan_retrial(
        entry, T0 + 10 * DAY, RETRIAL_OPENS, _machine_a(), _shape_moe()
    )
    expect_eq(fired.state, PLAN_DUE, "25 opens at 10 days is due")
    expect_eq(fired.trigger, TRIGGER_OPENS, "the opens trigger is named")
    var burst = plan_retrial(
        entry, T0 + DAY, 100000, _machine_a(), _shape_moe()
    )
    expect_eq(
        burst.state,
        PLAN_KEEP,
        "a burst of opens under the 7-day floor never fires (bounded)",
    )
    var floor_edge = plan_retrial(
        entry, T0 + Int64(RETRIAL_MIN_AGE_S), RETRIAL_OPENS,
        _machine_a(), _shape_moe(),
    )
    expect_eq(floor_edge.state, PLAN_DUE, "opens fire exactly at the floor")
    var floor_under = plan_retrial(
        entry, T0 + Int64(RETRIAL_MIN_AGE_S) - 1, RETRIAL_OPENS,
        _machine_a(), _shape_moe(),
    )
    expect_eq(floor_under.state, PLAN_KEEP, "one second under the floor keeps")
    var one_open = plan_retrial(entry, T0 + 10 * DAY, 1, _machine_a(), _shape_moe())
    expect_eq(one_open.state, PLAN_KEEP, "a single open never re-trials")
    var both = plan_retrial(
        entry, T0 + Int64(RETRIAL_AGE_S), RETRIAL_OPENS, _machine_a(), _shape_moe()
    )
    expect_eq(both.trigger, TRIGGER_AGE_OPENS, "both triggers firing is named")
    var negative = plan_retrial(entry, T0 + 10 * DAY, -5, _machine_a(), _shape_moe())
    expect_eq(negative.opens, 0, "a negative opens counter clamps to 0")
    expect_eq(negative.state, PLAN_KEEP, "the clamped counter does not fire")
    print("PASS: cadence opens -- 25 past the 7d floor; bursts bounded; never per-open")


def test_clock_skew() raises:
    var entry = _entry_measured()
    var skew = plan_retrial(entry, T0 - 3600, 9999, _machine_a(), _shape_moe())
    expect_eq(skew.state, PLAN_KEEP, "a clock before the stamp is never due")
    expect_contains(skew.reason, "skew", "the skew is named as the reason")
    var same = plan_retrial(entry, T0, RETRIAL_OPENS, _machine_a(), _shape_moe())
    expect_eq(same.state, PLAN_KEEP, "age zero is not due even with opens counted")
    print("PASS: clock skew -- negative age keeps, with the reason on the plan")


def test_manual_supremacy_plan() raises:
    expect_true(
        not kind_retriable(_entry_all_manual().prompt),
        "a MANUAL-FIXED kind is not re-triable",
    )
    expect_true(
        kind_retriable(_entry_measured().prompt),
        "a measured kind is re-triable",
    )
    expect_true(
        not kind_retriable(_absent()), "an absent kind is not re-triable"
    )
    var all_manual = plan_retrial(
        _entry_all_manual(), T0 + 400 * DAY, 100000, _machine_a(), _shape_moe()
    )
    expect_eq(
        all_manual.state,
        PLAN_MANUAL_ONLY,
        "an all-manual entry is never due, at any age or opens",
    )
    var mixed = plan_retrial(
        _entry_mixed_manual(), T0 + Int64(RETRIAL_AGE_S), 0,
        _machine_a(), _shape_moe(),
    )
    expect_eq(mixed.state, PLAN_DUE, "a mixed entry is due for its measured kind")
    expect_true(not mixed.due_prompt, "the manual kind is not due")
    expect_true(mixed.due_reply, "the measured kind is due")
    print("PASS: manual supremacy (plan) -- manual never due; mixed due per kind")


def test_key_drift() raises:
    var entry = _entry_measured()
    var now = T0 + Int64(RETRIAL_AGE_S)
    var machine_drift = plan_retrial(entry, now, 0, _machine_b(), _shape_moe())
    expect_eq(machine_drift.state, PLAN_KEY_DRIFT, "a drifted machine is not a re-trial")
    expect_contains(machine_drift.reason, "machine", "the drift names the machine half")
    var model_drift = plan_retrial(entry, now, 0, _machine_a(), _shape_dense())
    expect_eq(model_drift.state, PLAN_KEY_DRIFT, "a drifted shape is not a re-trial")
    expect_contains(model_drift.reason, "model shape", "the drift names the model half")
    var both = plan_retrial(entry, now, 0, _machine_b(), _shape_dense())
    expect_eq(both.state, PLAN_KEY_DRIFT, "a fully drifted key is not a re-trial")
    print("PASS: key drift -- machine / model / both named, never a re-trial")


def test_adopt_changed() raises:
    var entry = _entry_mixed_manual()
    var plan = plan_retrial(
        entry, T0 + Int64(RETRIAL_AGE_S), 0, _machine_a(), _shape_moe()
    )
    var now = T0 + Int64(RETRIAL_AGE_S)
    var fresh_reply = learned_pass_from_choice(
        "auto", "cpu threads=2", DEVICE_CPU, 2, "MEASURED-WIN", True
    )
    var outcome = adopt_retrial(
        entry, plan, _absent(), _absent(), fresh_reply, now
    )
    expect_eq(outcome.status, OUT_ADOPTED, "a changed kind adopts the entry")
    expect_true(outcome.has_new_entry, "the adopted entry exists")
    expect_eq64(
        outcome.new_entry.measured_at, now, "the adopted stamp is the re-trial instant"
    )
    expect_eq(outcome.new_entry.reply.threads, 2, "the fresh reply choice stands")
    expect_contains(
        outcome.new_entry.reply.decision, "MEASURED-WIN", "the fresh decision stands"
    )
    expect_eq(
        outcome.new_entry.prompt.device, DEVICE_GPU, "the manual kind is carried verbatim"
    )
    expect_contains(
        outcome.new_entry.prompt.decision, "MANUAL-FIXED", "manual provenance carried"
    )
    expect_eq(outcome.kinds[0].outcome, KIND_CARRIED_MANUAL, "prompt kind record: carried-manual")
    expect_eq(outcome.kinds[1].outcome, KIND_NOT_PRESENT, "drafts kind record: not present")
    expect_eq(outcome.kinds[2].outcome, KIND_CHANGED, "reply kind record: changed")
    var log = outcome.log_text()
    expect_contains(log, "trigger: AGE", "the log names the trigger")
    expect_contains(log, "cpu threads=1", "the log states the old choice")
    expect_contains(log, "cpu threads=2", "the log states the new choice")
    expect_contains(log, "CHANGED", "the log states the change")
    expect_contains(log, "CARRIED-MANUAL", "the log states the manual carry")
    expect_contains(log, "outcome: ADOPTED", "the log states the outcome")
    print("PASS: adopt changed -- fresh verdict replaces, manual carried, change logged")


def test_adopt_reproduced() raises:
    var entry = _entry_measured()
    var now = T0 + 40 * DAY
    var plan = plan_retrial(entry, now, 0, _machine_a(), _shape_moe())
    expect_eq(plan.state, PLAN_DUE, "the fixture entry is due")
    var outcome = adopt_retrial(
        entry,
        plan,
        learned_pass_from_choice(
            "auto", "cpu threads=2", DEVICE_CPU, 2, "MEASURED-WIN", True
        ),
        _absent(),
        learned_pass_from_choice(
            "auto", "cpu threads=1", DEVICE_CPU, 1, "DEFAULT-CONFIRMED", True
        ),
        now,
    )
    expect_eq(outcome.status, OUT_KEPT, "a fully reproduced re-trial keeps the entry")
    expect_eq(outcome.kinds[0].outcome, KIND_REPRODUCED, "prompt reproduced")
    expect_eq(outcome.kinds[2].outcome, KIND_REPRODUCED, "reply reproduced")
    expect_eq64(
        outcome.new_entry.measured_at,
        now,
        "the kept entry's stamp refreshes to the re-trial instant",
    )
    expect_eq(outcome.new_entry.prompt.threads, 2, "the kept choice is unchanged")
    expect_contains(
        outcome.log_text(), "REPRODUCED", "the log states the reproduction"
    )
    expect_contains(
        outcome.log_text(), "outcome: KEPT", "the log states the kept outcome"
    )
    print("PASS: adopt reproduced -- choice kept, stamp honestly refreshed, logged")


def test_adopt_refusal_absent() raises:
    var entry = _entry_measured()
    var now = T0 + Int64(RETRIAL_AGE_S)
    var plan = plan_retrial(entry, now, 0, _machine_a(), _shape_moe())
    var outcome = adopt_retrial(
        entry,
        plan,
        _absent(),
        _absent(),
        learned_pass_from_choice(
            "auto", "cpu threads=1", DEVICE_CPU, 1, "DEFAULT-CONFIRMED", True
        ),
        now,
    )
    expect_eq(outcome.status, OUT_ADOPTED, "a refused kind changes the entry (to absent)")
    expect_eq(outcome.kinds[0].outcome, KIND_REFUSED_ABSENT, "prompt refused to absent")
    expect_true(
        not outcome.new_entry.prompt.present,
        "the refused kind is ABSENT in the adopted entry (J-044 discipline)",
    )
    expect_true(outcome.new_entry.reply.present, "the surviving kind stands")
    expect_contains(
        outcome.log_text(), "REFUSED-NOW-ABSENT", "the log states the refusal outcome"
    )
    print("PASS: adopt refusal -- kind goes absent, entry adopted, logged")


def test_adopt_all_refused_erases() raises:
    var entry = LearnedEntry()
    entry.machine = _machine_a()
    entry.model = _shape_moe()
    entry.measured_at = T0
    entry.prompt = learned_pass_from_choice(
        "auto", "cpu threads=2", DEVICE_CPU, 2, "MEASURED-WIN", True
    )
    var now = T0 + Int64(RETRIAL_AGE_S)
    var plan = plan_retrial(entry, now, 0, _machine_a(), _shape_moe())
    var outcome = adopt_retrial(entry, plan, _absent(), _absent(), _absent(), now)
    expect_eq(outcome.status, OUT_ERASED, "an all-absent re-trial erases the entry")
    expect_true(not outcome.has_new_entry, "no adopted entry exists to store")
    expect_contains(outcome.log_text(), "outcome: ERASED", "the erasure is logged")
    print("PASS: adopt all-refused -- entry erased, never stored as nothing")


def test_adopt_requires_due() raises:
    var entry = _entry_measured()
    var plan = plan_retrial(entry, T0 + DAY, 0, _machine_a(), _shape_moe())
    expect_eq(plan.state, PLAN_KEEP, "the fixture plan keeps")
    var refused = False
    try:
        _ = adopt_retrial(entry, plan, _absent(), _absent(), _absent(), T0 + DAY)
    except:
        refused = True
    expect_true(refused, "adoption under a non-DUE plan is refused")
    print("PASS: adopt gate -- only a DUE plan can adopt")


def test_disk_apply_and_log() raises:
    var path = _test_dir() + "/apply/learned-placement.v1"
    _ = erase_learned_file(path)
    _ = erase_learned_file(retrial_log_path(path))
    expect_eq(store_learned_entry(path, _entry_measured()), 1, "seed store count")
    var now = T0 + Int64(RETRIAL_AGE_S)
    var loaded = load_learned_file(path)
    var entry = loaded.entries[0].copy()
    var plan = plan_retrial(entry, now, 0, _machine_a(), _shape_moe())
    var outcome = apply_retrial(
        path,
        entry,
        plan,
        learned_pass_from_choice(
            "auto", "cpu threads=4", DEVICE_CPU, 4, "MEASURED-WIN", True
        ),
        _absent(),
        learned_pass_from_choice(
            "auto", "cpu threads=1", DEVICE_CPU, 1, "DEFAULT-CONFIRMED", True
        ),
        now,
    )
    expect_eq(outcome.status, OUT_ADOPTED, "the disk apply adopts")
    var after = load_learned_file(path)
    expect_eq(after.status, LOAD_LOADED, "the file still loads whole")
    var hit = lookup_learned(after, _machine_a(), _shape_moe())
    expect_eq(hit.status, LOOKUP_APPLIED, "the adopted entry applies")
    expect_eq(hit.entry.prompt.threads, 4, "the adopted threads stand on disk")
    expect_eq64(hit.entry.measured_at, now, "the adopted stamp stands on disk")
    expect_true(_exists(retrial_log_path(path)), "the retrial log was created")
    var log = _read_text(retrial_log_path(path))
    expect_contains(log, "trigger: AGE", "the filed log names the trigger")
    expect_contains(log, "cpu threads=2", "the filed log states the old choice")
    expect_contains(log, "cpu threads=4", "the filed log states the new choice")
    expect_contains(log, "outcome: ADOPTED", "the filed log states the outcome")
    # A second re-trial, reproduced this time: KEPT, stamp moves, log grows.
    var now2 = now + Int64(RETRIAL_AGE_S)
    var entry2 = load_learned_file(path).entries[0].copy()
    var plan2 = plan_retrial(entry2, now2, 0, _machine_a(), _shape_moe())
    var outcome2 = apply_retrial(
        path,
        entry2,
        plan2,
        learned_pass_from_choice(
            "auto", "cpu threads=4", DEVICE_CPU, 4, "MEASURED-WIN", True
        ),
        _absent(),
        learned_pass_from_choice(
            "auto", "cpu threads=1", DEVICE_CPU, 1, "DEFAULT-CONFIRMED", True
        ),
        now2,
    )
    expect_eq(outcome2.status, OUT_KEPT, "the second re-trial keeps")
    expect_eq64(
        load_learned_file(path).entries[0].measured_at,
        now2,
        "the kept stamp refreshed on disk",
    )
    var log2 = _read_text(retrial_log_path(path))
    expect_contains(log2, "outcome: ADOPTED", "the first record stands in the log")
    expect_contains(log2, "outcome: KEPT", "the second record was appended")
    print("PASS: disk apply + log -- adopted on disk, log appended per re-trial")


def test_disk_apply_erased() raises:
    var path = _test_dir() + "/erased/learned-placement.v1"
    _ = erase_learned_file(path)
    _ = erase_learned_file(retrial_log_path(path))
    var entry = LearnedEntry()
    entry.machine = _machine_a()
    entry.model = _shape_moe()
    entry.measured_at = T0
    entry.prompt = learned_pass_from_choice(
        "auto", "cpu threads=2", DEVICE_CPU, 2, "MEASURED-WIN", True
    )
    _ = store_learned_entry(path, entry)
    var now = T0 + Int64(RETRIAL_AGE_S)
    var plan = plan_retrial(entry, now, 0, _machine_a(), _shape_moe())
    var outcome = apply_retrial(
        path, entry, plan, _absent(), _absent(), _absent(), now
    )
    expect_eq(outcome.status, OUT_ERASED, "the disk apply erases")
    var after = load_learned_file(path)
    expect_eq(after.status, LOAD_LOADED, "the file remains a valid learned file")
    expect_eq(len(after.entries), 0, "the erased entry is gone from disk")
    expect_contains(
        _read_text(retrial_log_path(path)),
        "outcome: ERASED",
        "the erasure is in the filed log",
    )
    print("PASS: disk apply erased -- entry gone, valid empty file, erasure logged")


def test_log_append_skipped_refused() raises:
    var path = _test_dir() + "/skiplog/learned-placement.v1"
    var outcome = RetrialOutcome()
    expect_eq(outcome.status, OUT_SKIPPED, "a fresh outcome is the SKIPPED state")
    var refused = False
    try:
        append_retrial_log(path, outcome)
    except:
        refused = True
    expect_true(refused, "appending a SKIPPED outcome is refused")
    expect_true(
        not _exists(retrial_log_path(path)), "no log file was created by the refusal"
    )
    print("PASS: log discipline -- skipped re-trials write no log record")


def test_run_retrial_skips() raises:
    var inventory = observe_device_inventory()
    var facts = observe_cpu_facts()
    var config = HarnessConfig()
    # Missing file: SKIPPED, clean, no log.
    var missing_path = _test_dir() + "/skips/missing.v1"
    _ = erase_learned_file(missing_path)
    _ = erase_learned_file(retrial_log_path(missing_path))
    var missing = run_retrial(
        missing_path, _machine_a(), _shape_moe(), T0 + 400 * DAY, 0,
        inventory, facts, config,
    )
    expect_eq(missing.status, OUT_SKIPPED, "a missing learned file skips")
    expect_eq(
        load_learned_file(missing_path).status,
        LOAD_MISSING,
        "the missing state is untouched",
    )
    expect_true(
        not _exists(retrial_log_path(missing_path)),
        "a skipped re-trial writes no log",
    )
    # Not due: SKIPPED, file byte-identical.
    var path = _test_dir() + "/skips/learned-placement.v1"
    _ = erase_learned_file(path)
    _ = store_learned_entry(path, _entry_measured())
    var before = _read_text(path)
    var not_due = run_retrial(
        path, _machine_a(), _shape_moe(), T0 + DAY, 0, inventory, facts, config
    )
    expect_eq(not_due.status, OUT_SKIPPED, "a not-due entry skips")
    expect_true(_read_text(path) == before, "the learned file is byte-identical")
    expect_true(
        not _exists(retrial_log_path(path)), "the not-due skip writes no log"
    )
    # Manual-only: SKIPPED even at great age, file byte-identical.
    var manual_path = _test_dir() + "/skips/manual.v1"
    _ = erase_learned_file(manual_path)
    _ = store_learned_entry(manual_path, _entry_all_manual())
    var manual_before = _read_text(manual_path)
    var manual = run_retrial(
        manual_path, _machine_a(), _shape_moe(), T0 + 400 * DAY, 100000,
        inventory, facts, config,
    )
    expect_eq(manual.status, OUT_SKIPPED, "an all-manual entry skips at any age")
    expect_contains(manual.reason, "MANUAL-ONLY", "the skip names manual supremacy")
    expect_true(
        _read_text(manual_path) == manual_before,
        "the manual entry is byte-identical after the skip",
    )
    # Corrupt file: SKIPPED (REFUSED discipline), bytes untouched.
    var corrupt_path = _test_dir() + "/skips/corrupt.v1"
    _write_text(corrupt_path, "not a learned file\n")
    var corrupt = run_retrial(
        corrupt_path, _machine_a(), _shape_moe(), T0 + 400 * DAY, 0,
        inventory, facts, config,
    )
    expect_eq(corrupt.status, OUT_SKIPPED, "a corrupt learned file skips clean")
    expect_true(
        _read_text(corrupt_path) == "not a learned file\n",
        "the corrupt file is left byte-identical",
    )
    print("PASS: run skips -- missing / not-due / manual-only / corrupt write nothing")


def test_live_retrial() raises:
    var facts = observe_cpu_facts()
    var key = machine_key_from_facts(facts, GpuFacts())
    var inventory = observe_device_inventory()
    var config = HarnessConfig()
    var stamp = learned_now_seconds()
    var entry = LearnedEntry()
    entry.machine = key
    entry.model = _shape_moe()
    entry.measured_at = stamp - Int64(RETRIAL_AGE_S) - DAY
    entry.prompt = learned_pass_from_choice(
        "auto", "cpu threads=1", DEVICE_CPU, 1, "DEFAULT-CONFIRMED", True
    )
    var path = _test_dir() + "/live/learned-placement.v1"
    _ = erase_learned_file(path)
    _ = erase_learned_file(retrial_log_path(path))
    _ = store_learned_entry(path, entry)
    var now = learned_now_seconds()
    var outcome = run_retrial(
        path, key, _shape_moe(), now, 0, inventory, facts, config
    )
    expect_true(
        outcome.status == OUT_KEPT or outcome.status == OUT_ADOPTED,
        "the live re-trial ran (KEPT or ADOPTED, as the chooser honestly returns)",
    )
    var after = load_learned_file(path)
    expect_eq(after.status, LOAD_LOADED, "the live file loads after the re-trial")
    var hit = lookup_learned(after, key, _shape_moe())
    expect_eq(hit.status, LOOKUP_APPLIED, "the live entry still applies")
    expect_eq64(hit.entry.measured_at, now, "the live stamp is the re-trial instant")
    var log = _read_text(retrial_log_path(path))
    expect_contains(log, "trigger: AGE", "the live log names the age trigger")
    print("LIVE RETRIAL LOG RECORD:\n" + outcome.log_text())
    print("PASS: live re-trial -- real facts key, real chooser, adopted/kept + logged")


def main() raises:
    test_cadence_age()
    test_cadence_opens_bounded()
    test_clock_skew()
    test_manual_supremacy_plan()
    test_key_drift()
    test_adopt_changed()
    test_adopt_reproduced()
    test_adopt_refusal_absent()
    test_adopt_all_refused_erases()
    test_adopt_requires_due()
    test_disk_apply_and_log()
    test_disk_apply_erased()
    test_log_append_skipped_refused()
    test_run_retrial_skips()
    test_live_retrial()
    print("ALL PASS: re-trials (15 groups)")
