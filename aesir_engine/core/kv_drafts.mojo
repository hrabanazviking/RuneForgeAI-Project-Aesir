"""KV + drafts accounting (Janas road J-095).

The roadmap text: "KV + drafts. Speculative verification
with 8-bit KV: rollback exactness at 8 bits, acceptance
unchanged or the difference measured."

DESIGN, stated up front (the J-095 doc,
docs/janas/J095_KV_DRAFTS.md, is its normative text; this
header records the definitions and verdict rules
PRE-REGISTERED before any J-095 number was produced).

THE TWO QUESTIONS, DEFINED THROUGH THE TREE'S OWN
MODULES (no new machinery is invented for either):

(Q1) ROLLBACK EXACTNESS. In this tree a speculative round
(J-071's account, J-072's loop) tentatively writes k+1 KV
rows, commits accepted+1, and rolls back k-accepted by
LENGTH RESTORE: the committed length returns to
snapshot + accepted + 1, and rows past it are dead -- the
host KVCache (core/mimir_well.mojo) appends by explicit
position and bounds its reads by the active length
(get_k_slice/get_v_slice take seq_len), and J-088's
Int8KVStore has the identical geometry (separate K/V
buffers, [layer][position][kv_width], append by explicit
position; attention_int8_head reads only positions
< seq_len). Neither cache clears bytes on rollback.
Rollback exactness is therefore a statement about the
STORED STATE, graded in three parts:
  (R-A) COMMITTED PRESERVATION: tentative appends at
    positions >= the snapshot length change ZERO stored
    scalars at positions < the snapshot length.
  (R-B) NEVER-DRAFTED EQUALITY: after rollback and the
    next appends overwriting the rolled-back positions
    with the plain continuation's rows, the final store
    equals the store that never drafted -- BIT-EXACT at
    the precision's own representation (f16 elements at
    f16; int8 codes AND their f32 scales at int8) -- at
    every position < the final committed length.
  (R-C) DEAD-ROW IRRELEVANCE: attention over the
    committed length is unchanged by the presence of
    tentative rows past it (the read bound at work).
BIT-EXACT is defined per precision, over that precision's
stored representation. ROLLBACK EXTRA ERROR is the
difference between the rolled-back state and the
never-drafted state AT THE SAME PRECISION: exact iff
that difference is exactly zero. The quantization error
an int8 row carries against its f16 source (J-088's
bound: <= half its row scale) is NOT rollback error --
it is present identically in the never-drafted int8
state, and this module never charges it to rollback.
VERDICT RULE (pre-registered): the rollback at a
precision is EXACT iff (R-A) diff == 0, (R-B) diff == 0
and (R-C) holds in the exercised form; any nonzero diff
grades NOT_EXACT, and the diff count is filed, never
rounded away. At the LOOP level the length/RNG rollback
is precision-free by construction: the Part V account
and loop functions take no precision input at all (this
fact is asserted mechanically by the slice's inspect
script over the modules' own text), so the loop-level
rollback J-072/J-073/J-085 proved at the account level
is the same rollback at both precisions.

(Q2) ACCEPTANCE. A round's acceptance is J-071's
accepted_count (the longest draft prefix equal to the
target's own greedy list); totals are J-075's ledger
(accepted / drafted per row). Acceptance is a function
of the draft list and the TARGET list only -- no Part V
account, loop, or ledger function takes a KV precision
input -- so at the ACCOUNT level, given the same target
lists, acceptance at int8 is UNCHANGED from f16 by
construction, and any replay of filed accounts
reproduces its totals under either label with a
difference of exactly zero. Precision can change
acceptance ONLY by changing the target lists themselves
(a model's greedy choices are a function of its logits,
which read the KV): that is a LIVE question, and it is
NOT PROVEN by anything in this module -- no live session
integrates the int8 store (J-088 section 7 deferred the
integration; J-091's ladder verdict for every int8 cell
is INTEGRATION_BLOCKED, inherited unchanged here). The
live difference, its paired measurement, and the exact
recipe are filed in the J-095 doc section 7 for the
J-098 gate. VERDICT RULE (pre-registered): account-level
acceptance grades UNCHANGED iff a replay of the filed
J-075 fixture accounts reproduces J-075's filed totals
EXACTLY (the validation gate) and the f16-labelled and
int8-labelled replays differ by exactly (0 rounds,
0 drafted, 0 accepted); a changed-target control replay
must grade DIFFERS by the exact amount its target change
implies, proving the replay can see a difference when
one exists. No simulated acceptance number is filed as
a measured live acceptance anywhere in this slice.

BYTE PRICE OF A ROUND, PER PRECISION (exact arithmetic
through core/kv_account for f16 and core/kv_int8 for
int8): the verify pass tentatively writes k+1 rows,
commits accepted+1 and discards k-accepted; this module
prices each part per token of context, so the cost of
rollback at 8 bits vs 16 bits is a filed number, not an
impression. (By-construction write shapes, in J-091's
sense: a discarded row was written and then made dead;
nothing here claims a device byte count.)

WHAT THIS MODULE IS NOT: it wires into no session,
executes no forward, times nothing, and contains no
speed and no live acceptance statistic. The first live
host grades Q1 on a real store through these same diff
functions and Q2 through J-075's ledger over filed live
accounts, per the doc section 7 recipe.
"""

from core.kv_account import KV_ELEM_F16, kv_bytes_per_token
from core.kv_int8 import Int8KVStore, kv8_bytes_per_token
from core.speculative_acceptance import AcceptanceRow
from core.speculative_verify import VerifyAccount, account_is_consistent

# Precision codes: the same values as core/kv_int8's
# KV8_PRECISION_* (f16 beside int8), so a resolved
# KvPrecisionChoice names a precision here unchanged.
comptime KVD_PRECISION_F16 = 0
comptime KVD_PRECISION_INT8 = 1

# Rollback verdicts (rule in the header).
comptime KVD_ROLLBACK_EXACT = 0
comptime KVD_ROLLBACK_NOT_EXACT = 1

# Acceptance-difference verdicts (account level; rule in
# the header). A live difference is a different claim and
# is NOT PROVEN in this slice whatever these return.
comptime KVD_ACCEPT_UNCHANGED = 0
comptime KVD_ACCEPT_DIFFERS = 1


def kvd_precision_name(code: Int) raises -> String:
    if code == KVD_PRECISION_F16:
        return String("f16")
    if code == KVD_PRECISION_INT8:
        return String("int8")
    raise Error("KvDrafts: unknown precision code")


def kvd_rollback_name(code: Int) raises -> String:
    if code == KVD_ROLLBACK_EXACT:
        return String("EXACT")
    if code == KVD_ROLLBACK_NOT_EXACT:
        return String("NOT_EXACT")
    raise Error("KvDrafts: unknown rollback verdict code")


def kvd_accept_name(code: Int) raises -> String:
    if code == KVD_ACCEPT_UNCHANGED:
        return String("UNCHANGED")
    if code == KVD_ACCEPT_DIFFERS:
        return String("DIFFERS")
    raise Error("KvDrafts: unknown acceptance verdict code")


# -- byte price of a round, per precision -----------------------------


def draft_kv_per_token(
    precision: Int, layers: Int, kv_heads: Int, head_dim: Int
) raises -> Int:
    """One token of KV at a precision, priced through the
    precision's own accounting module: f16 through
    core/kv_account (J-087's census), per-row int8
    through core/kv_int8 (J-088's store price, defined
    through the census so the two cannot drift)."""
    if precision == KVD_PRECISION_F16:
        return kv_bytes_per_token(layers, kv_heads, head_dim, KV_ELEM_F16)
    if precision == KVD_PRECISION_INT8:
        return kv8_bytes_per_token(layers, kv_heads, head_dim)
    raise Error("KvDrafts: unknown precision code")


def _account_price(
    account: VerifyAccount,
    precision: Int,
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
    rows: Int,
) raises -> Int:
    if not account_is_consistent(account):
        raise Error(
            "KvDrafts: an inconsistent verify account prices nothing;"
            " restate the account or the round"
        )
    return rows * draft_kv_per_token(precision, layers, kv_heads, head_dim)


def tentative_rows_bytes(
    account: VerifyAccount,
    precision: Int,
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
) raises -> Int:
    """Bytes the verify pass tentatively writes: k+1 rows."""
    return _account_price(
        account, precision, layers, kv_heads, head_dim, account.k + 1
    )


def committed_rows_bytes(
    account: VerifyAccount,
    precision: Int,
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
) raises -> Int:
    """Bytes the round commits: accepted+1 rows."""
    return _account_price(
        account, precision, layers, kv_heads, head_dim, account.accepted_count + 1
    )


def rollback_rows_bytes(
    account: VerifyAccount,
    precision: Int,
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
) raises -> Int:
    """Bytes the round discards by rollback: exactly the
    account's kv_rows_to_roll_back rows, per precision."""
    return _account_price(
        account, precision, layers, kv_heads, head_dim, account.kv_rows_to_roll_back
    )


# -- int8 store state difference (Q1's grading surface) ---------------


def _check_store_pair(a: Int8KVStore, b: Int8KVStore, upto: Int) raises:
    if (
        a.layers != b.layers
        or a.kv_heads != b.kv_heads
        or a.head_dim != b.head_dim
        or a.max_seq_len != b.max_seq_len
    ):
        raise Error("KvDrafts: store shapes must match to be compared")
    if upto <= 0 or upto > a.max_seq_len:
        raise Error("KvDrafts: comparison length must sit inside the stores")


def int8_code_diff_count(
    a: Int8KVStore, b: Int8KVStore, upto: Int
) raises -> Int:
    """Differing int8 codes (K and V together) over every
    layer and every position < upto. Zero is bit-exactness
    of the payload at the committed positions."""
    _check_store_pair(a, b, upto)
    var diff = 0
    for layer in range(a.layers):
        for pos in range(upto):
            var base = (layer * a.max_seq_len + pos) * a.kv_width
            for j in range(a.kv_width):
                if a.k_data[base + j] != b.k_data[base + j]:
                    diff += 1
                if a.v_data[base + j] != b.v_data[base + j]:
                    diff += 1
    return diff


def int8_scale_diff_count(
    a: Int8KVStore, b: Int8KVStore, upto: Int
) raises -> Int:
    """Differing f32 scales (K and V together) over every
    layer and every position < upto. A state is its codes
    AND its scales: either differing is a differing state."""
    _check_store_pair(a, b, upto)
    var diff = 0
    for layer in range(a.layers):
        for pos in range(upto):
            var base = (layer * a.max_seq_len + pos) * a.kv_heads
            for h in range(a.kv_heads):
                if a.k_scales[base + h] != b.k_scales[base + h]:
                    diff += 1
                if a.v_scales[base + h] != b.v_scales[base + h]:
                    diff += 1
    return diff


def int8_state_diff_count(
    a: Int8KVStore, b: Int8KVStore, upto: Int
) raises -> Int:
    """Total differing stored scalars (codes + scales) --
    the rollback extra difference of the header: zero iff
    the two int8 states are bit-exact over < upto."""
    return int8_code_diff_count(a, b, upto) + int8_scale_diff_count(a, b, upto)


def int8_max_dequant_diff(
    a: Int8KVStore, b: Int8KVStore, upto: Int
) raises -> Float32:
    """Largest absolute difference between the two stores'
    dequantized rows over < upto (the grading surface's
    read_k/read_v, J-088). Zero when the states agree; a
    consequence of the code/scale counts, filed so a
    reader sees the difference in value terms too."""
    _check_store_pair(a, b, upto)
    var worst = Float32(0)
    for layer in range(a.layers):
        for pos in range(upto):
            var ka = a.read_k(layer, pos)
            var kb = b.read_k(layer, pos)
            var va = a.read_v(layer, pos)
            var vb = b.read_v(layer, pos)
            for j in range(a.kv_width):
                var dk = ka[j] - kb[j]
                if dk < Float32(0):
                    dk = -dk
                if dk > worst:
                    worst = dk
                var dv = va[j] - vb[j]
                if dv < Float32(0):
                    dv = -dv
                if dv > worst:
                    worst = dv
    return worst


def rollback_verdict(diff_count: Int) raises -> Int:
    """The header's Q1 rule in mechanical form: a rollback
    is EXACT iff its extra difference against the
    never-drafted state at the same precision is zero."""
    if diff_count < 0:
        raise Error("KvDrafts: a difference count cannot be negative")
    if diff_count == 0:
        return KVD_ROLLBACK_EXACT
    return KVD_ROLLBACK_NOT_EXACT


# -- acceptance difference (Q2's account-level surface) ---------------


struct AcceptanceDifference(Copyable, ImplicitlyCopyable):
    """One ledger row's totals minus another's, signed:
    rounds, drafted, accepted -- the exact difference the
    roadmap text asks to be measured where one exists."""

    var rounds: Int
    var drafted: Int
    var accepted: Int

    def __init__(out self, rounds: Int, drafted: Int, accepted: Int):
        self.rounds = rounds
        self.drafted = drafted
        self.accepted = accepted

    def is_zero(self) -> Bool:
        return self.rounds == 0 and self.drafted == 0 and self.accepted == 0


def acceptance_difference(
    a: AcceptanceRow, b: AcceptanceRow
) raises -> AcceptanceDifference:
    """a - b over two J-075 ledger rows. The rows' keys
    (kind, pair, text type, language) must be the same
    row: a difference across rows is a category error and
    is refused, never filed."""
    if (
        a.proposer_kind != b.proposer_kind
        or a.pair_id != b.pair_id
        or a.text_type != b.text_type
        or a.language != b.language
    ):
        raise Error(
            "KvDrafts: an acceptance difference is taken within one"
            " ledger row key; the rows given are different rows"
        )
    return AcceptanceDifference(
        a.rounds - b.rounds, a.drafted - b.drafted, a.accepted - b.accepted
    )


def acceptance_verdict(diff: AcceptanceDifference) -> Int:
    """The header's Q2 account-level rule: UNCHANGED iff
    the difference is exactly (0, 0, 0)."""
    if diff.is_zero():
        return KVD_ACCEPT_UNCHANGED
    return KVD_ACCEPT_DIFFERS
