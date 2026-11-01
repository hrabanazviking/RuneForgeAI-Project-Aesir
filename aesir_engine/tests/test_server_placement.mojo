"""Server placement parity (J-049): the session defaults
resolved once at serve open (J-036 options + J-047 mode +
learned, open refusal and quality gate inherited), the
per-request placement fields the three generation request
shapes may carry (prompt_on / drafts_on / reply_on / mode,
claimed flat -- never inside Ollama's numbers-only options
object), the per-request stack (request hand > request preset
> session resolution, per kind, provenance on every outcome),
and the conformance rule in require_loaded_context's shape: a
request-governed fixed placement must equal the resident
session's executed placement, a request-governed measurement
demand is refused, and a silent kind is served under the
session default.

Fixtures follow the J-047 suite's shapes: resolved options
from CLI raw values, fixture inventories built from J-037's
real fact types and builders (GPU present and absent), learned
records built from J-044's builder. The live group runs J-037's
real observer on this machine. No inference runs and no server
is started: resolution, refusal, and conformance are pure
logic over resolved options, exactly the slice's subject.
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
    ModeOption,
    RawModeInputs,
    resolve_mode,
)
from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    RawPlacementInputs,
    resolve_placement_options,
)
from core.server_placement import (
    PROV_REQUEST,
    PROV_SESSION,
    ResidentPlacement,
    ServerPlacementDefaults,
    ServerPlacementRequest,
    ServerRequestPlacement,
    apply_server_placement_field,
    is_server_placement_field,
    require_server_defaults_conformance,
    require_server_request_conformance,
    resident_single,
    resolve_server_defaults,
    resolve_server_request_placement,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "ServerPlacement "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "ServerPlacement "
            + what
            + ": expected '"
            + expected
            + "', got '"
            + actual
            + "'"
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("ServerPlacement " + what + ": expected true")


def expect_false(value: Bool, what: String) raises:
    if value:
        raise Error("ServerPlacement " + what + ": expected false")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "ServerPlacement "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


# --- fixtures ------------------------------------------------------------


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


def _absent() -> LearnedPassChoice:
    return learned_pass_from_choice(
        "auto", "", DEVICE_CPU, 0, "REFUSAL", False
    )


def _no_learned() -> LearnedEntry:
    var entry = LearnedEntry()
    entry.prompt = _absent()
    entry.drafts = _absent()
    entry.reply = _absent()
    return entry^


def _defaults(
    prompt: String,
    drafts: String,
    reply: String,
    mode_value: String,
    inv: DeviceInventory,
) raises -> ServerPlacementDefaults:
    """Session defaults from CLI raw values (empty = unset),
    no learned entry applied."""
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
    var options = resolve_placement_options(cli, RawPlacementInputs())
    var mode_cli = RawModeInputs()
    if mode_value.byte_length() > 0:
        mode_cli.value = mode_value
        mode_cli.value_set = True
    var mode = resolve_mode(mode_cli, RawModeInputs())
    return resolve_server_defaults(
        options, mode, _no_learned(), False, inv
    )


def _request(
    prompt: String, drafts: String, reply: String, mode_value: String
) raises -> ServerPlacementRequest:
    var request = ServerPlacementRequest()
    if prompt.byte_length() > 0:
        _ = apply_server_placement_field(request, "prompt_on", prompt)
    if drafts.byte_length() > 0:
        _ = apply_server_placement_field(request, "drafts_on", drafts)
    if reply.byte_length() > 0:
        _ = apply_server_placement_field(request, "reply_on", reply)
    if mode_value.byte_length() > 0:
        _ = apply_server_placement_field(request, "mode", mode_value)
    return request


def _empty_request() -> ServerPlacementRequest:
    return ServerPlacementRequest()


def _resolve_error(
    defaults: ServerPlacementDefaults,
    request: ServerPlacementRequest,
    inv: DeviceInventory,
) -> String:
    try:
        _ = resolve_server_request_placement(defaults, request, inv)
        return String("")
    except refusal:
        return String(refusal)


def _defaults_error(
    defaults: ServerPlacementDefaults, resident: ResidentPlacement
) -> String:
    try:
        require_server_defaults_conformance(defaults, resident)
        return String("")
    except refusal:
        return String(refusal)


def _request_error(
    placement: ServerRequestPlacement, resident: ResidentPlacement
) -> String:
    try:
        require_server_request_conformance(placement, resident)
        return String("")
    except refusal:
        return String(refusal)


# --- groups ----------------------------------------------------------------


def test_field_claiming() raises:
    var request = ServerPlacementRequest()
    expect_true(
        is_server_placement_field("prompt_on"), "prompt_on is claimed"
    )
    expect_true(
        is_server_placement_field("drafts_on"), "drafts_on is claimed"
    )
    expect_true(
        is_server_placement_field("reply_on"), "reply_on is claimed"
    )
    expect_true(is_server_placement_field("mode"), "mode is claimed")
    expect_false(
        is_server_placement_field("temperature"),
        "temperature stays the parser's own field",
    )
    expect_false(
        is_server_placement_field("prompt"),
        "the prompt text field is not a placement field",
    )
    expect_true(
        apply_server_placement_field(request, "prompt_on", "gpu"),
        "apply claims prompt_on",
    )
    expect_true(request.prompt_set, "prompt raw stored set")
    expect_str(request.prompt, "gpu", "prompt raw stored verbatim")
    expect_false(
        apply_server_placement_field(request, "temperature", "0.7"),
        "apply leaves foreign fields to the parser",
    )
    expect_true(request.any_set(), "any_set sees the claim")
    var duplicate = String("")
    try:
        _ = apply_server_placement_field(request, "prompt_on", "cpu")
    except refusal:
        duplicate = String(refusal)
    expect_contains(duplicate, "set twice", "duplicate field refused")
    expect_contains(duplicate, "state it once", "duplicate reason")
    print("PASS: server placement -- field claiming (names, raw store, duplicate)")


def test_defaults_silent_auto() raises:
    var inv = _inventory(True)
    var defaults = _defaults("", "", "", "", inv)
    var placement = resolve_server_request_placement(
        defaults, _empty_request(), inv
    )
    for kind in [PASS_PROMPT, PASS_DRAFTS, PASS_REPLY]:
        var outcome = placement.for_kind(kind)
        expect_eq(
            outcome.governing, GOV_AUTO, "silent session governs AUTO"
        )
        expect_eq(
            outcome.provenance,
            PROV_SESSION,
            "silent outcome provenance is the session",
        )
        expect_false(
            outcome.has_fixed_choice, "auto fixes no device set"
        )
    var defaults_line = _defaults_error(defaults, resident_single(DEVICE_GPU))
    expect_str(
        defaults_line, "", "auto defaults conform to any resident"
    )
    print("PASS: server placement -- silent defaults resolve AUTO (session)")


def test_session_hand_governs_silent_request() raises:
    var inv = _inventory(True)
    var defaults = _defaults("gpu", "cpu", "cpu+gpu", "", inv)
    var placement = resolve_server_request_placement(
        defaults, _empty_request(), inv
    )
    var prompt = placement.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_MANUAL_FIXED, "session hand fixed")
    expect_eq(prompt.provenance, PROV_SESSION, "session provenance")
    expect_true(prompt.has_fixed_choice, "session fixed carries a set")
    expect_str(
        prompt.fixed_choice.describe(), "gpu", "session prompt set gpu"
    )
    var reply = placement.for_kind(PASS_REPLY)
    expect_str(
        reply.fixed_choice.describe(),
        "cpu+gpu",
        "session co-work set carried whole",
    )
    expect_contains(
        reply.reason, "session default governs", "fall-through stated"
    )
    print("PASS: server placement -- session hand governs a silent request")


def test_session_preset_and_learned_fallthrough() raises:
    var inv = _inventory(True)
    # Session preset eco governs silent kinds.
    var eco = _defaults("", "", "", "eco", inv)
    var p1 = resolve_server_request_placement(eco, _empty_request(), inv)
    var prompt = p1.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_PRESET_FIXED, "session eco fixed")
    expect_eq(prompt.provenance, PROV_SESSION, "session eco provenance")
    expect_str(
        prompt.fixed_choice.describe(), "cpu", "session eco set is cpu"
    )
    # Session learned governs where hand and preset are silent.
    var cli = RawPlacementInputs()
    var options = resolve_placement_options(cli, RawPlacementInputs())
    var mode = resolve_mode(RawModeInputs(), RawModeInputs())
    var learned = _no_learned()
    learned.reply = learned_pass_from_choice(
        "auto", "gpu", DEVICE_GPU, 0, "MEASURED-WIN", True
    )
    var with_learned = resolve_server_defaults(
        options, mode, learned, True, inv
    )
    var p2 = resolve_server_request_placement(
        with_learned, _empty_request(), inv
    )
    var reply = p2.for_kind(PASS_REPLY)
    expect_eq(reply.governing, GOV_LEARNED, "session learned governs")
    expect_eq(reply.provenance, PROV_SESSION, "learned provenance session")
    expect_str(
        reply.fixed_choice.describe(), "gpu", "learned set carried"
    )
    print("PASS: server placement -- session preset + learned fall-through")


def test_request_overrides_session_hand() raises:
    var inv = _inventory(True)
    var defaults = _defaults("cpu", "", "cpu", "", inv)
    var request = _request("gpu", "", "gpu", "")
    var placement = resolve_server_request_placement(defaults, request, inv)
    var prompt = placement.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_MANUAL_FIXED, "request hand fixed")
    expect_eq(prompt.provenance, PROV_REQUEST, "request provenance")
    expect_str(
        prompt.fixed_choice.describe(), "gpu", "request set wins"
    )
    expect_contains(
        prompt.reason,
        "session default is unchanged",
        "per-request scope stated",
    )
    # The defaults themselves are untouched by the request.
    var after = resolve_server_request_placement(
        defaults, _empty_request(), inv
    )
    expect_str(
        after.for_kind(PASS_PROMPT).fixed_choice.describe(),
        "cpu",
        "session default survives the request",
    )
    print("PASS: server placement -- request hand overrides, defaults unmutated")


def test_request_partial_fallthrough() raises:
    var inv = _inventory(True)
    var defaults = _defaults("cpu", "", "cpu", "", inv)
    var request = _request("gpu", "", "", "")
    var placement = resolve_server_request_placement(defaults, request, inv)
    expect_eq(
        placement.for_kind(PASS_PROMPT).provenance,
        PROV_REQUEST,
        "stated kind is the request's",
    )
    expect_eq(
        placement.for_kind(PASS_REPLY).provenance,
        PROV_SESSION,
        "silent kind stays the session's",
    )
    expect_eq(
        placement.for_kind(PASS_DRAFTS).provenance,
        PROV_SESSION,
        "silent drafts stays the session's",
    )
    print("PASS: server placement -- partial request falls through per kind")


def test_request_race_and_auto_shapes() raises:
    var inv = _inventory(True)
    var defaults = _defaults("", "", "", "", inv)
    var race = resolve_server_request_placement(
        defaults, _request("", "", "cpu,gpu", ""), inv
    )
    var reply = race.for_kind(PASS_REPLY)
    expect_eq(reply.governing, GOV_MANUAL_RACE, "request race governs")
    expect_eq(reply.provenance, PROV_REQUEST, "race provenance request")
    expect_str(reply.measure_field, "cpu,gpu", "race field is exact")
    expect_false(reply.has_fixed_choice, "race fixes no set")
    var auto = resolve_server_request_placement(
        defaults, _request("auto", "", "", ""), inv
    )
    var prompt = auto.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_MANUAL_AUTO, "explicit auto governs")
    expect_eq(prompt.provenance, PROV_REQUEST, "auto provenance request")
    expect_contains(
        prompt.measure_field, "cpu", "auto field names the survivors"
    )
    print("PASS: server placement -- request race + explicit auto shapes")


def test_request_mode_presets() raises:
    var inv = _inventory(True)
    var defaults = _defaults("", "", "", "", inv)
    var eco = resolve_server_request_placement(
        defaults, _request("", "", "", "eco"), inv
    )
    var prompt = eco.for_kind(PASS_PROMPT)
    expect_eq(prompt.governing, GOV_PRESET_FIXED, "request eco fixed")
    expect_eq(prompt.provenance, PROV_REQUEST, "request eco provenance")
    expect_str(
        prompt.fixed_choice.describe(), "cpu", "request eco set cpu"
    )
    expect_str(prompt.effective_text, "cpu threads=1", "eco label")
    var maxed = resolve_server_request_placement(
        defaults, _request("", "", "", "max"), inv
    )
    expect_eq(
        maxed.for_kind(PASS_REPLY).governing,
        GOV_PRESET_MEASURE,
        "request max measures",
    )
    var auto_mode = resolve_server_request_placement(
        defaults, _request("", "", "", "auto"), inv
    )
    expect_eq(
        auto_mode.for_kind(PASS_PROMPT).governing,
        GOV_AUTO,
        "request mode auto governs nothing",
    )
    expect_eq(
        auto_mode.for_kind(PASS_PROMPT).provenance,
        PROV_SESSION,
        "mode auto falls through to the session",
    )
    print("PASS: server placement -- request mode presets (eco / max / auto)")


def test_request_hand_beats_request_mode() raises:
    var inv = _inventory(True)
    var defaults = _defaults("", "", "", "", inv)
    var placement = resolve_server_request_placement(
        defaults, _request("gpu", "", "", "eco"), inv
    )
    var prompt = placement.for_kind(PASS_PROMPT)
    expect_eq(
        prompt.governing, GOV_MANUAL_FIXED, "hand beats own preset"
    )
    expect_str(
        prompt.fixed_choice.describe(), "gpu", "hand set stands"
    )
    var reply = placement.for_kind(PASS_REPLY)
    expect_eq(
        reply.governing,
        GOV_PRESET_FIXED,
        "preset still governs the silent kind",
    )
    expect_eq(
        reply.provenance, PROV_REQUEST, "preset provenance request"
    )
    print("PASS: server placement -- request hand beats request preset")


def test_request_parse_refusals() raises:
    var inv = _inventory(True)
    var defaults = _defaults("", "", "", "", inv)
    var unknown = _resolve_error(
        defaults, _request("tpu", "", "", ""), inv
    )
    expect_contains(unknown, "unknown device", "unknown device refused")
    var npu_reply = _resolve_error(
        defaults, _request("", "", "npu", ""), inv
    )
    expect_contains(
        npu_reply, "never takes a reply pass", "npu reply refused at parse"
    )
    var npu_drafts = _resolve_error(
        defaults, _request("", "gpu+npu", "", ""), inv
    )
    expect_contains(
        npu_drafts,
        "never takes a drafts pass",
        "npu drafts refused at parse, whole value",
    )
    var bad_mode = _resolve_error(
        defaults, _request("", "", "", "ultra"), inv
    )
    expect_contains(bad_mode, "not a mode", "bad request mode refused")
    var empty = _resolve_error(defaults, _request("", "", "", ""), inv)
    expect_str(empty, "", "silent request resolves (control)")
    var empty_value = ServerPlacementRequest()
    _ = apply_server_placement_field(empty_value, "reply_on", "")
    var empty_err = _resolve_error(defaults, empty_value, inv)
    expect_contains(
        empty_err, "must not be empty", "empty request value refused"
    )
    print("PASS: server placement -- request parse refusals with reasons")


def test_request_kill_refusal() raises:
    var inv = _inventory(True)
    var cli = RawPlacementInputs()
    cli.no_gpu = True
    var options = resolve_placement_options(cli, RawPlacementInputs())
    var mode = resolve_mode(RawModeInputs(), RawModeInputs())
    var defaults = resolve_server_defaults(
        options, mode, _no_learned(), False, inv
    )
    var err = _resolve_error(defaults, _request("gpu", "", "", ""), inv)
    expect_contains(err, "killed by", "request cannot resurrect a kill")
    expect_contains(err, "--no-gpu", "kill source named")
    # auto under the same kill still resolves: its field shrinks.
    var ok = resolve_server_request_placement(
        defaults, _request("auto", "", "", ""), inv
    )
    expect_eq(
        ok.for_kind(PASS_PROMPT).governing,
        GOV_MANUAL_AUTO,
        "auto survives the kill with a shrunk field",
    )
    expect_false(
        "gpu" in ok.for_kind(PASS_PROMPT).measure_field,
        "killed device leaves the auto field",
    )
    print("PASS: server placement -- session kills bind requests")


def test_request_inventory_refusals() raises:
    var absent = _inventory(False)
    var defaults_absent = _defaults("", "", "", "", absent)
    var race_err = _resolve_error(
        defaults_absent, _request("", "", "cpu,gpu", ""), absent
    )
    expect_contains(
        race_err, "names gpu", "race refused whole on absent member"
    )
    expect_contains(
        race_err, "refused whole at open", "whole-choice law stated"
    )
    expect_contains(
        race_err, "request field", "refusal names the request layer"
    )
    var present = _inventory(True)
    var defaults_present = _defaults("", "", "", "", present)
    var npu_err = _resolve_error(
        defaults_present, _request("npu", "", "", ""), present
    )
    expect_contains(npu_err, "names npu", "parked npu refused")
    expect_contains(npu_err, "parked", "parked fact on the refusal")
    print("PASS: server placement -- request inventory refusals (whole, parked)")


def test_defaults_conformance() raises:
    var inv = _inventory(True)
    var gpu_defaults = _defaults("gpu", "", "gpu", "", inv)
    expect_str(
        _defaults_error(gpu_defaults, resident_single(DEVICE_GPU)),
        "",
        "gpu defaults conform to a gpu resident",
    )
    var cpu_defaults = _defaults("cpu", "", "cpu", "", inv)
    var mismatch = _defaults_error(
        cpu_defaults, resident_single(DEVICE_GPU)
    )
    expect_contains(
        mismatch, "session default", "mismatch names the default"
    )
    expect_contains(
        mismatch, "resident session executes", "mismatch names resident"
    )
    expect_contains(
        mismatch, "open is refused", "mismatch refuses the open"
    )
    var eco_defaults = _defaults("", "", "", "eco", inv)
    expect_str(
        _defaults_error(eco_defaults, resident_single(DEVICE_CPU)),
        "",
        "eco defaults conform to a cpu resident",
    )
    var unstated = _defaults_error(gpu_defaults, ResidentPlacement())
    expect_contains(
        unstated, "not stated", "unstated resident fails closed at open"
    )
    var auto_defaults = _defaults("", "", "", "max", inv)
    expect_str(
        _defaults_error(auto_defaults, resident_single(DEVICE_GPU)),
        "",
        "measurement defaults fix nothing and pass",
    )
    print("PASS: server placement -- defaults conformance at open")


def test_request_conformance() raises:
    var inv = _inventory(True)
    var defaults = _defaults("", "", "", "", inv)
    var resident_gpu = resident_single(DEVICE_GPU)
    var equal = resolve_server_request_placement(
        defaults, _request("gpu", "", "gpu", ""), inv
    )
    expect_str(
        _request_error(equal, resident_gpu),
        "",
        "request fixed equal to resident passes",
    )
    var differing = resolve_server_request_placement(
        defaults, _request("cpu", "", "", ""), inv
    )
    var diff_err = _request_error(differing, resident_gpu)
    expect_contains(
        diff_err, "resident session executes", "differing fixed refused"
    )
    expect_contains(
        diff_err, "never silently ignored", "refusal shape stated"
    )
    expect_contains(
        diff_err, "session defaults at open", "refusal names the road"
    )
    var race = resolve_server_request_placement(
        defaults, _request("", "", "cpu,gpu", ""), inv
    )
    var race_err = _request_error(race, resident_gpu)
    expect_contains(
        race_err, "measurement is an open-time act", "race demand refused"
    )
    var explicit_auto = resolve_server_request_placement(
        defaults, _request("auto", "", "", ""), inv
    )
    var auto_err = _request_error(explicit_auto, resident_gpu)
    expect_contains(
        auto_err,
        "no per-request measurement exists",
        "explicit auto demand refused",
    )
    var maxed = resolve_server_request_placement(
        defaults, _request("", "", "", "max"), inv
    )
    expect_contains(
        _request_error(maxed, resident_gpu),
        "measurement is an open-time act",
        "mode max demand refused",
    )
    var eco = resolve_server_request_placement(
        defaults, _request("", "", "", "eco"), inv
    )
    expect_contains(
        _request_error(eco, resident_gpu),
        "fixed at 'cpu'",
        "request eco refused against a gpu resident",
    )
    expect_str(
        _request_error(eco, resident_single(DEVICE_CPU)),
        "",
        "request eco passes against a cpu resident",
    )
    var silent = resolve_server_request_placement(
        defaults, _empty_request(), inv
    )
    expect_str(
        _request_error(silent, resident_gpu),
        "",
        "silent request needs no per-request conformance",
    )
    var unstated_err = _request_error(equal, ResidentPlacement())
    expect_contains(
        unstated_err,
        "not stated",
        "request-governed kinds fail closed unstated",
    )
    print("PASS: server placement -- request conformance (equal / differ / measure)")


def test_drafts_request_no_conformance() raises:
    var inv = _inventory(True)
    var defaults = _defaults("", "", "", "", inv)
    var placement = resolve_server_request_placement(
        defaults, _request("", "gpu", "", ""), inv
    )
    var drafts = placement.for_kind(PASS_DRAFTS)
    expect_eq(drafts.governing, GOV_MANUAL_FIXED, "drafts resolves fixed")
    expect_eq(drafts.provenance, PROV_REQUEST, "drafts provenance request")
    expect_contains(
        drafts.reason, "gap G1", "drafts outcome carries the G1 gate"
    )
    expect_str(
        _request_error(placement, resident_single(DEVICE_CPU)),
        "",
        "drafts faces no resident conformance (no route executes it)",
    )
    print("PASS: server placement -- drafts resolves, no conformance, G1 stated")


def test_report_rendering() raises:
    var inv = _inventory(True)
    var defaults = _defaults("cpu", "", "", "", inv)
    var placement = resolve_server_request_placement(
        defaults, _request("gpu", "", "", ""), inv
    )
    var report = placement.report()
    expect_contains(report, "J-049", "report names the slice")
    expect_contains(
        report,
        "request hand > request preset > session",
        "report states the stack",
    )
    expect_contains(report, "(request)", "report shows request surface")
    expect_contains(report, "(session)", "report shows session surface")
    expect_contains(
        report,
        "never mutates the session defaults",
        "report states immutability",
    )
    expect_contains(
        report, "conformance:", "report states the conformance rule"
    )
    print("PASS: server placement -- report rendering")


def test_live_inventory() raises:
    var inv = observe_device_inventory()
    print("LIVE DEVICE LINE: " + inv.device_line())
    expect_true(inv.cpu.present, "live cpu present")
    expect_true(not inv.gpu.present, "live gpu absent on this VM")
    expect_true(not inv.npu.present, "live npu parked/absent on this road")
    var defaults = _defaults("cpu", "", "cpu", "", inv)
    expect_str(
        _defaults_error(defaults, resident_single(DEVICE_CPU)),
        "",
        "live: cpu defaults conform to a cpu resident",
    )
    var gpu_err = _resolve_error(
        defaults, _request("gpu", "", "", ""), inv
    )
    expect_contains(
        gpu_err, "names gpu", "live: request gpu refused with reason"
    )
    var ok = resolve_server_request_placement(
        defaults, _request("cpu", "", "", ""), inv
    )
    expect_str(
        _request_error(ok, resident_single(DEVICE_CPU)),
        "",
        "live: request cpu conforms to a cpu resident",
    )
    print("PASS: server placement -- live inventory on this VM")


def main() raises:
    test_field_claiming()
    test_defaults_silent_auto()
    test_session_hand_governs_silent_request()
    test_session_preset_and_learned_fallthrough()
    test_request_overrides_session_hand()
    test_request_partial_fallthrough()
    test_request_race_and_auto_shapes()
    test_request_mode_presets()
    test_request_hand_beats_request_mode()
    test_request_parse_refusals()
    test_request_kill_refusal()
    test_request_inventory_refusals()
    test_defaults_conformance()
    test_request_conformance()
    test_drafts_request_no_conformance()
    test_report_rendering()
    test_live_inventory()
    print("ALL PASS: server placement parity (17 groups)")
