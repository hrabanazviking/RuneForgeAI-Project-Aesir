"""Cross-model draft pairing account (Janas road J-074).

The roadmap text: "Cross-model drafts. A small model drafts
for a large one (`--draft` analogue): pairing rules
(tokenizer identity required -- verified, not assumed), the
Qwen3-0.6B->4B pattern from Janas's docs as the first pair."

THE PAIRING RULES, stated before any building (the slice
doc, docs/janas/J074_CROSS_MODEL_DRAFTS.md section 1, is
their normative text). A (drafter, target) pair is
ADMISSIBLE only when every rule below holds; each failure
is a mechanical refusal with a named reason, checked in
this order (the first refusal is the verdict's reason):

1. FILES PRESENT. Both model files exist at the stated
   paths. A missing file refuses the pair outright
   (PAIR_REFUSE_MISSING_FILE) -- a pairing over absent
   files is a plan, not a pair.
2. KNOWN FAMILY PAIRING. Drafter and target are the same
   known architecture family (the census's documented
   cross-model form: "a small model of the same family
   sharing the vocabulary", J-006). A cross-family pair,
   or any pair involving an unknown family, is refused
   (PAIR_REFUSE_UNKNOWN_FAMILY_PAIRING) -- no pairing is
   admitted on a family resemblance the road has not
   named.
3. MATERIALLY SMALLER. The drafter's resident bytes are
   at most half the target's (PAIR_REFUSE_DRAFTER_NOT_
   SMALLER otherwise, which also covers drafter >=
   target). The documented first pair sits far inside
   this bound (0.6B against 4B is roughly one seventh of
   the parameters); the bound exists so a "drafter" that
   costs nearly a second target cannot call itself one.
4. TOKENIZER IDENTITY, VERIFIED -- NOT ASSUMED. The pair
   is admitted only on a tokenizer comparison actually
   run over the two files' tokenizer sections: same
   tokenizer model string, same vocabulary length, every
   token string equal at every index, merges equal at
   every index where both files carry merges (a one-sided
   merges section is itself a mismatch), and equal BOS /
   EOS ids. No comparison run -> PAIR_REFUSE_TOKENIZER_
   UNVERIFIED (family name, shared vocabulary SIZE, and
   catalogue pairing are evidence of nothing here: this
   road's own probe found two files with identical vocab
   length and identical tokenizer-model strings whose
   token tables diverge, J-074 doc section 3). A run
   comparison that diverges -> PAIR_REFUSE_TOKENIZER_
   MISMATCH, with the first divergence index carried in
   the verdict.
5. k INSIDE THE CROSS-MODEL SLOT'S CAP. The requested
   draft depth sits in 1..cap, the cap taken from J-071's
   account (plan_proposer(PROPOSER_CROSS_MODEL).max_k --
   the draft-check band's 15), never restated here
   (PAIR_REFUSE_K_OVER_CAP otherwise).
6. ONE BUDGET FOR BOTH MODELS. The pair's memory is
   accounted ONCE, through Part II/III's existing shared
   accounting: both models' resident bytes, KV allowances,
   and scratch are SUMMED and sized through J-026's
   plan_shared_cache_pool (which charges the OS headroom
   once, for the process -- sizing each model separately
   and adding the budgets is the over-commit that
   function exists to replace). A pair whose summed
   reserve leaves no pool budget, or leaves it below the
   one-token floor, is refused (PAIR_REFUSE_BUDGET_
   EXCEEDED).

WHAT THIS ACCOUNT IS NOT: it executes no forward, loads
no model, and contains no acceptance statistic and no
speed. Admissibility is a gate, not a gain: whether an
admissible pair PAYS is J-075's measurement, and whether
it RUNS is the deferred live leg's (J-074 doc section 6,
re-cited at the J-086 gate). No proposer implementation,
verify-pass executor, or session wiring exists in this
tree (J-072/J-073, unchanged here): require_draft_check_
use() still fails closed and the facade still refuses.

HOST CONTRACT (binding on the first live host): (1) pin
both files by sha256 and refuse on a pin mismatch before
any pairing call; (2) extract both tokenizer sections and
run compare_tokenizers over the FULL tables (the probe
set is the whole vocabulary and merges, index by index --
any text probe is a subset of it); (3) call evaluate_pair
and honour its verdict exactly -- an inadmissible pair is
never run "to see"; (4) charge the pair through the
verdict's single sizing, never per-model; (5) file the
comparison, the verdict, and both pins with the run's
evidence, so J-075's acceptance instrumentation reads
accounts, not reconstructions.
"""

from core.expert_cache import ExpertCacheSizing, plan_shared_cache_pool
from core.speculative_verify import PROPOSER_CROSS_MODEL, plan_proposer

# Architecture families (Aesir's wave families, per the
# J-060 battery matrix and the J-011 census). A family not
# listed here is FAMILY_UNKNOWN and pairs with nothing.
comptime FAMILY_QWEN3 = 0
comptime FAMILY_QWEN35 = 1
comptime FAMILY_QWEN3_NEXT = 2
comptime FAMILY_GEMMA4 = 3
comptime FAMILY_LLAMA3 = 4
comptime FAMILY_OLMOE = 5
comptime FAMILY_UNKNOWN = -1

# Pair verdict reason codes (evaluate_pair's vocabulary).
comptime PAIR_ADMISSIBLE = 0
comptime PAIR_REFUSE_MISSING_FILE = 1
comptime PAIR_REFUSE_UNKNOWN_FAMILY_PAIRING = 2
comptime PAIR_REFUSE_DRAFTER_NOT_SMALLER = 3
comptime PAIR_REFUSE_TOKENIZER_UNVERIFIED = 4
comptime PAIR_REFUSE_TOKENIZER_MISMATCH = 5
comptime PAIR_REFUSE_K_OVER_CAP = 6
comptime PAIR_REFUSE_BUDGET_EXCEEDED = 7

# Merges-section states in a TokenizerComparison.
comptime MERGES_BOTH_COMPARED = 0
comptime MERGES_BOTH_ABSENT = 1
comptime MERGES_ONE_SIDED = 2


def family_name(code: Int) raises -> String:
    if code == FAMILY_QWEN3:
        return String("qwen3")
    if code == FAMILY_QWEN35:
        return String("qwen3.5")
    if code == FAMILY_QWEN3_NEXT:
        return String("qwen3-next")
    if code == FAMILY_GEMMA4:
        return String("gemma4")
    if code == FAMILY_LLAMA3:
        return String("llama3")
    if code == FAMILY_OLMOE:
        return String("olmoe")
    if code == FAMILY_UNKNOWN:
        return String("unknown")
    raise Error("CrossModelPairing: unknown family code")


def pair_reason_name(code: Int) raises -> String:
    if code == PAIR_ADMISSIBLE:
        return String("ADMISSIBLE")
    if code == PAIR_REFUSE_MISSING_FILE:
        return String("REFUSE_MISSING_FILE")
    if code == PAIR_REFUSE_UNKNOWN_FAMILY_PAIRING:
        return String("REFUSE_UNKNOWN_FAMILY_PAIRING")
    if code == PAIR_REFUSE_DRAFTER_NOT_SMALLER:
        return String("REFUSE_DRAFTER_NOT_SMALLER")
    if code == PAIR_REFUSE_TOKENIZER_UNVERIFIED:
        return String("REFUSE_TOKENIZER_UNVERIFIED")
    if code == PAIR_REFUSE_TOKENIZER_MISMATCH:
        return String("REFUSE_TOKENIZER_MISMATCH")
    if code == PAIR_REFUSE_K_OVER_CAP:
        return String("REFUSE_K_OVER_CAP")
    if code == PAIR_REFUSE_BUDGET_EXCEEDED:
        return String("REFUSE_BUDGET_EXCEEDED")
    raise Error("CrossModelPairing: unknown pair reason code")


struct TokenizerComparison(Copyable):
    """One tokenizer comparison, fully derived -- never asserted.

    Computed by compare_tokenizers from the two files' full
    tokenizer tables. Identity is the conjunction stated in
    the header rule 4; every divergence is counted, and the
    first divergence index of each table is carried so a
    refusal names WHERE the tables part, not just that
    they do.
    """

    var vocab_compared: Int
    var token_mismatches: Int
    var first_token_divergence: Int
    var merges_state: Int
    var merges_compared: Int
    var merge_mismatches: Int
    var first_merge_divergence: Int
    var model_equal: Bool
    var bos_equal: Bool
    var eos_equal: Bool

    def __init__(out self):
        self.vocab_compared = 0
        self.token_mismatches = 0
        self.first_token_divergence = -1
        self.merges_state = MERGES_BOTH_ABSENT
        self.merges_compared = 0
        self.merge_mismatches = 0
        self.first_merge_divergence = -1
        self.model_equal = False
        self.bos_equal = False
        self.eos_equal = False

    def __copyinit__(out self, existing: Self):
        self.vocab_compared = existing.vocab_compared
        self.token_mismatches = existing.token_mismatches
        self.first_token_divergence = existing.first_token_divergence
        self.merges_state = existing.merges_state
        self.merges_compared = existing.merges_compared
        self.merge_mismatches = existing.merge_mismatches
        self.first_merge_divergence = existing.first_merge_divergence
        self.model_equal = existing.model_equal
        self.bos_equal = existing.bos_equal
        self.eos_equal = existing.eos_equal

    def identical(self) -> Bool:
        """True only when every compared element agreed."""
        if self.vocab_compared <= 0:
            return False
        if self.token_mismatches != 0:
            return False
        if self.merges_state == MERGES_ONE_SIDED:
            return False
        if self.merge_mismatches != 0:
            return False
        return self.model_equal and self.bos_equal and self.eos_equal


def compare_tokenizers(
    drafter_tokens: List[String],
    target_tokens: List[String],
    drafter_merges: List[String],
    target_merges: List[String],
    drafter_model: String,
    target_model: String,
    drafter_bos: Int,
    target_bos: Int,
    drafter_eos: Int,
    target_eos: Int,
) -> TokenizerComparison:
    """Compare two tokenizer tables token-for-token.

    The probe set is the whole vocabulary and the whole
    merges list, index by index: token i of the drafter
    must be the same string as token i of the target, for
    every i either table holds (a length difference counts
    every past-the-end index as a mismatch and diverges at
    the shorter length). The same discipline applies to
    merges when both files carry them; when exactly one
    does, the comparison records MERGES_ONE_SIDED, which
    identical() treats as a mismatch -- an SPM table and a
    BPE table are not the same tokenizer worn two ways.
    """
    var cmp = TokenizerComparison()
    cmp.model_equal = drafter_model == target_model
    cmp.bos_equal = drafter_bos == target_bos
    cmp.eos_equal = drafter_eos == target_eos

    var vocab_n = len(drafter_tokens)
    if len(target_tokens) > vocab_n:
        vocab_n = len(target_tokens)
    cmp.vocab_compared = vocab_n
    for i in range(vocab_n):
        var same = False
        if i < len(drafter_tokens) and i < len(target_tokens):
            same = drafter_tokens[i] == target_tokens[i]
        if not same:
            cmp.token_mismatches += 1
            if cmp.first_token_divergence == -1:
                cmp.first_token_divergence = i

    if len(drafter_merges) == 0 and len(target_merges) == 0:
        cmp.merges_state = MERGES_BOTH_ABSENT
        cmp.merges_compared = 0
    elif len(drafter_merges) == 0 or len(target_merges) == 0:
        cmp.merges_state = MERGES_ONE_SIDED
        cmp.merges_compared = 0
        cmp.first_merge_divergence = 0
    else:
        cmp.merges_state = MERGES_BOTH_COMPARED
        var merges_n = len(drafter_merges)
        if len(target_merges) > merges_n:
            merges_n = len(target_merges)
        cmp.merges_compared = merges_n
        for i in range(merges_n):
            var same = False
            if i < len(drafter_merges) and i < len(target_merges):
                same = drafter_merges[i] == target_merges[i]
            if not same:
                cmp.merge_mismatches += 1
                if cmp.first_merge_divergence == -1:
                    cmp.first_merge_divergence = i
    return cmp^


struct ModelSide(Copyable, ImplicitlyCopyable):
    """One side of a proposed pair, as the host states it.

    resident / kv_allowance / scratch are the same byte
    quantities Part II's sizing consumes (J-018/J-026):
    resident set measured from the tensor directory, a KV
    allowance for the configured context, and scratch.
    They are stated per side and SUMMED by evaluate_pair
    into the pair's single shared sizing -- never sized
    per model.
    """

    var family: Int
    var file_present: Bool
    var resident_bytes: Int
    var kv_allowance_bytes: Int
    var scratch_bytes: Int

    def __init__(
        out self,
        family: Int,
        file_present: Bool,
        resident_bytes: Int,
        kv_allowance_bytes: Int,
        scratch_bytes: Int,
    ):
        self.family = family
        self.file_present = file_present
        self.resident_bytes = resident_bytes
        self.kv_allowance_bytes = kv_allowance_bytes
        self.scratch_bytes = scratch_bytes


struct PairVerdict(Copyable):
    """evaluate_pair's verdict: admissible, or the named refusal.

    The pair's summed quantities and its single shared
    sizing are carried on every verdict (admissible or
    refused) so the filing shows the pair's full account,
    not just its fate. sizing is meaningful only when the
    budget rule was reached (budget_checked); before that
    rule it is a zero sizing and must not be quoted.
    """

    var admissible: Bool
    var reason_code: Int
    var k_cap: Int
    var first_token_divergence: Int
    var pair_resident_bytes: Int
    var pair_kv_allowance_bytes: Int
    var budget_checked: Bool
    var sizing: ExpertCacheSizing

    def __init__(out self):
        self.admissible = False
        self.reason_code = -1
        self.k_cap = 0
        self.first_token_divergence = -1
        self.pair_resident_bytes = 0
        self.pair_kv_allowance_bytes = 0
        self.budget_checked = False
        self.sizing = ExpertCacheSizing(0, 0, 0, 0, 0, 0, 0, False, True)

    def __copyinit__(out self, existing: Self):
        self.admissible = existing.admissible
        self.reason_code = existing.reason_code
        self.k_cap = existing.k_cap
        self.first_token_divergence = existing.first_token_divergence
        self.pair_resident_bytes = existing.pair_resident_bytes
        self.pair_kv_allowance_bytes = existing.pair_kv_allowance_bytes
        self.budget_checked = existing.budget_checked
        self.sizing = existing.sizing


def cross_model_k_cap() raises -> Int:
    """The cross-model slot's k cap, from J-071's account.

    Read from plan_proposer every time, never restated:
    if J-071's band or the cross-model shape ever moves,
    this account moves with it.
    """
    return plan_proposer(PROPOSER_CROSS_MODEL).max_k


def evaluate_pair(
    drafter: ModelSide,
    target: ModelSide,
    tokenizer: TokenizerComparison,
    tokenizer_verified: Bool,
    requested_k: Int,
    free_at_open_bytes: Int,
    total_bytes: Int,
    hard_cap_bytes: Int,
    per_token_routed_bytes: Int,
) raises -> PairVerdict:
    """Judge one proposed pair under the six stated rules.

    tokenizer_verified states that `tokenizer` was actually
    derived from the two files' tokenizer sections (the
    host contract's step 2); a verdict built on an assumed
    comparison is refused as UNVERIFIED before the
    comparison's own result is even read. Refusals return
    in rule order (header); the sizing values of the
    underlying shared pool propagate their own errors for
    out-of-range inputs, exactly as J-026's sizing raises.
    """
    var verdict = PairVerdict()
    verdict.k_cap = cross_model_k_cap()
    verdict.pair_resident_bytes = drafter.resident_bytes + target.resident_bytes
    verdict.pair_kv_allowance_bytes = (
        drafter.kv_allowance_bytes + target.kv_allowance_bytes
    )

    # Rule 1: both files present.
    if not drafter.file_present or not target.file_present:
        verdict.reason_code = PAIR_REFUSE_MISSING_FILE
        return verdict^

    # Rule 2: same known family.
    if (
        drafter.family == FAMILY_UNKNOWN
        or target.family == FAMILY_UNKNOWN
        or drafter.family != target.family
    ):
        verdict.reason_code = PAIR_REFUSE_UNKNOWN_FAMILY_PAIRING
        return verdict^

    # Rule 3: drafter materially smaller (at most half).
    if drafter.resident_bytes < 0 or target.resident_bytes <= 0:
        raise Error("CrossModelPairing: resident bytes out of range")
    if drafter.resident_bytes * 2 > target.resident_bytes:
        verdict.reason_code = PAIR_REFUSE_DRAFTER_NOT_SMALLER
        return verdict^

    # Rule 4: tokenizer identity, verified not assumed.
    if not tokenizer_verified:
        verdict.reason_code = PAIR_REFUSE_TOKENIZER_UNVERIFIED
        return verdict^
    if not tokenizer.identical():
        verdict.reason_code = PAIR_REFUSE_TOKENIZER_MISMATCH
        verdict.first_token_divergence = tokenizer.first_token_divergence
        return verdict^

    # Rule 5: k inside the cross-model slot's cap.
    if requested_k < 1 or requested_k > verdict.k_cap:
        verdict.reason_code = PAIR_REFUSE_K_OVER_CAP
        return verdict^

    # Rule 6: one shared budget for both models (J-026).
    verdict.sizing = plan_shared_cache_pool(
        free_at_open_bytes,
        total_bytes,
        hard_cap_bytes,
        verdict.pair_resident_bytes,
        verdict.pair_kv_allowance_bytes,
        drafter.scratch_bytes + target.scratch_bytes,
        per_token_routed_bytes,
    )
    verdict.budget_checked = True
    if verdict.sizing.budget_bytes <= 0 or verdict.sizing.below_floor:
        verdict.reason_code = PAIR_REFUSE_BUDGET_EXCEEDED
        return verdict^

    verdict.admissible = True
    verdict.reason_code = PAIR_ADMISSIBLE
    return verdict^
