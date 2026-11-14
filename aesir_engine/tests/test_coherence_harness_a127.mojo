# tests/test_coherence_harness_a127.mojo
# A-127: Coherence grading harness -- the IQ matrix
# score rows filed (NOT_GRADED, named reasons, no
# filed sampled generations) and the pure text
# scorer sanity-checked on the SYNTHETIC fixture,
# and these cases cover: the axes and their product
# (9 IQ quants called from A-114, filtered by its
# predicate), duplicate-free enumeration, the A-115
# obligation read by call (every row COHERENCE_ONLY,
# the policy table's coherence count), exact metric
# witnesses on controlled samples, the unique-ratio
# and run-length arithmetic, both known-good samples
# passing, the known-broken samples failing with
# their named defects (repetition, garbage,
# off-topic, degenerate short / punctuation /
# sentence-less, prompt echo, empty refused), the
# NOT_GRADED reason split, degenerate axes and
# non-IQ quants refused, the summary sums, and a
# deterministic digest across re-runs.

from core.coherence_harness_a127 import (
    CH_FIXTURE_STATUS,
    HarnessReport,
    HarnessRow,
    coherence_verdict_name,
    harness_archs,
    harness_backends,
    harness_line,
    harness_render,
    harness_row_line,
    iq_quants,
    run_harness,
    sample_metrics,
    score_sample,
    syn_cases,
    build_harness,
)
from core.exactness_policy import (
    POL_COHERENCE_FAIL,
    POL_COHERENCE_PASS,
    POLICY_COHERENCE_ONLY,
    policy_counts,
    policy_for_quant,
)
from core.matrix_runner import MX_NOT_GRADED


def _row(
    read report: HarnessReport, quant: String, arch: String, backend: String
) raises -> HarnessRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.quant == quant and r.arch == arch:
            if r.backend == backend:
                return r
    raise Error("coherence harness row not found")


def _topics2(a: String, b: String) -> List[String]:
    var t = List[String]()
    t.append(a)
    t.append(b)
    return t^


def _good1() -> String:
    return String(
        "Hospitality is the friendly and generous "
        "reception of guests who arrive at a house or "
        "an inn. A good host offers food, drink, and a "
        "warm place beside the fire. Guests remember "
        "that welcome long after the road has taken "
        "them home again."
    )


def _raises_score(text: String) -> Bool:
    try:
        _ = score_sample(text, List[String](), String(""))
    except:
        return True
    return False


def _raises_build(
    quants: List[String], archs: List[String], backends: List[String]
) -> Bool:
    try:
        _ = build_harness(quants, archs, backends)
    except:
        return True
    return False


def test_coherence_axes_product() raises:
    var quants = iq_quants()
    var archs = harness_archs()
    var backends = harness_backends()
    if len(quants) != 9 or len(archs) != 3 or len(backends) != 4:
        raise Error("coherence axes must be 9 IQ x 3 archs x 4 backends")
    if quants[0] != String("IQ1_S") or quants[8] != String("IQ4_XS"):
        raise Error("IQ axis must run IQ1_S .. IQ4_XS in A-114 order")
    if archs[0] != String("llama") or archs[1] != String("gemma4"):
        raise Error("arch axis must be A-114 order")
    if archs[2] != String("mistral3"):
        raise Error("arch axis must be A-114 order")
    if backends[0] != String("cpu") or backends[1] != String("vulkan"):
        raise Error("backends must be A-109 harness order")
    if backends[2] != String("hip") or backends[3] != String("npu"):
        raise Error("backends must be A-109 harness order")
    var report = run_harness()
    if report.total != 108 or len(report.rows) != 108:
        raise Error("harness must file exactly 108 IQ score rows")


def test_coherence_enumeration_unique() raises:
    var report = run_harness()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            var a = report.rows[i]
            var b = report.rows[j]
            if a.quant == b.quant and a.arch == b.arch:
                if a.backend == b.backend:
                    raise Error("duplicate coherence harness row")
    var first = report.rows[0]
    if first.quant != String("IQ1_S") or first.arch != String("llama"):
        raise Error("enumeration must start at IQ1_S / llama")
    if first.backend != String("cpu"):
        raise Error("enumeration must start on cpu")
    if String("A-127 Coherence grading harness") not in harness_line():
        raise Error("harness line must name the slice")
    if String("SYNTHETIC") not in harness_line():
        raise Error("harness line must label the synthetic fixture")


def test_coherence_policy_coherence_only() raises:
    var counts = policy_counts()
    if counts[0] != 19 or counts[2] != 9:
        raise Error("A-115 table must file 19 rows, 9 coherence-only")
    var report = run_harness()
    for i in range(len(report.rows)):
        var row = policy_for_quant(report.rows[i].quant)
        if row.obligation != POLICY_COHERENCE_ONLY:
            raise Error("every IQ row must be COHERENCE_ONLY per A-115")
        if report.rows[i].obligation != POLICY_COHERENCE_ONLY:
            raise Error("harness row obligation must match the policy")
    if report.coherence != 108 or report.owed != 0:
        raise Error("policy split must be coherence 108 / owed 0")


def test_coherence_metrics_exact_counts() raises:
    var m = sample_metrics(
        String("Cats sleep well. Dogs run fast. Birds sing sweetly."),
        List[String](),
    )
    if m.words != 9 or m.sentences != 3:
        raise Error("controlled sample must file 9 words / 3 sentences")
    if m.unique_x1000 != 1000 or m.max_run != 1 or m.garbage != 0:
        raise Error("controlled sample witnesses must be exact")
    if m.alpha_x1000 != 784:
        raise Error("alpha_x1000 must be 40 letters of 51 bytes = 784")
    if m.score_x1000 != 892:
        raise Error("score_x1000 must be (1000 + 784) // 2 = 892")
    if m.topic_hit:
        raise Error("no topics stated, so no topic hit may file")


def test_coherence_unique_and_run() raises:
    var m = sample_metrics(
        String("the the the cat sat. the cat sat. the cat ran."),
        List[String](),
    )
    if m.words != 11 or m.max_run != 3:
        raise Error("run sample must file 11 words / max run 3")
    if m.unique_x1000 != 363:
        raise Error("unique must be 4 distinct of 11 words = 363")


def test_coherence_sanity_good_passes() raises:
    var cases = syn_cases()
    var good = 0
    for i in range(len(cases)):
        if cases[i].name == String("SYN_GOOD_HOSPITALITY"):
            good += 1
            if cases[i].verdict != POL_COHERENCE_PASS:
                raise Error("known-good hospitality sample must pass")
            if cases[i].reason != String("COHERENCE_CHECKS_PASS"):
                raise Error("good sample reason must be checks-pass")
        if cases[i].name == String("SYN_GOOD_HARBOUR"):
            good += 1
            if cases[i].verdict != POL_COHERENCE_PASS:
                raise Error("known-good harbour sample must pass")
    if good != 2:
        raise Error("fixture must carry exactly 2 known-good samples")
    var direct = score_sample(
        _good1(), _topics2(String("hospitality"), String("guests")),
        String(""),
    )
    if direct.verdict != POL_COHERENCE_PASS:
        raise Error("direct scoring of the good sample must pass")
    if direct.metrics.words != 43 or direct.metrics.sentences != 3:
        raise Error("good sample must file 43 words / 3 sentences")


def test_coherence_sanity_repetition_fails() raises:
    var cases = syn_cases()
    for i in range(len(cases)):
        if cases[i].name == String("SYN_LOOP"):
            if cases[i].verdict != POL_COHERENCE_FAIL:
                raise Error("repetition loop must fail coherence")
            if cases[i].reason != String("REPETITION_LOW_DIVERSITY"):
                raise Error("loop defect must be named low-diversity")
            return
    raise Error("fixture must carry the repetition case")


def test_coherence_sanity_garbage_fails() raises:
    var cases = syn_cases()
    for i in range(len(cases)):
        if cases[i].name == String("SYN_GARBAGE"):
            if cases[i].verdict != POL_COHERENCE_FAIL:
                raise Error("garbage sample must fail coherence")
            if cases[i].reason != String("GARBAGE_CHARS"):
                raise Error("garbage defect must be named")
            return
    raise Error("fixture must carry the garbage case")


def test_coherence_sanity_offtopic_fails() raises:
    var cases = syn_cases()
    for i in range(len(cases)):
        if cases[i].name == String("SYN_OFFTOPIC"):
            if cases[i].verdict != POL_COHERENCE_FAIL:
                raise Error("off-topic sample must fail coherence")
            if cases[i].reason != String("OFF_TOPIC"):
                raise Error("off-topic defect must be named")
            return
    raise Error("fixture must carry the off-topic case")


def test_coherence_sanity_degenerate_fails() raises:
    var cases = syn_cases()
    var seen = 0
    for i in range(len(cases)):
        if cases[i].name == String("SYN_SHORT"):
            seen += 1
            if cases[i].reason != String("TOO_SHORT"):
                raise Error("short sample defect must be named")
        if cases[i].name == String("SYN_PUNCT"):
            seen += 1
            if cases[i].reason != String("NON_ALPHA_CONTENT"):
                raise Error("punctuation defect must be named")
    if seen != 2:
        raise Error("fixture must carry short + punctuation cases")
    var flat = score_sample(
        String(
            "the old keeper walked down the long road "
            "toward the sea and thought about the years "
            "he had spent mending nets and watching "
            "storms roll over the harbour while the "
            "town slept behind him"
        ),
        List[String](),
        String(""),
    )
    if flat.verdict != POL_COHERENCE_FAIL:
        raise Error("sentence-less sample must fail coherence")
    if flat.reason != String("TOO_FEW_SENTENCES"):
        raise Error("sentence-less defect must be named")


def test_coherence_sanity_echo_and_empty() raises:
    var cases = syn_cases()
    var seen = 0
    for i in range(len(cases)):
        if cases[i].name == String("SYN_ECHO"):
            seen += 1
            if cases[i].reason != String("PROMPT_ECHO"):
                raise Error("echo defect must be named")
        if cases[i].name == String("SYN_EMPTY"):
            seen += 1
            if cases[i].verdict != POL_COHERENCE_FAIL:
                raise Error("empty refusal must file as a fail case")
            if cases[i].reason != String("EMPTY_SAMPLE_REFUSED"):
                raise Error("empty defect must be named as refusal")
    if seen != 2:
        raise Error("fixture must carry echo + empty cases")
    if not _raises_score(String("")):
        raise Error("the scorer must refuse an empty sample")
    if not _raises_score(String("   ")):
        raise Error("the scorer must refuse a whitespace sample")


def test_coherence_not_graded_reasons() raises:
    var report = run_harness()
    if report.not_graded != 108 or report.passed != 0:
        raise Error("every IQ cell must file NOT_GRADED today")
    if report.failed != 0:
        raise Error("no IQ cell may fail on no evidence")
    if report.backend_not_graded != 81:
        raise Error("81 non-cpu cells must file the backend reason")
    if report.arch_not_graded != 18:
        raise Error("18 cpu non-llama cells must file the arch reason")
    if report.no_generations != 9:
        raise Error("9 cpu llama cells must file no-generations")
    var cpu_llama = _row(
        report, String("IQ2_XS"), String("llama"), String("cpu")
    )
    if cpu_llama.verdict != MX_NOT_GRADED:
        raise Error("cpu llama IQ cell must be NOT_GRADED")
    if cpu_llama.reason != String("NO_FILED_GENERATIONS"):
        raise Error("cpu llama IQ cell reason must be named")
    if cpu_llama.score_x1000 != -1:
        raise Error("ungraded cells file score -1, never a fake 0")
    var gpu = _row(
        report, String("IQ2_XS"), String("llama"), String("hip")
    )
    if gpu.reason != String("BACKEND_NO_CPU_COMPARATOR"):
        raise Error("non-cpu IQ cell reason must be named")
    var gemma = _row(
        report, String("IQ2_XS"), String("gemma4"), String("cpu")
    )
    if gemma.reason != String("NO_FILED_RECORDS"):
        raise Error("cpu non-llama IQ cell reason must be named")
    if String("NOT_GRADED") not in harness_row_line(cpu_llama):
        raise Error("row line must file the NOT_GRADED verdict")


def test_coherence_summary_sums() raises:
    var report = run_harness()
    if report.passed + report.failed + report.not_graded != report.total:
        raise Error("verdict counts must sum to the total")
    var reasons = (
        report.backend_not_graded + report.arch_not_graded
        + report.no_generations
    )
    if reasons != report.not_graded:
        raise Error("reason counts must sum to the not-graded count")
    if report.syn_total != 9 or report.syn_pass != 2:
        raise Error("synthetic fixture must file 9 cases, 2 passing")
    if report.syn_fail != 7:
        raise Error("synthetic fixture must file 7 failing cases")
    if report.syn_pass + report.syn_fail != report.syn_total:
        raise Error("synthetic counts must sum to their total")


def test_coherence_invalid_axes_refused() raises:
    if not _raises_build(List[String](), harness_archs(), harness_backends()):
        raise Error("an empty quant axis must be refused")
    var bad = List[String]()
    bad.append(String("Q4_K_M"))
    if not _raises_build(bad, harness_archs(), harness_backends()):
        raise Error("a non-IQ quant on the coherence axis is refused")
    var dup = List[String]()
    dup.append(String("IQ1_S"))
    dup.append(String("IQ1_S"))
    if not _raises_build(dup, harness_archs(), harness_backends()):
        raise Error("a duplicate quant entry must be refused")
    if not _raises_build(iq_quants(), List[String](), harness_backends()):
        raise Error("an empty arch axis must be refused")
    if not _raises_build(iq_quants(), harness_archs(), List[String]()):
        raise Error("an empty backend axis must be refused")


def test_coherence_digest_deterministic() raises:
    var a = run_harness()
    var b = run_harness()
    if a.digest != b.digest:
        raise Error("digest must reproduce across re-runs")
    if a.digest == 0:
        raise Error("digest must be filed")
    if harness_render(a.copy()) != harness_render(b.copy()):
        raise Error("render must reproduce across re-runs")
    if String(CH_FIXTURE_STATUS) != String("SYNTHETIC"):
        raise Error("fixture status must be SYNTHETIC")
    if coherence_verdict_name(POL_COHERENCE_PASS) != String("COHERENCE_PASS"):
        raise Error("verdict names must be A-115's coherence names")
