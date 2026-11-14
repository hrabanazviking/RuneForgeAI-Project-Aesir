"""A-127: Coherence grading harness -- sampled
generations scored for coherence for the quant /
backend cells where exactness is not owed (Wave 15,
Coherence & quality, the opener).

The roadmap text: "Coherence grading harness.
Sampled generations scored for coherence (the S-095
road pattern) for the quant/backend cells where
exactness is not owed. Acceptance: harness scores
filed for the IQ matrix; scorer sanity-checked
against known-good and known-broken samples."

THE SURFACE, HONESTLY (what exists to score):
The cells where exactness is not owed are exactly
the nine IQ quant families: the banked A-115 policy
(core/exactness_policy.mojo) files them
COHERENCE_ONLY, read here BY CALL from
policy_for_quant for every row -- never re-typed,
never defaulted. The IQ matrix of this harness is
those 9 quants (A-114's matrix_quants() filtered by
A-114's is_iq_quant, both called) x 3 architectures
(A-114's matrix_archs(): llama, gemma4, mistral3,
called) x 4 backends (exactly A-109's
tf_harness_backends(): cpu, vulkan, hip, npu,
called) = 108 cells.

ZERO filed sampled-generation records exist for
any IQ cell in the banked tree. A-114 filed the IQ
rows FIXTURE_LIMITED for teacher-forcing (the
stories260K fixture cannot satisfy the 256-value
IQ super-block by construction), and A-115's own
doc states the position plainly: "No coherence
evidence exists in the banked records yet, so
every IQ row grades NOT_GRADED until such evidence
is filed; the policy mints no pass from token
records." This harness therefore files a score row
for every one of the 108 IQ cells -- verdict
NOT_GRADED with a named reason and score -1 (the
absence stated, never zero-filled into a fake
perfect row, the A-114 witness convention) -- and
proves the scorer itself on the labelled SYNTHETIC
sanity fixture below. The harness retires the
NOT_GRADED rows cell by cell as sampled-generation
records are filed for them (A-128's filed samples
are the first named source), re-verdicted at
A-135.

THE SCORER (the harness proper): a pure text
scorer over a stated sample, in the pattern of the
tree's own frozen coherence rubric f1-coherence-
v1.1 (data/armvegr/coherence_rubric_v1_1.json,
frozen by H138, reused verbatim by H158 / H186 /
H195): >= 3 complete sentences, no long repeated
runs, no garbage characters, predominantly real
words, on-topic. The S-095 road pattern governs
the expectations: coherence expectations are set
from the oracle's / the tree's own filed behaviour
on the same material (here, the frozen rubric the
tree already grades generations by), never against
an imagined ideal, and never by token-exactness --
ggml's own CPU vs CUDA IQ kernels disagree with
each other (S-029), so token-exact parity for IQ
is not proven by construction and is never
demanded here.

THE SCORER RULE, PRE-REGISTERED (stated here
before any test in tests/test_coherence_harness_
a127.mojo was run). Metrics over the sample's
bytes (words = maximal runs of ASCII letters /
digits containing at least one letter, compared
lowercased): words, sentences (terminal . ! ?
count), unique_x1000 (distinct words x1000 /
words), max_run (longest run of one word repeated
consecutively), garbage (control bytes other than
tab / newline / carriage return, DEL, and U+FFFD
replacement-character sequences), alpha_x1000
(ASCII letter bytes x1000 / total bytes),
gibberish_x1000 (words of length >= 4 with no
vowel a e i o u, x1000 / words), topic_hit (any
stated topic word appearing in the lowercased
sample), score_x1000 = (unique_x1000 +
alpha_x1000) // 2. An empty or whitespace-only
sample is REFUSED (raised), never graded. For a
stated sample with stated topic words and an
optional stated prompt, in order:
  (S1) garbage > 0 -> COHERENCE_FAIL /
       GARBAGE_CHARS.
  (S2) alpha_x1000 < 500 -> COHERENCE_FAIL /
       NON_ALPHA_CONTENT.
  (S3) a prompt is stated and the sample,
       normalised (lowercased, non-alphanumeric
       collapsed to single spaces, trimmed),
       equals the normalised prompt ->
       COHERENCE_FAIL / PROMPT_ECHO.
  (S4) words < 12 -> COHERENCE_FAIL / TOO_SHORT.
  (S5) sentences < 3 -> COHERENCE_FAIL /
       TOO_FEW_SENTENCES.
  (S6) max_run > 3 -> COHERENCE_FAIL /
       REPETITION_RUN; else unique_x1000 < 400 ->
       COHERENCE_FAIL / REPETITION_LOW_DIVERSITY.
  (S7) gibberish_x1000 > 100 -> COHERENCE_FAIL /
       GIBBERISH_WORDS.
  (S8) topic words are stated and none hits ->
       COHERENCE_FAIL / OFF_TOPIC.
  else COHERENCE_PASS / COHERENCE_CHECKS_PASS.
Verdict codes for a scored sample are A-115's own
POL_COHERENCE_PASS (5) / POL_COHERENCE_FAIL (6),
called from the banked policy module -- the only
verdicts a coherence-only row can file.

THE MATRIX RULE, PRE-REGISTERED. For one IQ cell
(quant, arch, backend), in order:
  (R1) backend != cpu -> NOT_GRADED, reason
       BACKEND_NO_CPU_COMPARATOR, score -1.
       Grading is CPU engine vs CPU comparator
       only; this harness files no device-
       execution evidence for vulkan / hip / npu,
       and accelerator-visible is NOT accelerator-
       run.
  (R2) arch != llama -> NOT_GRADED, reason
       NO_FILED_RECORDS, score -1. The only filed
       records of any kind are llama-arch; nothing
       is extrapolated across architectures.
  (R3) cpu x llama -> NOT_GRADED, reason
       NO_FILED_GENERATIONS, score -1: no sampled-
       generation record is filed for any IQ cell
       (see THE SURFACE above).
Filed harness on the banked records: total 108,
pass 0, fail 0, not_graded 108 (81 backend + 18
arch + 9 no-generations), policy coherence 108,
owed 0. Zero unexplained cells.

  (R4) THE SYNTHETIC SANITY FIXTURE (labelled
       SYNTHETIC in every line): stated text
       samples scored by the pre-registered S1-S8
       rule, each defect named:
       SYN_GOOD_HOSPITALITY (coherent on-topic
       prose, topic hospitality / guests) ->
       COHERENCE_PASS; SYN_GOOD_HARBOUR (coherent
       on-topic prose, topic harbour / fishermen)
       -> COHERENCE_PASS; SYN_LOOP (one short
       sentence repeated) -> COHERENCE_FAIL /
       REPETITION_LOW_DIVERSITY; SYN_GARBAGE
       (U+FFFD replacement characters seeded into
       prose) -> COHERENCE_FAIL / GARBAGE_CHARS;
       SYN_SHORT (three words) -> COHERENCE_FAIL /
       TOO_SHORT; SYN_PUNCT (punctuation only) ->
       COHERENCE_FAIL / NON_ALPHA_CONTENT;
       SYN_OFFTOPIC (fluent prose about processors,
       topic hospitality) -> COHERENCE_FAIL /
       OFF_TOPIC; SYN_ECHO (the sample is its own
       prompt, verbatim) -> COHERENCE_FAIL /
       PROMPT_ECHO; SYN_EMPTY (the empty sample:
       the scorer refuses it, and the refusal is
       filed) -> COHERENCE_FAIL /
       EMPTY_SAMPLE_REFUSED. Synthetic summary:
       total 9, pass 2, fail 7. The fixture proves
       the scorer discriminates; it is NOT
       generation evidence for any matrix cell and
       mints no cell verdict.

INTEGRATION POINTS (honest, named): A-115 is
BANKED and called (policy_for_quant, POL_
COHERENCE_PASS / POL_COHERENCE_FAIL); A-114 is
BANKED and called (matrix_quants, matrix_archs,
is_iq_quant, MX_* verdict codes, mx_fnv1a64);
A-109's tf_harness_backends is called. A-125
(team-25) and A-126 (team-26) build in parallel --
no dependency taken on either. A-128 (long-
generation stability) files the first real sampled
generations this harness can score; A-135 (Part V
gate) re-verdicts the IQ matrix from whatever
generation records stand filed by then.

RAW-ORACLE DISCIPLINE (standing): no token record
is graded here at all -- coherence is the only
currency for these cells, per the banked policy;
comparator artifacts remain a verdict class in
the surfaces this harness reads (none are filed
by it); no accelerator claim is made without
device-execution evidence. The harness executes
no model on this machine, opens no device, and
claims no speed: pure enumeration and byte
arithmetic over stated samples and the banked
policy / matrix surfaces.
"""

from core.exactness_policy import (
    POL_COHERENCE_FAIL,
    POL_COHERENCE_PASS,
    POLICY_COHERENCE_ONLY,
    policy_for_quant,
)
from core.matrix_runner import (
    MX_NOT_GRADED,
    is_iq_quant,
    matrix_archs,
    matrix_quants,
    matrix_verdict_name,
    mx_fnv1a64,
)
from core.teacher_forcing_harness import tf_harness_backends

comptime CH_GRADED_BACKEND = "cpu"
comptime CH_GRADED_ARCH = "llama"
comptime CH_MIN_WORDS = 12
comptime CH_MIN_SENTENCES = 3
comptime CH_MAX_RUN = 3
comptime CH_MIN_UNIQUE_X1000 = 400
comptime CH_MIN_ALPHA_X1000 = 500
comptime CH_MAX_GIBBERISH_X1000 = 100
comptime CH_FIXTURE_STATUS = "SYNTHETIC"
comptime CH_NO_SCORE = -1


def iq_quants() -> List[String]:
    """The 9 IQ quant axis entries: A-114's
    matrix_quants() filtered by A-114's is_iq_quant,
    both called -- the coherence-only half of the
    matrix, in axis order, never re-typed."""
    var out = List[String]()
    var quants = matrix_quants()
    for i in range(len(quants)):
        if is_iq_quant(quants[i]):
            out.append(quants[i])
    return out^


def harness_archs() -> List[String]:
    """The 3 architecture axis entries: exactly
    A-114's matrix_archs(), called."""
    return matrix_archs()


def harness_backends() -> List[String]:
    """The 4 backend axis entries: exactly A-109's
    tf_harness_backends(), called."""
    return tf_harness_backends()


# --- Byte helpers (the scorer works on bytes; word
# identity is lowercased ASCII, stated in the
# header). ---


def _lower_byte(b: Int) -> Int:
    if b >= 65 and b <= 90:
        return b + 32
    return b


def _is_alpha(b: Int) -> Bool:
    return (b >= 65 and b <= 90) or (b >= 97 and b <= 122)


def _is_digit(b: Int) -> Bool:
    return b >= 48 and b <= 57


def _is_space(b: Int) -> Bool:
    return b == 32 or b == 9 or b == 10 or b == 13


def _lower_bytes(text: String) -> List[Int]:
    var bytes = text.as_bytes()
    var out = List[Int]()
    for i in range(len(bytes)):
        out.append(_lower_byte(Int(bytes[i])))
    return out^


def _word_lists(text: String) -> List[List[Int]]:
    """The sample's words as lowercased byte lists:
    maximal runs of ASCII letters / digits that
    contain at least one letter."""
    var bytes = _lower_bytes(text)
    var words = List[List[Int]]()
    var cur = List[Int]()
    var cur_alpha = False
    for i in range(len(bytes) + 1):
        var b = -1
        if i < len(bytes):
            b = bytes[i]
        if b >= 0 and (_is_alpha(b) or _is_digit(b)):
            cur.append(b)
            if _is_alpha(b):
                cur_alpha = True
        else:
            if len(cur) > 0 and cur_alpha:
                words.append(cur.copy())
            cur = List[Int]()
            cur_alpha = False
    return words^


def _normalised(text: String) -> List[Int]:
    """The prompt-echo normal form: lowercased,
    every non-alphanumeric byte collapsed to one
    space, no leading / trailing space."""
    var bytes = _lower_bytes(text)
    var out = List[Int]()
    var pending_space = False
    for i in range(len(bytes)):
        var b = bytes[i]
        if _is_alpha(b) or _is_digit(b):
            if pending_space and len(out) > 0:
                out.append(32)
            pending_space = False
            out.append(b)
        else:
            pending_space = True
    return out^


def _bytes_equal(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def _contains(lower: List[Int], needle: List[Int]) -> Bool:
    """Naive substring search over byte lists."""
    if len(needle) == 0:
        return False
    if len(needle) > len(lower):
        return False
    for s in range(len(lower) - len(needle) + 1):
        var ok = True
        for k in range(len(needle)):
            if lower[s + k] != needle[k]:
                ok = False
                break
        if ok:
            return True
    return False


struct SampleMetrics(Copyable, ImplicitlyCopyable):
    """The stated metrics of one sample (see the
    header for definitions). All ratios are filed
    x1000 integers; no floats anywhere."""

    var words: Int
    var sentences: Int
    var unique_x1000: Int
    var max_run: Int
    var garbage: Int
    var alpha_x1000: Int
    var gibberish_x1000: Int
    var topic_hit: Bool
    var score_x1000: Int

    def __init__(
        out self,
        words: Int,
        sentences: Int,
        unique_x1000: Int,
        max_run: Int,
        garbage: Int,
        alpha_x1000: Int,
        gibberish_x1000: Int,
        topic_hit: Bool,
        score_x1000: Int,
    ):
        self.words = words
        self.sentences = sentences
        self.unique_x1000 = unique_x1000
        self.max_run = max_run
        self.garbage = garbage
        self.alpha_x1000 = alpha_x1000
        self.gibberish_x1000 = gibberish_x1000
        self.topic_hit = topic_hit
        self.score_x1000 = score_x1000


def sample_metrics(text: String, topics: List[String]) -> SampleMetrics:
    """Every metric of the pre-registered rule over
    one stated sample. Pure byte arithmetic; never
    raises (refusal lives in score_sample)."""
    var bytes = text.as_bytes()
    var total = len(bytes)
    var sentences = 0
    var garbage = 0
    var alpha = 0
    var i = 0
    while i < total:
        var b = Int(bytes[i])
        if b == 46 or b == 33 or b == 63:
            sentences += 1
        if _is_alpha(b):
            alpha += 1
        if b == 239 and i + 2 < total:
            if Int(bytes[i + 1]) == 191 and Int(bytes[i + 2]) == 189:
                garbage += 1
                i += 3
                continue
        if (b < 32 and b != 9 and b != 10 and b != 13) or b == 127:
            garbage += 1
        i += 1
    var alpha_x1000 = 0
    if total > 0:
        alpha_x1000 = alpha * 1000 // total
    var words = _word_lists(text)
    var nw = len(words)
    var unique = 0
    var gibberish = 0
    var max_run = 0
    var run = 0
    for w in range(nw):
        var is_new = True
        for u in range(w):
            if _bytes_equal(words[w], words[u]):
                is_new = False
                break
        if is_new:
            unique += 1
        if w > 0 and _bytes_equal(words[w], words[w - 1]):
            run += 1
        else:
            run = 1
        if run > max_run:
            max_run = run
        var has_vowel = False
        for c in range(len(words[w])):
            var ch = words[w][c]
            if ch == 97 or ch == 101 or ch == 105 or ch == 111 or ch == 117:
                has_vowel = True
                break
        if len(words[w]) >= 4 and not has_vowel:
            gibberish += 1
    var unique_x1000 = 0
    var gibberish_x1000 = 0
    if nw > 0:
        unique_x1000 = unique * 1000 // nw
        gibberish_x1000 = gibberish * 1000 // nw
    var lower = _lower_bytes(text)
    var topic_hit = False
    for t in range(len(topics)):
        if _contains(lower, _lower_bytes(topics[t])):
            topic_hit = True
            break
    var score_x1000 = (unique_x1000 + alpha_x1000) // 2
    if nw == 0:
        score_x1000 = 0
    return SampleMetrics(
        nw, sentences, unique_x1000, max_run, garbage,
        alpha_x1000, gibberish_x1000, topic_hit, score_x1000,
    )


struct ScoreResult(Copyable, ImplicitlyCopyable):
    """One scored sample: A-115's coherence verdict
    code, the named reason, and the metric witness."""

    var verdict: Int
    var reason: String
    var metrics: SampleMetrics

    def __init__(
        out self, verdict: Int, reason: String, metrics: SampleMetrics
    ):
        self.verdict = verdict
        self.reason = reason
        self.metrics = metrics


def coherence_verdict_name(code: Int) -> String:
    """The filed name of a coherence verdict code
    (A-115's POL_COHERENCE_PASS / POL_COHERENCE_FAIL
    namespace)."""
    if code == POL_COHERENCE_PASS:
        return String("COHERENCE_PASS")
    if code == POL_COHERENCE_FAIL:
        return String("COHERENCE_FAIL")
    return String("NOT_GRADED")


def score_sample(
    text: String, topics: List[String], prompt: String
) raises -> ScoreResult:
    """The pre-registered S1-S8 rule over one stated
    sample. An empty or whitespace-only sample is
    REFUSED (raised), never graded -- a refusal is
    not a coherence judgement."""
    var bytes = text.as_bytes()
    var any_content = False
    for i in range(len(bytes)):
        if not _is_space(Int(bytes[i])):
            any_content = True
            break
    if not any_content:
        raise Error("CoherenceHarness: empty sample refused")
    var m = sample_metrics(text, topics)
    if m.garbage > 0:
        return ScoreResult(
            POL_COHERENCE_FAIL, String("GARBAGE_CHARS"), m
        )
    if m.alpha_x1000 < CH_MIN_ALPHA_X1000:
        return ScoreResult(
            POL_COHERENCE_FAIL, String("NON_ALPHA_CONTENT"), m
        )
    if prompt.byte_length() > 0:
        if _bytes_equal(_normalised(text), _normalised(prompt)):
            return ScoreResult(
                POL_COHERENCE_FAIL, String("PROMPT_ECHO"), m
            )
    if m.words < CH_MIN_WORDS:
        return ScoreResult(POL_COHERENCE_FAIL, String("TOO_SHORT"), m)
    if m.sentences < CH_MIN_SENTENCES:
        return ScoreResult(
            POL_COHERENCE_FAIL, String("TOO_FEW_SENTENCES"), m
        )
    if m.max_run > CH_MAX_RUN:
        return ScoreResult(
            POL_COHERENCE_FAIL, String("REPETITION_RUN"), m
        )
    if m.unique_x1000 < CH_MIN_UNIQUE_X1000:
        return ScoreResult(
            POL_COHERENCE_FAIL,
            String("REPETITION_LOW_DIVERSITY"),
            m,
        )
    if m.gibberish_x1000 > CH_MAX_GIBBERISH_X1000:
        return ScoreResult(
            POL_COHERENCE_FAIL, String("GIBBERISH_WORDS"), m
        )
    if len(topics) > 0 and not m.topic_hit:
        return ScoreResult(POL_COHERENCE_FAIL, String("OFF_TOPIC"), m)
    return ScoreResult(
        POL_COHERENCE_PASS, String("COHERENCE_CHECKS_PASS"), m
    )


# --- The IQ matrix harness (R1-R3). ---


struct HarnessRow(Copyable, ImplicitlyCopyable):
    var quant: String
    var arch: String
    var backend: String
    var verdict: Int
    var reason: String
    var obligation: Int
    var score_x1000: Int

    def __init__(
        out self,
        quant: String,
        arch: String,
        backend: String,
        verdict: Int,
        reason: String,
        obligation: Int,
        score_x1000: Int,
    ):
        self.quant = quant
        self.arch = arch
        self.backend = backend
        self.verdict = verdict
        self.reason = reason
        self.obligation = obligation
        self.score_x1000 = score_x1000


def _check_quants(quants: List[String]) raises:
    if len(quants) == 0:
        raise Error("CoherenceHarness: quant axis is empty")
    for i in range(len(quants)):
        if not is_iq_quant(quants[i]):
            raise Error(
                "CoherenceHarness: non-IQ quant on the "
                "coherence axis refused: " + quants[i]
            )
        _ = policy_for_quant(quants[i])
        for j in range(i + 1, len(quants)):
            if quants[i] == quants[j]:
                raise Error(
                    "CoherenceHarness: duplicate quant entry "
                    + quants[i]
                )


def _check_axis(axis: List[String], name: String) raises:
    if len(axis) == 0:
        raise Error("CoherenceHarness: " + name + " axis is empty")
    for i in range(len(axis)):
        for j in range(i + 1, len(axis)):
            if axis[i] == axis[j]:
                raise Error(
                    "CoherenceHarness: duplicate " + name
                    + " entry " + axis[i]
                )


def build_harness(
    quants: List[String], archs: List[String], backends: List[String]
) raises -> List[HarnessRow]:
    """One score row per IQ cell, in axis order
    (quant, then arch, then backend). Every row's
    obligation is read from the banked A-115 policy
    by call; a row whose obligation is not
    COHERENCE_ONLY is refused, never filed."""
    _check_quants(quants)
    _check_axis(archs, String("arch"))
    _check_axis(backends, String("backend"))
    var rows = List[HarnessRow]()
    for qi in range(len(quants)):
        var prow = policy_for_quant(quants[qi])
        if prow.obligation != POLICY_COHERENCE_ONLY:
            raise Error(
                "CoherenceHarness: quant is not coherence-"
                "only per A-115: " + quants[qi]
            )
        for ai in range(len(archs)):
            for bi in range(len(backends)):
                var reason = String("NO_FILED_GENERATIONS")
                if backends[bi] != String(CH_GRADED_BACKEND):
                    reason = String("BACKEND_NO_CPU_COMPARATOR")
                elif archs[ai] != String(CH_GRADED_ARCH):
                    reason = String("NO_FILED_RECORDS")
                rows.append(
                    HarnessRow(
                        quants[qi], archs[ai], backends[bi],
                        MX_NOT_GRADED, reason, prow.obligation,
                        CH_NO_SCORE,
                    )
                )
    return rows^


# --- The SYNTHETIC sanity fixture (R4; status:
# SYNTHETIC, never hidden). Stated text samples
# scored by S1-S8; every defect named. ---


struct SynCase(Copyable, ImplicitlyCopyable):
    var name: String
    var verdict: Int
    var reason: String
    var words: Int
    var score_x1000: Int

    def __init__(
        out self,
        name: String,
        verdict: Int,
        reason: String,
        words: Int,
        score_x1000: Int,
    ):
        self.name = name
        self.verdict = verdict
        self.reason = reason
        self.words = words
        self.score_x1000 = score_x1000


def _topics(items: List[String]) -> List[String]:
    return items.copy()


def _score_or_refused(
    text: String, topics: List[String], prompt: String
) -> ScoreResult:
    """The fixture's scoring door: a scorer refusal
    (the empty sample) is filed as COHERENCE_FAIL /
    EMPTY_SAMPLE_REFUSED with zeroed witnesses --
    the refusal itself is the evidence."""
    try:
        return score_sample(text, topics, prompt)
    except:
        return ScoreResult(
            POL_COHERENCE_FAIL,
            String("EMPTY_SAMPLE_REFUSED"),
            SampleMetrics(0, 0, 0, 0, 0, 0, 0, False, 0),
        )


def syn_cases() -> List[SynCase]:
    var cases = List[SynCase]()
    var good1 = String(
        "Hospitality is the friendly and generous "
        "reception of guests who arrive at a house or "
        "an inn. A good host offers food, drink, and a "
        "warm place beside the fire. Guests remember "
        "that welcome long after the road has taken "
        "them home again."
    )
    var t1 = List[String]()
    t1.append(String("hospitality"))
    t1.append(String("guests"))
    var r1 = _score_or_refused(good1, t1, String(""))
    cases.append(
        SynCase(
            String("SYN_GOOD_HOSPITALITY"), r1.verdict, r1.reason,
            r1.metrics.words, r1.metrics.score_x1000,
        )
    )
    var good2 = String(
        "The harbour woke slowly as pale smoke rose "
        "from the chimneys above the quiet water. "
        "Fishermen carried their heavy nets down to "
        "the boats and called to one another across "
        "the bay. By noon the market stalls were full "
        "of silver fish and the smell of salt and "
        "bread."
    )
    var t2 = List[String]()
    t2.append(String("harbour"))
    t2.append(String("fishermen"))
    var r2 = _score_or_refused(good2, t2, String(""))
    cases.append(
        SynCase(
            String("SYN_GOOD_HARBOUR"), r2.verdict, r2.reason,
            r2.metrics.words, r2.metrics.score_x1000,
        )
    )
    var loop = String(
        "the hotel is good. the hotel is good. "
        "the hotel is good. the hotel is good. "
        "the hotel is good. the hotel is good. "
        "the hotel is good. the hotel is good."
    )
    var r3 = _score_or_refused(loop, List[String](), String(""))
    cases.append(
        SynCase(
            String("SYN_LOOP"), r3.verdict, r3.reason,
            r3.metrics.words, r3.metrics.score_x1000,
        )
    )
    var garbage = String(
        "The � output � fell apart � into � broken "
        "symbols and silent noise today. Every second "
        "word on the page dissolved into marks that "
        "no reader could ever hope to follow home."
    )
    var r4 = _score_or_refused(garbage, List[String](), String(""))
    cases.append(
        SynCase(
            String("SYN_GARBAGE"), r4.verdict, r4.reason,
            r4.metrics.words, r4.metrics.score_x1000,
        )
    )
    var r5 = _score_or_refused(
        String("hello there friend"), List[String](), String("")
    )
    cases.append(
        SynCase(
            String("SYN_SHORT"), r5.verdict, r5.reason,
            r5.metrics.words, r5.metrics.score_x1000,
        )
    )
    var r6 = _score_or_refused(
        String("!!! ??? ,,, ... ;;; --- !!!"),
        List[String](),
        String(""),
    )
    cases.append(
        SynCase(
            String("SYN_PUNCT"), r6.verdict, r6.reason,
            r6.metrics.words, r6.metrics.score_x1000,
        )
    )
    var offtopic = String(
        "A processor keeps recently used data in a "
        "small cache close to its fastest cores. Later "
        "requests can then be served far more quickly "
        "than a fetch from main memory. This simple "
        "idea shapes the design of almost every "
        "modern machine."
    )
    var r7 = _score_or_refused(offtopic, t1.copy(), String(""))
    cases.append(
        SynCase(
            String("SYN_OFFTOPIC"), r7.verdict, r7.reason,
            r7.metrics.words, r7.metrics.score_x1000,
        )
    )
    var r8 = _score_or_refused(good1.copy(), t1.copy(), good1.copy())
    cases.append(
        SynCase(
            String("SYN_ECHO"), r8.verdict, r8.reason,
            r8.metrics.words, r8.metrics.score_x1000,
        )
    )
    var r9 = _score_or_refused(
        String(""), List[String](), String("")
    )
    cases.append(
        SynCase(
            String("SYN_EMPTY"), r9.verdict, r9.reason,
            r9.metrics.words, r9.metrics.score_x1000,
        )
    )
    return cases^


struct HarnessReport(Copyable, Movable):
    var rows: List[HarnessRow]
    var syn: List[SynCase]
    var total: Int
    var passed: Int
    var failed: Int
    var not_graded: Int
    var backend_not_graded: Int
    var arch_not_graded: Int
    var no_generations: Int
    var owed: Int
    var coherence: Int
    var syn_total: Int
    var syn_pass: Int
    var syn_fail: Int
    var digest: UInt64

    def __init__(
        out self,
        rows: List[HarnessRow],
        syn: List[SynCase],
        total: Int,
        passed: Int,
        failed: Int,
        not_graded: Int,
        backend_not_graded: Int,
        arch_not_graded: Int,
        no_generations: Int,
        owed: Int,
        coherence: Int,
        syn_total: Int,
        syn_pass: Int,
        syn_fail: Int,
        digest: UInt64,
    ):
        self.rows = rows.copy()
        self.syn = syn.copy()
        self.total = total
        self.passed = passed
        self.failed = failed
        self.not_graded = not_graded
        self.backend_not_graded = backend_not_graded
        self.arch_not_graded = arch_not_graded
        self.no_generations = no_generations
        self.owed = owed
        self.coherence = coherence
        self.syn_total = syn_total
        self.syn_pass = syn_pass
        self.syn_fail = syn_fail
        self.digest = digest


def run_harness() raises -> HarnessReport:
    var rows = build_harness(
        iq_quants(), harness_archs(), harness_backends()
    )
    var passed = 0
    var failed = 0
    var not_graded = 0
    var backend_ng = 0
    var arch_ng = 0
    var no_gen = 0
    var owed = 0
    var coherence = 0
    for i in range(len(rows)):
        # Matrix rows carry A-114 MX_* codes; the A-115
        # POL_* coherence codes are a separate namespace
        # (the two are filed separately and never mixed,
        # per A-115's header -- MX_NOT_GRADED and
        # POL_COHERENCE_PASS share a numeral by
        # coincidence and must not be conflated here).
        if rows[i].verdict == MX_NOT_GRADED:
            not_graded += 1
        if rows[i].reason == String("BACKEND_NO_CPU_COMPARATOR"):
            backend_ng += 1
        elif rows[i].reason == String("NO_FILED_RECORDS"):
            arch_ng += 1
        elif rows[i].reason == String("NO_FILED_GENERATIONS"):
            no_gen += 1
        if rows[i].obligation == POLICY_COHERENCE_ONLY:
            coherence += 1
        else:
            owed += 1
    var syn = syn_cases()
    var syn_pass = 0
    var syn_fail = 0
    for i in range(len(syn)):
        if syn[i].verdict == POL_COHERENCE_PASS:
            syn_pass += 1
        elif syn[i].verdict == POL_COHERENCE_FAIL:
            syn_fail += 1
    var report = HarnessReport(
        rows.copy(), syn.copy(), len(rows), passed, failed,
        not_graded, backend_ng, arch_ng, no_gen, owed, coherence,
        len(syn), syn_pass, syn_fail, UInt64(0),
    )
    report.digest = mx_fnv1a64(harness_render(report.copy()))
    return report^


def harness_row_line(row: HarnessRow) -> String:
    var s = String("CH_ROW quant=") + row.quant
    s += String(" arch=") + row.arch
    s += String(" backend=") + row.backend
    s += String(" verdict=") + matrix_verdict_name(row.verdict)
    s += String(" reason=") + row.reason
    s += String(" policy=COHERENCE_ONLY")
    s += String(" score_x1000=") + String(row.score_x1000)
    return s


def syn_case_line(scase: SynCase) -> String:
    var s = String("CH_SYN case=") + scase.name
    s += String(" status=") + String(CH_FIXTURE_STATUS)
    s += String(" verdict=") + coherence_verdict_name(scase.verdict)
    s += String(" reason=") + scase.reason
    s += String(" words=") + String(scase.words)
    s += String(" score_x1000=") + String(scase.score_x1000)
    return s


def harness_render(read report: HarnessReport) -> String:
    var s = String("A127_HARNESS quants=")
    s += String(len(iq_quants()))
    s += String(" archs=") + String(len(harness_archs()))
    s += String(" backends=") + String(len(harness_backends()))
    s += String(" total=") + String(report.total)
    s += String(" fixture_status=") + String(CH_FIXTURE_STATUS)
    s += String("\n")
    for i in range(len(report.rows)):
        s += harness_row_line(report.rows[i]) + String("\n")
    for i in range(len(report.syn)):
        s += syn_case_line(report.syn[i]) + String("\n")
    s += String("A127_HARNESS_SUMMARY total=") + String(report.total)
    s += String(" pass=") + String(report.passed)
    s += String(" fail=") + String(report.failed)
    s += String(" not_graded=") + String(report.not_graded)
    s += String(" backend_not_graded=")
    s += String(report.backend_not_graded)
    s += String(" arch_not_graded=") + String(report.arch_not_graded)
    s += String(" no_generations=") + String(report.no_generations)
    s += String(" owed=") + String(report.owed)
    s += String(" coherence=") + String(report.coherence)
    s += String("\n")
    s += String("A127_SYNTHETIC_SUMMARY status=")
    s += String(CH_FIXTURE_STATUS)
    s += String(" total=") + String(report.syn_total)
    s += String(" pass=") + String(report.syn_pass)
    s += String(" fail=") + String(report.syn_fail)
    return s


def harness_line() -> String:
    return String(
        "A-127 Coherence grading harness: the 9 IQ"
        " quants (A-115 coherence-only, by call) x 3"
        " archs x 4 backends = 108 score rows filed;"
        " every cell NOT_GRADED with a named reason"
        " (no filed sampled generations for any IQ"
        " cell), score -1, zero unexplained; the pure"
        " text scorer sanity-checked on the SYNTHETIC"
        " fixture (labelled SYNTHETIC in every line):"
        " 2 known-good pass, 7 known-broken fail with"
        " named defects; IQ graded on coherence,"
        " never token-exactness"
    )
