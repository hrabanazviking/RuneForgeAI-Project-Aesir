# tests/test_comparator_checklist_a112.mojo
# A-112: Comparator-artifact checklist, automated -- the
# roadmap acceptance is that seeded fake divergences of
# each class are caught by the checklist and verdicted
# as comparator artifacts: one seeded case per class
# (template rendering, BOS rendering, backend mismatch,
# step-0 boundary), plus the controls that keep the
# checklist honest -- a clean genuine divergence past
# step 0 still files, a step-0 divergence joined by a
# later one is genuine, precedence records every hit,
# and inconsistent records are refused, not verdicted.

from core.comparator_checklist import (
    ARTIFACT_BACKEND_MISMATCH,
    ARTIFACT_BOS,
    ARTIFACT_NONE,
    ARTIFACT_STEP0_BOUNDARY,
    ARTIFACT_TEMPLATE,
    CHECK_CLEAN,
    CHECK_COMPARATOR_ARTIFACT,
    CHECKLIST_CHECKS_RUN,
    CHECKLIST_CPU_BACKEND,
    artifact_blocks_filing,
    artifact_kind_name,
    checklist_line,
    checklist_verdict_name,
    may_file_divergence,
    run_comparator_checklist,
)


def _clean(prompt: String) raises -> Int:
    """Verdict code for a clean-shaped account with the
    given prompt and exact records (helper for brevity)."""
    var s = run_comparator_checklist(
        prompt,
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([0, 0]),
        List[Int]([0, 0]),
    )
    return s.verdict


def _raises_account(ranks: List[Int], gaps: List[Int]) -> Bool:
    try:
        _ = run_comparator_checklist(
            String("The sea is wide."),
            True,
            True,
            String("cpu"),
            String("cpu"),
            ranks,
            gaps,
        )
    except:
        return True
    return False


def test_comparator_constants_and_names() raises:
    if CHECKLIST_CHECKS_RUN != 4:
        raise Error("checklist must run exactly four checks")
    if CHECKLIST_CPU_BACKEND != String("cpu"):
        raise Error("the only grading backend pair is CPU vs CPU")
    if artifact_kind_name(ARTIFACT_NONE) != String("NONE"):
        raise Error("kind name drifted: NONE")
    if artifact_kind_name(ARTIFACT_TEMPLATE) != String("TEMPLATE_RENDERING"):
        raise Error("kind name drifted: TEMPLATE_RENDERING")
    if artifact_kind_name(ARTIFACT_BOS) != String("BOS_RENDERING"):
        raise Error("kind name drifted: BOS_RENDERING")
    if artifact_kind_name(ARTIFACT_BACKEND_MISMATCH) != String(
        "BACKEND_MISMATCH"
    ):
        raise Error("kind name drifted: BACKEND_MISMATCH")
    if artifact_kind_name(ARTIFACT_STEP0_BOUNDARY) != String("STEP0_BOUNDARY"):
        raise Error("kind name drifted: STEP0_BOUNDARY")
    if checklist_verdict_name(CHECK_CLEAN) != String("CLEAN"):
        raise Error("verdict name drifted: CLEAN")
    if checklist_verdict_name(CHECK_COMPARATOR_ARTIFACT) != String(
        "COMPARATOR_ARTIFACT"
    ):
        raise Error("verdict name drifted: COMPARATOR_ARTIFACT")


def test_comparator_clean_exact() raises:
    var s = run_comparator_checklist(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([0, 0, 0]),
        List[Int]([0, 0, 0]),
    )
    if s.verdict != CHECK_CLEAN or s.kind != ARTIFACT_NONE:
        raise Error("exact clean account did not file CLEAN/NONE")
    if s.template_hit or s.bos_hit or s.backend_hit or s.step0_hit:
        raise Error("exact clean account recorded a check hit")
    if s.checks_run != 4 or s.steps != 3:
        raise Error("clean account counts drifted")
    if s.divergent_count != 0 or s.first_divergent_step != -1:
        raise Error("exact account shows a divergence")
    if may_file_divergence(s):
        raise Error("exact account may file a divergence")
    if artifact_blocks_filing(s):
        raise Error("clean account blocks filing")
    if _clean(String("plain raw prompt, no marks")) != CHECK_CLEAN:
        raise Error("plain prompt helper account not clean")


def test_comparator_clean_genuine_divergence() raises:
    # The control the checklist exists to protect: a real
    # divergence past step 0 in a clean comparison files.
    var s = run_comparator_checklist(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([0, 5, 1]),
        List[Int]([0, 2000, 500]),
    )
    if s.verdict != CHECK_CLEAN or s.kind != ARTIFACT_NONE:
        raise Error("genuine divergence was verdicted an artifact")
    if s.step0_hit:
        raise Error("divergence past step 0 fired the step-0 check")
    if s.divergent_count != 1 or s.first_divergent_step != 1:
        raise Error("genuine divergence counts drifted")
    if not may_file_divergence(s):
        raise Error("clean genuine divergence may not be filed")


def test_comparator_template_caught() raises:
    # Seeded fake divergence, class TEMPLATE: the prompt
    # was rendered by a chat template, so its divergence
    # is the template's, not the engine's.
    var prompts = List[String]()
    prompts.append(String("[INST] The sea is wide. [/INST]"))
    prompts.append(String("<|im_start|>user\nThe sea is wide.<|im_end|>"))
    prompts.append(String("### Human: The sea is wide."))
    for p in prompts:
        var s = run_comparator_checklist(
            p,
            True,
            True,
            String("cpu"),
            String("cpu"),
            List[Int]([0, 4, 0]),
            List[Int]([0, 1800, 0]),
        )
        if s.verdict != CHECK_COMPARATOR_ARTIFACT:
            raise Error("seeded template divergence not verdicted artifact")
        if s.kind != ARTIFACT_TEMPLATE or not s.template_hit:
            raise Error("seeded template divergence kind is not TEMPLATE")
        if may_file_divergence(s) or not artifact_blocks_filing(s):
            raise Error("template artifact did not block the filing")


def test_comparator_template_precedence_exact() raises:
    # The checks run BEFORE grading: a template-rendered
    # comparison is an artifact even when its records
    # happen to be exact -- the comparison was invalid,
    # so its perfect rows prove nothing either.
    var s = run_comparator_checklist(
        String("<|im_start|>user\nThe sea is wide.<|im_end|>"),
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([0, 0]),
        List[Int]([0, 0]),
    )
    if s.verdict != CHECK_COMPARATOR_ARTIFACT or s.kind != ARTIFACT_TEMPLATE:
        raise Error("template comparison with exact rows not an artifact")
    if s.divergent_count != 0:
        raise Error("exact-row template account shows a divergence")


def test_comparator_bos_flags_caught() raises:
    # Seeded fake divergence, class BOS: BOS applied on
    # the engine side only shifts every position by one.
    var s = run_comparator_checklist(
        String("The sea is wide."),
        True,
        False,
        String("cpu"),
        String("cpu"),
        List[Int]([0, 0, 6]),
        List[Int]([0, 0, 2400]),
    )
    if s.verdict != CHECK_COMPARATOR_ARTIFACT or s.kind != ARTIFACT_BOS:
        raise Error("seeded BOS divergence not verdicted BOS artifact")
    if not s.bos_hit or s.template_hit:
        raise Error("BOS seeded account hits drifted")
    if may_file_divergence(s):
        raise Error("BOS artifact may file a divergence")
    var mirror = run_comparator_checklist(
        String("The sea is wide."),
        False,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([0, 0, 6]),
        List[Int]([0, 0, 2400]),
    )
    if mirror.kind != ARTIFACT_BOS:
        raise Error("mirrored BOS mismatch not verdicted BOS")


def test_comparator_bos_rendered_caught() raises:
    # Seeded fake divergence, class BOS (rendered mark):
    # the prompt bytes carry a rendered BOS "<s>" that
    # neither side's stated handling accounts for. The
    # mark files under BOS, not TEMPLATE -- the classes
    # stay distinct.
    var s = run_comparator_checklist(
        String("<s>The sea is wide."),
        False,
        False,
        String("cpu"),
        String("cpu"),
        List[Int]([0, 3, 0]),
        List[Int]([0, 1200, 0]),
    )
    if s.verdict != CHECK_COMPARATOR_ARTIFACT or s.kind != ARTIFACT_BOS:
        raise Error("rendered-BOS divergence not verdicted BOS artifact")
    if not s.bos_hit or s.template_hit:
        raise Error("rendered-BOS account filed under the wrong class")


def test_comparator_backend_mismatch_caught() raises:
    # Seeded fake divergences, class BACKEND_MISMATCH:
    # cross-backend pairs, an accelerator pair (visible
    # is not a grading comparator), and an unnamed
    # oracle -- each grades the comparison, not the
    # engine.
    var pairs = List[List[String]]()
    pairs.append(List[String]([String("cpu"), String("vulkan")]))
    pairs.append(List[String]([String("vulkan"), String("cpu")]))
    pairs.append(List[String]([String("vulkan"), String("vulkan")]))
    pairs.append(List[String]([String("cpu"), String("")]))
    pairs.append(List[String]([String(""), String("cpu")]))
    for pair in pairs:
        var s = run_comparator_checklist(
            String("The sea is wide."),
            True,
            True,
            pair[0],
            pair[1],
            List[Int]([0, 4, 0]),
            List[Int]([0, 1800, 0]),
        )
        if s.verdict != CHECK_COMPARATOR_ARTIFACT:
            raise Error("seeded backend divergence not verdicted artifact")
        if s.kind != ARTIFACT_BACKEND_MISMATCH or not s.backend_hit:
            raise Error("seeded backend divergence kind is not BACKEND")
        if may_file_divergence(s):
            raise Error("backend artifact may file a divergence")


def test_comparator_step0_caught() raises:
    # Seeded fake divergence, class STEP0_BOUNDARY: the
    # only divergent record sits at step 0 and every
    # later step is exact or near-tie -- a prompt-
    # boundary effect, never an engine divergence on
    # this evidence alone.
    var s = run_comparator_checklist(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([4, 0, 1]),
        List[Int]([1500, 0, 500]),
    )
    if s.verdict != CHECK_COMPARATOR_ARTIFACT:
        raise Error("seeded step-0 divergence not verdicted artifact")
    if s.kind != ARTIFACT_STEP0_BOUNDARY or not s.step0_hit:
        raise Error("seeded step-0 divergence kind is not STEP0_BOUNDARY")
    if s.first_divergent_step != 0 or s.divergent_count != 1:
        raise Error("step-0 account counts drifted")
    if may_file_divergence(s) or not artifact_blocks_filing(s):
        raise Error("step-0 artifact did not block the filing")


def test_comparator_step0_plus_later_genuine() raises:
    # A divergent step 0 joined by a divergent later step
    # is NOT a boundary artifact: the later divergence is
    # engine evidence and the filing proceeds.
    var s = run_comparator_checklist(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([4, 0, 3]),
        List[Int]([1500, 0, 10]),
    )
    if s.verdict != CHECK_CLEAN or s.kind != ARTIFACT_NONE:
        raise Error("step-0 plus later divergence verdicted an artifact")
    if s.step0_hit:
        raise Error("later divergence fired the step-0 check")
    if s.divergent_count != 2 or not may_file_divergence(s):
        raise Error("step-0 plus later account may not file")


def test_comparator_combined_precedence() raises:
    # Every check fires at once: the summary records all
    # four hits and the kind follows the pre-registered
    # precedence (template, then BOS, then backend, then
    # step-0) so filings name one kind deterministically.
    var s = run_comparator_checklist(
        String("[INST] The sea is wide. [/INST]"),
        True,
        False,
        String("cpu"),
        String("vulkan"),
        List[Int]([4, 0, 0]),
        List[Int]([1500, 0, 0]),
    )
    if not s.template_hit or not s.bos_hit or not s.backend_hit:
        raise Error("combined account did not record every hit")
    if not s.step0_hit:
        raise Error("combined account lost the step-0 hit")
    if s.kind != ARTIFACT_TEMPLATE:
        raise Error("combined account precedence is not TEMPLATE first")
    var bos_backend = run_comparator_checklist(
        String("The sea is wide."),
        False,
        True,
        String("hip"),
        String("cpu"),
        List[Int]([0, 4, 0]),
        List[Int]([0, 1800, 0]),
    )
    if bos_backend.kind != ARTIFACT_BOS:
        raise Error("BOS + backend account precedence is not BOS")
    var backend_step0 = run_comparator_checklist(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("npu"),
        List[Int]([4, 0, 0]),
        List[Int]([1500, 0, 0]),
    )
    if backend_step0.kind != ARTIFACT_BACKEND_MISMATCH:
        raise Error("backend + step-0 account precedence is not BACKEND")


def test_comparator_invalid_records_refused() raises:
    # A broken transcription is refused, not verdicted:
    # A-111's gate validation is the checklist's first
    # step, so no artifact kind can launder it.
    if not _raises_account(List[Int]([0]), List[Int]([5])):
        raise Error("rank 0 with a nonzero gap was not refused")
    if not _raises_account(List[Int]([2]), List[Int]([0])):
        raise Error("positive rank with a zero gap was not refused")
    if not _raises_account(List[Int]([-1]), List[Int]([5])):
        raise Error("negative rank was not refused")
    if not _raises_account(List[Int]([0, 0]), List[Int]([0])):
        raise Error("length mismatch was not refused")
    var line = checklist_line()
    if String("A-112") not in line:
        raise Error("checklist line lost its slice tag")
    if String("COMPARATOR_ARTIFACT") not in line:
        raise Error("checklist line lost its verdict")
