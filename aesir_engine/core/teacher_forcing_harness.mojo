# core/teacher_forcing_harness.mojo
# A-109: Teacher-forcing harness v2 -- ONE harness grading every
# backend: teacher-forcing rank + logit gap computed on RAW
# prompts, with the A-045 CPU matrix encoded as data so the
# harness itself reproduces (and can re-check) those results.
#
# Raw-oracle discipline is this module's core law:
#   - Rows come from teacher-forcing on RAW prompts only, never
#     template-rendered prompts. A deliberately template-rendered
#     input is DETECTED and REJECTED by the harness itself
#     (tf_detect_template / tf_validate_run) before any grading.
#   - The A-045 reproduction is CPU engine vs CPU comparator
#     ONLY; a run naming any other oracle backend for that
#     reproduction is rejected as BACKEND_MISMATCH, a comparator
#     artifact verdict class -- never filed as engine divergence.
#   - Grading arithmetic is the banked A-045 arithmetic
#     (core/parity_battery): rank 1 = faithful; rank <= 2 with
#     sub-logit gap (< 1.0) = near-tie (faithful band); else
#     divergence requiring a verdict class. IQ rows are graded
#     on rank/gap/coherence, never token-exactness.
#   - Every graded run records its oracle backend per run; a row
#     without a named oracle backend is invalid, not defaulted.
#
# What v2 adds over the A-045 battery driver: (1) the grading
# entry point takes logit rows from ANY backend through the one
# tf_grade_rows function, so later backends cannot drift to
# their own arithmetic; (2) template detection runs inside the
# harness, not in the operator's head; (3) the A-045 CPU matrix
# is data in this module (a045_matrix) and tf_reproduces_a045
# is an exact cell-for-cell check of a candidate matrix against
# it; (4) every run summary carries an FNV-1a digest so a
# reproduction is byte-identical, not eyeballed.

from core.parity_battery import (
    parity_logit_gap,
    parity_logit_rank,
    parity_verdict_code,
)

comptime TF_OK = 0
comptime TF_REJECT_TEMPLATE = 1
comptime TF_REJECT_BACKEND_MISMATCH = 2
comptime TF_REJECT_NO_ORACLE = 3

comptime TF_CPU_ORACLE_SHA = "57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3"


def tf_reject_name(code: Int) -> String:
    if code == TF_OK:
        return String("accepted")
    if code == TF_REJECT_TEMPLATE:
        return String("TEMPLATE_RENDERED")
    if code == TF_REJECT_BACKEND_MISMATCH:
        return String("BACKEND_MISMATCH")
    if code == TF_REJECT_NO_ORACLE:
        return String("NO_ORACLE_BACKEND")
    return String("unknown")


def tf_template_markers() -> List[String]:
    var m = List[String]()
    m.append(String("<|im_start|>"))
    m.append(String("<|im_end|>"))
    m.append(String("<|end_of_turn|>"))
    m.append(String("[INST]"))
    m.append(String("[/INST]"))
    m.append(String("<<SYS>>"))
    m.append(String("<start_of_turn>"))
    m.append(String("<end_of_turn>"))
    m.append(String("### Instruction:"))
    m.append(String("### Human:"))
    m.append(String("### Assistant:"))
    return m^


def tf_detect_template(prompt: String) -> Bool:
    """True when the prompt carries any chat-template rendering
    marker. RAW prompts in the A-045/A-030 standard (plain text,
    tokenizer add_bos only, no chat template) never carry these;
    a prompt that does was rendered by a template -- the exact
    comparator artifact that manufactured fake divergences when
    graded as if raw (llama-cli --single-turn trap)."""
    var markers = tf_template_markers()
    for i in range(len(markers)):
        if markers[i] in prompt:
            return True
    if prompt.startswith("<s>"):
        return True
    return False


def tf_validate_run(
    prompt: String, engine_backend: String, oracle_backend: String
) -> Int:
    """Harness gate, run before any grading. Returns TF_OK or a
    rejection code: template-rendered input is rejected by the
    harness itself; the A-045 CPU reproduction requires a named
    CPU oracle and a CPU engine (CPU vs CPU only)."""
    if tf_detect_template(prompt):
        return TF_REJECT_TEMPLATE
    if oracle_backend.byte_length() == 0:
        return TF_REJECT_NO_ORACLE
    if oracle_backend != String("cpu") or engine_backend != String("cpu"):
        return TF_REJECT_BACKEND_MISMATCH
    return TF_OK


def tf_harness_backends() -> List[String]:
    """Every backend this one harness grades. The grading entry
    point is identical for all of them; only the A-045 CPU
    reproduction pins engine+oracle to cpu (tf_validate_run)."""
    var b = List[String]()
    b.append(String("cpu"))
    b.append(String("vulkan"))
    b.append(String("hip"))
    b.append(String("npu"))
    return b^


def tf_fnv1a64(text: String) -> UInt64:
    var hash: UInt64 = 14695981039346656037
    var prime: UInt64 = 1099511628211
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        hash = hash ^ UInt64(bytes[i])
        hash = hash * prime
    return hash


struct TfGrade(Copyable, ImplicitlyCopyable):
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var worst_rank: Int
    var max_gap: Float32
    var mean_gap: Float32

    def __init__(
        out self,
        faithful: Int = 0,
        near_tie: Int = 0,
        divergent: Int = 0,
        worst_rank: Int = 0,
        max_gap: Float32 = Float32(0.0),
        mean_gap: Float32 = Float32(0.0),
    ):
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.worst_rank = worst_rank
        self.max_gap = max_gap
        self.mean_gap = mean_gap


def tf_grade_rows(
    rows: List[List[Float32]], seq: List[Int], prompt_len: Int
) -> TfGrade:
    """THE one grading entry point for every backend. Teacher-
    forcing: rows[p] is the logit row after seq[p]; it grades
    seq[p+1]. Continuation positions only (p+1 >= prompt_len);
    prompt-internal positions are the prompt-boundary comparator
    class and are excluded, exactly as in A-045. Mean gap is over
    the continuation positions (32 in the A-045 standard)."""
    var g = TfGrade()
    var count = 0
    var gap_sum = Float32(0.0)
    for p in range(len(seq) - 1):
        if p + 1 < prompt_len:
            continue
        var target = seq[p + 1]
        var rank = parity_logit_rank(rows[p], target)
        var gap = parity_logit_gap(rows[p], target)
        var code = parity_verdict_code(rank, gap)
        if code == 0:
            g.faithful += 1
        elif code == 1:
            g.near_tie += 1
        else:
            g.divergent += 1
        if rank > g.worst_rank:
            g.worst_rank = rank
        if gap > g.max_gap:
            g.max_gap = gap
        gap_sum += gap
        count += 1
    if count > 0:
        g.mean_gap = gap_sum / Float32(count)
    return g


struct A045Row(Copyable, ImplicitlyCopyable):
    var label: String
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var worst_rank: Int
    var max_gap_x10000: Int
    var mean_gap_x10000: Int
    var greedy_match: Int
    var verdict: String

    def __init__(
        out self,
        label: String,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        worst_rank: Int,
        max_gap_x10000: Int,
        mean_gap_x10000: Int,
        greedy_match: Int,
        verdict: String,
    ):
        self.label = label
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.worst_rank = worst_rank
        self.max_gap_x10000 = max_gap_x10000
        self.mean_gap_x10000 = mean_gap_x10000
        self.greedy_match = greedy_match
        self.verdict = verdict


def a045_matrix() -> List[A045Row]:
    """The A-045 CPU matrix, as data (docs/bench/
    A045_CPU_PARITY_BATTERY.md; gaps scaled x10000, truncated
    as printed to 4 decimals there). Ten measured rows; the
    nine IQ-labelled rows are NOT here -- they are the fixture-
    limitation count in a045_iq_fixture_limited_count."""
    var r = List[A045Row]()
    r.append(A045Row("F16", 32, 0, 0, 1, 0, 0, 32, "faithful"))
    r.append(A045Row("BF16", 32, 0, 0, 1, 0, 0, 32, "faithful"))
    r.append(A045Row("Q8_0", 32, 0, 0, 1, 0, 0, 32, "faithful"))
    r.append(A045Row("Q4_0", 27, 3, 2, 3, 15703, 962, 10, "divergence-quant-noise"))
    r.append(A045Row("Q5_0", 31, 1, 0, 2, 156, 5, 16, "faithful+near-tie"))
    r.append(A045Row("Q2_K", 27, 3, 2, 3, 15703, 962, 10, "fixture-artifact"))
    r.append(A045Row("Q3_K_M", 29, 1, 2, 5, 13828, 657, 4, "divergence-quant-noise"))
    r.append(A045Row("Q4_K_M", 31, 1, 0, 2, 938, 29, 29, "faithful+near-tie"))
    r.append(A045Row("Q5_K_M", 32, 0, 0, 1, 0, 0, 32, "faithful"))
    r.append(A045Row("Q6_K", 32, 0, 0, 1, 0, 0, 32, "fixture-artifact"))
    return r^


def a045_iq_fixture_limited_count() -> Int:
    # IQ1_S, IQ1_M, IQ2_XXS, IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S,
    # IQ4_NL, IQ4_XS: fixture limitation verdict in A-045 (the
    # stories260K fixture cannot satisfy the 256-value IQ super-
    # block by construction; not an engine defect).
    return 9


def tf_reproduces_a045(candidate: List[A045Row]) -> Bool:
    """Exact cell-for-cell reproduction check: same row count,
    same labels in order, same counts, worst ranks, scaled gaps,
    greedy matches and verdicts. Any drift returns False -- the
    caller files it as a reproduction failure, never re-grades
    it as a new divergence."""
    var base = a045_matrix()
    if len(candidate) != len(base):
        return False
    for i in range(len(base)):
        var a = base[i]
        var b = candidate[i]
        if a.label != b.label or a.faithful != b.faithful:
            return False
        if a.near_tie != b.near_tie or a.divergent != b.divergent:
            return False
        if a.worst_rank != b.worst_rank:
            return False
        if a.max_gap_x10000 != b.max_gap_x10000:
            return False
        if a.mean_gap_x10000 != b.mean_gap_x10000:
            return False
        if a.greedy_match != b.greedy_match or a.verdict != b.verdict:
            return False
    return True


def tf_summary_line(label: String, backend: String, oracle: String, g: TfGrade) -> String:
    var s = String("TF109_SUMMARY label=") + label
    s += String(" backend=") + backend + String(" oracle_backend=") + oracle
    s += String(" faithful=") + String(g.faithful)
    s += String(" near_tie=") + String(g.near_tie)
    s += String(" divergent=") + String(g.divergent)
    s += String(" worst_rank=") + String(g.worst_rank)
    s += String(" max_gap=") + String(g.max_gap)
    s += String(" mean_gap=") + String(g.mean_gap)
    return s


def tf_summary_digest(label: String, backend: String, oracle: String, g: TfGrade) -> UInt64:
    return tf_fnv1a64(tf_summary_line(label, backend, oracle, g))
