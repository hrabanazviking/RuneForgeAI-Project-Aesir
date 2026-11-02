"""Assistant-model draft pairing account (Janas road J-078).

The roadmap text: "Assistant-model drafts. A separate small
drafter model of the target's own family (the Gemma pattern):
loading both, the pair's memory budget, measured gain."

The census form (J-006, from Janas's public docs): Gemma 4's
assistant is a small drafting model OF THE TARGET'S FAMILY
that reads the main model's KV, taken as its --mtp file.
J-071 gave that form its proposer shape (PROPOSER_ASSISTANT_
MODEL, head slot, verified tokenizer match required, carries
no KV of its own); J-077 admitted an assistant file that
carries its own assistant tensors through the head gate.
This module is the PAIR gate the roadmap's slice names: it
decides whether one stated (target, assistant) pair may be
loaded together and run as a drafter pair, sizes the pair's
memory ONCE, and refuses every inadmissible pair by name.
It binds to the road's existing accounts and duplicates
none of them:

- Census verdicts come from J-076's MtpCensus alone.
- An assistant file carrying head tensors is admitted ONLY
  through J-077's evaluate_mtp_admission, and only under
  the assistant proposer kind J-077 dispatches for it.
- Tokenizer identity is J-074's TokenizerComparison and
  its verified-not-assumed rule, unchanged.
- Family codes and per-side byte quantities are J-074's
  (FAMILY_* / ModelSide), unchanged.
- The pair's memory is sized ONCE through J-026's
  plan_shared_cache_pool over the summed quantities (OS
  headroom charged once for the process), as in J-074.
- The drafter shape is J-071's plan for PROPOSER_ASSISTANT_
  MODEL, dispatched through J-072's head slot, and the k
  cap is read from J-071 every time, never restated.

THE PAIR RULES (pre-registered; the slice doc,
docs/janas/J078_ASSISTANT_MODEL_DRAFTS.md section 1, is
their normative text). A pair is ADMISSIBLE only when
every rule holds; the first failure, checked in this
order, is the verdict's named reason:

1. NAMED FILES. Both requests name a file (an empty name
   refuses, ASSISTANT_REFUSE_EMPTY_FILE_NAME) and both
   files exist (ASSISTANT_REFUSE_MISSING_FILE).
2. BOTH FILES CENSUSED. Both tensor directories were
   actually read. An unread directory refuses the pair as
   UNCENSUSED (ASSISTANT_REFUSE_UNCENSUSED_FILE): names
   carried beside an unread directory are never trusted,
   counted, or classified (J-076/J-077's rule). A read
   directory that is empty on either side refuses as
   VOCAB_ONLY (ASSISTANT_REFUSE_VOCAB_ONLY) -- a tokenizer
   fixture is not a model and can neither target nor draft.
3. SAME FAMILY (the Gemma pattern). Target and assistant
   are the same KNOWN architecture family (J-074's codes).
   A cross-family pair, or any unknown family, refuses
   (ASSISTANT_REFUSE_FAMILY_MISMATCH).
4. ASSISTANT FORM. The assistant side takes exactly one
   of two admitted forms:
   - HEAD FORM: its directory carries head tensors
     (J-076 verdict WITH_MTP) AND J-077's gate admits it
     as the ASSISTANT proposer (assistant tensors only).
     A WITH_MTP file whose heads are nextn/mtp is an MTP
     head file -- J-077 owns it under the MTP-head kind --
     and refuses HERE (ASSISTANT_REFUSE_ASSISTANT_FORM):
     it is not an assistant model, and this gate does not
     re-file it as one.
   - STANDALONE FORM: its directory is an ordinary model
     directory (J-076 verdict NO_MTP, zero heads): a
     separate small model of the family, admitted under
     J-074's pairing discipline. It runs under the same
     J-071 assistant shape (the census's assistant reads
     the target's KV, so the shape carries no KV of its
     own; a host states the assistant's KV allowance as
     the bytes it will actually hold, 0 for the census
     form, and this account sums what is stated).
   Any other assistant census state refuses as FORM.
5. TOKENIZER IDENTITY, VERIFIED -- NOT ASSUMED (J-074
   rule 4, unchanged): a comparison actually run over
   both files' full tokenizer sections. No run refuses
   (ASSISTANT_REFUSE_TOKENIZER_UNVERIFIED); a divergent
   run refuses (ASSISTANT_REFUSE_TOKENIZER_MISMATCH) with
   the first divergence index carried in the verdict.
6. MATERIALLY SMALLER (J-074 rule 3, unchanged): the
   assistant's resident bytes are at most half the
   target's (ASSISTANT_REFUSE_ASSISTANT_NOT_SMALLER).
7. BUDGET SHARE (this slice's rule, answered-locally in
   doc section 6): the assistant's total stated footprint
   (resident + KV allowance + scratch) is at most ONE
   QUARTER of the pair's total stated footprint -- the
   assistant may not eat the memory the target and its
   cache live in. Over the share refuses
   (ASSISTANT_REFUSE_OVER_BUDGET_SHARE). Rule 6 grades
   resident bytes alone; this rule grades everything the
   assistant asks the pair to carry, so a small-resident
   assistant with a large private KV/scratch demand still
   refuses here.
8. k INSIDE THE ASSISTANT CAP: 1..cap, the cap read from
   J-071's account (plan_proposer(PROPOSER_ASSISTANT_
   MODEL).max_k, the draft-check band's 15), never
   restated (ASSISTANT_REFUSE_K_OVER_CAP).
9. ONE BUDGET FOR BOTH FILES: both sides' resident bytes,
   KV allowances, and scratch are summed and sized once
   through plan_shared_cache_pool (J-026). A summed
   reserve leaving no pool budget, or one below the
   one-token floor, refuses (ASSISTANT_REFUSE_BUDGET_
   EXCEEDED).

WHAT THIS ACCOUNT IS NOT: it executes no forward, loads
no model, and contains no acceptance statistic and no
speed. Admissibility plus an exact budget is this slice's
proven half; whether an admissible pair PAYS is measured
live or not at all -- tonight no Gemma pair file is
reachable (J-076: the assistant file is absent at ledger
level and no Gemma main file's directory has been read),
no proposer/executor/session wiring exists in this tree
(J-074 section 2, unchanged), and the measured-gain leg is
deferred with its exact recipe in the slice doc section 5,
re-cited at the J-086 gate. require_draft_check_use()
still fails closed and the facade still refuses.

HOST CONTRACT (binding on the first live host): (1) pin
both files by sha256 and refuse on a pin mismatch before
any pairing call; (2) read BOTH files' full tensor
directories (names only) and extract both tokenizer
sections; run J-074's compare_tokenizers over the FULL
tables; (3) call evaluate_assistant_pair and honour its
verdict exactly -- an inadmissible pair is never loaded
"together to see"; (4) charge the pair through the
verdict's single sizing, never per-model, and hold the
assistant inside its filed share; (5) file the censuses,
the comparison, the verdict, and both pins with the run's
evidence, so J-075's acceptance ledger (assistant kind,
pair id 0) and the J-086 gate read accounts, not
reconstructions.
"""

from core.cross_model_pairing import (
    FAMILY_UNKNOWN,
    ModelSide,
    TokenizerComparison,
)
from core.expert_cache import ExpertCacheSizing, plan_shared_cache_pool
from core.mtp_census import (
    VERDICT_NO_MTP,
    VERDICT_VOCAB_ONLY,
    VERDICT_WITH_MTP,
    MtpCensus,
)
from core.mtp_head_support import evaluate_mtp_admission
from core.speculative_loop import dispatch_proposer
from core.speculative_verify import (
    PROPOSER_ASSISTANT_MODEL,
    SLOT_HEAD,
    ProposerShape,
    plan_proposer,
)

# Pair verdict reason codes (evaluate_assistant_pair's vocabulary).
comptime ASSISTANT_ADMITTED = 0
comptime ASSISTANT_REFUSE_EMPTY_FILE_NAME = 1
comptime ASSISTANT_REFUSE_MISSING_FILE = 2
comptime ASSISTANT_REFUSE_UNCENSUSED_FILE = 3
comptime ASSISTANT_REFUSE_VOCAB_ONLY = 4
comptime ASSISTANT_REFUSE_FAMILY_MISMATCH = 5
comptime ASSISTANT_REFUSE_ASSISTANT_FORM = 6
comptime ASSISTANT_REFUSE_TOKENIZER_UNVERIFIED = 7
comptime ASSISTANT_REFUSE_TOKENIZER_MISMATCH = 8
comptime ASSISTANT_REFUSE_ASSISTANT_NOT_SMALLER = 9
comptime ASSISTANT_REFUSE_OVER_BUDGET_SHARE = 10
comptime ASSISTANT_REFUSE_K_OVER_CAP = 11
comptime ASSISTANT_REFUSE_BUDGET_EXCEEDED = 12

# The assistant's admitted forms (rule 4).
comptime ASSISTANT_ROUTE_NONE = -1
comptime ASSISTANT_ROUTE_HEAD = 0
comptime ASSISTANT_ROUTE_STANDALONE = 1

# Rule 7's share bound: the assistant's footprint is at
# most one quarter of the pair's footprint (250 per mille).
comptime ASSISTANT_MAX_SHARE_PER_MILLE = 250

# A census-verdict field for a side whose directory was
# never read: no J-076 verdict exists for such a file.
comptime ASSISTANT_NO_CENSUS_VERDICT = -1


def assistant_reason_name(code: Int) raises -> String:
    if code == ASSISTANT_ADMITTED:
        return String("ADMITTED")
    if code == ASSISTANT_REFUSE_EMPTY_FILE_NAME:
        return String("REFUSE_EMPTY_FILE_NAME")
    if code == ASSISTANT_REFUSE_MISSING_FILE:
        return String("REFUSE_MISSING_FILE")
    if code == ASSISTANT_REFUSE_UNCENSUSED_FILE:
        return String("REFUSE_UNCENSUSED_FILE")
    if code == ASSISTANT_REFUSE_VOCAB_ONLY:
        return String("REFUSE_VOCAB_ONLY")
    if code == ASSISTANT_REFUSE_FAMILY_MISMATCH:
        return String("REFUSE_FAMILY_MISMATCH")
    if code == ASSISTANT_REFUSE_ASSISTANT_FORM:
        return String("REFUSE_ASSISTANT_FORM")
    if code == ASSISTANT_REFUSE_TOKENIZER_UNVERIFIED:
        return String("REFUSE_TOKENIZER_UNVERIFIED")
    if code == ASSISTANT_REFUSE_TOKENIZER_MISMATCH:
        return String("REFUSE_TOKENIZER_MISMATCH")
    if code == ASSISTANT_REFUSE_ASSISTANT_NOT_SMALLER:
        return String("REFUSE_ASSISTANT_NOT_SMALLER")
    if code == ASSISTANT_REFUSE_OVER_BUDGET_SHARE:
        return String("REFUSE_OVER_BUDGET_SHARE")
    if code == ASSISTANT_REFUSE_K_OVER_CAP:
        return String("REFUSE_K_OVER_CAP")
    if code == ASSISTANT_REFUSE_BUDGET_EXCEEDED:
        return String("REFUSE_BUDGET_EXCEEDED")
    raise Error("AssistantPairing: unknown pair reason code")


def assistant_route_name(code: Int) raises -> String:
    if code == ASSISTANT_ROUTE_HEAD:
        return String("head_assistant")
    if code == ASSISTANT_ROUTE_STANDALONE:
        return String("standalone_model")
    if code == ASSISTANT_ROUTE_NONE:
        return String("none")
    raise Error("AssistantPairing: unknown assistant route code")


def assistant_k_cap() raises -> Int:
    """The assistant proposer's k cap, from J-071's account.

    Read from plan_proposer every time, never restated:
    if J-071's band or the assistant shape ever moves,
    this account moves with it (the J-074/J-077 pattern).
    """
    return plan_proposer(PROPOSER_ASSISTANT_MODEL).max_k


def _footprint(side: ModelSide) -> Int:
    return side.resident_bytes + side.kv_allowance_bytes + side.scratch_bytes


struct AssistantPairVerdict(Copyable):
    """One (target, assistant) pair's verdict, fully derived.

    The pair's summed quantities, footprints, and share are
    carried on every verdict (admitted or refused) so the
    filing shows the pair's full account, not just its fate.
    sizing is meaningful only when the budget rule was
    reached (budget_checked); before that rule it is a zero
    sizing and must not be quoted. On refusal the proposer
    fields are inert (-1 / False): a refused pair yields no
    drafter shape (admitted_assistant_shape raises on it).
    """

    var target_name: String
    var assistant_name: String
    var admitted: Bool
    var reason_code: Int
    var route: Int
    var k_cap: Int
    var first_token_divergence: Int
    var target_census_verdict: Int
    var assistant_census_verdict: Int
    var assistant_head_count: Int
    var assistant_nextn_count: Int
    var assistant_mtp_count: Int
    var assistant_kind_count: Int
    var proposer_kind: Int
    var proposer_slot: Int
    var max_k: Int
    var requires_tokenizer_match: Bool
    var carries_own_kv: Bool
    var target_footprint_bytes: Int
    var assistant_footprint_bytes: Int
    var pair_footprint_bytes: Int
    var assistant_share_per_mille: Int
    var pair_resident_bytes: Int
    var pair_kv_allowance_bytes: Int
    var budget_checked: Bool
    var sizing: ExpertCacheSizing

    def __init__(out self):
        self.target_name = String("")
        self.assistant_name = String("")
        self.admitted = False
        self.reason_code = -1
        self.route = ASSISTANT_ROUTE_NONE
        self.k_cap = 0
        self.first_token_divergence = -1
        self.target_census_verdict = ASSISTANT_NO_CENSUS_VERDICT
        self.assistant_census_verdict = ASSISTANT_NO_CENSUS_VERDICT
        self.assistant_head_count = 0
        self.assistant_nextn_count = 0
        self.assistant_mtp_count = 0
        self.assistant_kind_count = 0
        self.proposer_kind = -1
        self.proposer_slot = -1
        self.max_k = 0
        self.requires_tokenizer_match = False
        self.carries_own_kv = False
        self.target_footprint_bytes = 0
        self.assistant_footprint_bytes = 0
        self.pair_footprint_bytes = 0
        self.assistant_share_per_mille = 0
        self.pair_resident_bytes = 0
        self.pair_kv_allowance_bytes = 0
        self.budget_checked = False
        self.sizing = ExpertCacheSizing(0, 0, 0, 0, 0, 0, 0, False, True)

    def __copyinit__(out self, existing: Self):
        self.target_name = existing.target_name
        self.assistant_name = existing.assistant_name
        self.admitted = existing.admitted
        self.reason_code = existing.reason_code
        self.route = existing.route
        self.k_cap = existing.k_cap
        self.first_token_divergence = existing.first_token_divergence
        self.target_census_verdict = existing.target_census_verdict
        self.assistant_census_verdict = existing.assistant_census_verdict
        self.assistant_head_count = existing.assistant_head_count
        self.assistant_nextn_count = existing.assistant_nextn_count
        self.assistant_mtp_count = existing.assistant_mtp_count
        self.assistant_kind_count = existing.assistant_kind_count
        self.proposer_kind = existing.proposer_kind
        self.proposer_slot = existing.proposer_slot
        self.max_k = existing.max_k
        self.requires_tokenizer_match = existing.requires_tokenizer_match
        self.carries_own_kv = existing.carries_own_kv
        self.target_footprint_bytes = existing.target_footprint_bytes
        self.assistant_footprint_bytes = existing.assistant_footprint_bytes
        self.pair_footprint_bytes = existing.pair_footprint_bytes
        self.assistant_share_per_mille = existing.assistant_share_per_mille
        self.pair_resident_bytes = existing.pair_resident_bytes
        self.pair_kv_allowance_bytes = existing.pair_kv_allowance_bytes
        self.budget_checked = existing.budget_checked
        self.sizing = existing.sizing


def evaluate_assistant_pair(
    target_name: String,
    target: ModelSide,
    target_directory_read: Bool,
    target_tensor_names: List[String],
    assistant_name: String,
    assistant: ModelSide,
    assistant_directory_read: Bool,
    assistant_tensor_names: List[String],
    tokenizer: TokenizerComparison,
    tokenizer_verified: Bool,
    requested_k: Int,
    free_at_open_bytes: Int,
    total_bytes: Int,
    hard_cap_bytes: Int,
    per_token_routed_bytes: Int,
) raises -> AssistantPairVerdict:
    """Judge one proposed assistant pair under the stated rules.

    target_tensor_names / assistant_tensor_names are the
    files' FULL tensor directories as the host read them;
    the *_directory_read flags state that they are. When a
    flag is False the names beside it are not trusted, not
    counted, and not classified. Refusals return in rule
    order (header); the sizing values of the underlying
    shared pool propagate their own errors for out-of-range
    inputs, exactly as J-026's sizing raises.
    """
    var verdict = AssistantPairVerdict()
    verdict.target_name = target_name
    verdict.assistant_name = assistant_name
    verdict.k_cap = assistant_k_cap()
    verdict.target_footprint_bytes = _footprint(target)
    verdict.assistant_footprint_bytes = _footprint(assistant)
    verdict.pair_footprint_bytes = (
        verdict.target_footprint_bytes + verdict.assistant_footprint_bytes
    )
    if verdict.pair_footprint_bytes > 0:
        verdict.assistant_share_per_mille = (
            verdict.assistant_footprint_bytes * 1000
        ) // verdict.pair_footprint_bytes
    verdict.pair_resident_bytes = target.resident_bytes + assistant.resident_bytes
    verdict.pair_kv_allowance_bytes = (
        target.kv_allowance_bytes + assistant.kv_allowance_bytes
    )

    # Rule 1: both requests name a file, and both files exist.
    if target_name.byte_length() == 0 or assistant_name.byte_length() == 0:
        verdict.reason_code = ASSISTANT_REFUSE_EMPTY_FILE_NAME
        return verdict^
    if not target.file_present or not assistant.file_present:
        verdict.reason_code = ASSISTANT_REFUSE_MISSING_FILE
        return verdict^

    # Rule 2: both directories actually read, and neither is
    # a vocab-only fixture. The censuses are J-076's alone.
    if not target_directory_read or not assistant_directory_read:
        verdict.reason_code = ASSISTANT_REFUSE_UNCENSUSED_FILE
        return verdict^
    var target_census = MtpCensus()
    for i in range(len(target_tensor_names)):
        target_census.record(target_tensor_names[i])
    var assistant_census = MtpCensus()
    for i in range(len(assistant_tensor_names)):
        assistant_census.record(assistant_tensor_names[i])
    verdict.target_census_verdict = target_census.verdict()
    verdict.assistant_census_verdict = assistant_census.verdict()
    verdict.assistant_head_count = assistant_census.head_count()
    verdict.assistant_nextn_count = assistant_census.nextn_count
    verdict.assistant_mtp_count = assistant_census.mtp_count
    verdict.assistant_kind_count = assistant_census.assistant_count
    if (
        verdict.target_census_verdict == VERDICT_VOCAB_ONLY
        or verdict.assistant_census_verdict == VERDICT_VOCAB_ONLY
    ):
        verdict.reason_code = ASSISTANT_REFUSE_VOCAB_ONLY
        return verdict^

    # Rule 3: same known family (the Gemma pattern).
    if (
        target.family == FAMILY_UNKNOWN
        or assistant.family == FAMILY_UNKNOWN
        or target.family != assistant.family
    ):
        verdict.reason_code = ASSISTANT_REFUSE_FAMILY_MISMATCH
        return verdict^

    # Rule 4: the assistant's form. A head-carrying assistant
    # is admitted only through J-077's gate, and only under
    # the assistant kind that gate dispatches for it.
    if verdict.assistant_census_verdict == VERDICT_WITH_MTP:
        var gate = evaluate_mtp_admission(
            assistant_name, True, assistant_tensor_names
        )
        if not gate.admitted or gate.proposer_kind != PROPOSER_ASSISTANT_MODEL:
            verdict.reason_code = ASSISTANT_REFUSE_ASSISTANT_FORM
            return verdict^
        verdict.route = ASSISTANT_ROUTE_HEAD
    elif verdict.assistant_census_verdict == VERDICT_NO_MTP:
        verdict.route = ASSISTANT_ROUTE_STANDALONE
    else:
        verdict.reason_code = ASSISTANT_REFUSE_ASSISTANT_FORM
        return verdict^

    # Rule 5: tokenizer identity, verified not assumed (J-074).
    if not tokenizer_verified:
        verdict.reason_code = ASSISTANT_REFUSE_TOKENIZER_UNVERIFIED
        return verdict^
    if not tokenizer.identical():
        verdict.reason_code = ASSISTANT_REFUSE_TOKENIZER_MISMATCH
        verdict.first_token_divergence = tokenizer.first_token_divergence
        return verdict^

    # Rule 6: assistant materially smaller (J-074's bound).
    if assistant.resident_bytes < 0 or target.resident_bytes <= 0:
        raise Error("AssistantPairing: resident bytes out of range")
    if assistant.resident_bytes * 2 > target.resident_bytes:
        verdict.reason_code = ASSISTANT_REFUSE_ASSISTANT_NOT_SMALLER
        return verdict^

    # Rule 7: the assistant's share of the pair's footprint.
    if verdict.assistant_footprint_bytes * 4 > verdict.pair_footprint_bytes:
        verdict.reason_code = ASSISTANT_REFUSE_OVER_BUDGET_SHARE
        return verdict^

    # Rule 8: k inside the assistant slot's cap (J-071).
    if requested_k < 1 or requested_k > verdict.k_cap:
        verdict.reason_code = ASSISTANT_REFUSE_K_OVER_CAP
        return verdict^

    # Rule 9: one shared budget for both files (J-026).
    verdict.sizing = plan_shared_cache_pool(
        free_at_open_bytes,
        total_bytes,
        hard_cap_bytes,
        verdict.pair_resident_bytes,
        verdict.pair_kv_allowance_bytes,
        target.scratch_bytes + assistant.scratch_bytes,
        per_token_routed_bytes,
    )
    verdict.budget_checked = True
    if verdict.sizing.budget_bytes <= 0 or verdict.sizing.below_floor:
        verdict.reason_code = ASSISTANT_REFUSE_BUDGET_EXCEEDED
        return verdict^

    # Admitted: the shape is J-072's dispatch of J-071's
    # assistant plan, obtained at verdict time so the filing
    # carries the loop's own shape, never a restatement.
    var shape = dispatch_proposer(SLOT_HEAD, PROPOSER_ASSISTANT_MODEL)
    verdict.admitted = True
    verdict.reason_code = ASSISTANT_ADMITTED
    verdict.proposer_kind = shape.kind
    verdict.proposer_slot = shape.slot
    verdict.max_k = shape.max_k
    verdict.requires_tokenizer_match = shape.requires_tokenizer_match
    verdict.carries_own_kv = shape.carries_own_kv
    return verdict^


def admitted_assistant_shape(
    verdict: AssistantPairVerdict,
) raises -> ProposerShape:
    """The J-071/J-072 drafter shape of an ADMITTED pair.

    Re-dispatched through J-072's head slot at call time, so
    the shape a host runs under is the loop's own dispatch,
    not a copy filed at verdict time. A refused verdict
    raises: no shape exists for it, and none may be invented
    -- this raise is the mechanical form of "refused by
    name, never silently plain".
    """
    if not verdict.admitted:
        raise Error(
            "AssistantPairing: refused pair has no drafter shape ("
            + assistant_pair_refusal_line(verdict) + ")"
        )
    return dispatch_proposer(SLOT_HEAD, PROPOSER_ASSISTANT_MODEL)


def assistant_pair_refusal_line(
    verdict: AssistantPairVerdict,
) raises -> String:
    """One filed line naming a pair verdict: both files,
    the route where admitted, and the reason where refused.

    A host files exactly one line per pair request, so a
    refusal is evidence with both names on it -- never a
    silent fallback to plain generation under the request
    that was refused.
    """
    if verdict.admitted:
        return (
            String("ADMITTED target=")
            + verdict.target_name
            + " assistant="
            + verdict.assistant_name
            + " route="
            + assistant_route_name(verdict.route)
            + " share_per_mille="
            + String(verdict.assistant_share_per_mille)
        )
    return (
        String("REFUSED target=")
        + verdict.target_name
        + " assistant="
        + verdict.assistant_name
        + " reason="
        + assistant_reason_name(verdict.reason_code)
        + " -- assistant pair not run"
    )
