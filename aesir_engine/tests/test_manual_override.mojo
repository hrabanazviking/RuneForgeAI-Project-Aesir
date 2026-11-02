"""Manual override supremacy (J-047): the --mode preset
surface (grammar, sources, cli > env > default precedence,
refusals); the per-kind precedence stack (hand fixed / hand
race / explicit hand auto over preset over learned over auto,
with provenance and re-trial applicability on every outcome);
and the generalised invalid-device refusal at open (single,
co-work, and race forms; hand, preset, and learned sources;
the parked NPU as an execution device) against fixture
inventories and the live inventory of the machine running the
test.

Fixture inventories are built from J-037's real fact types and
builders (parse_cpuinfo / cpu_entry / gpu_entry over injected
nvidia-smi output / gpu_absent_entry / npu_entry parked). The
live group runs the real observer on this machine: on this VM
the GPU is absent and the NPU parked, so the live refusals are
genuine machine truth, exercised as truth. No inference runs;
no chooser is run -- resolution and refusal are pure logic
over resolved options, exactly the slice's subject.
"""
from core.device_inventory import (
    DeviceInventory,
    NPU_LEDGER_PARKED,
    cpu_entry,
    gpu_absent_entry,
    gpu_entry,
    npu_entry,
    observe_device_inventory,
    parse_cpuinfo,
    parse_nvidia_smi_csv,
)
from core.learned_file import (
    LearnedEntry,
    LearnedPassChoice,
    learned_pass_from_choice,
)
from core.manual_override import (
    GOV_AUTO,
    GOV_LEARNED,
    GOV_MANUAL_AUTO,
    GOV_MANUAL_FIXED,
    GOV_MANUAL_RACE,
    GOV_PRESET_FIXED,
    GOV_PRESET_MEASURE,
    MODE_AUTO,
    MODE_ECO,
    MODE_MAX,
    ModeOption,
    RawModeInputs,
    governing_name,
    mode_env_inputs,
    mode_name,
    preset_intent,
    resolve_mode,
    resolve_precedence,
    scan_mode_args,
    validate_open_choices,
)
from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    PlacementOptions,
    RawPlacementInputs,
    resolve_placement_options,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "ManualOverride "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "ManualOverride "
            + what
            + ": expected '"
            + expected
            + "', got '"
            + actual
            + "'"
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("ManualOverride " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "ManualOverride "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


# --- fixtures ------------------------------------------------------------


def _options(
    prompt: String, drafts: String, reply: String
) raises -> PlacementOptions:
    """Resolved placement options from CLI raw values; an empty
    string leaves the kind unset (silent)."""
    var cli = RawPlacementInputs()
    if prompt.byte_length() > 0:
        cli.prompt = prompt
        cli.prompt_set = True
    if drafts.byte_length() > 0:
        cli.drafts = drafts
        cli.drafts_set = True
    if reply.byte_length() > 0:
        cli.reply = reply
        cli.reply_set = True
    return resolve_placement_options(cli, RawPlacementInputs())


def _mode(value: String) raises -> ModeOption:
    var cli = RawModeInputs()
    if value.byte_length() > 0:
        cli.value = value
        cli.value_set = True
    return resolve_mode(cli, RawModeInputs())


def _learned(
    prompt: LearnedPassChoice,
    drafts: LearnedPassChoice,
    reply: LearnedPassChoice,
) -> LearnedEntry:
    var entry = LearnedEntry()
    entry.prompt = prompt
    entry.drafts = drafts
    entry.reply = reply
    return entry^


def _absent() -> LearnedPassChoice:
    return learned_pass_from_choice(
        "auto", "", DEVICE_CPU, 0, "REFUSAL", False
    )


def _learned_cpu(threads: Int) -> LearnedPassChoice:
    return learned_pass_from_choice(
        "auto",
        "cpu threads=" + String(threads),
        DEVICE_CPU,
        threads,
        "MEASURED-WIN",
        True,
    )


def _inventory(gpu_present: Bool) raises -> DeviceInventory:
    var inv = DeviceInventory()
    var text = String("")
    for i in range(4):
        text += "processor\t: " + String(i) + "\n"
        text += "model name\t: Fixture CPU 9000\n"
        text += "physical id\t: 0\n"
        text += "core id\t\t: " + String(i) + "\n\n"
    inv.cpu = cpu_entry(parse_cpuinfo(text))
    if gpu_present:
        inv.gpu = gpu_entry(
            parse_nvidia_smi_csv("Fixture GPU X, 8192, 4096\n")
        )
    else:
        inv.gpu = gpu_absent_entry(
            "no GPU probe answered: fixture states no gpu"
        )
    inv.npu = npu_entry(NPU_LEDGER_PARKED, String(""))
    return inv^


def _refusal_of(
    options: PlacementOptions,
    mode: ModeOption,
    learned: LearnedEntry,
    has_learned: Bool,
    inv: DeviceInventory,
) -> String:
    """Run open validation and return the refusal text, or the
    empty string when validation passes."""
    try:
        validate_open_choices(options, mode, learned, has_learned, inv)
        return String("")
    except refusal:
        return String(refusal)


# --- groups ----------------------------------------------------------------


def test_mode_grammar_and_precedence() raises:
    var unset = resolve_mode(RawModeInputs(), RawModeInputs())
    expect_eq(unset.mode, MODE_AUTO, "unset mode is auto")
    expect_true(not unset.was_set, "unset mode records silence")
    var cli = RawModeInputs()
    cli.value = "eco"
    cli.value_set = True
    var env = RawModeInputs()
    env.value = "max"
    env.value_set = True
    var from_cli = resolve_mode(cli, env)
    expect_eq(from_cli.mode, MODE_ECO, "cli beats env")
    expect_str(
        mode_name(from_cli.mode), "eco", "cli mode renders eco"
    )
    var from_env = resolve_mode(RawModeInputs(), env)
    expect_eq(from_env.mode, MODE_MAX, "env supplies the mode")
    expect_true(from_env.was_set, "env mode records set")
    expect_contains(
        from_cli.describe(), "eco", "describe names the mode"
    )
    expect_contains(
        from_cli.describe(), "cli", "describe names the source"
    )
    print("PASS: override -- mode grammar and cli > env > default precedence")


def test_mode_refusals() raises:
    for bad in [String("ultra"), String("ECO"), String(""), String(" eco1")]:
        var refused = False
        var raw = RawModeInputs()
        raw.value = bad
        raw.value_set = True
        try:
            _ = resolve_mode(raw, RawModeInputs())
        except:
            refused = True
        expect_true(refused, "mode value refused: '" + bad + "'")
    var reason = String("")
    var raw2 = RawModeInputs()
    raw2.value = "ultra"
    raw2.value_set = True
    try:
        _ = resolve_mode(raw2, RawModeInputs())
    except refusal:
        reason = String(refusal)
    expect_contains(reason, "not a mode", "refusal states the grammar")
    expect_contains(reason, "auto, eco, max", "refusal names the modes")
    print("PASS: override -- mode refusals (unknown, case, empty) with reasons")


def test_mode_scan_and_env() raises:
    var args = List[String]()
    args.append("--model")
    args.append("some-model")
    args.append("--mode=eco")
    args.append("--other")
    var scanned = scan_mode_args(args)
    expect_true(scanned.value_set, "scan finds --mode=value beside --model")
    expect_str(scanned.value, "eco", "scan reads the value")
    var args2 = List[String]()
    args2.append("--mode")
    args2.append("max")
    var scanned2 = scan_mode_args(args2)
    expect_str(scanned2.value, "max", "scan reads the spaced value")
    var dup = False
    var args3 = List[String]()
    args3.append("--mode")
    args3.append("eco")
    args3.append("--mode=max")
    try:
        _ = scan_mode_args(args3)
    except:
        dup = True
    expect_true(dup, "duplicate --mode refused")
    var missing = False
    var args4 = List[String]()
    args4.append("--mode")
    try:
        _ = scan_mode_args(args4)
    except:
        missing = True
    expect_true(missing, "--mode with no value refused")
    var typo = False
    var args5 = List[String]()
    args5.append("--modee")
    args5.append("eco")
    try:
        _ = scan_mode_args(args5)
    except:
        typo = True
    expect_true(typo, "typo'd --modee refused in the namespace")
    var env_raw = mode_env_inputs()
    _ = env_raw  # shape only: the live env is the caller's own
    print("PASS: override -- mode argv scan (forms, duplicate, missing, typo)")


def test_preset_intents() raises:
    var auto = _mode("")
    for kind in [PASS_PROMPT, PASS_DRAFTS, PASS_REPLY]:
        var intent = preset_intent(auto, kind)
        expect_true(not intent.governs, "mode auto governs nothing")
    var eco = _mode("eco")
    var eco_prompt = preset_intent(eco, PASS_PROMPT)
    expect_true(eco_prompt.governs, "eco governs")
    expect_true(eco_prompt.fixed, "eco is a fixed intent")
    expect_eq(eco_prompt.device, DEVICE_CPU, "eco fixes the cpu")
    expect_eq(eco_prompt.threads, 1, "eco fixes the serial rung")
    expect_str(eco_prompt.label, "cpu threads=1", "eco label")
    expect_contains(
        eco_prompt.note, "never uses the gpu", "eco note cites the census rule"
    )
    var max_mode = _mode("max")
    var max_reply = preset_intent(max_mode, PASS_REPLY)
    expect_true(max_reply.governs, "max governs")
    expect_true(not max_reply.fixed, "max is a measure intent, not fixed")
    expect_contains(
        max_reply.note, "learned default is bypassed", "max bypasses learned"
    )
    var eco_drafts = preset_intent(eco, PASS_DRAFTS)
    expect_contains(
        eco_drafts.note, "fails closed", "drafts intent carries the G1 gate"
    )
    print("PASS: override -- preset intents (auto none, eco fixed, max measure)")


def test_hand_fixed_wins_over_all() raises:
    var options = _options("gpu", "", "")
    var learned = _learned(
        _learned_cpu(2), _absent(), _learned_cpu(1)
    )
    var res = resolve_precedence(options, _mode("eco"), learned, True)
    var prompt = res.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_MANUAL_FIXED, "hand single governs")
    expect_str(
        governing_name(prompt.governing), "MANUAL-FIXED", "governing name"
    )
    expect_str(prompt.effective_text, "gpu", "hand choice stands verbatim")
    expect_true(prompt.has_fixed, "hand fixed is fixed")
    expect_true(not prompt.retrial_applies, "hand choice never re-trialled")
    expect_contains(
        prompt.reason, "never ranked", "reason states the supremacy terms"
    )
    expect_contains(
        prompt.provenance, "cli", "provenance names the hand source"
    )
    var cowork = _options("cpu+gpu", "", "")
    var res2 = resolve_precedence(cowork, _mode("max"), learned, True)
    var prompt2 = res2.for_kind(PASS_PROMPT)
    expect_eq(prompt2.governing, GOV_MANUAL_FIXED, "hand co-work governs")
    expect_str(
        prompt2.effective_text, "cpu+gpu", "co-work stands verbatim"
    )
    print("PASS: override -- hand fixed (single + co-work) wins over all layers")


def test_hand_race_wins() raises:
    var options = _options("", "", "cpu,gpu")
    var learned = _learned(_absent(), _absent(), _learned_cpu(4))
    var res = resolve_precedence(options, _mode("eco"), learned, True)
    var reply = res.for_kind(PASS_REPLY)
    expect_eq(reply.governing, GOV_MANUAL_RACE, "hand race governs")
    expect_str(reply.measure_field, "cpu,gpu", "race field is exactly the hand's")
    expect_true(not reply.has_fixed, "race is measured, not fixed")
    expect_true(not reply.retrial_applies, "hand race never re-trialled")
    expect_contains(
        reply.reason, "no layer widens or narrows", "race reason states the field law"
    )
    print("PASS: override -- hand race fixes the field; preset/learned skipped")


def test_explicit_hand_auto_wins() raises:
    var options = _options("auto", "", "")
    var learned = _learned(_learned_cpu(2), _absent(), _absent())
    var res = resolve_precedence(options, _mode("eco"), learned, True)
    var prompt = res.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_MANUAL_AUTO, "explicit auto governs as hand")
    expect_true(not prompt.has_fixed, "explicit auto measures")
    expect_contains(
        prompt.measure_field, "cpu", "explicit auto measures the full field"
    )
    expect_contains(
        prompt.reason,
        "the measurement the user asked for",
        "explicit auto reason states the direction",
    )
    # Silence is not a statement: the same value unset falls through.
    var silent = _options("", "", "")
    var res2 = resolve_precedence(silent, _mode("eco"), learned, True)
    expect_eq(
        res2.for_kind(PASS_PROMPT).governing,
        GOV_PRESET_FIXED,
        "unset auto is silence and the preset governs",
    )
    print("PASS: override -- explicit hand auto directs measurement; unset is silence")


def test_preset_governs_over_learned() raises:
    var silent = _options("", "", "")
    var learned = _learned(
        _learned_cpu(2), _absent(), _learned_cpu(1)
    )
    var eco_res = resolve_precedence(silent, _mode("eco"), learned, True)
    var prompt = eco_res.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_PRESET_FIXED, "eco governs over learned")
    expect_str(prompt.effective_text, "cpu threads=1", "eco intent stands")
    expect_eq(prompt.threads, 1, "eco threads")
    expect_true(not prompt.retrial_applies, "preset outcome is no re-trial target")
    var max_res = resolve_precedence(silent, _mode("max"), learned, True)
    var reply = max_res.for_kind(PASS_REPLY)
    expect_eq(reply.governing, GOV_PRESET_MEASURE, "max governs over learned")
    expect_true(not reply.has_fixed, "max measures, learned bypassed")
    expect_contains(
        reply.reason, "bypassed", "max reason states the learned bypass"
    )
    print("PASS: override -- preset (eco fixed / max measure) governs over learned")


def test_learned_then_auto() raises:
    var silent = _options("", "", "")
    var learned = _learned(
        _learned_cpu(2), _absent(), _learned_cpu(1)
    )
    var res = resolve_precedence(silent, _mode(""), learned, True)
    var prompt = res.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_LEARNED, "learned governs under silence")
    expect_str(
        prompt.effective_text, "cpu threads=2", "learned choice applies"
    )
    expect_true(prompt.retrial_applies, "measured learned choice is re-triable")
    expect_contains(
        prompt.provenance, "MEASURED-WIN", "learned provenance states decision"
    )
    var drafts = res.for_kind(PASS_DRAFTS)
    expect_eq(
        drafts.governing, GOV_AUTO, "absent learned kind falls to auto"
    )
    var none = resolve_precedence(silent, _mode(""), learned, False)
    expect_eq(
        none.for_kind(PASS_PROMPT).governing,
        GOV_AUTO,
        "a non-applied entry supplies nothing",
    )
    var empty = resolve_precedence(
        silent, _mode(""), _learned(_absent(), _absent(), _absent()), True
    )
    expect_eq(
        empty.for_kind(PASS_REPLY).governing,
        GOV_AUTO,
        "all-absent entry falls to auto",
    )
    print("PASS: override -- learned applies under silence; absent falls to auto")


def test_learned_manual_fixed_provenance() raises:
    var silent = _options("", "", "")
    var manual_learned = learned_pass_from_choice(
        "gpu", "gpu", DEVICE_GPU, 0, "MANUAL-FIXED", True
    )
    var learned = _learned(manual_learned, _absent(), _absent())
    var res = resolve_precedence(silent, _mode(""), learned, True)
    var prompt = res.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_LEARNED, "persisted hand choice applies as learned")
    expect_true(
        not prompt.retrial_applies,
        "persisted hand choice is never re-trialled",
    )
    expect_contains(
        prompt.provenance, "persisted hand choice", "provenance states its nature"
    )
    expect_contains(
        prompt.reason, "never re-trialled", "reason states the J-045 discipline"
    )
    print("PASS: override -- learned MANUAL-FIXED keeps hand provenance, no re-trial")


def test_report_rendering() raises:
    var options = _options("gpu", "", "")
    var learned = _learned(_learned_cpu(2), _absent(), _learned_cpu(1))
    var res = resolve_precedence(options, _mode("eco"), learned, True)
    var report = res.report()
    expect_contains(report, "mode: eco", "report names the mode")
    expect_contains(
        report, "hand > preset > learned > auto", "report states the stack"
    )
    expect_contains(report, "prompt: MANUAL-FIXED", "report prompt layer")
    expect_contains(report, "drafts: PRESET-FIXED", "report drafts layer")
    expect_contains(report, "reply: PRESET-FIXED", "report reply layer")
    expect_contains(
        report, "defaults only", "report carries the J-044 sentence"
    )
    print("PASS: override -- report renders the stack and every kind's layer")


def test_open_refusal_single_absent() raises:
    var inv = _inventory(False)
    var options = _options("", "", "gpu")
    var refusal = _refusal_of(
        options, _mode(""), _learned(_absent(), _absent(), _absent()),
        False, inv,
    )
    expect_true(refusal.byte_length() > 0, "absent gpu hand choice refused")
    expect_contains(refusal, "names gpu", "refusal names the device")
    expect_contains(refusal, "reply pass", "refusal names the kind")
    expect_contains(
        refusal, "gpu absent", "refusal carries the inventory fact"
    )
    expect_contains(
        refusal,
        "fixture states no gpu",
        "refusal carries the inventory reason verbatim",
    )
    expect_contains(
        refusal, "refused whole", "refusal states the whole-choice law"
    )
    print("PASS: override -- open refusal: single absent device (hand, reply)")


def test_open_refusal_cowork_and_race_whole() raises:
    var inv = _inventory(False)
    var no_learned = _learned(_absent(), _absent(), _absent())
    var cowork = _options("cpu+gpu", "", "")
    var r1 = _refusal_of(cowork, _mode(""), no_learned, False, inv)
    expect_contains(r1, "names gpu", "co-work refused on its absent member")
    expect_contains(r1, "cpu+gpu", "co-work refusal names the whole value")
    var race = _options("cpu,gpu", "", "")
    var r2 = _refusal_of(race, _mode(""), no_learned, False, inv)
    expect_contains(r2, "names gpu", "race refused on its absent member")
    expect_contains(
        r2, "no device is dropped", "race refusal states no trimming"
    )
    # Both members present: the same forms pass whole.
    var inv_gpu = _inventory(True)
    var ok = _refusal_of(cowork, _mode(""), no_learned, False, inv_gpu)
    expect_str(ok, "", "co-work passes when both members are present")
    var ok2 = _refusal_of(race, _mode(""), no_learned, False, inv_gpu)
    expect_str(ok2, "", "race passes when every member is present")
    print("PASS: override -- open refusal: co-work + race refused whole, never trimmed")


def test_open_refusal_npu_parked() raises:
    var inv = _inventory(True)
    var no_learned = _learned(_absent(), _absent(), _absent())
    var single = _options("npu", "", "")
    var r1 = _refusal_of(single, _mode(""), no_learned, False, inv)
    expect_contains(r1, "names npu", "parked npu single refused at open")
    expect_contains(r1, "prompt pass", "npu refusal names the prompt kind")
    expect_contains(r1, "parked", "npu refusal carries the parked fact")
    var cowork = _options("npu+gpu", "", "")
    var r2 = _refusal_of(cowork, _mode(""), no_learned, False, inv)
    expect_contains(r2, "names npu", "parked npu co-work member refused")
    var race = _options("cpu,npu", "", "")
    var r3 = _refusal_of(race, _mode(""), no_learned, False, inv)
    expect_contains(r3, "names npu", "parked npu race member refused")
    print("PASS: override -- open refusal: parked NPU in single/co-work/race forms")


def test_open_refusal_learned_and_preset_paths() raises:
    var inv = _inventory(False)
    var silent = _options("", "", "")
    var gpu_learned = learned_pass_from_choice(
        "auto", "gpu", DEVICE_GPU, 0, "SOLE-MEASURED", True
    )
    # A SOLE-MEASURED gpu learned choice cannot be built through
    # J-044 validation (it is a fixture in the record shape, as
    # J-044/J-045's live fixtures are); the resolver consumes the
    # record fields, which is the surface under test here.
    var learned = _learned(gpu_learned, _absent(), _absent())
    var r1 = _refusal_of(silent, _mode(""), learned, True, inv)
    expect_contains(r1, "names gpu", "governing learned gpu refused")
    expect_contains(
        r1, "learned default", "learned refusal names its source layer"
    )
    # The same learned choice shadowed by a hand cpu choice is
    # never applied, so it does not block the hand's open.
    var hand_cpu = _options("cpu", "", "")
    var ok = _refusal_of(hand_cpu, _mode(""), learned, True, inv)
    expect_str(ok, "", "shadowed learned device does not refuse the hand's open")
    # Preset eco names only the cpu, which is present: it passes
    # on a gpu-absent machine.
    var ok2 = _refusal_of(silent, _mode("eco"), learned, True, inv)
    expect_str(ok2, "", "eco preset passes where its cpu is present")
    # Defaults name nothing: a silent, modeless, learned-less
    # open passes even with the gpu absent.
    var ok3 = _refusal_of(
        silent, _mode(""),
        _learned(_absent(), _absent(), _absent()), False, inv,
    )
    expect_str(ok3, "", "silent defaults pass open validation")
    print("PASS: override -- open refusal: learned source; shadowed + preset paths")


def test_live_inventory() raises:
    var inv = observe_device_inventory()
    print("LIVE DEVICE LINE: " + inv.device_line())
    expect_true(inv.cpu.present, "live cpu present")
    expect_true(not inv.gpu.present, "live gpu absent on this VM")
    expect_true(not inv.npu.present, "live npu parked/absent on this road")
    var no_learned = _learned(_absent(), _absent(), _absent())
    var gpu_hand = _options("", "", "gpu")
    var refusal = _refusal_of(gpu_hand, _mode(""), no_learned, False, inv)
    expect_contains(refusal, "names gpu", "live: hand gpu refused with reason")
    expect_contains(refusal, "reply pass", "live: refusal names the kind")
    var npu_hand = _options("npu", "", "")
    var refusal2 = _refusal_of(npu_hand, _mode(""), no_learned, False, inv)
    expect_contains(refusal2, "names npu", "live: hand npu refused (parked)")
    expect_contains(refusal2, "parked", "live: refusal carries the parked fact")
    var cpu_hand = _options("cpu", "", "cpu")
    var ok = _refusal_of(cpu_hand, _mode("eco"), no_learned, False, inv)
    expect_str(ok, "", "live: hand cpu + eco preset pass open validation")
    var res = resolve_precedence(
        cpu_hand, _mode("eco"), no_learned, False
    )
    print("LIVE RESOLUTION:\n" + res.report())
    expect_eq(
        res.for_kind(PASS_PROMPT).governing,
        GOV_MANUAL_FIXED,
        "live: hand cpu prompt governs",
    )
    expect_eq(
        res.for_kind(PASS_DRAFTS).governing,
        GOV_PRESET_FIXED,
        "live: eco governs the silent drafts kind",
    )
    print("PASS: override -- live inventory refusals + resolution on this VM")


def main() raises:
    test_mode_grammar_and_precedence()
    test_mode_refusals()
    test_mode_scan_and_env()
    test_preset_intents()
    test_hand_fixed_wins_over_all()
    test_hand_race_wins()
    test_explicit_hand_auto_wins()
    test_preset_governs_over_learned()
    test_learned_then_auto()
    test_learned_manual_fixed_provenance()
    test_report_rendering()
    test_open_refusal_single_absent()
    test_open_refusal_cowork_and_race_whole()
    test_open_refusal_npu_parked()
    test_open_refusal_learned_and_preset_paths()
    test_live_inventory()
    print("ALL PASS: manual override supremacy (16 groups)")
