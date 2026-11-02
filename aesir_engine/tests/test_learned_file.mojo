"""The learned file (J-044): the machine+model key derivation
from the inventory's own facts, the serialise/parse round trip
(byte-identical re-serialisation), a refused kind stored ABSENT
(a refusal leaves no learned default), the parked-NPU refusal
at save and at validate, the manual-form/decision consistency
refusals, the pure cache-home path rule, the disk surface
(save / load-at-open with MISSING as the clean state / store
with same-key replacement / corrupt + truncated + bit-flipped
files refused whole with reasons and left untouched), key
mismatch lookups naming which half of the key failed, per-key
and whole-file erasure, the show-on-request report (defaults
only; no expert maps), and a live round trip keyed by this
machine's real CPU facts.

No number in this suite is a placement verdict: the fixtures'
choices are the choosers' record shapes, filed to prove the
persistence mechanics, not any device's merit.
"""
from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.device_inventory import CpuFacts, GpuFacts
from core.learned_file import (
    LOAD_LOADED,
    LOAD_MISSING,
    LOAD_REFUSED,
    LOOKUP_APPLIED,
    LOOKUP_BOTH_MISMATCH,
    LOOKUP_MACHINE_MISMATCH,
    LOOKUP_MODEL_MISMATCH,
    LOOKUP_NOT_LOADED,
    LOOKUP_NO_ENTRY,
    LearnedEntry,
    LearnedLoad,
    LearnedPassChoice,
    MachineKey,
    ModelShape,
    erase_learned_entry,
    erase_learned_file,
    learned_file_path,
    learned_now_seconds,
    learned_pass_from_choice,
    load_learned_file,
    lookup_learned,
    machine_key_from_facts,
    model_shape,
    parse_learned_file,
    resolve_learned_path,
    save_learned_file,
    serialize_learned_file,
    store_learned_entry,
)
from core.placement_options import DEVICE_CPU, DEVICE_GPU, DEVICE_NPU
from core.thread_topology import observe_cpu_facts


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "LearnedFile "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("LearnedFile " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "LearnedFile "
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
    var env = _env_value("J044_TEST_DIR")
    if env[0] and env[1].byte_length() > 0:
        return env[1]
    return String("/tmp/j044-learned-") + String(
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


# --- fixtures ------------------------------------------------------------


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


def _entry_a() -> LearnedEntry:
    var entry = LearnedEntry()
    entry.machine = _machine_a()
    entry.model = _shape_moe()
    entry.measured_at = Int64(1760000000)
    entry.prompt = learned_pass_from_choice(
        "auto", "cpu threads=2", DEVICE_CPU, 2, "MEASURED-WIN", True
    )
    entry.drafts = learned_pass_from_choice(
        "auto", "", DEVICE_CPU, 0, "REFUSAL", False
    )
    entry.reply = learned_pass_from_choice(
        "auto", "cpu threads=1", DEVICE_CPU, 1, "DEFAULT-CONFIRMED", True
    )
    return entry^


def _entry_b() -> LearnedEntry:
    var entry = LearnedEntry()
    entry.machine = _machine_a()
    entry.model = _shape_dense()
    entry.measured_at = Int64(1760003600)
    entry.prompt = learned_pass_from_choice(
        "gpu", "gpu", DEVICE_GPU, 0, "MANUAL-FIXED", True
    )
    entry.reply = learned_pass_from_choice(
        "cpu,gpu", "cpu threads=1", DEVICE_CPU, 1, "SOLE-MEASURED", True
    )
    return entry^


# --- groups ----------------------------------------------------------------


def test_keys() raises:
    var a = _machine_a()
    var a2 = _machine_a()
    expect_true(a.equals(a2), "identical fixture facts derive equal keys")
    var perturbed = _machine_a()
    perturbed.logical = 9
    expect_true(not a.equals(perturbed), "a perturbed count breaks the key")
    expect_contains(a.render(), "Fixture CPU 9000", "machine render names the cpu")
    expect_contains(a.render(), "Fixture GPU X", "machine render names the gpu")
    var moe = _shape_moe()
    expect_true(moe.equals(_shape_moe()), "identical shapes are equal")
    expect_true(not moe.equals(_shape_dense()), "different shapes differ")
    expect_contains(moe.render(), "olmoe", "shape render names the arch")
    expect_contains(moe.render(), "experts=64", "shape render states experts")
    expect_contains(_shape_dense().render(), "dense", "dense shape renders dense")
    var bad_arch = False
    try:
        model_shape("Olmoe!", 2048, 16, 16, 16, 11008, 8192, 64, 8).validate()
    except:
        bad_arch = True
    expect_true(bad_arch, "an architecture outside [a-z0-9._-] is refused")
    var bad_dense = False
    try:
        model_shape("llama", 4096, 32, 32, 8, 14336, 131072, 0, 3).validate()
    except:
        bad_dense = True
    expect_true(bad_dense, "a dense shape claiming used experts is refused")
    print("PASS: keys -- derived from facts, exact equality, renders, validation")


def test_serialize_roundtrip() raises:
    var entries = List[LearnedEntry]()
    entries.append(_entry_a())
    entries.append(_entry_b())
    var text = serialize_learned_file(entries)
    expect_true(
        text.startswith("AESIR_LEARNED_PLACEMENT_V1"),
        "the serialised file carries the version header",
    )
    expect_contains(text, "count=2", "the serialised file counts its entries")
    expect_true(
        "expert_map" not in text and "expert-map" not in text,
        "no expert-map section exists in the format (J-027)",
    )
    var parsed = parse_learned_file(text)
    expect_eq(len(parsed), 2, "round trip entry count")
    expect_true(parsed[0].machine.equals(_machine_a()), "entry A machine key")
    expect_true(parsed[0].model.equals(_shape_moe()), "entry A model key")
    expect_eq(Int(parsed[0].measured_at), 1760000000, "entry A measured-at")
    expect_true(parsed[0].prompt.present, "entry A prompt present")
    expect_eq(parsed[0].prompt.device, DEVICE_CPU, "entry A prompt device")
    expect_eq(parsed[0].prompt.threads, 2, "entry A prompt threads")
    expect_contains(parsed[0].prompt.decision, "MEASURED-WIN", "entry A decision")
    expect_contains(
        parsed[0].prompt.placement_text, "cpu threads=2", "entry A placement"
    )
    expect_true(parsed[1].prompt.present, "entry B prompt present")
    expect_eq(parsed[1].prompt.device, DEVICE_GPU, "entry B prompt device (manual gpu)")
    expect_eq(parsed[1].prompt.threads, 0, "a device-fixed choice fixes no threads")
    var again = serialize_learned_file(parsed)
    expect_true(again == text, "re-serialisation is byte-identical")
    print("PASS: serialise/parse round trip -- whole, exact, byte-identical")


def test_refusal_kind_absent() raises:
    var entry = _entry_a()
    expect_true(not entry.drafts.present, "a refusal record builds ABSENT")
    expect_true(
        entry.drafts.option_text == "-",
        "the absent kind carries its canonical empty fields",
    )
    var text_entries = List[LearnedEntry]()
    text_entries.append(_entry_a())
    var parsed = parse_learned_file(serialize_learned_file(text_entries))
    expect_true(not parsed[0].drafts.present, "absence survives the round trip")
    var empty = LearnedEntry()
    empty.machine = _machine_a()
    empty.model = _shape_moe()
    empty.measured_at = Int64(1760000000)
    var refused = False
    try:
        var holder = List[LearnedEntry]()
        holder.append(empty^)
        _ = serialize_learned_file(holder)
    except:
        refused = True
    expect_true(refused, "an entry learning nothing is refused at save")
    print("PASS: refusal kind absent -- no learned default from a refusal")


def test_npu_refused() raises:
    var entry = _entry_a()
    entry.prompt = learned_pass_from_choice(
        "auto", "npu", DEVICE_NPU, 0, "SOLE-MEASURED", True
    )
    var refused = False
    var reason = String("")
    try:
        var holder = List[LearnedEntry]()
        holder.append(entry^)
        _ = serialize_learned_file(holder)
    except error:
        refused = True
        reason = String(error)
    expect_true(refused, "an npu chosen device is refused at save")
    expect_contains(reason, "parked", "the refusal names the parked ledger")
    print("PASS: npu refused -- a parked device is never persisted")


def test_validation_refusals() raises:
    var cases = List[LearnedPassChoice]()
    cases.append(
        learned_pass_from_choice(
            "auto", "cpu threads=2", DEVICE_CPU, 2, "MANUAL-FIXED", True
        )
    )
    cases.append(
        learned_pass_from_choice(
            "gpu", "gpu", DEVICE_GPU, 0, "MEASURED-WIN", True
        )
    )
    cases.append(
        learned_pass_from_choice(
            "auto", "cpu threads=2", DEVICE_CPU, 2, "INVENTED", True
        )
    )
    cases.append(
        learned_pass_from_choice(
            "auto", "gpu", DEVICE_GPU, 2, "MEASURED-WIN", True
        )
    )
    var names = List[String]()
    names.append("auto option with MANUAL-FIXED")
    names.append("explicit option with a measured decision")
    names.append("an unknown decision name")
    names.append("a non-cpu choice fixing threads")
    for i in range(len(cases)):
        var refused = False
        try:
            cases[i].validate(0)
        except:
            refused = True
        expect_true(refused, "validation refuses: " + names[i])
    print("PASS: validation refusals -- form/decision consistency, decisions, threads")


def test_path_resolution() raises:
    var file_wins = resolve_learned_path(
        (True, String("/x/file.v1")), (True, String("/c")), (True, String("/h"))
    )
    expect_true(file_wins == "/x/file.v1", "AESIR_LEARNED_FILE wins outright")
    var cache_next = resolve_learned_path(
        (False, String("")), (True, String("/c")), (True, String("/h"))
    )
    expect_true(
        cache_next == "/c/learned-placement.v1", "AESIR_CACHE_HOME names the dir"
    )
    var home_next = resolve_learned_path(
        (False, String("")), (False, String("")), (True, String("/h"))
    )
    expect_true(
        home_next == "/h/.cache/aesir/learned-placement.v1",
        "HOME gives the XDG-shaped cache home",
    )
    var fallback = resolve_learned_path(
        (False, String("")), (False, String("")), (False, String(""))
    )
    expect_true(
        fallback == ".aesir-cache/learned-placement.v1",
        "no env gives the relative fallback",
    )
    var empty_falls = resolve_learned_path(
        (True, String("")), (True, String("/c")), (True, String("/h"))
    )
    expect_true(
        empty_falls == "/c/learned-placement.v1",
        "an empty file env counts as unset, never as a path",
    )
    print("PASS: path resolution -- file > cache home > HOME > relative fallback")


def test_disk_save_load() raises:
    var path = _test_dir() + "/learned-placement.v1"
    _ = erase_learned_file(path)
    var missing = load_learned_file(path)
    expect_eq(missing.status, LOAD_MISSING, "missing file loads as MISSING")
    expect_eq(len(missing.entries), 0, "the missing state carries no entries")
    expect_contains(
        missing.report(), "clean no-learned state", "MISSING reports clean"
    )
    var entries = List[LearnedEntry]()
    entries.append(_entry_a())
    entries.append(_entry_b())
    save_learned_file(path, entries)
    var on_disk = _read_text(path)
    expect_true(
        on_disk.startswith("AESIR_LEARNED_PLACEMENT_V1"),
        "the file on disk carries the header",
    )
    var loaded = load_learned_file(path)
    expect_eq(loaded.status, LOAD_LOADED, "saved file loads as LOADED")
    expect_eq(len(loaded.entries), 2, "loaded entry count")
    var hit = lookup_learned(loaded, _machine_a(), _shape_moe())
    expect_eq(hit.status, LOOKUP_APPLIED, "the exact key applies after load")
    expect_eq(hit.entry.prompt.threads, 2, "the applied entry's thread choice")
    print("PASS: disk save/load -- MISSING clean, save atomic, load whole, lookup applies")


def test_lookup_mismatches() raises:
    var load = LearnedLoad()
    load.status = LOAD_LOADED
    load.path = String("fixture")
    load.entries.append(_entry_a())
    load.entries.append(_entry_b())
    var perturbed_shape = _shape_moe()
    perturbed_shape.embedding_length = 999
    var model_miss = lookup_learned(load, _machine_a(), perturbed_shape)
    expect_eq(model_miss.status, LOOKUP_MODEL_MISMATCH, "known machine, new shape")
    expect_contains(model_miss.reason, "model shape", "model mismatch reason")
    var machine_miss = lookup_learned(load, _machine_b(), _shape_moe())
    expect_eq(machine_miss.status, LOOKUP_MACHINE_MISMATCH, "known shape, new machine")
    var both_miss = lookup_learned(load, _machine_b(), perturbed_shape)
    expect_eq(both_miss.status, LOOKUP_BOTH_MISMATCH, "neither half known")
    var empty_load = LearnedLoad()
    empty_load.status = LOAD_LOADED
    var no_entry = lookup_learned(empty_load, _machine_a(), _shape_moe())
    expect_eq(no_entry.status, LOOKUP_NO_ENTRY, "a loaded empty file has no entry")
    var missing_load = load_learned_file(_test_dir() + "/never-written.v1")
    var not_loaded = lookup_learned(missing_load, _machine_a(), _shape_moe())
    expect_eq(not_loaded.status, LOOKUP_NOT_LOADED, "a missing state applies nothing")
    print("PASS: lookup mismatches -- model / machine / both / no-entry / not-loaded")


def test_store_and_replace() raises:
    var path = _test_dir() + "/store/learned-placement.v1"
    _ = erase_learned_file(path)
    expect_eq(store_learned_entry(path, _entry_a()), 1, "first store count")
    expect_eq(store_learned_entry(path, _entry_b()), 2, "second key appends")
    var updated = _entry_a()
    updated.prompt = learned_pass_from_choice(
        "auto", "cpu threads=4", DEVICE_CPU, 4, "MEASURED-WIN", True
    )
    updated.measured_at = Int64(1760007200)
    expect_eq(store_learned_entry(path, updated), 2, "same key replaces, not appends")
    var loaded = load_learned_file(path)
    var hit = lookup_learned(loaded, _machine_a(), _shape_moe())
    expect_eq(hit.status, LOOKUP_APPLIED, "replaced entry applies")
    expect_eq(hit.entry.prompt.threads, 4, "the replacement's threads stand")
    expect_eq(Int(hit.entry.measured_at), 1760007200, "the replacement's stamp stands")
    var corrupt_path = _test_dir() + "/store/corrupt.v1"
    _write_text(corrupt_path, "not a learned file\n")
    var refused = False
    try:
        _ = store_learned_entry(corrupt_path, _entry_a())
    except:
        refused = True
    expect_true(refused, "storing into a corrupt file raises")
    expect_true(
        _read_text(corrupt_path) == "not a learned file\n",
        "the corrupt file is left byte-identical by the refused store",
    )
    print("PASS: store -- append, same-key replace, corrupt store refused untouched")


def test_corrupt_loads() raises:
    var dir = _test_dir() + "/corrupt"
    var good_entries = List[LearnedEntry]()
    good_entries.append(_entry_a())
    var good_text = serialize_learned_file(good_entries)
    var cases = List[String]()
    cases.append("total garbage, no structure at all\nsecond line\n")
    cases.append(String(good_text[byte=: len(good_text.bytes()) // 2]))
    cases.append(good_text.replace("machine_logical=8", "machine_logical=9"))
    cases.append(good_text.replace("AESIR_LEARNED_PLACEMENT_V1", "AESIR_LEARNED_PLACEMENT_V9"))
    cases.append("")
    var names = List[String]()
    names.append("garbage")
    names.append("truncated half")
    names.append("bit-flipped body (checksum)")
    names.append("unknown version header")
    names.append("empty file")
    for i in range(len(cases)):
        var path = dir + "/case" + String(i) + ".v1"
        save_learned_file(dir + "/seed.v1", good_entries)
        _write_text(path, cases[i])
        var load = load_learned_file(path)
        expect_eq(load.status, LOAD_REFUSED, "corrupt loads REFUSED: " + names[i])
        expect_eq(len(load.entries), 0, "a refusal carries no entries: " + names[i])
        expect_true(
            load.reason.byte_length() > 0, "a refusal states its reason: " + names[i]
        )
        expect_true(
            _read_text(path) == cases[i],
            "the refused file is left untouched: " + names[i],
        )
        var lookup = lookup_learned(load, _machine_a(), _shape_moe())
        expect_eq(
            lookup.status, LOOKUP_NOT_LOADED, "nothing applies from a refusal: " + names[i]
        )
    print("PASS: corrupt loads -- garbage/truncated/flipped/version/empty all REFUSED whole")


def test_erase() raises:
    var path = _test_dir() + "/erase/learned-placement.v1"
    _ = erase_learned_file(path)
    var entries = List[LearnedEntry]()
    entries.append(_entry_a())
    entries.append(_entry_b())
    save_learned_file(path, entries)
    expect_true(
        erase_learned_entry(path, _machine_a(), _shape_moe()),
        "per-key erase removes its entry",
    )
    var after_one = load_learned_file(path)
    expect_eq(after_one.status, LOAD_LOADED, "still loaded after per-key erase")
    expect_eq(len(after_one.entries), 1, "one entry remains")
    expect_true(
        not erase_learned_entry(path, _machine_a(), _shape_moe()),
        "erasing an absent key is False, not an error",
    )
    expect_true(
        erase_learned_entry(path, _machine_a(), _shape_dense()),
        "erasing the last entry succeeds",
    )
    var empty = load_learned_file(path)
    expect_eq(empty.status, LOAD_LOADED, "last-key erasure leaves a valid file")
    expect_eq(len(empty.entries), 0, "the valid file holds no entries")
    var whole = erase_learned_file(path)
    expect_true(whole.erased and whole.was_present, "whole-file erase reports")
    expect_eq(
        load_learned_file(path).status, LOAD_MISSING, "after whole erase: MISSING"
    )
    var again = erase_learned_file(path)
    expect_true(
        again.erased and not again.was_present,
        "erasing an absent file is the clean already-erased state",
    )
    expect_true(
        not erase_learned_entry(path, _machine_a(), _shape_moe()),
        "per-key erase on a missing file is False",
    )
    print("PASS: erase -- per-key, last-key valid-empty, whole-file, absent clean")


def test_report_show() raises:
    var load = LearnedLoad()
    load.status = LOAD_LOADED
    load.path = String("/fixture/learned-placement.v1")
    load.entries.append(_entry_a())
    load.entries.append(_entry_b())
    var report = load.report()
    expect_contains(report, "state: LOADED (2 entries)", "report states the load")
    expect_contains(report, "olmoe", "report shows the first key's model")
    expect_contains(report, "llama", "report shows the second key's model")
    expect_contains(report, "prompt: cpu threads=2", "report shows per-kind choices")
    expect_contains(report, "drafts: absent", "report shows the absent kind")
    expect_contains(report, "measured-at: 1760000000", "report shows provenance")
    expect_contains(report, "defaults only", "manual supremacy rides the report")
    expect_contains(report, "expert maps: none", "the no-map sentence rides the report")
    print("PASS: report -- per-key dump, defaults-only, no expert maps")


def test_live_roundtrip() raises:
    var facts = observe_cpu_facts()
    var key = machine_key_from_facts(facts, GpuFacts())
    expect_true(key.logical >= 1, "the live machine key states its logical count")
    var entry = LearnedEntry()
    entry.machine = key
    entry.model = _shape_moe()
    entry.measured_at = learned_now_seconds()
    expect_true(entry.measured_at > 0, "the realtime stamp is positive")
    entry.prompt = learned_pass_from_choice(
        "auto", "cpu threads=1", DEVICE_CPU, 1, "DEFAULT-CONFIRMED", True
    )
    var path = _test_dir() + "/live/learned-placement.v1"
    _ = erase_learned_file(path)
    _ = store_learned_entry(path, entry)
    var loaded = load_learned_file(path)
    expect_eq(loaded.status, LOAD_LOADED, "live-keyed entry loads")
    var hit = lookup_learned(loaded, key, _shape_moe())
    expect_eq(hit.status, LOOKUP_APPLIED, "the live machine's own key applies")
    var other_shape = _shape_moe()
    other_shape.embedding_length += 1
    var miss = lookup_learned(loaded, key, other_shape)
    expect_eq(miss.status, LOOKUP_MODEL_MISMATCH, "a perturbed live shape mismatches")
    print("LIVE LEARNED REPORT (this machine's facts):\n" + loaded.report())
    var live_path = learned_file_path()
    expect_contains(
        live_path, "learned-placement.v1", "the live path names the learned file"
    )
    print("PASS: live round trip -- real cpu facts key, store, load, apply, mismatch")


def main() raises:
    test_keys()
    test_serialize_roundtrip()
    test_refusal_kind_absent()
    test_npu_refused()
    test_validation_refusals()
    test_path_resolution()
    test_disk_save_load()
    test_lookup_mismatches()
    test_store_and_replace()
    test_corrupt_loads()
    test_erase()
    test_report_show()
    test_live_roundtrip()
    print("ALL PASS: learned file (13 groups)")
