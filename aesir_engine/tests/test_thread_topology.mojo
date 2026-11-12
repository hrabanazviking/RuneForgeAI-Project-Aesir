"""Thread topology trials (J-039): the ladder derived from
inventory CPU facts (serial / half / all-physical / all-logical,
performance-only only when the machine states a hybrid split,
NOT APPLICABLE-WITH-REASON otherwise), de-duplication and
ordering, the pre-registered i9-lesson verdict rule on injected
medians, threaded-workload checksum identity against the J-038
serial workload at every thread count (with the par_for chunk
count as the proof the rung's threads ran), the AESIR_THREADS
knob readback, and live bounded trials of J-038's pass-shaped
workloads on this machine (prompt + reply measured per rung;
draft-check unmeasurable-with-reason, gap G1).

The live groups measure HARNESS MECHANICS only: the workloads
are the harness's own matvec/GEMM micro-workloads, not model
passes, and no number here is a placement verdict for any model
(J-040--J-042 own choices, on real passes).
"""
from core.device_inventory import (
    CpuFacts,
    apply_hybrid_split,
    parse_cpuinfo,
)
from core.parallel import par_cpu_count, par_default_threads, par_thread_count
from core.placement_harness import (
    HarnessConfig,
    prompt_workload,
    reply_workload,
    run_workload_once,
    prepare_workload,
)
from core.placement_options import PASS_DRAFTS, PASS_PROMPT, PASS_REPLY
from core.thread_topology import (
    THREAD_ALL_LOGICAL,
    THREAD_ALL_PHYSICAL,
    THREAD_PERF_ONLY,
    TRES_BOUND_STOPPED,
    TRES_MEASURED,
    TRES_UNMEASURABLE,
    VERDICT_ALL_FASTEST,
    VERDICT_LESSON_CONFIRMED,
    VERDICT_NOT_GRADED,
    VERDICT_WITHIN_NOISE,
    clear_thread_knobs,
    derive_thread_ladder,
    grade_thread_results,
    observe_cpu_facts,
    run_thread_trials,
    run_workload_threaded,
    set_thread_knobs,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "ThreadTopology "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("ThreadTopology " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "ThreadTopology "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


def _cpuinfo(num: Int, cores: Int) -> String:
    """A cpuinfo with `num` processors over `cores` distinct
    (physical id, core id) pairs (cores == num: no SMT; cores <
    num: SMT siblings share a core id)."""
    var text = String("")
    for i in range(num):
        text += "processor\t: " + String(i) + "\n"
        text += "model name\t: Fixture CPU\n"
        text += "physical id\t: 0\n"
        text += "core id\t\t: " + String(i % cores) + "\n\n"
    return text


def test_ladder_vm_facts() raises:
    var ladder = derive_thread_ladder(parse_cpuinfo(_cpuinfo(4, 4)))
    expect_eq(len(ladder.candidates), 3, "VM ladder rung count")
    expect_eq(ladder.candidates[0].threads, 1, "serial rung")
    expect_eq(ladder.candidates[1].threads, 2, "half rung")
    expect_eq(ladder.candidates[2].threads, 4, "all-cores rung")
    expect_eq(
        ladder.candidates[2].kind,
        THREAD_ALL_PHYSICAL,
        "all-cores rung kind",
    )
    expect_contains(
        ladder.pe_status,
        "NOT APPLICABLE-WITH-REASON",
        "no split is stated, so no P/E rung exists",
    )
    print("PASS: ladder from VM-shaped facts [1, 2, 4], P/E not applicable-with-reason")


def test_ladder_hybrid_split() raises:
    var facts = parse_cpuinfo(_cpuinfo(12, 12))
    apply_hybrid_split(facts, "0-7", "8-11")
    var ladder = derive_thread_ladder(facts)
    expect_eq(len(ladder.candidates), 4, "hybrid ladder rung count")
    expect_eq(ladder.candidates[0].threads, 1, "serial rung")
    expect_eq(ladder.candidates[1].threads, 6, "half rung")
    expect_eq(ladder.candidates[2].threads, 8, "performance-only rung")
    expect_eq(
        ladder.candidates[2].kind, THREAD_PERF_ONLY, "performance rung kind"
    )
    expect_eq(ladder.candidates[3].threads, 12, "all/hybrid rung")
    expect_contains(
        ladder.pe_status,
        "8 performance / 4 efficiency",
        "the stated split rides on the ladder record",
    )
    print("PASS: ladder on a machine-stated hybrid split [1, 6, 8 perf-only, 12]")


def test_ladder_smt() raises:
    var ladder = derive_thread_ladder(parse_cpuinfo(_cpuinfo(16, 8)))
    expect_eq(len(ladder.candidates), 4, "SMT ladder rung count")
    expect_eq(ladder.candidates[1].threads, 4, "half of physical")
    expect_eq(ladder.candidates[2].threads, 8, "all physical rung")
    expect_eq(
        ladder.candidates[2].kind, THREAD_ALL_PHYSICAL, "physical rung kind"
    )
    expect_eq(ladder.candidates[3].threads, 16, "all logical rung")
    expect_eq(
        ladder.candidates[3].kind, THREAD_ALL_LOGICAL, "logical rung kind"
    )
    print("PASS: ladder on an SMT machine [1, 4, 8 physical, 16 logical]")


def test_ladder_dedup_small() raises:
    var two = derive_thread_ladder(parse_cpuinfo(_cpuinfo(2, 2)))
    expect_eq(len(two.candidates), 2, "2-core ladder de-duplicates half==serial")
    expect_eq(two.candidates[0].threads, 1, "2-core serial rung")
    expect_eq(two.candidates[1].threads, 2, "2-core all rung")
    var one = derive_thread_ladder(parse_cpuinfo(_cpuinfo(1, 1)))
    expect_eq(len(one.candidates), 1, "1-core ladder is the serial rung alone")
    print("PASS: ladder de-duplication on small machines ([1, 2] and [1])")


def test_ladder_topology_poor() raises:
    var facts = parse_cpuinfo(
        "processor\t: 0\nHardware\t: Fixture\n\nprocessor\t: 1\n"
        "processor\t: 2\nprocessor\t: 3\n"
    )
    expect_eq(facts.physical_cores, -1, "physical count unstated")
    var ladder = derive_thread_ladder(facts)
    expect_eq(len(ladder.candidates), 3, "topology-poor ladder rung count")
    expect_eq(ladder.candidates[2].threads, 4, "all rung stands on logical")
    expect_contains(
        ladder.basis_note,
        "states no physical core count",
        "the basis is stated, not hidden",
    )
    var refused = False
    try:
        _ = derive_thread_ladder(CpuFacts())
    except:
        refused = True
    expect_true(refused, "facts with no processors are refused")
    print("PASS: ladder on topology-poor facts stands on the logical count, stated")


def test_verdict_rule() raises:
    expect_eq(
        grade_thread_results(4, 100, 4, 100),
        VERDICT_ALL_FASTEST,
        "the widest rung holding the best median is all-fastest",
    )
    expect_eq(
        grade_thread_results(2, 100, 4, 120),
        VERDICT_LESSON_CONFIRMED,
        "a narrower rung winning by 20% confirms the lesson",
    )
    expect_eq(
        grade_thread_results(2, 100, 4, 105),
        VERDICT_WITHIN_NOISE,
        "exactly at the 5% band edge is noise (the rule is beyond)",
    )
    expect_eq(
        grade_thread_results(2, 100, 4, 106),
        VERDICT_LESSON_CONFIRMED,
        "just beyond the band confirms",
    )
    expect_eq(
        grade_thread_results(1, 90, 4, 130),
        VERDICT_LESSON_CONFIRMED,
        "serial beating all-cores by 44% confirms",
    )
    print("PASS: verdict rule on injected medians (all-fastest / band / confirmed)")


def test_threaded_checksum_identity() raises:
    for spec in [reply_workload(), prompt_workload()]:
        var data = prepare_workload(spec)
        var reference = run_workload_once(data, spec)
        for threads in [1, 2, 4]:
            set_thread_knobs(threads)
            var round = run_workload_threaded(data, spec, threads)
            clear_thread_knobs()
            expect_true(
                round[0] == reference,
                "threaded checksum equals the serial checksum",
            )
            expect_eq(
                round[1], threads, "par_for used the rung's chunk count"
            )
    print("PASS: threaded checksum identical to serial at 1/2/4 threads; chunks == threads")


def test_thread_knobs() raises:
    set_thread_knobs(2)
    expect_eq(par_thread_count(), 2, "AESIR_THREADS=2 reads back as 2")
    set_thread_knobs(3)
    expect_eq(par_thread_count(), 3, "AESIR_THREADS=3 reads back as 3")
    clear_thread_knobs()
    expect_eq(
        par_thread_count(),
        par_default_threads(par_cpu_count()),
        "cleared knobs restore the default policy (A-041 choke-guard "
        "default since A-041; was the raw online-CPU count before)",
    )
    print("PASS: thread knobs set/read back/clear through Aesir's own thread layer")


def test_live_trials() raises:
    var facts = observe_cpu_facts()
    expect_eq(facts.logical, 4, "this VM states 4 logical processors")
    expect_eq(facts.physical_cores, 4, "this VM states 4 physical cores")
    expect_true(
        not facts.has_hybrid_split(), "this VM states no hybrid split"
    )
    var config = HarnessConfig()
    var reply_sweep = run_thread_trials(
        facts, PASS_REPLY, reply_workload(), config
    )
    print("LIVE REPLY THREAD TRIAL:\n" + reply_sweep.report())
    expect_eq(len(reply_sweep.results), 3, "reply ladder rung count")
    expect_eq(reply_sweep.measured_count(), 3, "every reply rung measured")
    for result in reply_sweep.results:
        expect_eq(result.summary.count, 5, "reply: 5 rounds counted")
        expect_eq(result.settle_run, 1, "reply: settle ran and was discarded")
        expect_eq(
            result.chunks, result.threads, "reply: chunks == rung threads"
        )
        expect_true(result.summary.median_ns > 0, "reply median is real")
    var prompt_sweep = run_thread_trials(
        facts, PASS_PROMPT, prompt_workload(), config
    )
    print("LIVE PROMPT THREAD TRIAL:\n" + prompt_sweep.report())
    expect_eq(prompt_sweep.measured_count(), 3, "every prompt rung measured")
    for result in prompt_sweep.results:
        expect_eq(result.summary.count, 5, "prompt: 5 rounds counted")
        expect_eq(
            result.chunks, result.threads, "prompt: chunks == rung threads"
        )
    print("PASS: live thread trials on this machine (prompt + reply, all rungs measured)")


def test_draft_check_and_bound() raises:
    var facts = observe_cpu_facts()
    var draft_sweep = run_thread_trials(
        facts, PASS_DRAFTS, reply_workload(), HarnessConfig()
    )
    print("LIVE DRAFT-CHECK THREAD TRIAL:\n" + draft_sweep.report())
    expect_eq(draft_sweep.measured_count(), 0, "no draft-check timing exists")
    expect_eq(
        draft_sweep.results[0].status,
        TRES_UNMEASURABLE,
        "draft-check rungs record unmeasurable-with-reason",
    )
    expect_contains(
        draft_sweep.results[0].reason, "G1", "the reason names gap G1"
    )
    expect_eq(
        draft_sweep.verdict_code,
        VERDICT_NOT_GRADED,
        "an unmeasurable kind is not graded",
    )
    var tight = HarnessConfig(
        settle_rounds=1,
        measured_rounds=5,
        per_candidate_budget_ns=1,
        per_sweep_budget_ns=10000000000,
    )
    var bound_sweep = run_thread_trials(
        facts, PASS_REPLY, reply_workload(), tight
    )
    print("LIVE BOUND THREAD TRIAL:\n" + bound_sweep.report())
    expect_eq(
        bound_sweep.results[0].status,
        TRES_BOUND_STOPPED,
        "a 1 ns budget bound-stops the first rung",
    )
    expect_eq(
        bound_sweep.results[0].summary.count,
        0,
        "no measured round is counted past the bound",
    )
    expect_eq(
        bound_sweep.results[0].settle_run, 1, "the settle round still ran"
    )
    expect_eq(
        bound_sweep.verdict_code,
        VERDICT_NOT_GRADED,
        "a sweep with no measured rung is not graded",
    )
    print("PASS: draft-check unmeasurable-with-reason (G1); live bound enforced")


def main() raises:
    test_ladder_vm_facts()
    test_ladder_hybrid_split()
    test_ladder_smt()
    test_ladder_dedup_small()
    test_ladder_topology_poor()
    test_verdict_rule()
    test_threaded_checksum_identity()
    test_thread_knobs()
    test_live_trials()
    test_draft_check_and_bound()
    print("ALL PASS: thread topology trials (10 groups)")
