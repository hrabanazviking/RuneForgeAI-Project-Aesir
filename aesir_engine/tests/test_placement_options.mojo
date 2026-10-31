"""Placement options (J-036): grammar, precedence, kill switches,
pass-kind legality, the fail-closed use gates, the argv scan, and
the environment layer.

Every expectation is stated from the J-036 design (docs/janas/
J036_PLACEMENT_OPTIONS.md), which itself stands on the J-003 census
value forms and the J-035 taxonomy: auto / single / a+b co-work /
comma race; CLI over env over default; a killed device named in any
option refused with the reason; the NPU refused for draft-check and
reply; drafts use fail-closed against the absent draft-check pass
(J-035 G1); quality levers fail-closed at use (gate A2 surface,
J-091 evidence). No inference, no device, no engine: parsing only.
"""
from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    PLACE_AUTO,
    PLACE_COWORK,
    PLACE_RACE,
    PLACE_SINGLE,
    SOURCE_CLI,
    SOURCE_DEFAULT,
    SOURCE_ENV,
    RawPlacementInputs,
    effective_auto_devices,
    parse_placement_value,
    placement_env_inputs,
    require_draft_check_use,
    require_quality_use,
    resolve_placement_options,
    scan_placement_args,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PlacementOptions "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "PlacementOptions "
            + what
            + ": expected '"
            + expected
            + "', got '"
            + actual
            + "'"
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("PlacementOptions " + what + ": expected true")


def contains(haystack: String, needle: String) -> Bool:
    var h = haystack.as_bytes()
    var n = needle.as_bytes()
    if len(n) == 0:
        return True
    if len(n) > len(h):
        return False
    for start in range(len(h) - len(n) + 1):
        var matched = True
        for j in range(len(n)):
            if h[start + j] != n[j]:
                matched = False
                break
        if matched:
            return True
    return False


def expect_error_contains(
    message: String, needle: String, what: String
) raises:
    if not contains(message, needle):
        raise Error(
            "PlacementOptions "
            + what
            + ": error '"
            + message
            + "' does not name '"
            + needle
            + "'"
        )


# --- grammar: the four forms --------------------------------------


def test_placement_forms() raises:
    var auto = parse_placement_value("auto", PASS_PROMPT)
    expect_eq(auto.form, PLACE_AUTO, "auto form")
    expect_eq(auto.count, 0, "auto count")
    expect_str(auto.describe(), "auto", "auto describe")

    var single = parse_placement_value("gpu", PASS_PROMPT)
    expect_eq(single.form, PLACE_SINGLE, "single form")
    expect_eq(single.first, DEVICE_GPU, "single device")
    expect_eq(single.count, 1, "single count")
    expect_str(single.describe(), "gpu", "single describe")

    # The census's own co-work example, in Aesir's words.
    var cowork = parse_placement_value("npu+gpu", PASS_PROMPT)
    expect_eq(cowork.form, PLACE_COWORK, "cowork form")
    expect_eq(cowork.first, DEVICE_NPU, "cowork first")
    expect_eq(cowork.second, DEVICE_GPU, "cowork second")
    expect_eq(cowork.count, 2, "cowork count")
    expect_str(cowork.describe(), "npu+gpu", "cowork describe")
    expect_true(cowork.names_device(DEVICE_NPU), "cowork names npu")
    expect_true(not cowork.names_device(DEVICE_CPU), "cowork omits cpu")

    var race = parse_placement_value("npu,gpu", PASS_PROMPT)
    expect_eq(race.form, PLACE_RACE, "race form")
    expect_eq(race.count, 2, "race count")
    expect_str(race.describe(), "npu,gpu", "race describe")

    var race3 = parse_placement_value("cpu,gpu,npu", PASS_PROMPT)
    expect_eq(race3.count, 3, "race3 count")
    expect_eq(race3.third, DEVICE_NPU, "race3 third")
    expect_str(race3.describe(), "cpu,gpu,npu", "race3 describe")

    # Whitespace around the value and around separators is trimmed;
    # the stored form is canonical.
    var spaced = parse_placement_value(" gpu + cpu ", PASS_PROMPT)
    expect_str(spaced.describe(), "gpu+cpu", "spaced cowork canonical")
    print("PASS: placement forms auto/single/cowork/race")


def test_placement_grammar_refusals() raises:
    try:
        _ = parse_placement_value("", PASS_PROMPT)
        raise Error("PlacementOptions empty value was accepted")
    except e:
        expect_error_contains(String(e), "must not be empty", "empty value")
    try:
        _ = parse_placement_value("tpu", PASS_PROMPT)
        raise Error("PlacementOptions unknown device was accepted")
    except e:
        expect_error_contains(String(e), "unknown device 'tpu'", "unknown device")
    try:
        _ = parse_placement_value("GPU", PASS_PROMPT)
        raise Error("PlacementOptions upper-case device was accepted")
    except e:
        expect_error_contains(String(e), "unknown device 'GPU'", "case refusal")
    try:
        _ = parse_placement_value("gpu+gpu", PASS_PROMPT)
        raise Error("PlacementOptions same-device co-work was accepted")
    except e:
        expect_error_contains(String(e), "twice", "cowork same device")
    try:
        _ = parse_placement_value("gpu+cpu+npu", PASS_PROMPT)
        raise Error("PlacementOptions three-device co-work was accepted")
    except e:
        expect_error_contains(String(e), "exactly two", "cowork three devices")
    try:
        _ = parse_placement_value("gpu+", PASS_PROMPT)
        raise Error("PlacementOptions empty-side co-work was accepted")
    except e:
        expect_error_contains(String(e), "empty side", "cowork empty side")
    try:
        _ = parse_placement_value("auto+gpu", PASS_PROMPT)
        raise Error("PlacementOptions auto-in-cowork was accepted")
    except e:
        expect_error_contains(String(e), "whole value", "auto in cowork")
    try:
        _ = parse_placement_value("gpu,,cpu", PASS_PROMPT)
        raise Error("PlacementOptions empty race entry was accepted")
    except e:
        expect_error_contains(String(e), "empty entry", "race empty entry")
    try:
        _ = parse_placement_value("gpu,cpu,gpu", PASS_PROMPT)
        raise Error("PlacementOptions duplicate race entry was accepted")
    except e:
        expect_error_contains(String(e), "twice", "race duplicate")
    try:
        _ = parse_placement_value("gpu+cpu,gpu", PASS_PROMPT)
        raise Error("PlacementOptions mixed separators were accepted")
    except e:
        expect_error_contains(String(e), "mixes", "mixed separators")
    print("PASS: placement grammar refusals carry reasons")


def test_pass_kind_legality() raises:
    # The NPU takes prompt passes; it never takes a draft-check and
    # never takes a reply -- in any form, refused whole.
    var prompt_npu = parse_placement_value("npu", PASS_PROMPT)
    expect_eq(prompt_npu.first, DEVICE_NPU, "npu prompt allowed")
    _ = parse_placement_value("npu+gpu", PASS_PROMPT)
    _ = parse_placement_value("cpu,gpu", PASS_REPLY)
    _ = parse_placement_value("gpu", PASS_DRAFTS)
    try:
        _ = parse_placement_value("npu", PASS_REPLY)
        raise Error("PlacementOptions npu reply was accepted")
    except e:
        expect_error_contains(String(e), "never takes a reply pass", "npu reply")
    try:
        _ = parse_placement_value("cpu,npu", PASS_REPLY)
        raise Error("PlacementOptions npu in reply race was accepted")
    except e:
        expect_error_contains(String(e), "never takes a reply pass", "npu reply race")
    try:
        _ = parse_placement_value("npu+gpu", PASS_DRAFTS)
        raise Error("PlacementOptions npu drafts was accepted")
    except e:
        expect_error_contains(
            String(e), "never takes a drafts pass", "npu drafts cowork"
        )
    print("PASS: pass-kind legality (npu refused for drafts and reply)")


# --- precedence, kills, resolution ---------------------------------


def test_precedence() raises:
    var cli = RawPlacementInputs()
    var env = RawPlacementInputs()
    env.prompt = "gpu"
    env.prompt_set = True
    env.reply = "cpu"
    env.reply_set = True

    var from_env = resolve_placement_options(cli, env)
    expect_eq(from_env.prompt.source, SOURCE_ENV, "env source")
    expect_str(from_env.prompt.choice.describe(), "gpu", "env value")
    expect_true(from_env.prompt.was_set, "env was_set")
    expect_eq(from_env.drafts.source, SOURCE_DEFAULT, "default source")
    expect_true(not from_env.drafts.was_set, "default was_set false")
    expect_eq(from_env.drafts.choice.form, PLACE_AUTO, "default is auto")

    cli.prompt = "npu+gpu"
    cli.prompt_set = True
    var from_cli = resolve_placement_options(cli, env)
    expect_eq(from_cli.prompt.source, SOURCE_CLI, "cli beats env source")
    expect_str(from_cli.prompt.choice.describe(), "npu+gpu", "cli beats env value")
    expect_eq(from_cli.reply.source, SOURCE_ENV, "env stands where cli silent")
    print("PASS: precedence cli over env over default, sources recorded")


def test_kill_switches() raises:
    # A killed device named in any option is refused with the reason,
    # whichever layer supplied the value and whichever the kill.
    var cli = RawPlacementInputs()
    cli.no_gpu = True
    cli.prompt = "gpu"
    cli.prompt_set = True
    try:
        _ = resolve_placement_options(cli, RawPlacementInputs())
        raise Error("PlacementOptions killed gpu placement was accepted")
    except e:
        expect_error_contains(String(e), "killed by --no-gpu", "cli kill refusal")

    var env = RawPlacementInputs()
    env.gpu_env = "0"
    env.gpu_env_set = True
    env.reply = "cpu+gpu"
    env.reply_set = True
    try:
        _ = resolve_placement_options(RawPlacementInputs(), env)
        raise Error("PlacementOptions env-killed gpu placement was accepted")
    except e:
        expect_error_contains(String(e), "killed by AESIR_GPU=0", "env kill refusal")

    # auto is never refused by a kill: its effective field shrinks,
    # and the CPU always remains in it.
    var auto_cli = RawPlacementInputs()
    auto_cli.no_gpu = True
    auto_cli.no_npu = True
    var auto_opts = resolve_placement_options(auto_cli, RawPlacementInputs())
    expect_true(auto_opts.kills.gpu_killed, "gpu killed recorded")
    expect_true(auto_opts.kills.npu_killed, "npu killed recorded")
    expect_str(
        effective_auto_devices(auto_opts.kills), "cpu", "auto field fully killed"
    )
    var partial = RawPlacementInputs()
    partial.no_npu = True
    var partial_opts = resolve_placement_options(partial, RawPlacementInputs())
    expect_str(
        effective_auto_devices(partial_opts.kills),
        "cpu, gpu",
        "auto field minus npu",
    )

    # AESIR_GPU=1 states the device lives; a bad value is refused.
    var alive = RawPlacementInputs()
    alive.gpu_env = "1"
    alive.gpu_env_set = True
    alive.prompt = "gpu"
    alive.prompt_set = True
    var alive_opts = resolve_placement_options(RawPlacementInputs(), alive)
    expect_true(not alive_opts.kills.gpu_killed, "AESIR_GPU=1 does not kill")
    var bad = RawPlacementInputs()
    bad.gpu_env = "2"
    bad.gpu_env_set = True
    try:
        _ = resolve_placement_options(RawPlacementInputs(), bad)
        raise Error("PlacementOptions AESIR_GPU=2 was accepted")
    except e:
        expect_error_contains(String(e), "AESIR_GPU", "bad kill value refused")
    print("PASS: kill switches refuse named devices, shrink the auto field")


# --- the fail-closed use gates -------------------------------------


def test_drafts_use_fail_closed() raises:
    # --drafts-on parses, validates and stores like the others...
    var cli = RawPlacementInputs()
    cli.drafts = "gpu"
    cli.drafts_set = True
    var options = resolve_placement_options(cli, RawPlacementInputs())
    expect_str(options.drafts.choice.describe(), "gpu", "drafts value stored")
    expect_eq(options.drafts.source, SOURCE_CLI, "drafts source stored")
    # ...and its legality rules apply at parse (npu refused)...
    var npu_cli = RawPlacementInputs()
    npu_cli.drafts = "npu"
    npu_cli.drafts_set = True
    try:
        _ = resolve_placement_options(npu_cli, RawPlacementInputs())
        raise Error("PlacementOptions npu drafts resolved")
    except e:
        expect_error_contains(String(e), "never takes a drafts pass", "drafts npu")
    # ...but any USE of a drafts placement refuses, naming G1.
    try:
        require_draft_check_use()
        raise Error("PlacementOptions draft-check use was allowed")
    except e:
        expect_error_contains(String(e), "gap G1", "drafts use names G1")
        expect_error_contains(String(e), "J-071", "drafts use names its road")
    print("PASS: drafts-on stores, drafts use fails closed (G1)")


def test_quality_surface() raises:
    var defaults = resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )
    expect_str(defaults.quality.quality, "high", "default tier is high")
    expect_eq(defaults.quality.head_bits, 0, "default head native")
    expect_str(defaults.quality.attention, "exact", "default attention exact")
    expect_eq(defaults.quality.bits, 0, "default bits native")
    expect_true(not defaults.quality.any_lever_engaged(), "defaults engage nothing")
    require_quality_use(defaults)  # high + no lever: today's behaviour

    var cli = RawPlacementInputs()
    cli.quality = "medium"
    cli.quality_set = True
    cli.head = "4"
    cli.head_set = True
    var env = RawPlacementInputs()
    env.attention = "fast"
    env.attention_set = True
    env.bits = "4"
    env.bits_set = True
    env.quality = "low"
    env.quality_set = True
    var options = resolve_placement_options(cli, env)
    expect_str(options.quality.quality, "medium", "cli tier beats env tier")
    expect_eq(options.quality.quality_source, SOURCE_CLI, "tier source cli")
    expect_eq(options.quality.head_bits, 4, "head lever stored")
    expect_str(options.quality.attention, "fast", "env attention stands")
    expect_eq(options.quality.attention_source, SOURCE_ENV, "attention source env")
    expect_eq(options.quality.bits, 4, "env bits stand")
    expect_true(options.quality.any_lever_engaged(), "levers engaged recorded")

    # Use of any lowered tier or lever refuses, tier first.
    try:
        require_quality_use(options)
        raise Error("PlacementOptions lowered tier use was allowed")
    except e:
        expect_error_contains(String(e), "--quality medium", "tier use refusal")
    var head_only = RawPlacementInputs()
    head_only.head = "4"
    head_only.head_set = True
    var head_opts = resolve_placement_options(head_only, RawPlacementInputs())
    try:
        require_quality_use(head_opts)
        raise Error("PlacementOptions head lever use was allowed")
    except e:
        expect_error_contains(String(e), "--head 4", "head use refusal")

    # Bad lever values are refused at resolve, never reinterpreted.
    var bad_tier = RawPlacementInputs()
    bad_tier.quality = "ultra"
    bad_tier.quality_set = True
    try:
        _ = resolve_placement_options(bad_tier, RawPlacementInputs())
        raise Error("PlacementOptions unknown tier was accepted")
    except e:
        expect_error_contains(String(e), "not a tier", "tier refusal")
    var bad_bits = RawPlacementInputs()
    bad_bits.bits = "5"
    bad_bits.bits_set = True
    try:
        _ = resolve_placement_options(bad_bits, RawPlacementInputs())
        raise Error("PlacementOptions bits 5 was accepted")
    except e:
        expect_error_contains(String(e), "not a lever value", "bits refusal")
    var bad_head = RawPlacementInputs()
    bad_head.head = "8"
    bad_head.head_set = True
    try:
        _ = resolve_placement_options(bad_head, RawPlacementInputs())
        raise Error("PlacementOptions head 8 was accepted")
    except e:
        expect_error_contains(String(e), "not a lever value", "head refusal")
    print("PASS: quality surface parses, stores, and fails closed at use")


# --- argv scan ------------------------------------------------------


def test_argv_scan() raises:
    var args = List[String]()
    args.append("--model")
    args.append("some.gguf")
    args.append("--prompt-on=npu+gpu")
    args.append("--reply-on")
    args.append("gpu")
    args.append("--no-npu")
    args.append("--quality")
    args.append("low")
    args.append("--temp")
    args.append("0.7")
    var raw = scan_placement_args(args)
    expect_true(raw.prompt_set, "scan prompt set")
    expect_str(raw.prompt, "npu+gpu", "scan prompt value")
    expect_true(raw.reply_set, "scan reply set")
    expect_str(raw.reply, "gpu", "scan reply value")
    expect_true(raw.no_npu, "scan no-npu")
    expect_true(not raw.no_gpu, "scan no-gpu unset")
    expect_str(raw.quality, "low", "scan quality value")

    # The scan composes with resolve: --no-npu against the scanned
    # npu+gpu prompt placement refuses with both names in the reason.
    try:
        _ = resolve_placement_options(raw, RawPlacementInputs())
        raise Error("PlacementOptions scanned kill conflict resolved")
    except e:
        expect_error_contains(String(e), "killed by --no-npu", "scan+resolve kill")

    var dup = List[String]()
    dup.append("--prompt-on")
    dup.append("gpu")
    dup.append("--prompt-on")
    dup.append("cpu")
    try:
        _ = scan_placement_args(dup)
        raise Error("PlacementOptions duplicate flag was accepted")
    except e:
        expect_error_contains(String(e), "set twice", "duplicate refused")

    var missing = List[String]()
    missing.append("--reply-on")
    try:
        _ = scan_placement_args(missing)
        raise Error("PlacementOptions missing value was accepted")
    except e:
        expect_error_contains(String(e), "requires a value", "missing value")

    var typo = List[String]()
    typo.append("--prompt-onn")
    typo.append("gpu")
    try:
        _ = scan_placement_args(typo)
        raise Error("PlacementOptions typo flag was accepted")
    except e:
        expect_error_contains(String(e), "unknown option", "typo refused")

    var no_cpu = List[String]()
    no_cpu.append("--no-cpu")
    try:
        _ = scan_placement_args(no_cpu)
        raise Error("PlacementOptions --no-cpu was accepted")
    except e:
        expect_error_contains(String(e), "cannot be killed", "no-cpu refused")

    var switch_value = List[String]()
    switch_value.append("--no-gpu=1")
    try:
        _ = scan_placement_args(switch_value)
        raise Error("PlacementOptions valued switch was accepted")
    except e:
        expect_error_contains(String(e), "takes no value", "switch value refused")
    print("PASS: argv scan forms, duplicates, typos, --no-cpu refusal")


# --- environment layer ----------------------------------------------


def _set_env(name: String, value: String):
    var name_buf = InlineArray[Int8, 32](fill=0)
    var name_bytes = name.as_bytes()
    for i in range(len(name_bytes)):
        name_buf[i] = Int8(name_bytes[i])
    var value_buf = InlineArray[Int8, 64](fill=0)
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


def test_env_layer() raises:
    _set_env("AESIR_PROMPT_ON", "gpu")
    _set_env("AESIR_GPU", "0")
    _set_env("AESIR_REPLY_ON", "cpu+gpu")
    try:
        var env = placement_env_inputs()
        expect_true(env.prompt_set, "env prompt read")
        expect_str(env.prompt, "gpu", "env prompt value")
        expect_true(env.gpu_env_set, "env gpu switch read")
        expect_str(env.gpu_env, "0", "env gpu switch value")
        # End to end: the env layer alone resolves -- and its kill
        # refuses the env's own reply placement naming the GPU.
        try:
            _ = resolve_placement_options(RawPlacementInputs(), env)
            raise Error("PlacementOptions env kill conflict resolved")
        except e:
            expect_error_contains(
                String(e), "killed by AESIR_GPU=0", "env end-to-end kill"
            )
        _unset_env("AESIR_GPU")
        _unset_env("AESIR_REPLY_ON")
        var env2 = placement_env_inputs()
        var options = resolve_placement_options(RawPlacementInputs(), env2)
        expect_eq(options.prompt.source, SOURCE_ENV, "env end-to-end source")
        expect_str(
            options.prompt.choice.describe(), "gpu", "env end-to-end value"
        )
    finally:
        _unset_env("AESIR_PROMPT_ON")
        _unset_env("AESIR_GPU")
        _unset_env("AESIR_REPLY_ON")
    print("PASS: environment layer reads, resolves, and kills end to end")


def test_describe_report() raises:
    var cli = RawPlacementInputs()
    cli.prompt = "npu+gpu"
    cli.prompt_set = True
    cli.no_npu = False
    var env = RawPlacementInputs()
    env.reply = "gpu"
    env.reply_set = True
    var options = resolve_placement_options(cli, env)
    var report = options.describe()
    expect_true(contains(report, "prompt: npu+gpu (cli)"), "report prompt line")
    expect_true(contains(report, "reply: gpu (env)"), "report reply line")
    expect_true(contains(report, "drafts: auto (default)"), "report drafts line")
    expect_true(contains(report, "gap G1"), "report states the drafts gate")
    expect_true(contains(report, "quality: high (default)"), "report quality line")

    var killed = RawPlacementInputs()
    killed.no_gpu = True
    var killed_opts = resolve_placement_options(killed, RawPlacementInputs())
    var killed_report = killed_opts.describe()
    expect_true(
        contains(killed_report, "auto field: cpu, npu"),
        "report shrinks the auto field under a kill",
    )
    expect_true(
        contains(killed_report, "kills: gpu by --no-gpu"),
        "report names the kill and its switch",
    )
    print("PASS: describe report states values, sources, kills, gates")


def main() raises:
    test_placement_forms()
    test_placement_grammar_refusals()
    test_pass_kind_legality()
    test_precedence()
    test_kill_switches()
    test_drafts_use_fail_closed()
    test_quality_surface()
    test_argv_scan()
    test_env_layer()
    test_describe_report()
    print("ALL PASS: placement options (10 groups)")
