"""Sliding-window service accounting (Janas road J-097).

The roadmap text: "Sliding-window service. For
editor-style workloads (Part VII's completion), a
windowed context that re-reads a moved line cheaply
(Janas's completion doc names the cost it avoids);
Aesir's version measured."

DESIGN, stated up front (the J-097 doc,
docs/janas/J097_SLIDING_WINDOW.md, is its normative
text; this header records the definitions and verdict
rules PRE-REGISTERED before any J-097 number was
produced). No Janas material was consulted in this
slice: the service is defined and graded entirely
through Aesir's own filed modules (J-087's KV census,
J-088's int8 store, J-091's ladder, J-092's attention
share, J-094's prompt-read account, J-096's prefix
conservation, and the tree's own exact-token prefix
surface core/prompt_prefix). Where Janas's public
completion documentation names a cost this service
avoids, that naming is the roadmap's; the cost itself
is priced here only in Aesir's filed units.

(a) THE WINDOW SERVICE and SUFFIX INVALIDATION. The
service retains, for the current version of an
editor document, the document's token sequence and
the KV rows of its committed positions: the WINDOW
is that retained segment [0, L) of the current
version, bounded by the witness profile's context
cap (32,768; the section (b) workload sits inside
it). On an edit, the service computes the FIRST
DIVERGENCE between the old and new token sequences
(exact token comparison, the same comparison
core/prompt_prefix performs): the first position C
whose token differs, or the shorter length when one
sequence is a prefix of the other. Positions p < C
hold the same token at the same position with the
same causal ancestry, so their KV rows stay valid
(the window's anchored prefix). Positions p >= C
are invalid -- an edited token changes the causal
ancestry of every later position at every layer
past the first, an inserted or deleted line SLIDES
every later position by the length delta (its
tokens are the same but their positions and
ancestry changed), and a MOVED line's own rows are
NOT reusable at its new position (position and
ancestry both changed) -- and are recomputed by the
ordinary prefill. "Re-reads a moved line cheaply"
means exactly this and no more: the re-read of a
moved line costs the suffix from the EARLIER of its
two endpoints, never the whole document unless the
earlier endpoint is position 0. This service is not
the architecture's sliding-window attention (the
Gemma local layers in core/compute.mojo): that is a
model property; this is a context-retention service
over versions of one document. Documents longer
than the cap are NOT claimed: retaining only a
trailing part would change attention semantics and
is a different, unbuilt service (section (e)).

(b) WORKLOAD MODEL (editor-style, deterministic).
The document is 128 lines x 64 tokens = 8,192
tokens (a ladder rung, J-091/J-094) of the ladder
witness (Qwen2.5-Coder-7B: 28 layers, hidden 3,584,
ffn 18,944, 28 query heads, 4 kv heads, head_dim
128, file 4,683,074,688 B). Nine edit shapes, one
occurrence each, stated before measuring:
  EDIT_LATE    edit in place, line 96 (C = 6,144)
  EDIT_EARLY   edit in place, line 8 (C = 512)
  EDIT_FIRST   edit in place, line 0 (C = 0)
  MOVE_LATE    line 100 moved to the end (C = 6,400)
  MOVE_EARLY   line 8 moved to line 96 (C = 512)
  INSERT_MID   a new 64-token line at line 32
               (C = 2,048, new length 8,256)
  DELETE_MID   line 32 deleted (C = 2,048, new
               length 8,128)
  APPEND       a new line appended (C = 8,192, new
               length 8,256)
  NO_CHANGE    the same document re-presented
               (no divergence, C = 8,192)
The MIX is the unweighted sum over these nine
shapes. Token comparison itself is host integer
work over at most min(old, new) positions -- no
model work, charged to no MAC account, and bounded
by the document length; it is stated so it is never
smuggled into, or out of, the account.

(c) COST DEFINITION (filed units only; no wall is
measured on this VM in this slice). Through
core/prompt_read (J-094) over core/kv_ladder
(J-091): W(L) is the accounted read work of a
prompt of L tokens (attention + projection MACs;
the head pass is the first generated token's, never
the read's). REUSE is the number of leading
positions whose KV the service keeps: the first
divergence capped by the tree's FINAL-TOKEN rule --
core/prompt_prefix never reuses the final prompt
token (it always recomputes activations/logits), so
REUSE = min(C, new_length - 1), and also never more
than the old length holds. Per shape:
  NAIVE COST   = W(new_length) -- the full re-read
    an editor integration without this service pays
    on every edit (J-094's account).
  AVOIDED      = W(REUSE) exactly (J-096's prefix
    conservation: the kept prefix's work is the
    read work at REUSE; suffix projections are
    per-token constant and suffix attention pairs
    are the total pairs minus the prefix pairs).
  WINDOW COST  = NAIVE - AVOIDED = W(new_length)
    - W(REUSE): the suffix recompute, final token
    included wherever the cap binds.
  KV REWRITTEN = (new_length - REUSE) x the
    per-token KV price at the precision (f16
    through J-087, per-row int8 through J-088, both
    through core/kv_persistence's pricing so this
    account cannot drift from J-096's).
  SAVED PPM    = AVOIDED as floored ppm of NAIVE.

(d) CORRECTNESS RULE. The windowed result must
equal the full re-read's result, and the equality
is stated in two parts, never blurred: positions
p < REUSE are BIT-EXACT BY CONSTRUCTION against the
full re-read at the same precision -- same token,
same position, same causal ancestry at every layer
(by induction on layers: a position's layer-l KV
depends only on tokens at positions <= p through
layers < l), so a deterministic forward recomputes
the identical rows the window kept; and positions
p >= REUSE are RECOMPUTED by the ordinary prefill,
not approximated -- no row is reused across a
divergence, a position shift, or a move. The
divergence computation is exercised on real token
lists for every section (b) shape in the tests
(the predicted C must equal the computed first
divergence of the concretely edited sequences).
Whether a live session's kept rows are bit-identical
in practice is a live question: NOT PROVEN here,
deferred to the J-098 gate recipe in the doc, and
the first consumer (J-111, Part VII code completion)
inherits that deferral by name.

VERDICT RULE (pre-registered) -- KEPT ONLY IF IT
PAYS. The service is KEPT iff ALL of:
  (1) EXACTNESS: the divergence exercise passes for
    every shape (the tests) -- a mispredicted
    divergence withdraws the service, it is not
    filed;
  (2) NEVER WORSE: every shape's WINDOW COST <= its
    NAIVE COST, and every shape with REUSE > 0 is
    strictly cheaper than its naive re-read (the
    C = 0 shape may only tie: a first-line edit has
    no prefix to keep, and the service must say so
    rather than hide it);
  (3) THE MIX PAYS: the section (b) mix's SAVED PPM
    >= KW_MIN_SAVED_PPM (250,000 ppm -- a quarter of
    the naive re-read work over the stated editor
    mix, stated before measuring).
Any other outcome grades NOT_KEPT with its numbers
filed (J-025 / J-027 / J-090 precedents: a measured
rejection is a complete closure). Two bounds hold
whatever the rule returns: NO SESSION IS WIRED (no
editor or completion session consumes this service
today; int8 session integration is
INTEGRATION_BLOCKED, J-091, and the host prefix
surface this service's reuse cap follows is wired
only into the CUDA Llama session, not into any
editor surface) -- the inspect asserts the
no-wiring fact; and every live quantity (any wall,
any editor latency, J-111's published-class
comparison) is NOT PROVEN in this slice and is
filed as DEFERRED-WITH-REASON to the J-098 gate.

(e) WHAT IS NOT BUILT. No eviction or trailing-
window retention for over-cap documents, no
per-line KV relocation (a moved line's rows are
recomputed, section (a) -- a relocation that
re-based positions would need a position-remapping
proof this slice does not claim), no session or
editor wiring, and no live measurement. The built
surface is the account + the divergence mechanism
of this module, exercised deterministically.

HOST CONTRACT: (1) price every sliding-window claim
through this module; (2) reuse only positions below
kw_reusable for an edit whose divergence was
computed by exact token comparison over the actual
old and new sequences -- never a line-count guess;
(3) a mismatch between a shape's predicted and
computed divergence is a defect, filed, never
smoothed over; (4) a live wall or a faithfulness
grade may be filed only from a run under the J-097
doc section 7 recipe at the J-098 gate (guarded
window, sha-pin, machine state, ids-first
raw-oracle grading, never llama-cli --single-turn).
"""

from core.kv_persistence import KVP_PRECISION_F16, KVP_PRECISION_INT8, kvp_per_token
from core.prompt_read import read_work_total

comptime KW_KEPT = 0
comptime KW_NOT_KEPT = 1

comptime KW_SAVES = 0
comptime KW_NO_SAVE = 1

comptime KW_EDIT_IN_PLACE = 0
comptime KW_MOVE = 1
comptime KW_INSERT = 2
comptime KW_DELETE = 3
comptime KW_APPEND = 4
comptime KW_NO_CHANGE = 5

comptime KW_MIN_SAVED_PPM = 250000

# The section (b) workload geometry.
comptime KW_DOC_LINES = 128
comptime KW_TOKENS_PER_LINE = 64
comptime KW_DOC_TOKENS = 8192


def kw_verdict_name(code: Int) raises -> String:
    if code == KW_KEPT:
        return String("KEPT")
    if code == KW_NOT_KEPT:
        return String("NOT_KEPT")
    raise Error("KVWindow: unknown verdict code")


def kw_shape_verdict_name(code: Int) raises -> String:
    if code == KW_SAVES:
        return String("SAVES")
    if code == KW_NO_SAVE:
        return String("NO_SAVE")
    raise Error("KVWindow: unknown shape verdict code")


# -- divergence and reuse -------------------------------------------------


def kw_first_divergence(old: List[Int], new: List[Int]) -> Int:
    """The first position whose token differs between
    the old and new sequences, or the shorter length
    when one is a prefix of the other (exact token
    comparison -- the comparison core/prompt_prefix
    performs, returning the divergence itself)."""
    var limit = min(len(old), len(new))
    var count = 0
    while count < limit and old[count] == new[count]:
        count += 1
    return count


def kw_reusable(old_len: Int, new_len: Int, first_div: Int) raises -> Int:
    """Leading positions whose KV survives an edit:
    the first divergence, capped by the tree's
    final-token rule (the final prompt token always
    recomputes, core/prompt_prefix) and by the old
    length (a position the old version never held
    has no row to keep)."""
    if old_len <= 0 or new_len <= 0:
        raise Error("KVWindow: document lengths must be positive")
    if first_div < 0 or first_div > min(old_len, new_len):
        raise Error("KVWindow: first divergence lies outside both documents")
    var reuse = min(first_div, new_len - 1)
    return min(reuse, old_len)


# -- shape predictions ------------------------------------------------------


def _check_doc(lines: Int, tokens_per_line: Int) raises:
    if lines <= 0 or tokens_per_line <= 0:
        raise Error("KVWindow: document geometry must be positive")


def kw_shape_first_divergence(
    shape: Int, lines: Int, tokens_per_line: Int, a: Int, b: Int
) raises -> Int:
    """The stated first divergence (in tokens) of one
    edit shape over a document of `lines` lines of
    `tokens_per_line` tokens. `a` is the edited /
    moved-from / inserted-at / deleted line; for
    KW_MOVE, `b` is the moved line's new start line.
    APPEND and NO_CHANGE diverge at the old length
    (no kept position is disturbed)."""
    _check_doc(lines, tokens_per_line)
    if shape == KW_EDIT_IN_PLACE:
        if a < 0 or a >= lines:
            raise Error("KVWindow: edited line outside the document")
        return a * tokens_per_line
    if shape == KW_MOVE:
        if a < 0 or a >= lines or b < 0 or b >= lines:
            raise Error("KVWindow: moved line or destination outside the document")
        return min(a, b) * tokens_per_line
    if shape == KW_INSERT:
        if a < 0 or a > lines:
            raise Error("KVWindow: insertion line outside the document")
        return a * tokens_per_line
    if shape == KW_DELETE:
        if a < 0 or a >= lines:
            raise Error("KVWindow: deleted line outside the document")
        return a * tokens_per_line
    if shape == KW_APPEND or shape == KW_NO_CHANGE:
        return lines * tokens_per_line
    raise Error("KVWindow: unknown edit shape code")


def kw_shape_new_len(shape: Int, lines: Int, tokens_per_line: Int) raises -> Int:
    """The document length (tokens) after one shape:
    in-place edits, moves and re-presentation keep
    the length; an insertion or append adds one
    line; a deletion removes one."""
    _check_doc(lines, tokens_per_line)
    var base = lines * tokens_per_line
    if (
        shape == KW_EDIT_IN_PLACE or shape == KW_MOVE
        or shape == KW_NO_CHANGE
    ):
        return base
    if shape == KW_INSERT or shape == KW_APPEND:
        return base + tokens_per_line
    if shape == KW_DELETE:
        if lines < 2:
            raise Error("KVWindow: a deletion needs at least two lines")
        return base - tokens_per_line
    raise Error("KVWindow: unknown edit shape code")


# -- the account ------------------------------------------------------------


def kw_work_at(
    layers: Int, hidden: Int, q_width: Int, kv_width: Int, ffn: Int, length: Int
) raises -> Int:
    """J-094's read work at `length` through
    core/prompt_read; W(0) is 0 by definition (an
    empty prefix has no read work -- prompt_read
    itself refuses a zero rung, so the zero is
    stated here, not smuggled through it)."""
    if length < 0:
        raise Error("KVWindow: a length cannot be negative")
    if length == 0:
        return 0
    return read_work_total(layers, hidden, q_width, kv_width, ffn, length)


struct WindowAccount(Copyable, ImplicitlyCopyable):
    """One edit's window account (the header's
    section (c)): the naive full re-read, the work
    the kept prefix avoids, the window's own cost,
    the saved ppm, and the KV bytes the suffix
    rewrite writes at each precision."""

    var naive_work: Int
    var avoided_work: Int
    var window_work: Int
    var saved_ppm: Int
    var kv_rewritten_f16: Int
    var kv_rewritten_int8: Int

    def __init__(
        out self,
        naive_work: Int,
        avoided_work: Int,
        window_work: Int,
        saved_ppm: Int,
        kv_rewritten_f16: Int,
        kv_rewritten_int8: Int,
    ):
        self.naive_work = naive_work
        self.avoided_work = avoided_work
        self.window_work = window_work
        self.saved_ppm = saved_ppm
        self.kv_rewritten_f16 = kv_rewritten_f16
        self.kv_rewritten_int8 = kv_rewritten_int8


def kw_account(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    kv_heads: Int,
    head_dim: Int,
    new_len: Int,
    reuse: Int,
) raises -> WindowAccount:
    """The section (c) account for one edit whose new
    document is `new_len` tokens and whose kept
    prefix is `reuse` positions."""
    if new_len <= 0:
        raise Error("KVWindow: the new document must be positive")
    if reuse < 0 or reuse >= new_len:
        raise Error("KVWindow: reuse must satisfy 0 <= reuse < new length")
    var naive = kw_work_at(layers, hidden, q_width, kv_width, ffn, new_len)
    var avoided = kw_work_at(layers, hidden, q_width, kv_width, ffn, reuse)
    var rewritten = new_len - reuse
    return WindowAccount(
        naive,
        avoided,
        naive - avoided,
        avoided * 1000000 // naive,
        rewritten * kvp_per_token(KVP_PRECISION_F16, layers, kv_heads, head_dim),
        rewritten * kvp_per_token(KVP_PRECISION_INT8, layers, kv_heads, head_dim),
    )


def kw_shape_verdict(naive_work: Int, window_work: Int) raises -> Int:
    """Per-shape verdict: SAVES iff the windowed
    re-read is strictly cheaper than the naive full
    re-read; NO_SAVE on a tie (the C = 0 shape) --
    a window cost above naive is refused as an
    accounting error, never filed as a verdict."""
    if naive_work <= 0 or window_work < 0:
        raise Error("KVWindow: shape work inputs must be non-negative, naive positive")
    if window_work > naive_work:
        raise Error("KVWindow: window cost above the naive cost is an accounting error")
    if window_work < naive_work:
        return KW_SAVES
    return KW_NO_SAVE


def kw_service_verdict(
    total_avoided: Int, total_naive: Int, never_worse: Bool, exact: Bool
) raises -> Int:
    """The header's verdict rule in mechanical form:
    KEPT iff the divergence exercise was exact,
    no shape was worse than naive, and the mix's
    saved ppm reaches KW_MIN_SAVED_PPM."""
    if total_naive <= 0 or total_avoided < 0 or total_avoided > total_naive:
        raise Error("KVWindow: mix totals must satisfy 0 <= avoided <= naive, naive positive")
    if not exact or not never_worse:
        return KW_NOT_KEPT
    if total_avoided * 1000000 // total_naive < KW_MIN_SAVED_PPM:
        return KW_NOT_KEPT
    return KW_KEPT
