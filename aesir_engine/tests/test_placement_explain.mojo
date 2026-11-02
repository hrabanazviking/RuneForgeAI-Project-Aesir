"""Placement explainability (J-050): the `--explain-placement`
report assembled from the real Part III pieces -- per pass
kind, the candidates measured and their numbers (or why a
candidate never measured), the choice, the governing layer
and provenance (J-047, or J-049 where a server request
governs), and the learned-file state (J-044 load + lookup,
the stored choice per kind, J-045's re-trial due state) --
with the J-043 co-work, J-048 pressure, and J-046 tolerance
lines where those pieces are supplied, and every absent
piece rendered as its stated absence, never filled in.

Fixtures follow the J-047/J-049 suites' shapes: resolved
options from CLI raw values, fixture inventories built from
J-037's real fact types and builders (GPU present and
absent), learned records built from J-044's builder, chooser
records built in the choosers' own record shapes with
injected measurements (the statuses and numbers are the
fixture's, stated as such -- no chooser is run on fixtures).
The live group runs J-037's real observer on this machine
and J-044's real learned-path load. No inference runs and
no session or server is started.
"""
from core.cowork_passes import plan_cowork_prompt
from core.device_inventory import (
    CpuFacts,
    DeviceInventory,
    GpuFacts,
    NPU_LEDGER_PARKED,
    cpu_entry,
    gpu_absent_entry,
    gpu_entry,
    npu_entry,
    observe_device_inventory,
    parse_cpuinfo,
    parse_nvidia_smi_csv,
)
from core.draft_placement import DraftChoiceRecord, DraftMeasurement
from core.learned_file import (
    LOAD_LOADED,
    LOAD_MISSING,
    LOAD_REFUSED,
    LOOKUP_APPLIED,
    LearnedEntry,
    LearnedLoad,
    MachineKey,
    ModelShape,
    learned_pass_from_choice,
    load_learned_file,
    lookup_learned,
    machine_key_from_facts,
    model_shape,
    learned_file_path,
)
from core.manual_override import (
    GOV_AUTO,
    GOV_LEARNED,
    GOV_MANUAL_FIXED,
    ModeOption,
    RawModeInputs,
    resolve_mode,
    resolve_precedence,
)
from core.placement_explain import (
    EX_MEASURED,
    ExplainCandidate,
    PlacementExplainInputs,
    assemble_placement_explanation,
    candidate_status_name,
    explain_candidate_from_draft,
    explain_candidate_from_prompt,
    explain_candidate_from_reply,
    explain_decision_name,
    is_explain_placement_flag,
    learned_state_from,
    scan_explain_placement_args,
)
from core.placement_harness import TimingSummary
from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    PlacementOptions,
    RawPlacementInputs,
    resolve_placement_options,
)
from core.placement_pressure import plan_placement_pressure
from core.prompt_placement import PromptChoiceRecord, PromptMeasurement
from core.reply_placement import ReplyChoiceRecord, ReplyMeasurement
from core.retrial import PLAN_DUE, PLAN_MANUAL_ONLY, plan_retrial
from core.server_placement import (
    ServerPlacementRequest,
    resolve_server_defaults,
    resolve_server_request_placement,
)
from core.within_tolerance import RepetitionGrade, ToleranceProof


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PlacementExplain "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "PlacementExplain "
            + what
            + ": expected '"
            + expected
            + "', got '"
            + actual
            + "'"
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("PlacementExplain " + what + ": expected true")


def expect_false(value: Bool, what: String) raises:
    if value:
        raise Error("PlacementExplain " + what + ": expected false")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "PlacementExplain "
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


def _shape() -> ModelShape:
    return model_shape("olmoe", 2048, 16, 16, 16, 11008, 8192, 64, 8)


def _entry() -> LearnedEntry:
    var entry = LearnedEntry()
    entry.machine = _machine()
    entry.model = _shape()
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


def _options(
    prompt: String, drafts: String, reply: String
) raises -> PlacementOptions:
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


def _mode() raises -> ModeOption:
    return resolve_mode(RawModeInputs(), RawModeInputs())


def _inputs(inv: DeviceInventory) raises -> PlacementExplainInputs:
    var inputs = PlacementExplainInputs()
    inputs.options = _options("", "", "")
    inputs.mode = _mode()
    inputs.resolution = resolve_precedence(
        inputs.options, inputs.mode, LearnedEntry(), False
    )
    inputs.inventory = inv.copy()
    return inputs^


def _summary(
    count: Int, median: Int, lo: Int, hi: Int
) -> TimingSummary:
    var summary = TimingSummary()
    summary.count = count
    summary.median_ns = median
    summary.min_ns = lo
    summary.max_ns = hi
    summary.spread_ns = hi - lo
    return summary


def _prompt_record() -> PromptChoiceRecord:
    var record = PromptChoiceRecord()
    record.option_text = String("auto")
    record.decision_code = 0
    record.decision_text = String("fixture decision text")
    record.has_choice = True
    record.chosen_label = String("cpu threads=2")
    record.chosen_device = DEVICE_CPU
    record.chosen_threads = 2
    record.best_label = String("cpu threads=2")
    record.best_median_ns = 1000
    record.runner_label = String("cpu threads=1")
    record.runner_median_ns = 1200
    record.margin_percent = 20
    record.separation_ok = True
    var winner = PromptMeasurement()
    winner.label = String("cpu threads=2")
    winner.device = DEVICE_CPU
    winner.threads = 2
    winner.status = 0
    winner.summary = _summary(3, 1000, 900, 1100)
    record.measurements.append(winner)
    var runner = PromptMeasurement()
    runner.label = String("cpu threads=1")
    runner.device = DEVICE_CPU
    runner.threads = 1
    runner.status = 0
    runner.summary = _summary(3, 1200, 1150, 1300)
    record.measurements.append(runner)
    var excluded = PromptMeasurement()
    excluded.label = String("gpu")
    excluded.device = DEVICE_GPU
    excluded.status = 1
    excluded.reason = String("gpu absent on the fixture machine")
    record.measurements.append(excluded)
    var parked = PromptMeasurement()
    parked.label = String("npu")
    parked.device = 2
    parked.status = 2
    parked.reason = String("npu parked by campaign law")
    record.measurements.append(parked)
    var stopped = PromptMeasurement()
    stopped.label = String("cpu threads=4")
    stopped.device = DEVICE_CPU
    stopped.threads = 4
    stopped.status = 3
    stopped.reason = String("sweep bound reached")
    stopped.summary = _summary(1, 5000, 5000, 5000)
    record.measurements.append(stopped)
    record.device_sweep_note = String("fixture sweep note")
    return record^


def _reply_record() -> ReplyChoiceRecord:
    var record = ReplyChoiceRecord()
    record.option_text = String("auto")
    record.decision_code = 1
    record.decision_text = String("fixture reply decision")
    record.has_choice = True
    record.chosen_label = String("cpu threads=1")
    record.chosen_device = DEVICE_CPU
    record.chosen_threads = 1
    record.best_label = String("cpu threads=1")
    record.best_median_ns = 2000
    record.runner_median_ns = -1
    var only = ReplyMeasurement()
    only.label = String("cpu threads=1")
    only.device = DEVICE_CPU
    only.threads = 1
    only.status = 0
    only.summary = _summary(3, 2000, 1900, 2100)
    record.measurements.append(only)
    return record^


def _draft_record() -> DraftChoiceRecord:
    var record = DraftChoiceRecord()
    record.option_text = String("auto")
    record.decision_code = 6
    record.decision_text = String(
        "no draft-check pass exists (J-035 gap G1)"
    )
    record.has_choice = False
    var unmeasurable = DraftMeasurement()
    unmeasurable.label = String("cpu threads=1")
    unmeasurable.device = DEVICE_CPU
    unmeasurable.threads = 1
    unmeasurable.status = 2
    unmeasurable.reason = String(
        "no draft-check pass exists to time (J-035 gap G1)"
    )
    record.measurements.append(unmeasurable)
    return record^


def _scan_error(args: List[String]) -> String:
    try:
        _ = scan_explain_placement_args(args)
        return String("")
    except refusal:
        return String(refusal)


# --- groups ----------------------------------------------------------------


def test_flag_scan() raises:
    expect_true(
        is_explain_placement_flag("--explain-placement"),
        "the bare flag is the flag",
    )
    expect_false(
        is_explain_placement_flag("--explain"),
        "a prefix is not the flag",
    )
    var none = List[String]()
    none.append("--prompt-on")
    none.append("gpu")
    expect_false(
        scan_explain_placement_args(none), "absent flag scans false"
    )
    var once = List[String]()
    once.append("--explain-placement")
    expect_true(
        scan_explain_placement_args(once), "stated once scans true"
    )
    var twice = List[String]()
    twice.append("--explain-placement")
    twice.append("--explain-placement")
    expect_contains(
        _scan_error(twice), "state it once", "duplicate flag refused"
    )
    var valued = List[String]()
    valued.append("--explain-placement=full")
    expect_contains(
        _scan_error(valued), "takes no value", "valued flag refused"
    )
    print("PASS: explain -- flag scan (once / absent / duplicate / value)")


def test_candidate_conversion() raises:
    var record = _prompt_record()
    var winner = explain_candidate_from_prompt(record.measurements[0])
    expect_eq(winner.status, EX_MEASURED, "winner status measured")
    expect_true(winner.has_numbers, "winner carries numbers")
    expect_eq(winner.median_ns, 1000, "winner median carried")
    expect_eq(winner.min_ns, 900, "winner min carried")
    expect_eq(winner.max_ns, 1100, "winner max carried")
    expect_eq(winner.rounds, 3, "winner rounds carried")
    expect_contains(
        winner.render(), "median 1000 ns", "winner line is the chooser's"
    )
    var excluded = explain_candidate_from_prompt(record.measurements[2])
    expect_false(excluded.has_numbers, "excluded carries no numbers")
    expect_contains(
        excluded.render(),
        "EXCLUDED -- gpu absent on the fixture machine",
        "excluded reason verbatim",
    )
    var stopped = explain_candidate_from_prompt(record.measurements[4])
    expect_contains(
        stopped.render(), "BOUND-STOPPED", "bound-stopped named"
    )
    expect_str(
        candidate_status_name(0), "MEASURED", "status name measured"
    )
    expect_str(
        candidate_status_name(2), "UNMEASURABLE", "status name unmeasurable"
    )
    expect_str(
        explain_decision_name(0), "MEASURED-WIN", "decision name win"
    )
    expect_str(
        explain_decision_name(6), "REFUSAL", "decision name refusal"
    )
    var reply_cand = explain_candidate_from_reply(
        _reply_record().measurements[0]
    )
    expect_eq(reply_cand.median_ns, 2000, "reply candidate median")
    var draft_cand = explain_candidate_from_draft(
        _draft_record().measurements[0]
    )
    expect_false(draft_cand.has_numbers, "draft candidate unmeasurable")
    expect_contains(
        draft_cand.render(), "gap G1", "draft reason carries G1"
    )
    print("PASS: explain -- candidate conversion (statuses, numbers, reasons)")


def test_never_measured_honesty() raises:
    var inputs = _inputs(_inventory(False))
    var explanation = assemble_placement_explanation(inputs^)
    var report = explanation.report()
    for kind in [PASS_PROMPT, PASS_DRAFTS, PASS_REPLY]:
        var block = explanation.for_kind(kind)
        expect_false(block.has_record, "no record supplied, none claimed")
        expect_eq(
            len(block.candidates), 0, "no candidates without a record"
        )
    expect_contains(
        report, "never measured in", "never-measured stated in report"
    )
    expect_contains(
        report,
        "candidates: none recorded (never measured)",
        "empty candidate field stated",
    )
    expect_contains(
        report,
        "learned file: NOT STATED",
        "unsupplied learned state stated as absence",
    )
    expect_contains(
        report, "not planned in this explanation", "retrial absence stated"
    )
    expect_contains(
        report, "pressure: not stated", "pressure absence stated"
    )
    expect_contains(
        report, "gpu absent", "inventory line carries the absent gpu"
    )
    expect_contains(
        report, "npu absent", "inventory line carries the parked npu"
    )
    print("PASS: explain -- never-measured + absent-piece honesty")


def test_full_records() raises:
    var inputs = _inputs(_inventory(True))
    inputs.has_prompt_record = True
    inputs.prompt_record = _prompt_record()
    inputs.has_reply_record = True
    inputs.reply_record = _reply_record()
    inputs.has_draft_record = True
    inputs.draft_record = _draft_record()
    var explanation = assemble_placement_explanation(inputs^)
    var prompt = explanation.for_kind(PASS_PROMPT)
    expect_true(prompt.has_record, "prompt record carried")
    expect_eq(len(prompt.candidates), 5, "all five candidates carried")
    expect_eq(prompt.measured_count(), 2, "two candidates measured")
    expect_true(prompt.has_choice, "prompt choice carried")
    expect_str(prompt.chosen_text, "cpu threads=2", "prompt choice label")
    expect_contains(
        prompt.best_text, "runner-up: cpu threads=1", "best/runner carried"
    )
    expect_contains(
        prompt.best_text, "margin 20%", "margin carried"
    )
    var drafts = explanation.for_kind(PASS_DRAFTS)
    expect_true(drafts.has_record, "draft record carried")
    expect_false(drafts.has_choice, "draft refusal carried as no choice")
    var report = explanation.report()
    expect_contains(
        report,
        "choice: NONE (the chooser refused",
        "draft refusal rendered as NONE",
    )
    expect_contains(
        report, "device sweep: fixture sweep note", "sweep note carried"
    )
    print("PASS: explain -- full chooser records (choice, numbers, refusal)")


def test_governing_precedence() raises:
    var inv = _inventory(True)
    var inputs = PlacementExplainInputs()
    inputs.options = _options("gpu", "", "")
    inputs.mode = _mode()
    inputs.resolution = resolve_precedence(
        inputs.options, inputs.mode, _entry(), True
    )
    inputs.inventory = inv.copy()
    var explanation = assemble_placement_explanation(inputs^)
    var prompt = explanation.for_kind(PASS_PROMPT)
    expect_contains(
        prompt.governing_text,
        "MANUAL-FIXED",
        "hand-fixed prompt governing named",
    )
    var reply = explanation.for_kind(PASS_REPLY)
    expect_contains(
        reply.governing_text, "LEARNED", "learned reply governing named"
    )
    expect_contains(
        reply.governing_text,
        "cpu threads=1",
        "learned reply fixed text carried",
    )
    var drafts = explanation.for_kind(PASS_DRAFTS)
    expect_contains(
        drafts.governing_text, "AUTO", "silent drafts fall to auto"
    )
    expect_true(
        explanation.prompt.governing_text.byte_length() > 0,
        "governing text present",
    )
    _ = GOV_MANUAL_FIXED
    _ = GOV_LEARNED
    _ = GOV_AUTO
    print("PASS: explain -- governing layers (hand / learned / auto, J-047)")


def test_learned_applied() raises:
    var load = LearnedLoad()
    load.status = LOAD_LOADED
    load.reason = String("loaded")
    load.path = String("/fixture/learned-placement.v1")
    load.entries.append(_entry())
    var lookup = lookup_learned(load, _machine(), _shape())
    expect_eq(lookup.status, LOOKUP_APPLIED, "fixture lookup applies")
    var inputs = _inputs(_inventory(True))
    inputs.learned = learned_state_from(load, lookup)
    var explanation = assemble_placement_explanation(inputs^)
    var report = explanation.report()
    expect_contains(report, "learned file: LOADED", "load state stated")
    expect_contains(report, "learned lookup: APPLIED", "lookup stated")
    expect_contains(
        report, "Fixture CPU 9000", "entry key rendered in the report"
    )
    expect_contains(
        report, "measured-at: 1760000000", "measured-at stamp rendered"
    )
    var prompt = explanation.for_kind(PASS_PROMPT)
    expect_contains(
        prompt.learned_text,
        "cpu threads=2",
        "stored prompt choice in its block",
    )
    expect_contains(
        prompt.learned_text,
        "measured-at 1760000000",
        "stamp cited per kind",
    )
    var drafts = explanation.for_kind(PASS_DRAFTS)
    expect_contains(
        drafts.learned_text,
        "absent in the applied entry",
        "absent kind stated inside an applied entry",
    )
    print("PASS: explain -- learned state applied (key, choices, stamp)")


def test_learned_missing_refused_mismatch() raises:
    var missing = LearnedLoad()
    missing.status = LOAD_MISSING
    missing.reason = String("no learned file at this path")
    missing.path = String("/fixture/none.v1")
    var no_lookup = lookup_learned(missing, _machine(), _shape())
    var inputs = _inputs(_inventory(True))
    inputs.learned = learned_state_from(missing, no_lookup)
    var explanation = assemble_placement_explanation(inputs^)
    expect_contains(
        explanation.report(),
        "learned file: MISSING",
        "missing state stated, not an error",
    )
    expect_contains(
        explanation.for_kind(PASS_PROMPT).learned_text,
        "no stored choice applies",
        "missing file means no choice applies",
    )
    var refused = LearnedLoad()
    refused.status = LOAD_REFUSED
    refused.reason = String("checksum mismatch")
    refused.path = String("/fixture/bad.v1")
    var inputs2 = _inputs(_inventory(True))
    inputs2.learned = learned_state_from(
        refused, lookup_learned(refused, _machine(), _shape())
    )
    var explanation2 = assemble_placement_explanation(inputs2^)
    expect_contains(
        explanation2.report(),
        "learned file: REFUSED",
        "refused state stated with its load name",
    )
    expect_contains(
        explanation2.report(),
        "checksum mismatch",
        "refusal reason carried",
    )
    var loaded = LearnedLoad()
    loaded.status = LOAD_LOADED
    loaded.path = String("/fixture/learned-placement.v1")
    loaded.entries.append(_entry())
    var other = model_shape("llama", 4096, 32, 32, 8, 14336, 131072, 0, 0)
    var mismatch = lookup_learned(loaded, _machine(), other)
    var inputs3 = _inputs(_inventory(True))
    inputs3.learned = learned_state_from(loaded, mismatch)
    var explanation3 = assemble_placement_explanation(inputs3^)
    expect_contains(
        explanation3.for_kind(PASS_REPLY).learned_text,
        "MODEL-MISMATCH",
        "model mismatch named per kind",
    )
    print("PASS: explain -- learned missing / refused / mismatch states")


def test_retrial_states() raises:
    var entry = _entry()
    var due = plan_retrial(
        entry, Int64(1760000000 + 2592000), 0, _machine(), _shape()
    )
    expect_eq(due.state, PLAN_DUE, "age trigger makes the plan due")
    var inputs = _inputs(_inventory(True))
    var load = LearnedLoad()
    load.status = LOAD_LOADED
    load.path = String("/fixture/learned-placement.v1")
    load.entries.append(_entry())
    inputs.learned = learned_state_from(
        load, lookup_learned(load, _machine(), _shape())
    )
    inputs.has_retrial_plan = True
    inputs.retrial_plan = due
    var explanation = assemble_placement_explanation(inputs^)
    expect_contains(
        explanation.for_kind(PASS_PROMPT).retrial_text,
        "DUE for this kind",
        "retriable prompt kind due",
    )
    expect_contains(
        explanation.for_kind(PASS_DRAFTS).retrial_text,
        "not due for this kind",
        "absent drafts kind not due",
    )
    var manual = LearnedEntry()
    manual.machine = _machine()
    manual.model = _shape()
    manual.measured_at = Int64(1760000000)
    manual.prompt = learned_pass_from_choice(
        "gpu", "gpu", DEVICE_GPU, 0, "MANUAL-FIXED", True
    )
    var manual_plan = plan_retrial(
        manual, Int64(1760000000 + 2592000 * 4), 99, _machine(), _shape()
    )
    expect_eq(
        manual_plan.state, PLAN_MANUAL_ONLY, "manual-only never due"
    )
    print("PASS: explain -- re-trial due / not-due / manual-only (J-045)")


def test_cowork_and_pressure() raises:
    var inv = _inventory(True)
    var inputs = _inputs(inv.copy())
    inputs.has_cowork = True
    inputs.cowork = plan_cowork_prompt(inputs.options, inv)
    inputs.has_pressure = True
    inputs.pressure = plan_placement_pressure(
        10000000, 1000000, 500000, 4000000, 1000000, 500000,
        8000000, 0, False, False, False,
    )
    var explanation = assemble_placement_explanation(inputs^)
    var prompt = explanation.for_kind(PASS_PROMPT)
    expect_contains(
        prompt.extra_text, "co-work:", "co-work line on the prompt kind"
    )
    expect_contains(
        prompt.extra_text, "0 survived", "no fixture pair survives"
    )
    expect_contains(
        explanation.report(),
        "pressure: decision=",
        "pressure plan rendered in context",
    )
    expect_contains(
        explanation.report(),
        "pool_bytes=10000000",
        "pressure numbers are the plan's own",
    )
    var bare = assemble_placement_explanation(_inputs(_inventory(True))^)
    expect_contains(
        bare.for_kind(PASS_PROMPT).extra_text,
        "co-work: not stated",
        "absent co-work stated",
    )
    print("PASS: explain -- co-work + pressure lines (supplied / absent)")


def test_tolerance_summary() raises:
    var proof = ToleranceProof()
    var g1 = RepetitionGrade()
    g1.shape_name = String("fixture")
    g1.kind = PASS_PROMPT
    g1.verdict = 0
    proof.grades.append(g1^)
    var g2 = RepetitionGrade()
    g2.shape_name = String("fixture")
    g2.kind = PASS_PROMPT
    g2.verdict = 1
    proof.grades.append(g2^)
    var g3 = RepetitionGrade()
    g3.shape_name = String("fixture")
    g3.kind = PASS_REPLY
    g3.verdict = 2
    proof.grades.append(g3^)
    proof.shape_names.append(String("fixture"))
    var inputs = _inputs(_inventory(True))
    inputs.has_tolerance = True
    inputs.tolerance = proof^
    var explanation = assemble_placement_explanation(inputs^)
    expect_contains(
        explanation.for_kind(PASS_PROMPT).extra_text,
        "BEATEN 1, MET 1, MISSED 0, NOT PROVEN 0",
        "prompt grade counts exact",
    )
    expect_contains(
        explanation.for_kind(PASS_REPLY).extra_text,
        "MISSED 1",
        "reply miss counted",
    )
    expect_contains(
        explanation.for_kind(PASS_DRAFTS).extra_text,
        "draft-check NOT PROVEN",
        "drafts tolerance honesty (G1)",
    )
    print("PASS: explain -- tolerance summary counts (J-046)")


def test_server_governing() raises:
    var inv = _inventory(True)
    var options = _options("gpu", "", "")
    var defaults = resolve_server_defaults(
        options, _mode(), LearnedEntry(), False, inv
    )
    var placement = resolve_server_request_placement(
        defaults, ServerPlacementRequest(), inv
    )
    var inputs = _inputs(inv.copy())
    inputs.has_server = True
    inputs.server = placement^
    var explanation = assemble_placement_explanation(inputs^)
    expect_contains(
        explanation.for_kind(PASS_PROMPT).governing_text,
        "server session layer, J-049",
        "server provenance on the governing line",
    )
    expect_contains(
        explanation.report(),
        "server: per-request outcomes supplied (J-049)",
        "server context line stated",
    )
    print("PASS: explain -- server governing provenance (J-049)")


def test_report_shape() raises:
    var inputs = _inputs(_inventory(False))
    inputs.has_prompt_record = True
    inputs.prompt_record = _prompt_record()
    var report = assemble_placement_explanation(inputs^).report()
    expect_contains(
        report, "placement explanation (J-050)", "report header"
    )
    var prompt_at = report.find("== prompt ==")
    expect_true(prompt_at >= 0, "prompt block present")
    expect_true(
        report.find("== drafts ==") > prompt_at,
        "drafts block after prompt",
    )
    expect_true(
        report.find("== reply ==") > report.find("== drafts =="),
        "reply block after drafts",
    )
    expect_contains(
        report, "honesty:", "closing honesty lines present"
    )
    expect_contains(
        report,
        "not model pass timings",
        "numbers' class stated honestly",
    )
    print("PASS: explain -- report shape (order, header, honesty)")


def test_live_inventory() raises:
    var inv = observe_device_inventory()
    var inputs = _inputs(inv.copy())
    var path = learned_file_path()
    var load = load_learned_file(path)
    var lookup = lookup_learned(load, _machine(), _shape())
    inputs.learned = learned_state_from(load, lookup)
    var explanation = assemble_placement_explanation(inputs^)
    var report = explanation.report()
    print("LIVE DEVICE LINE: " + inv.device_line())
    expect_contains(report, "cpu present", "live cpu in the report")
    expect_contains(
        report, "learned file:", "live learned state stated"
    )
    print("PASS: explain -- live inventory + learned load on this VM")


def main() raises:
    test_flag_scan()
    test_candidate_conversion()
    test_never_measured_honesty()
    test_full_records()
    test_governing_precedence()
    test_learned_applied()
    test_learned_missing_refused_mismatch()
    test_retrial_states()
    test_cowork_and_pressure()
    test_tolerance_summary()
    test_server_governing()
    test_report_shape()
    test_live_inventory()
    print("ALL PASS: placement explainability (13 groups)")
