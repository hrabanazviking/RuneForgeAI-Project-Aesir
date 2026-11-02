"""Cold-start honesty account (Janas road J-069).

The roadmap text: "First prompt after open (compilation,
preparation, cache cold) timed and reported separately from
warm figures everywhere this road publishes numbers."

THE COLD-START SHAPE, stated before any building (the slice
doc, docs/janas/J069_COLD_START_HONESTY.md section 1, is its
normative text). A session's life has two regimes, and a
number from one may never be published as a number from the
other:

- COLD: the first prompt after open. Its wall is a SUM of
  four components, each reported separately or stated
  not-applicable with its reason:
    (C1) OPEN -- process start to model open complete:
         file open, mapping, directory parse, resident-set
         load. No surface in this tree times it today
         (J-053 finding F3's wider form: the host engine
         reports no timings at all; the native serve route
         times only begin_turn / decode per request).
    (C2) COMPILE -- first-use compilation and initialisation
         on the execution path: CUDA context and first
         kernel use, graph compilation where a backend
         compiles, first-touch allocation. A surface with
         no compilation step states 0 with that reason; it
         never folds an unmeasured compile cost silently
         into its first prefill.
    (C3) PREP -- one-time preparation: the NPU preparation
         of J-061 (8-bit copies + graphs; a graph-cache hit
         is a DIFFERENT prep figure from a cold prep, and
         the two are never averaged), expert-cache sizing,
         any open-time autotuning. Prep that does not
         apply is stated not-applicable, never omitted.
    (C4) COLD PREFILL -- the first prompt's own prefill
         with cold caches: the expert cache opens empty
         (J-017 section 5.2: the first token can owe the
         full cold ceiling, 487,587,840 B on OLMoE), the
         page cache in its stated state (J-019's
         discipline: cold is measured -- DONTNEED + mincore
         resident fraction -- never hoped), the prefix
         cache empty.
  The cold total is exactly C1+C2+C3+C4. A single merged
  "first prompt" number with no component split is not a
  cold figure this road may publish.

- WARM: any prompt after the first, in a session whose
  open, compile, and prep are done, with caches in their
  stated state. A warm figure EXCLUDES C1, C2, and C3
  entirely. A warm median over repetitions excludes the
  first (cold) repetition: a median of [cold, warm, warm]
  is a mixed figure and is refused, however it is labelled
  (the J-053 / J-068 deferred recipes' three-repetition
  shape is amended by this rule -- see the slice doc).

WHAT THE ACCOUNT DECIDES, AND WHAT IT REFUSES TO DECIDE
(the verdict rule, pre-registered in the doc section 1):

- PERMITTED BY ACCOUNT (accounting alone): the separation
  claim itself -- that a report states all four cold
  components separately (or not-applicable with reason)
  and keeps warm figures free of C1--C3.
- REQUIRES LIVE MEASUREMENT: any cold wall, warm wall, or
  tok/s figure. Accounting classifies and separates; it
  contains no speed and permits no speed claim without a
  live measurement on named hardware with machine state
  stated.
- REFUSED outright: a warm claim grounded on a cold-first
  run (the road's one measured prefill family -- the
  J-022 / J-023 / J-030 single-shot MoE legs, each a fresh
  process whose prefill IS a cold first prompt -- may be
  cited as cold, never as warm or steady-state); a warm
  claim whose figure includes open, compile, or prep time
  (conflated); a cold claim grounded on a warm or mixed
  run; a merged cold total with no component split.

This module is pure arithmetic in the J-066 / J-067 / J-068
pattern: it executes nothing, times nothing, opens no
device, and contains no speed. No existing module is
changed by this slice; wiring a live surface to REPORT
through this account rides with the first live leg that
runs under the doc section 7 recipe (re-cited at the
J-070 gate).

HOST CONTRACT: (1) at open, the host records C1, C2, C3
as it performs them (0 with reason where a step does not
apply; prep_cache_hit stated for C3); (2) the first
prompt's prefill is recorded as C4 with its cache states
(expert-cache-empty, page-cache state per J-019); (3)
every later prompt is warm by classification, and any
figure including C1--C3 is refused before publication;
(4) repetition plans file repetition 1 separately as the
cold figure and take warm medians over repetitions 2..n
only; (5) every published wall / tok/s passes
evaluate_cold_claim before it is stated.
"""

# Run classes from classify_run.
comptime RUN_COLD_FIRST = 0
comptime RUN_WARM = 1
comptime RUN_CONFLATED = 2

# Claim kinds for evaluate_cold_claim.
comptime CLAIM_SEPARATION = 0
comptime CLAIM_COLD_WALL = 1
comptime CLAIM_WARM_WALL = 2

# Claim verdicts (the J-067 claim-verdict vocabulary).
comptime COLD_CLAIM_PERMITTED = 0
comptime COLD_CLAIM_REQUIRES_LIVE = 1
comptime COLD_CLAIM_REFUSED = 2

# Repetition-plan verdicts from repetition_verdict.
comptime REP_OK = 0
comptime REP_SINGLE_COLD_ONLY = 1
comptime REP_REFUSED_MIXED = 2


def run_class_name(code: Int) raises -> String:
    if code == RUN_COLD_FIRST:
        return String("cold_first")
    if code == RUN_WARM:
        return String("warm")
    if code == RUN_CONFLATED:
        return String("conflated")
    raise Error("ColdStartAccount: unknown run class code")


def claim_name(code: Int) raises -> String:
    if code == COLD_CLAIM_PERMITTED:
        return String("PERMITTED")
    if code == COLD_CLAIM_REQUIRES_LIVE:
        return String("REQUIRES_LIVE")
    if code == COLD_CLAIM_REFUSED:
        return String("REFUSED")
    raise Error("ColdStartAccount: unknown claim code")


def repetition_verdict_name(code: Int) raises -> String:
    if code == REP_OK:
        return String("ok")
    if code == REP_SINGLE_COLD_ONLY:
        return String("single_cold_only")
    if code == REP_REFUSED_MIXED:
        return String("refused_mixed_median")
    raise Error("ColdStartAccount: unknown repetition verdict code")


struct ColdStartAccount(Copyable, ImplicitlyCopyable):
    """One cold first prompt after open, in four components.

    All times are caller-measured milliseconds; this struct
    only keeps them separate and sums them exactly. A
    component that does not apply on the surface is 0 with
    its applicability stated (prep_applies for C3); open and
    compile always apply as steps (a step that costs nothing
    measurable is 0, stated, never skipped).
    """

    var open_ms: Int
    var compile_ms: Int
    var prep_ms: Int
    var cold_prefill_ms: Int
    var prep_applies: Bool
    var prep_cache_hit: Bool
    var expert_cache_cold: Bool
    var page_cache_cold: Bool

    def __init__(
        out self,
        open_ms: Int,
        compile_ms: Int,
        prep_ms: Int,
        cold_prefill_ms: Int,
        prep_applies: Bool,
        prep_cache_hit: Bool,
        expert_cache_cold: Bool,
        page_cache_cold: Bool,
    ):
        self.open_ms = open_ms
        self.compile_ms = compile_ms
        self.prep_ms = prep_ms
        self.cold_prefill_ms = cold_prefill_ms
        self.prep_applies = prep_applies
        self.prep_cache_hit = prep_cache_hit
        self.expert_cache_cold = expert_cache_cold
        self.page_cache_cold = page_cache_cold

    def overhead_ms(self) -> Int:
        """Everything before the cold prefill itself: C1+C2+C3."""
        return self.open_ms + self.compile_ms + self.prep_ms

    def total_ms(self) -> Int:
        """The cold total: exactly C1+C2+C3+C4, never less."""
        return self.overhead_ms() + self.cold_prefill_ms


def plan_cold_start(
    open_ms: Int,
    compile_ms: Int,
    prep_ms: Int,
    cold_prefill_ms: Int,
    prep_applies: Bool,
    prep_cache_hit: Bool,
    expert_cache_cold: Bool,
    page_cache_cold: Bool,
) raises -> ColdStartAccount:
    """Validate and keep one cold first prompt's components.

    Refusals: any negative component; a prep figure stated
    for a preparation that does not apply (the component is
    not-applicable and must be 0, so a nonzero figure means
    the caller priced a different surface's prep); a graph-
    cache hit claimed for a preparation that does not apply;
    a cold prefill claimed with a warm expert cache (the
    first prompt after open faces the cache J-017 section
    5.2 describes -- empty; a first prompt that found its
    experts resident was not this account's cold case and
    must be restated, e.g. as a prefix-reuse case).
    """
    if open_ms < 0 or compile_ms < 0 or prep_ms < 0 or cold_prefill_ms < 0:
        raise Error("ColdStartAccount: components must be >= 0")
    if not prep_applies and prep_ms != 0:
        raise Error(
            "ColdStartAccount: prep does not apply here; its figure must be 0"
        )
    if not prep_applies and prep_cache_hit:
        raise Error(
            "ColdStartAccount: no graph-cache hit without a preparation"
        )
    if not expert_cache_cold:
        raise Error(
            "ColdStartAccount: a cold first prompt faces an empty expert"
            " cache; restate a warm-cache first prompt separately"
        )
    return ColdStartAccount(
        open_ms,
        compile_ms,
        prep_ms,
        cold_prefill_ms,
        prep_applies,
        prep_cache_hit,
        expert_cache_cold,
        page_cache_cold,
    )


def overhead_share_bp(account: ColdStartAccount) raises -> Int:
    """The open+compile+prep share of the cold total, in
    basis points (floored). A zero total is refused rather
    than divided."""
    var total = account.total_ms()
    if total <= 0:
        raise Error("ColdStartAccount: cold total must be positive")
    return account.overhead_ms() * 10000 // total


def classify_run(
    is_first_prompt_after_open: Bool,
    expert_cache_empty_at_start: Bool,
    includes_open_ms: Bool,
    includes_compile_ms: Bool,
    includes_prep_ms: Bool,
) -> Int:
    """Classify one timed run by what it actually contains.

    - COLD_FIRST: the first prompt after open, facing an
      empty expert cache. Its figure may ground cold claims
      only, whatever it is called.
    - WARM: not the first prompt, and the figure includes
      none of open / compile / prep.
    - CONFLATED: everything else -- a later prompt whose
      figure still carries an open-time component, or a
      claimed first prompt whose cache was not empty (a
      mixed case that grounds neither a cold nor a warm
      claim until it is restated honestly).
    """
    if is_first_prompt_after_open and expert_cache_empty_at_start:
        return RUN_COLD_FIRST
    if not is_first_prompt_after_open:
        if not includes_open_ms and not includes_compile_ms and not includes_prep_ms:
            return RUN_WARM
    return RUN_CONFLATED


def repetition_verdict(
    repetitions: Int, first_reported_separately: Bool
) raises -> Int:
    """Grade one repetition plan for warm-figure honesty.

    - REP_OK: at least two repetitions and the first is
      filed separately as the cold figure; warm medians are
      taken over repetitions 2..n only.
    - REP_SINGLE_COLD_ONLY: exactly one repetition -- it IS
      the cold run; no warm figure may be derived from it.
    - REP_REFUSED_MIXED: two or more repetitions whose first
      is folded into the reported median -- a mixed figure,
      refused as a warm figure however it is labelled.
    """
    if repetitions <= 0:
        raise Error("ColdStartAccount: repetitions must be positive")
    if repetitions == 1:
        return REP_SINGLE_COLD_ONLY
    if first_reported_separately:
        return REP_OK
    return REP_REFUSED_MIXED


def evaluate_cold_claim(
    claim_kind: Int,
    run_class: Int,
    components_all_stated: Bool,
    live_measured: Bool,
) raises -> Int:
    """The pre-registered verdict rule (doc section 1).

    - CLAIM_SEPARATION (the report separates cold from warm
      with all four components stated or not-applicable):
      PERMITTED on accounting alone when the components are
      all stated; REFUSED when any component is missing --
      a merged total is not a separation.
    - CLAIM_COLD_WALL (a cold wall / tok/s figure):
      REFUSED unless the grounding run is COLD_FIRST;
      REQUIRES_LIVE until a live measurement grounds it;
      PERMITTED only for a live-measured cold-first run.
    - CLAIM_WARM_WALL (a warm wall / tok/s figure):
      REFUSED when the grounding run is COLD_FIRST (a first
      prompt published as warm -- the conflation this slice
      exists to refuse) or CONFLATED; REQUIRES_LIVE until
      measured; PERMITTED only for a live-measured WARM run.
    """
    if claim_kind == CLAIM_SEPARATION:
        if components_all_stated:
            return COLD_CLAIM_PERMITTED
        return COLD_CLAIM_REFUSED
    if claim_kind == CLAIM_COLD_WALL:
        if run_class != RUN_COLD_FIRST:
            return COLD_CLAIM_REFUSED
        if not live_measured:
            return COLD_CLAIM_REQUIRES_LIVE
        return COLD_CLAIM_PERMITTED
    if claim_kind == CLAIM_WARM_WALL:
        if run_class != RUN_WARM:
            return COLD_CLAIM_REFUSED
        if not live_measured:
            return COLD_CLAIM_REQUIRES_LIVE
        return COLD_CLAIM_PERMITTED
    raise Error("ColdStartAccount: unknown claim kind")
