"""Saved configuration (J-104): the per-user saved-config
store (serialise/parse round trip byte-identical; strict-parse
refusals -- unknown line, bad checksum, unknown version,
non-canonical placement text, the NPU refused for drafts, draft
contradictions, a stated cap of 0, an empty configuration
refused at save), the pure cache-home path rule, the disk
surface (save / MISSING as the clean state / corrupt and
truncated files REFUSED whole with reasons and left untouched
/ store-into-refused raises / whole-file erasure and its
already-absent outcome), the one-story reconciliation
(per-kind resolution session hand > saved hand > preset >
learned > auto with the preset intent taken from J-047's own
preset_intent; the learned side honouring the exact-key lookup
outcomes by name; the draft field's order; the cache cap's
single ownership; a REFUSED store reported and skipped), and
the /save-config command family (every action parsed, field
statements applied with the assembled whole validated, draft
apply following J-083's readings, refusals named, a refused
apply leaving the caller's record untouched).

No number in this suite is a placement verdict: the fixtures'
choices are the choosers' record shapes, filed to prove the
persistence and reconciliation mechanics, not any device's
merit. No inference ran; the live chat leg is J-104's deferred
leg (doc section 5), re-cited at the J-118 gate.
"""
from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.device_inventory import CpuFacts, GpuFacts
from core.learned_file import (
    LOAD_LOADED,
    LOAD_REFUSED,
    LOOKUP_APPLIED,
    LearnedEntry,
    LearnedLoad,
    LookupResult,
    learned_pass_from_choice,
    load_learned_file,
    lookup_learned,
    machine_key_from_facts,
    model_shape,
    save_learned_file,
    MachineKey,
    ModelShape,
)
from core.manual_override import MODE_ECO, ModeOption, preset_intent
from core.placement_options import (
    DEVICE_CPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    SOURCE_CLI,
)
from core.saved_config import (
    CONFIG_ACTION_CLEAR,
    CONFIG_ACTION_ERASE,
    CONFIG_ACTION_HELP,
    CONFIG_ACTION_SET,
    CONFIG_ACTION_SHOW,
    SavedConfig,
    SavedLoad,
    SAVED_LOADED,
    SAVED_MISSING,
    SAVED_REFUSED,
    apply_config_clear,
    apply_config_set,
    config_story_report,
    erase_saved_config,
    load_saved_config,
    parse_config_command,
    parse_saved_config,
    resolve_saved_path,
    save_saved_config,
    serialize_saved_config,
    store_saved_config,
)


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("SavedConfig " + what + ": expected true")


def expect_eq_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "SavedConfig " + what + ": expected '" + expected
            + "', got '" + actual + "'"
        )


def expect_eq_int(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "SavedConfig " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "SavedConfig " + what + ": expected to contain '" + needle
            + "', got '" + text + "'"
        )


def expect_refused(what: String, body: String) raises:
    # Helper marker only; refusal checks are written inline per case
    # (each needs its own try scope), this keeps the vocabulary in
    # one place for the group prints.
    if body.byte_length() == 0:
        raise Error("SavedConfig " + what + ": empty refusal vocabulary")


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
    var env = _env_value("J104_TEST_DIR")
    if env[0] and env[1].byte_length() > 0:
        return env[1]
    return String("/tmp/j104-saved-") + String(
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


def _full_config() -> SavedConfig:
    var config = SavedConfig()
    config.prompt_on_present = True
    config.prompt_on = String("gpu")
    config.drafts_on_present = True
    config.drafts_on = String("cpu")
    config.reply_on_present = False
    config.draft_present = True
    config.draft_source = 2
    config.draft_mtp = 2
    config.draft_model = String("drafts/qwen3-0.6b.gguf")
    config.draft_k = 4
    config.cache_cap_present = True
    config.cache_cap_bytes = 536870912
    config.saved_at = 1762000000
    return config


def _machine() -> MachineKey:
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


def _model() -> ModelShape:
    return model_shape("olmoe", 2048, 16, 16, 16, 11008, 8192, 64, 8)


def _learned_load() -> LearnedLoad:
    var entry = LearnedEntry()
    entry.machine = _machine()
    entry.model = _model()
    entry.measured_at = 1761000000
    entry.prompt = learned_pass_from_choice(
        "auto", "cpu threads=2", DEVICE_CPU, 2, "MEASURED-WIN", True
    )
    entry.draft_present = True
    entry.draft_source = 1
    entry.draft_mtp = 1
    entry.draft_model = String("-")
    entry.draft_k = 3
    var load = LearnedLoad()
    load.status = LOAD_LOADED
    load.reason = String("loaded whole and verified")
    load.path = String("/fixture/learned-placement.v1")
    load.entries.append(entry^)
    return load^


def _saved_load(config: SavedConfig) -> SavedLoad:
    var load = SavedLoad()
    load.status = SAVED_LOADED
    load.reason = String("loaded whole and verified")
    load.path = String("/fixture/saved-config.v1")
    load.config = config
    return load


def _no_lookup() -> LookupResult:
    var lookup = LookupResult()
    return lookup^


# --- groups ----------------------------------------------------------------


def test_round_trip() raises:
    var config = _full_config()
    var text = serialize_saved_config(config)
    var parsed = parse_saved_config(text)
    expect_eq_str(parsed.prompt_on, "gpu", "round trip prompt")
    expect_eq_str(parsed.drafts_on, "cpu", "round trip drafts")
    expect_true(not parsed.reply_on_present, "round trip reply absent")
    expect_eq_str(parsed.draft_model, "drafts/qwen3-0.6b.gguf", "round trip draft model")
    expect_eq_int(parsed.draft_k, 4, "round trip draft k")
    expect_eq_int(parsed.cache_cap_bytes, 536870912, "round trip cap")
    expect_eq_int(Int(parsed.saved_at), 1762000000, "round trip stamp")
    var again = serialize_saved_config(parsed)
    expect_eq_str(again, text, "re-serialisation byte-identical")
    expect_contains(config.render(), "cache-cap: 536870912 bytes", "render cap")
    expect_contains(config.render(), "prompt: gpu", "render prompt")


def test_parse_refusals() raises:
    var good = serialize_saved_config(_full_config())
    # Bad checksum: flip the final hex digit.
    var flipped = String(good[byte=: good.byte_length() - 1])
    if good.endswith("f"):
        flipped += "0"
    else:
        flipped += "f"
    var refused = False
    try:
        _ = parse_saved_config(flipped)
    except:
        refused = True
    expect_true(refused, "checksum mismatch refused")
    # Unknown version header.
    refused = False
    try:
        _ = parse_saved_config(good.replace("AESIR_SAVED_CONFIG_V1", "AESIR_SAVED_CONFIG_V9"))
    except:
        refused = True
    expect_true(refused, "unknown version refused (checksum still valid shape)")
    # Extra line (the expert-map smuggle shape).
    refused = False
    try:
        _ = parse_saved_config(good + "\n")
    except:
        refused = True
    expect_true(refused, "extended file refused")
    # Non-canonical placement text.
    var bad = _full_config()
    bad.prompt_on = String("GPU")
    refused = False
    try:
        bad.validate()
    except:
        refused = True
    expect_true(refused, "non-canonical placement refused at validate")
    # The NPU refused for drafts (J-036 legality rides the parse).
    var npu = _full_config()
    npu.drafts_on = String("npu")
    refused = False
    try:
        npu.validate()
    except:
        refused = True
    expect_true(refused, "npu-for-drafts refused at validate")
    # Draft contradiction: mtp-head naming a separate file.
    var contra = _full_config()
    contra.draft_source = 1
    contra.draft_mtp = 1
    refused = False
    try:
        contra.validate()
    except:
        refused = True
    expect_true(refused, "mtp-head with a draft file refused")
    # A stated cap of 0.
    var zero = _full_config()
    zero.cache_cap_bytes = 0
    refused = False
    try:
        zero.validate()
    except:
        refused = True
    expect_true(refused, "stated cap of 0 refused")
    # An empty configuration is refused at save.
    refused = False
    try:
        _ = serialize_saved_config(SavedConfig())
    except:
        refused = True
    expect_true(refused, "empty configuration refused at save")


def test_path_rule() raises:
    expect_eq_str(
        resolve_saved_path((True, "/x/cfg.v1"), (True, "/cache"), (True, "/home/u")),
        "/x/cfg.v1",
        "file env wins",
    )
    expect_eq_str(
        resolve_saved_path((False, ""), (True, "/cache"), (True, "/home/u")),
        "/cache/saved-config.v1",
        "cache home next",
    )
    expect_eq_str(
        resolve_saved_path((False, ""), (False, ""), (True, "/home/u")),
        "/home/u/.cache/aesir/saved-config.v1",
        "home fallback",
    )
    expect_eq_str(
        resolve_saved_path((True, ""), (False, ""), (False, "")),
        ".aesir-cache/saved-config.v1",
        "empty env counts as unset; relative last resort",
    )


def test_disk_surface() raises:
    var path = _test_dir() + "/saved-config.v1"
    var missing = load_saved_config(path)
    expect_eq_int(missing.status, SAVED_MISSING, "missing is the clean state")
    save_saved_config(path, _full_config())
    var loaded = load_saved_config(path)
    expect_eq_int(loaded.status, SAVED_LOADED, "saved then loaded")
    expect_eq_str(loaded.config.prompt_on, "gpu", "disk round trip prompt")
    # Corrupt the file: load REFUSED, reason stated, file untouched.
    var corrupt_text = String("AESIR_SAVED_CONFIG_V1\nnot a real record\n")
    _write_text(path, corrupt_text)
    var refused_load = load_saved_config(path)
    expect_eq_int(refused_load.status, SAVED_REFUSED, "corrupt file refused")
    expect_true(refused_load.reason.byte_length() > 0, "refusal names its reason")
    expect_eq_str(_read_text(path), corrupt_text, "refused file left untouched")
    # Storing into a refused file raises.
    var raised = False
    try:
        store_saved_config(path, _full_config())
    except:
        raised = True
    expect_true(raised, "store into refused raises")
    # Erasure: present -> erased; absent -> already erased, both as data.
    var first = erase_saved_config(path)
    expect_true(first.erased and first.was_present, "erase present file")
    var second = erase_saved_config(path)
    expect_true(second.erased and not second.was_present, "erase absent is clean")
    expect_eq_int(load_saved_config(path).status, SAVED_MISSING, "post-erase missing")
    # Truncation of a valid file is REFUSED, never partial.
    save_saved_config(path, _full_config())
    var whole = _read_text(path)
    _write_text(path, String(whole[byte=: whole.byte_length() // 2]))
    expect_eq_int(load_saved_config(path).status, SAVED_REFUSED, "truncated refused")
    _ = erase_saved_config(path)


def test_reconciliation_placement() raises:
    var learned = _learned_load()
    var lookup = lookup_learned(learned, _machine(), _model())
    expect_eq_int(lookup.status, LOOKUP_APPLIED, "fixture lookup applies")
    var none_texts = List[String]()
    var none_set = List[Bool]()
    var none_preset = List[String]()
    for _ in range(3):
        none_texts.append(String("-"))
        none_set.append(False)
        none_preset.append(String(""))
    # Learned governs when nothing else states the kind.
    var saved_missing = SavedLoad()
    saved_missing.path = String("/fixture/saved-config.v1")
    var story = config_story_report(
        saved_missing, learned, lookup, none_texts, none_set,
        none_preset, String("-"), False,
    )
    expect_contains(story, "placement prompt: effective 'cpu threads=2", "learned governs prompt")
    expect_contains(story, "[learned]", "learned provenance named")
    expect_contains(story, "placement reply: effective 'auto' [auto]", "unstated kind falls to auto")
    # Saved hand beats learned.
    var saved = _saved_load(_full_config())
    var story_saved = config_story_report(
        saved, learned, lookup, none_texts, none_set,
        none_preset, String("-"), False,
    )
    expect_contains(story_saved, "placement prompt: effective 'gpu' [saved hand]", "saved beats learned")
    # Preset (eco, from J-047's own intent) beats learned, loses to saved.
    var mode = ModeOption()
    mode.mode = MODE_ECO
    mode.source = SOURCE_CLI
    mode.was_set = True
    var eco = preset_intent(mode, PASS_PROMPT)
    expect_true(eco.fixed, "eco intent is fixed")
    var preset_texts = List[String]()
    preset_texts.append(eco.label)
    preset_texts.append(String(""))
    preset_texts.append(String(""))
    var story_preset = config_story_report(
        saved_missing, learned, lookup, none_texts, none_set,
        preset_texts, String("-"), False,
    )
    expect_contains(story_preset, "placement prompt: effective 'cpu threads=1' [preset]", "preset beats learned")
    var story_preset_saved = config_story_report(
        saved, learned, lookup, none_texts, none_set,
        preset_texts, String("-"), False,
    )
    expect_contains(story_preset_saved, "placement prompt: effective 'gpu' [saved hand]", "saved beats preset")
    # Session hand beats everything.
    var session_texts = List[String]()
    var session_set = List[Bool]()
    session_texts.append(String("cpu+gpu"))
    session_texts.append(String("-"))
    session_texts.append(String("-"))
    session_set.append(True)
    session_set.append(False)
    session_set.append(False)
    var story_session = config_story_report(
        saved, learned, lookup, session_texts, session_set,
        preset_texts, String("-"), False,
    )
    expect_contains(story_session, "placement prompt: effective 'cpu+gpu' [session hand]", "session beats saved")


def test_reconciliation_draft_cap_refused() raises:
    var learned = _learned_load()
    var lookup = lookup_learned(learned, _machine(), _model())
    var texts = List[String]()
    var sets = List[Bool]()
    var presets = List[String]()
    for _ in range(3):
        texts.append(String("-"))
        sets.append(False)
        presets.append(String(""))
    # Learned draft section governs when nothing else states it;
    # the cap is unstated (no store owns it but saved).
    var saved_missing = SavedLoad()
    saved_missing.path = String("/fixture/saved-config.v1")
    var story = config_story_report(
        saved_missing, learned, lookup, texts, sets, presets,
        String("-"), False,
    )
    expect_contains(story, "draft settings: effective 'source mtp-head", "learned draft governs")
    expect_contains(story, "cache cap: effective 'unset' [none]", "cap unset without saved")
    # Saved draft + cap govern over learned.
    var saved = _saved_load(_full_config())
    var story_saved = config_story_report(
        saved, learned, lookup, texts, sets, presets, String("-"), False,
    )
    expect_contains(story_saved, "draft settings: effective 'source draft-model", "saved draft governs")
    expect_contains(story_saved, "cache cap: effective '536870912 bytes' [saved hand]", "saved cap governs")
    # A key mismatch names its outcome; the learned side states nothing.
    var other = model_shape("llama", 4096, 32, 32, 8, 14336, 131072, 0, 0)
    var miss = lookup_learned(learned, _machine(), other)
    var story_miss = config_story_report(
        saved_missing, learned, miss, texts, sets, presets,
        String("-"), False,
    )
    expect_contains(story_miss, "placement prompt: effective 'auto' [auto]", "mismatched learned states nothing")
    expect_contains(story_miss, "MODEL-MISMATCH", "mismatch named in the story")
    # REFUSED stores are reported and skipped, never partially read.
    var refused_saved = SavedLoad()
    refused_saved.status = SAVED_REFUSED
    refused_saved.reason = String("checksum mismatch (fixture)")
    refused_saved.path = String("/fixture/saved-config.v1")
    var refused_learned = LearnedLoad()
    refused_learned.status = LOAD_REFUSED
    refused_learned.reason = String("checksum mismatch (fixture)")
    refused_learned.path = String("/fixture/learned-placement.v1")
    var story_refused = config_story_report(
        refused_saved, refused_learned, _no_lookup(), texts, sets,
        presets, String("-"), False,
    )
    expect_contains(story_refused, "REFUSED: checksum mismatch (fixture)", "refused stores reported")
    expect_contains(story_refused, "placement prompt: effective 'auto' [auto]", "refused stores state nothing")
    expect_contains(story_refused, "separate erase paths", "standing sentences on the report")


def test_command_parse() raises:
    expect_eq_int(parse_config_command("/save-config").action, CONFIG_ACTION_SHOW, "bare shows")
    expect_eq_int(parse_config_command("/save-config help").action, CONFIG_ACTION_HELP, "help parses")
    expect_eq_int(parse_config_command("/save-config erase").action, CONFIG_ACTION_ERASE, "erase parses")
    var set_cmd = parse_config_command("/save-config prompt-on gpu")
    expect_eq_int(set_cmd.action, CONFIG_ACTION_SET, "set parses")
    expect_eq_str(set_cmd.field, "prompt-on", "set field")
    expect_eq_str(set_cmd.value, "gpu", "set value")
    var clear_cmd = parse_config_command("/save-config clear cache-cap")
    expect_eq_int(clear_cmd.action, CONFIG_ACTION_CLEAR, "clear parses")
    expect_eq_str(clear_cmd.field, "cache-cap", "clear field")
    for bad in [
        "/save-config bogus x",
        "/save-config prompt-on",
        "/save-config clear bogus",
        "/save-config erase now",
        "/save-config prompt-on gpu extra",
        "/save",
        "/save-configx",
    ]:
        var refused = False
        try:
            _ = parse_config_command(bad)
        except:
            refused = True
        expect_true(refused, "command refused: " + bad)


def test_command_apply() raises:
    var empty = SavedConfig()
    # Placement statement, canonicalised through J-036.
    var one = apply_config_set(empty, "prompt-on", "gpu", 1762000000)
    expect_true(one.prompt_on_present, "apply states prompt")
    expect_eq_str(one.prompt_on, "gpu", "apply prompt value")
    # A refused statement leaves the caller's record untouched.
    var refused = False
    try:
        _ = apply_config_set(one, "drafts-on", "npu", 1762000000)
    except:
        refused = True
    expect_true(refused, "npu-for-drafts refused at apply")
    expect_true(not one.drafts_on_present, "refused apply changed nothing")
    # Cache cap through J-018's grammar; 0 refused by name.
    var capped = apply_config_set(one, "cache-cap", "512MiB", 1762000000)
    expect_eq_int(capped.cache_cap_bytes, 536870912, "cap parsed by byte grammar")
    refused = False
    try:
        _ = apply_config_set(one, "cache-cap", "0", 1762000000)
    except:
        refused = True
    expect_true(refused, "cap 0 refused")
    # Draft readings (J-083): mtp on alone selects the head source.
    var drafted = apply_config_set(capped, "draft-mtp", "on", 1762000000)
    expect_eq_int(drafted.draft_source, 1, "mtp on selects head source")
    expect_eq_int(drafted.draft_mtp, 1, "mtp on recorded")
    expect_eq_int(drafted.draft_k, 4, "an unstated k takes J-072's initial (LOOP_K_INITIAL)")
    # k alone, with no source, refuses (the band needs a source).
    refused = False
    try:
        _ = apply_config_set(one, "draft-k", "4", 1762000000)
    except:
        refused = True
    expect_true(refused, "draft-k with no source refused")
    var with_k = apply_config_set(drafted, "draft-k", "4", 1762000000)
    expect_eq_int(with_k.draft_k, 4, "draft-k stated beside a source")
    refused = False
    try:
        _ = apply_config_set(with_k, "draft-k", "16", 1762000000)
    except:
        refused = True
    expect_true(refused, "draft-k outside the band refused")
    # A draft model beside the head source is a contradiction.
    refused = False
    try:
        _ = apply_config_set(with_k, "draft-model", "drafts/x.gguf", 1762000000)
    except:
        refused = True
    expect_true(refused, "draft model beside head source refused")
    # Clearing: unstated refuses; the last stated field refuses
    # with the erase road named.
    refused = False
    try:
        _ = apply_config_clear(one, "reply-on", 1762000000)
    except:
        refused = True
    expect_true(refused, "clearing an unstated field refused")
    refused = False
    try:
        _ = apply_config_clear(one, "prompt-on", 1762000000)
    except:
        refused = True
    expect_true(refused, "clearing the last field refused (erase instead)")
    var cleared = apply_config_clear(capped, "cache-cap", 1762000000)
    expect_true(not cleared.cache_cap_present, "clear unstated the cap")
    expect_true(cleared.prompt_on_present, "clear kept the other fields")


def main() raises:
    test_round_trip()
    print("PASS: round trip (serialise/parse byte-identical, renders)")
    test_parse_refusals()
    print("PASS: strict parse + validation refusals (checksum, version, extra line, canonical form, npu, draft contradiction, cap 0, empty)")
    test_path_rule()
    print("PASS: path rule (file env > cache home > home > relative; empty env unset)")
    test_disk_surface()
    print("PASS: disk surface (missing clean, refused whole + untouched, store-into-refused raises, erase as data, truncation refused)")
    test_reconciliation_placement()
    print("PASS: reconciliation -- placement layers (learned < preset < saved hand < session hand; auto floor)")
    test_reconciliation_draft_cap_refused()
    print("PASS: reconciliation -- draft order, cap ownership, key mismatch named, refused stores skipped")
    test_command_parse()
    print("PASS: command parse (show/help/erase/set/clear; unknown + misshapen refused)")
    test_command_apply()
    print("PASS: command apply (whole-config validation, J-083 draft readings, clear rules, refused apply untouched)")
    print("ALL PASS: saved configuration (8 groups)")
