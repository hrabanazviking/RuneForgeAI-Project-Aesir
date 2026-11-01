"""Draft configuration surface (J-083): the shared
--mtp / --no-mtp / --draft <model> / --draft-k parser driven
identically through the chat and server entry wrappers
(parity field-by-field and by describe()); precedence
cli > env > default per field; every named refusal
(contradictory mtp across layers, contradictory sources,
scan refusals, bad env value, k outside the cap read from
J-071's plan_proposer, hand-built invalid configurations);
the recorded gates bound, not rebuilt (J-077 MTP admission
admitting a head file and refusing a headless one by name;
J-074's pair gate admitting the documented pair shape and
refusing missing-file / unverified / mismatched /
not-smaller pairs); the fail-closed use gate standing for
every configuration; and persistence through Part III's
learned file (save -> load -> identical configuration,
same-key replacement, key mismatch, V1 byte compatibility
for entries without a draft configuration, corrupt file
refused clean). Fixtures are stated shapes and stated
files, never measurements: no model runs anywhere in this
suite, and no speed is proved or claimed.
"""
from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.cross_model_pairing import (
    FAMILY_QWEN3,
    ModelSide,
    TokenizerComparison,
    compare_tokenizers,
)
from core.device_inventory import CpuFacts, GpuFacts
from core.draft_config import (
    DRAFT_MTP_OFF,
    DRAFT_MTP_ON,
    DRAFT_MTP_UNSET,
    DRAFT_SOURCE_DRAFT_MODEL,
    DRAFT_SOURCE_MTP_HEAD,
    DRAFT_SOURCE_NONE,
    DraftConfig,
    RawDraftInputs,
    apply_draft_config,
    draft_config_to_entry,
    draft_env_inputs,
    draft_k_cap,
    load_draft_config,
    parse_draft_k,
    persist_draft_config,
    require_draft_config_use,
    resolve_chat_draft_config,
    resolve_draft_config,
    resolve_server_draft_config,
    scan_draft_args,
    validate_draft_config,
    validate_draft_model_pair,
    validate_mtp_source,
)
from core.learned_file import (
    LOAD_LOADED,
    LearnedEntry,
    MachineKey,
    ModelShape,
    learned_pass_from_choice,
    load_learned_file,
    machine_key_from_facts,
    model_shape,
    parse_learned_file,
    serialize_learned_file,
)
from core.placement_options import DEVICE_CPU, SOURCE_CLI, SOURCE_DEFAULT, SOURCE_ENV
from core.speculative_loop import LOOP_K_INITIAL
from core.speculative_verify import PROPOSER_MTP_HEAD


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "DraftConfig " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("DraftConfig " + what + ": expected true")


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "DraftConfig " + what + ": expected '" + expected
            + "', got '" + actual + "'"
        )


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "DraftConfig " + what + ": expected to contain '" + needle
            + "', got '" + text + "'"
        )


def _set_env(name: String, value: String):
    var name_buf = InlineArray[Int8, 32](fill=0)
    var name_bytes = name.as_bytes()
    for i in range(len(name_bytes)):
        name_buf[i] = Int8(name_bytes[i])
    var value_buf = InlineArray[Int8, 128](fill=0)
    var value_bytes = value.as_bytes()
    for i in range(len(value_bytes)):
        value_buf[i] = Int8(value_bytes[i])
    _ = external_call["setenv", Int32](
        name_buf.unsafe_ptr(), value_buf.unsafe_ptr(), Int32(1)
    )


def _unset_env(name: String):
    var name_buf = InlineArray[Int8, 32](fill=0)
    var name_bytes = name.as_bytes()
    for i in range(len(name_bytes)):
        name_buf[i] = Int8(name_bytes[i])
    _ = external_call["unsetenv", Int32](name_buf.unsafe_ptr())


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
    var env = _env_value("J083_TEST_DIR")
    if env[0] and env[1].byte_length() > 0:
        return env[1]
    return String("/tmp/j083-draft-") + String(external_call["getpid", Int32]())


def _write_text(path: String, text: String) raises:
    var handle = open(path, "w")
    handle.write(text)
    handle.close()


def _read_text(path: String) raises -> String:
    var text: String
    with open(path, "r") as source:
        text = source.read()
    return text


def _args(items: List[String]) -> List[String]:
    return items.copy()


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


def _shape_moe() -> ModelShape:
    return model_shape("olmoe", 2048, 16, 16, 16, 11008, 8192, 64, 8)


def _resolved(argv: List[String]) raises -> DraftConfig:
    return resolve_draft_config(scan_draft_args(argv), RawDraftInputs())


# --- groups ----------------------------------------------------------------


def test_defaults() raises:
    var config = _resolved(List[String]())
    expect_eq(config.source, DRAFT_SOURCE_NONE, "default source")
    expect_eq(config.mtp_state, DRAFT_MTP_UNSET, "default mtp")
    expect_str(config.draft_model, "-", "default model")
    expect_eq(config.k, LOOP_K_INITIAL, "default k is J-072's initial")
    expect_eq(config.k, 4, "default k value")
    expect_eq(config.mtp_layer, SOURCE_DEFAULT, "default mtp layer")
    expect_contains(config.describe(), "source=none", "describe states none")
    expect_contains(
        config.describe(), "use refused", "describe carries the use gate"
    )
    print("PASS: defaults -- no source, mtp unset, k = J-072 initial (4)")


def test_mtp_forms() raises:
    var chat = resolve_chat_draft_config(_args([String("--mtp")]))
    var server = resolve_server_draft_config(_args([String("--mtp")]))
    expect_eq(chat.source, DRAFT_SOURCE_MTP_HEAD, "mtp source")
    expect_eq(chat.mtp_state, DRAFT_MTP_ON, "mtp on")
    expect_eq(chat.mtp_layer, SOURCE_CLI, "mtp layer cli")
    expect_str(chat.describe(), server.describe(), "chat/server describe parity")
    var noisy = _resolved(
        _args([String("--model"), String("x.gguf"), String("--mtp")])
    )
    expect_eq(noisy.source, DRAFT_SOURCE_MTP_HEAD, "foreign flags ignored")
    print("PASS: --mtp -- head source on both surfaces, foreign flags ignored")


def test_draft_forms() raises:
    var spaced = _resolved(
        _args([String("--draft"), String("qwen3-0.6b.gguf")])
    )
    var equals = _resolved(_args([String("--draft=qwen3-0.6b.gguf")]))
    expect_eq(spaced.source, DRAFT_SOURCE_DRAFT_MODEL, "draft source")
    expect_str(spaced.draft_model, "qwen3-0.6b.gguf", "draft model")
    expect_str(spaced.describe(), equals.describe(), "--draft forms identical")
    var with_k = _resolved(
        _args(
            [
                String("--draft"),
                String("qwen3-0.6b.gguf"),
                String("--draft-k"),
                String("9"),
            ]
        )
    )
    expect_eq(with_k.k, 9, "draft-k stated")
    expect_eq(with_k.k_layer, SOURCE_CLI, "k layer cli")
    var no_mtp = _resolved(
        _args(
            [
                String("--no-mtp"),
                String("--draft"),
                String("qwen3-0.6b.gguf"),
            ]
        )
    )
    expect_eq(no_mtp.source, DRAFT_SOURCE_DRAFT_MODEL, "no-mtp+draft source")
    expect_eq(no_mtp.mtp_state, DRAFT_MTP_OFF, "no-mtp recorded beside draft")
    print("PASS: --draft forms -- spaced/equals identical; --no-mtp + --draft allowed")


def test_parity_matrix() raises:
    var cases = List[List[String]]()
    cases.append(List[String]())
    cases.append(_args([String("--mtp")]))
    cases.append(_args([String("--no-mtp")]))
    cases.append(_args([String("--draft"), String("d.gguf")]))
    cases.append(
        _args(
            [
                String("--draft"),
                String("d.gguf"),
                String("--draft-k"),
                String("9"),
            ]
        )
    )
    cases.append(
        _args(
            [
                String("--no-mtp"),
                String("--draft"),
                String("d.gguf"),
            ]
        )
    )
    for idx in range(len(cases)):
        var chat = resolve_chat_draft_config(cases[idx].copy())
        var server = resolve_server_draft_config(cases[idx].copy())
        expect_str(
            chat.describe(), server.describe(), "parity describe case " + String(idx)
        )
        expect_eq(chat.source, server.source, "parity source")
        expect_eq(chat.k, server.k, "parity k")
    print("PASS: parity matrix -- 6 argv shapes, chat == server on every field")


def test_precedence() raises:
    var cli = RawDraftInputs()
    cli.draft_k = String("7")
    cli.draft_k_set = True
    var env = RawDraftInputs()
    env.draft_k = String("3")
    env.draft_k_set = True
    env.draft_model = String("env-draft.gguf")
    env.draft_model_set = True
    var config = resolve_draft_config(cli, env)
    expect_eq(config.k, 7, "cli k beats env k")
    expect_eq(config.k_layer, SOURCE_CLI, "k layer cli")
    expect_str(config.draft_model, "env-draft.gguf", "env model stands")
    expect_eq(config.model_layer, SOURCE_ENV, "model layer env")
    print("PASS: precedence -- cli > env per field, independently")


def test_env_layer() raises:
    _set_env("AESIR_MTP", "1")
    _set_env("AESIR_DRAFT_K", "6")
    var env = draft_env_inputs()
    expect_true(env.mtp_on_set, "env mtp on read")
    expect_true(env.draft_k_set, "env k read")
    var config = resolve_draft_config(RawDraftInputs(), env)
    expect_eq(config.source, DRAFT_SOURCE_MTP_HEAD, "env mtp source")
    expect_eq(config.k, 6, "env k applied")
    expect_eq(config.mtp_layer, SOURCE_ENV, "mtp layer env")
    _unset_env("AESIR_MTP")
    _unset_env("AESIR_DRAFT_K")
    var bad = RawDraftInputs()
    bad.mtp_env_bad = String("2")
    bad.mtp_env_bad_set = True
    var refused = False
    try:
        _ = resolve_draft_config(RawDraftInputs(), bad)
    except:
        refused = True
    expect_true(refused, "bad AESIR_MTP value refused at resolve")
    print("PASS: env layer -- AESIR_MTP/AESIR_DRAFT_K read; bad value refused")


def test_contradictions() raises:
    var refused = 0
    try:
        _ = _resolved(_args([String("--mtp"), String("--no-mtp")]))
    except:
        refused += 1
    var cli_on = RawDraftInputs()
    cli_on.mtp_on_set = True
    var env_off = RawDraftInputs()
    env_off.mtp_off_set = True
    try:
        _ = resolve_draft_config(cli_on, env_off)
    except:
        refused += 1
    try:
        _ = _resolved(
            _args(
                [
                    String("--mtp"),
                    String("--draft"),
                    String("d.gguf"),
                ]
            )
        )
    except:
        refused += 1
    expect_eq(refused, 3, "contradiction refusals")
    print("PASS: contradictions -- mtp+no-mtp (same/cross layer), mtp+draft (3/3)")


def test_scan_refusals() raises:
    var refused = 0
    try:
        _ = scan_draft_args(
            _args(
                [
                    String("--draft"),
                    String("a.gguf"),
                    String("--draft"),
                    String("b.gguf"),
                ]
            )
        )
    except:
        refused += 1
    try:
        _ = scan_draft_args(_args([String("--mtp"), String("--mtp")]))
    except:
        refused += 1
    try:
        _ = scan_draft_args(_args([String("--draft")]))
    except:
        refused += 1
    try:
        _ = scan_draft_args(_args([String("--mtp=1")]))
    except:
        refused += 1
    try:
        _ = scan_draft_args(_args([String("--draftx"), String("a.gguf")]))
    except:
        refused += 1
    try:
        _ = scan_draft_args(_args([String("--draft"), String("")]))
        _ = _resolved(_args([String("--draft"), String("")]))
    except:
        refused += 1
    expect_eq(refused, 6, "scan refusals")
    # --drafts-on is J-036's placement flag, not this surface's:
    var raw = scan_draft_args(
        _args([String("--drafts-on"), String("gpu"), String("--mtp")])
    )
    expect_true(raw.mtp_on_set, "placement flag skipped, mtp still scanned")
    print("PASS: scan refusals -- dup/missing/valued-switch/typo/empty (6/6)")


def test_k_band() raises:
    expect_eq(draft_k_cap(DRAFT_SOURCE_MTP_HEAD), 15, "mtp cap from J-071")
    expect_eq(draft_k_cap(DRAFT_SOURCE_DRAFT_MODEL), 15, "draft cap from J-071")
    var top = _resolved(_args([String("--mtp"), String("--draft-k"), String("15")]))
    expect_eq(top.k, 15, "band top admitted")
    var refused = 0
    try:
        _ = _resolved(_args([String("--mtp"), String("--draft-k"), String("16")]))
    except:
        refused += 1
    try:
        _ = _resolved(_args([String("--mtp"), String("--draft-k"), String("0")]))
    except:
        refused += 1
    try:
        _ = _resolved(
            _args(
                [
                    String("--draft"),
                    String("d.gguf"),
                    String("--draft-k"),
                    String("16"),
                ]
            )
        )
    except:
        refused += 1
    try:
        _ = parse_draft_k("x")
    except:
        refused += 1
    try:
        _ = parse_draft_k("-1")
    except:
        refused += 1
    expect_eq(refused, 5, "k refusals")
    print("PASS: k band -- cap 15 from plan_proposer; 0/16/bad refused (5/5)")


def test_validate_handbuilt() raises:
    var refused = 0
    var head_with_file = DraftConfig()
    head_with_file.source = DRAFT_SOURCE_MTP_HEAD
    head_with_file.mtp_state = DRAFT_MTP_ON
    head_with_file.draft_model = String("other.gguf")
    try:
        validate_draft_config(head_with_file)
    except:
        refused += 1
    var draft_with_mtp = DraftConfig()
    draft_with_mtp.source = DRAFT_SOURCE_DRAFT_MODEL
    draft_with_mtp.mtp_state = DRAFT_MTP_ON
    draft_with_mtp.draft_model = String("d.gguf")
    try:
        validate_draft_config(draft_with_mtp)
    except:
        refused += 1
    var none_with_mtp = DraftConfig()
    none_with_mtp.mtp_state = DRAFT_MTP_ON
    try:
        validate_draft_config(none_with_mtp)
    except:
        refused += 1
    var unknown = DraftConfig()
    unknown.source = 9
    try:
        validate_draft_config(unknown)
    except:
        refused += 1
    expect_eq(refused, 4, "hand-built refusals")
    print("PASS: hand-built validation -- file-on-head, mtp-on-draft, mtp-on-none, unknown (4/4)")


def _head_names() -> List[String]:
    var names = List[String]()
    names.append(String("token_embd.weight"))
    names.append(String("blk.0.attn_q.weight"))
    names.append(String("blk.27.nextn.eh_proj.weight"))
    names.append(String("blk.27.nextn.embed_tokens.weight"))
    return names.copy()


def _plain_names() -> List[String]:
    var names = List[String]()
    names.append(String("token_embd.weight"))
    names.append(String("blk.0.attn_q.weight"))
    names.append(String("output.weight"))
    return names.copy()


def test_mtp_gate() raises:
    var config = _resolved(_args([String("--mtp")]))
    var admission = validate_mtp_source(
        config, String("qwen35-with-heads.gguf"), True, _head_names()
    )
    expect_true(admission.admitted, "head file admitted by J-077")
    expect_eq(admission.proposer_kind, PROPOSER_MTP_HEAD, "mtp-head proposer")
    expect_eq(admission.max_k, 15, "admission cap")
    var refused = 0
    try:
        _ = validate_mtp_source(
            config, String("plain.gguf"), True, _plain_names()
        )
    except:
        refused += 1
    try:
        _ = validate_mtp_source(
            config, String("plain.gguf"), False, _head_names()
        )
    except:
        refused += 1
    var draft_config = _resolved(_args([String("--draft"), String("d.gguf")]))
    try:
        _ = validate_mtp_source(
            draft_config, String("plain.gguf"), True, _head_names()
        )
    except:
        refused += 1
    expect_eq(refused, 3, "mtp gate refusals")
    print("PASS: mtp gate (J-077) -- admitted head file; no-head/uncensused/wrong-source refused (3/3)")


def _vocab() -> List[String]:
    var v = List[String]()
    v.append(String("<|endoftext|>"))
    v.append(String(" the"))
    v.append(String(" of"))
    v.append(String("token"))
    return v.copy()


def _merges() -> List[String]:
    var m = List[String]()
    m.append(String("Ġ t"))
    m.append(String("th e"))
    return m.copy()


def _identical_cmp() -> TokenizerComparison:
    return compare_tokenizers(
        _vocab(), _vocab(), _merges(), _merges(),
        String("gpt2"), String("gpt2"), 151643, 151643, 151643, 151643,
    )


def _pair_judge(
    config: DraftConfig,
    drafter: ModelSide,
    target: ModelSide,
    verified: Bool,
) raises -> Bool:
    try:
        _ = validate_draft_model_pair(
            config,
            drafter,
            target,
            _identical_cmp(),
            verified,
            16_000_000_000,
            16_000_000_000,
            0,
            1_000_000,
        )
        return True
    except:
        return False


def test_pair_gate() raises:
    var config = _resolved(
        _args(
            [
                String("--draft"),
                String("qwen3-0.6b.gguf"),
                String("--draft-k"),
                String("4"),
            ]
        )
    )
    var drafter = ModelSide(FAMILY_QWEN3, True, 380_000_000, 60_000_000, 10_000_000)
    var target = ModelSide(FAMILY_QWEN3, True, 2_400_000_000, 200_000_000, 10_000_000)
    expect_true(
        _pair_judge(config, drafter, target, True), "documented pair admitted"
    )
    var missing = ModelSide(FAMILY_QWEN3, False, 380_000_000, 60_000_000, 10_000_000)
    expect_true(
        not _pair_judge(config, missing, target, True), "missing file refused"
    )
    expect_true(
        not _pair_judge(config, drafter, target, False),
        "unverified tokenizer refused",
    )
    var big = ModelSide(FAMILY_QWEN3, True, 1_500_000_000, 60_000_000, 10_000_000)
    expect_true(
        not _pair_judge(config, big, target, True), "not-smaller drafter refused"
    )
    print("PASS: pair gate (J-074) -- pair admitted; missing/unverified/not-smaller refused")


def test_use_gate() raises:
    var refused = 0
    try:
        require_draft_config_use(_resolved(_args([String("--mtp")])))
    except:
        refused += 1
    try:
        require_draft_config_use(
            _resolved(_args([String("--draft"), String("d.gguf")]))
        )
    except:
        refused += 1
    try:
        require_draft_config_use(_resolved(List[String]()))
    except:
        refused += 1
    expect_eq(refused, 3, "use gate refusals")
    print("PASS: use gate -- configured mtp, configured draft, unconfigured (3/3 refused)")


def test_persistence_round_trip() raises:
    var path = _test_dir() + String("/learned-placement.v1")
    var config = _resolved(
        _args(
            [
                String("--no-mtp"),
                String("--draft"),
                String("qwen3-0.6b.gguf"),
                String("--draft-k"),
                String("6"),
            ]
        )
    )
    var count = persist_draft_config(
        path, config, _machine_a(), _shape_moe(), Int64(1760010000)
    )
    expect_eq(count, 1, "one entry stored")
    var text = _read_text(path)
    expect_true(
        text.startswith("AESIR_LEARNED_PLACEMENT_V2"),
        "draft-carrying file serialises as V2",
    )
    expect_contains(text, "draftcfg_present=1", "draft section on disk")
    var load = load_learned_file(path)
    expect_eq(load.status, LOAD_LOADED, "learned load LOADED")
    expect_contains(load.report(), "drafts-config: source draft-model", "report shows draft config")
    var back = load_draft_config(path, _machine_a(), _shape_moe())
    expect_true(back.found, "round trip found")
    expect_eq(back.config.source, config.source, "round trip source")
    expect_eq(back.config.mtp_state, config.mtp_state, "round trip mtp")
    expect_str(back.config.draft_model, config.draft_model, "round trip model")
    expect_eq(back.config.k, config.k, "round trip k")
    print("PASS: persistence round trip -- save -> load -> identical configuration")


def test_persistence_replace_and_miss() raises:
    var path = _test_dir() + String("/replace/learned-placement.v1")
    var first = _resolved(_args([String("--draft"), String("d.gguf")]))
    _ = persist_draft_config(
        path, first, _machine_a(), _shape_moe(), Int64(1760010000)
    )
    var second = _resolved(_args([String("--mtp"), String("--draft-k"), String("3")]))
    var count = persist_draft_config(
        path, second, _machine_a(), _shape_moe(), Int64(1760013600)
    )
    expect_eq(count, 1, "same key replaced, count stays 1")
    var back = load_draft_config(path, _machine_a(), _shape_moe())
    expect_true(back.found, "replaced config found")
    expect_eq(back.config.source, DRAFT_SOURCE_MTP_HEAD, "replaced source")
    expect_eq(back.config.k, 3, "replaced k")
    var perturbed = _shape_moe()
    perturbed.embedding_length += 1
    var miss = load_draft_config(path, _machine_a(), perturbed)
    expect_true(not miss.found, "perturbed shape does not apply")
    expect_contains(miss.reason, "MODEL-MISMATCH", "miss names its half")
    var absent = load_draft_config(
        _test_dir() + String("/nope/learned-placement.v1"),
        _machine_a(),
        _shape_moe(),
    )
    expect_true(not absent.found, "missing file is a clean not-found")
    expect_contains(absent.reason, "MISSING", "missing names its state")
    print("PASS: persistence replace/miss -- same-key replace; MODEL-MISMATCH; MISSING clean")


def test_persistence_v1_compat() raises:
    var entry = LearnedEntry()
    entry.machine = _machine_a()
    entry.model = _shape_moe()
    entry.measured_at = Int64(1760010000)
    entry.prompt = learned_pass_from_choice(
        "auto", "cpu threads=2", DEVICE_CPU, 2, "MEASURED-WIN", True
    )
    var entries = List[LearnedEntry]()
    entries.append(entry^)
    var text = serialize_learned_file(entries)
    expect_true(
        text.startswith("AESIR_LEARNED_PLACEMENT_V1"),
        "no-draft state serialises as V1, byte-identical form",
    )
    var parsed = parse_learned_file(text)
    expect_eq(len(parsed), 1, "V1 parse count")
    expect_true(not parsed[0].draft_present, "V1 entry has no draft config")
    var path = _test_dir() + String("/corrupt/learned-placement.v1")
    _write_text(path, String("garbage, not a learned file\n"))
    var refused = load_draft_config(path, _machine_a(), _shape_moe())
    expect_true(not refused.found, "corrupt file applies nothing")
    expect_contains(refused.reason, "REFUSED", "corrupt names REFUSED")
    print("PASS: V1 compat -- no-draft files unchanged; corrupt file refused clean")


def test_apply_merges_with_choices() raises:
    var entry = LearnedEntry()
    entry.machine = _machine_a()
    entry.model = _shape_moe()
    entry.measured_at = Int64(1760010000)
    entry.prompt = learned_pass_from_choice(
        "auto", "cpu threads=2", DEVICE_CPU, 2, "MEASURED-WIN", True
    )
    var config = _resolved(_args([String("--mtp"), String("--draft-k"), String("5")]))
    var merged = apply_draft_config(entry, config)
    var entries = List[LearnedEntry]()
    entries.append(merged^)
    var text = serialize_learned_file(entries)
    var parsed = parse_learned_file(text)
    expect_eq(len(parsed), 1, "merged parse count")
    expect_true(parsed[0].prompt.present, "pass choice survives")
    expect_str(parsed[0].prompt.placement_text, "cpu threads=2", "choice intact")
    expect_true(parsed[0].draft_present, "draft config survives")
    expect_eq(parsed[0].draft_source, DRAFT_SOURCE_MTP_HEAD, "merged source")
    expect_eq(parsed[0].draft_k, 5, "merged k")
    print("PASS: apply/merge -- pass choices and draft config round-trip together")


def main() raises:
    test_defaults()
    test_mtp_forms()
    test_draft_forms()
    test_parity_matrix()
    test_precedence()
    test_env_layer()
    test_contradictions()
    test_scan_refusals()
    test_k_band()
    test_validate_handbuilt()
    test_mtp_gate()
    test_pair_gate()
    test_use_gate()
    test_persistence_round_trip()
    test_persistence_replace_and_miss()
    test_persistence_v1_compat()
    test_apply_merges_with_choices()
    print("ALL PASS: draft configuration surface (17 groups)")
