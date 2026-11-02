"""MTP head support: the draft/MTP admission path (Janas road J-077).

The roadmap text: "MTP head support. Where J-076 finds heads,
Aesir reads and runs them as drafters; files without heads are
refused by name, never silently plain."

This module is the admission gate between J-076's census
(core/mtp_census.mojo) and J-071/J-072's speculative machinery
(core/speculative_verify.mojo, core/speculative_loop.mojo).
It binds to both and duplicates neither: the head verdict comes
from J-076's classifier alone, and an admitted file's drafter
shape comes from J-071's plan_proposer, checked through J-072's
dispatch_proposer against the head slot. The module reads no
file, loads no tensor, executes no forward, and contains no
speed: a host hands it one file's name and the tensor directory
the host read (or states that no directory was read), and this
module returns the file's fate as a drafter source.

THE ADMISSION RULES (pre-registered; the slice doc,
docs/janas/J077_MTP_HEAD_SUPPORT.md section 1, is their
normative text; answered-locally where noted in doc section 6):

1. EMPTY NAME REFUSED. A request naming no file is refused
   (MTP_REFUSE_EMPTY_FILE_NAME). There is nothing to admit and
   nothing to name, so the request itself is the defect.
2. UNCENSUSED MEANS NOT PROVEN. If the host states the file's
   directory was not read (directory_read is False), the file
   is refused as NOT PROVEN (MTP_REFUSE_NOT_PROVEN) -- whatever
   names the host may also carry are NOT trusted and are not
   classified: an uncensused file is never assumed to carry a
   head, and never assumed not to. This is J-076's rule that an
   unread file has no verdict, carried into admission.
3. THE CENSUS VERDICT DECIDES, AND NOTHING ELSE DECIDES.
   A read directory is classified tensor by tensor through
   J-076's MtpCensus (the nextn / mtp / assistant first-match
   rules, unchanged):
   - WITH_MTP (at least one head tensor): ADMITTED as a
     drafter source. The admission names every head tensor, in
     directory order, with its J-076 head kind beside it. The
     proposer kind is PROPOSER_MTP_HEAD when any nextn or mtp
     tensor is present; a directory whose only heads are
     assistant tensors admits as PROPOSER_ASSISTANT_MODEL --
     J-071's account gives the head slot to either form, and
     the two shapes differ exactly where they should (the
     assistant form requires a verified tokenizer match; the
     MTP-head form shares its target's tokenizer by
     construction). Either way the shape is obtained through
     J-072's dispatch_proposer(SLOT_HEAD, kind), so an admitted
     file can only ever enter the draft loop through the head
     slot, at the shape J-071 stated for it.
   - NO_MTP (a non-empty directory, fully read, zero heads --
     proven absent FOR THAT FILE): REFUSED BY NAME
     (MTP_REFUSE_NO_MTP). MTP was requested for a file proven
     to carry no head; the run does not fall back to plain
     generation under an MTP request, silently or otherwise.
   - VOCAB_ONLY (an empty directory): REFUSED BY NAME
     (MTP_REFUSE_VOCAB_ONLY). A tokenizer fixture is not a
     model and cannot draft; it is refused under its own
     verdict, not filed as a model without a head.
4. REFUSAL IS A NAMED RECORD, NOT A FALLBACK. Every refusal
   carries the file's name, its verdict word (or NOT_PROVEN),
   and its reason code; mtp_refusal_line() renders the three
   as one line a host files with its evidence. A refused
   admission yields no proposer shape: admitted_proposer_shape
   raises on it, so no code path can turn a refusal into a
   plain or speculative run by accident.

WHAT ADMISSION IS NOT: admission proves a head EXISTS in a
file's directory and states the drafter shape it would run
under. It does not prove Aesir can execute that head -- no
head executor, verify-pass executor, or session wiring exists
in this tree (J-072/J-074, unchanged here), so the live leg
(a WITH_MTP file admitted, its head drafting, the draft loop
running, J-071's identity holding over the run) is deferred
with its exact recipe in the slice doc section 5, re-cited
at the J-086 gate. Tonight no WITH_MTP file exists in any
census this road has filed (J-076 section 3), so no live leg
was possible; the admission and refusal halves above are the
proven halves, exercised over synthetic WITH_MTP directories
(SIMULATED names) and over J-076's real-file census rows
(PROVEN inputs).

HOST CONTRACT (binding on the first live host): (1) pin the
file by sha256 and refuse on a pin mismatch before any
admission call; (2) read the file's FULL tensor directory
(names only; no tensor data is needed for admission) and call
evaluate_mtp_admission with directory_read True and the full
name list -- a partial directory is an uncensused file, call
with directory_read False instead; (3) honour the verdict
exactly: an admitted file enters the draft loop only through
admitted_proposer_shape's dispatched head-slot shape, and a
refused file is never run plain under the MTP request that
was refused -- the refusal line is filed with the run's
evidence; (4) file the admission (file, verdict, head tensor
names where admitted, refusal line where refused) with the
run's evidence, so J-075's instrumentation and the J-086
gate read admissions, not reconstructions.
"""

from core.mtp_census import (
    HEAD_ASSISTANT,
    HEAD_NONE,
    VERDICT_NO_MTP,
    VERDICT_VOCAB_ONLY,
    VERDICT_WITH_MTP,
    MtpCensus,
    classify_tensor_name,
    verdict_name,
)
from core.speculative_loop import dispatch_proposer
from core.speculative_verify import (
    PROPOSER_ASSISTANT_MODEL,
    PROPOSER_MTP_HEAD,
    SLOT_HEAD,
    ProposerShape,
    plan_proposer,
)

# Admission reason codes (evaluate_mtp_admission's vocabulary).
comptime MTP_ADMITTED = 0
comptime MTP_REFUSE_NO_MTP = 1
comptime MTP_REFUSE_VOCAB_ONLY = 2
comptime MTP_REFUSE_NOT_PROVEN = 3
comptime MTP_REFUSE_EMPTY_FILE_NAME = 4

# The census-verdict field of an admission whose directory was
# never read: no J-076 verdict exists for such a file.
comptime MTP_NO_CENSUS_VERDICT = -1


def mtp_reason_name(code: Int) raises -> String:
    if code == MTP_ADMITTED:
        return String("ADMITTED")
    if code == MTP_REFUSE_NO_MTP:
        return String("REFUSE_NO_MTP")
    if code == MTP_REFUSE_VOCAB_ONLY:
        return String("REFUSE_VOCAB_ONLY")
    if code == MTP_REFUSE_NOT_PROVEN:
        return String("REFUSE_NOT_PROVEN")
    if code == MTP_REFUSE_EMPTY_FILE_NAME:
        return String("REFUSE_EMPTY_FILE_NAME")
    raise Error("MtpHeadSupport: unknown admission reason code")


struct MtpAdmission(Copyable):
    """One file's MTP admission verdict, fully derived.

    Built only by evaluate_mtp_admission from J-076's census
    of the directory the host read. On admission, head_names /
    head_kinds name every head tensor in directory order (the
    drafter source's substance), and the proposer fields carry
    J-071's shape as dispatched by J-072 for the head slot. On
    refusal, the proposer fields are inert (-1 / False) and the
    reason code plus census verdict name the refusal.
    """

    var file_name: String
    var admitted: Bool
    var reason_code: Int
    var has_census: Bool
    var census_verdict: Int
    var n_tensors: Int
    var nextn_count: Int
    var mtp_count: Int
    var assistant_count: Int
    var head_names: List[String]
    var head_kinds: List[Int]
    var proposer_kind: Int
    var proposer_slot: Int
    var max_k: Int
    var requires_tokenizer_match: Bool
    var carries_own_kv: Bool

    def __init__(out self):
        self.file_name = String("")
        self.admitted = False
        self.reason_code = -1
        self.has_census = False
        self.census_verdict = MTP_NO_CENSUS_VERDICT
        self.n_tensors = 0
        self.nextn_count = 0
        self.mtp_count = 0
        self.assistant_count = 0
        self.head_names = List[String]()
        self.head_kinds = List[Int]()
        self.proposer_kind = -1
        self.proposer_slot = -1
        self.max_k = 0
        self.requires_tokenizer_match = False
        self.carries_own_kv = False

    def __copyinit__(out self, existing: Self):
        self.file_name = existing.file_name
        self.admitted = existing.admitted
        self.reason_code = existing.reason_code
        self.has_census = existing.has_census
        self.census_verdict = existing.census_verdict
        self.n_tensors = existing.n_tensors
        self.nextn_count = existing.nextn_count
        self.mtp_count = existing.mtp_count
        self.assistant_count = existing.assistant_count
        self.head_names = existing.head_names.copy()
        self.head_kinds = existing.head_kinds.copy()
        self.proposer_kind = existing.proposer_kind
        self.proposer_slot = existing.proposer_slot
        self.max_k = existing.max_k
        self.requires_tokenizer_match = existing.requires_tokenizer_match
        self.carries_own_kv = existing.carries_own_kv

    def head_count(self) -> Int:
        """Head tensors named by this admission (0 on refusal)."""
        return len(self.head_names)


def evaluate_mtp_admission(
    file_name: String, directory_read: Bool, tensor_names: List[String]
) raises -> MtpAdmission:
    """Judge one file as an MTP drafter source, under the rules.

    directory_read states that tensor_names IS the file's full
    tensor directory as the host read it. When it is False the
    names are not trusted, not counted, and not classified:
    the file files as NOT PROVEN however head-shaped a carried
    name may look. Refusals are returned, not raised -- a
    refusal is a verdict with a record, and the host files it;
    only an admitted file's shape may proceed, through
    admitted_proposer_shape.
    """
    var admission = MtpAdmission()
    admission.file_name = file_name

    # Rule 1: a request naming no file is refused outright.
    if file_name.byte_length() == 0:
        admission.reason_code = MTP_REFUSE_EMPTY_FILE_NAME
        return admission^

    # Rule 2: an uncensused file is NOT PROVEN, never assumed.
    if not directory_read:
        admission.reason_code = MTP_REFUSE_NOT_PROVEN
        return admission^

    # Rule 3: J-076's census of the read directory decides.
    var census = MtpCensus()
    for i in range(len(tensor_names)):
        var name = tensor_names[i]
        census.record(name)
        var kind = classify_tensor_name(name)
        if kind != HEAD_NONE:
            admission.head_names.append(name)
            admission.head_kinds.append(kind)
    admission.has_census = True
    admission.census_verdict = census.verdict()
    admission.n_tensors = census.n_tensors
    admission.nextn_count = census.nextn_count
    admission.mtp_count = census.mtp_count
    admission.assistant_count = census.assistant_count

    if admission.census_verdict == VERDICT_WITH_MTP:
        # The proposer kind: a nextn/mtp head is the target's
        # own MTP head; assistant-only heads are the assistant
        # form. Both live in J-071's head slot, and the shape
        # is J-072's dispatch of J-071's plan -- never restated.
        var kind = PROPOSER_MTP_HEAD
        if census.nextn_count + census.mtp_count == 0:
            kind = PROPOSER_ASSISTANT_MODEL
        var shape = dispatch_proposer(SLOT_HEAD, kind)
        admission.admitted = True
        admission.reason_code = MTP_ADMITTED
        admission.proposer_kind = shape.kind
        admission.proposer_slot = shape.slot
        admission.max_k = shape.max_k
        admission.requires_tokenizer_match = shape.requires_tokenizer_match
        admission.carries_own_kv = shape.carries_own_kv
        return admission^

    # A proven census with no admitted head: the head list a
    # refusal does not carry is cleared, so no reader can
    # mistake a refused file for a drafter source. (WITH_MTP
    # is the only verdict that reaches here with heads, and
    # it returned above; this is a stated invariant, kept
    # mechanical rather than assumed.)
    admission.head_names = List[String]()
    admission.head_kinds = List[Int]()
    if admission.census_verdict == VERDICT_VOCAB_ONLY:
        admission.reason_code = MTP_REFUSE_VOCAB_ONLY
    else:
        admission.reason_code = MTP_REFUSE_NO_MTP
    return admission^


def admitted_proposer_shape(admission: MtpAdmission) raises -> ProposerShape:
    """The J-071/J-072 drafter shape of an ADMITTED file.

    Re-dispatched through J-072's head slot at call time, so
    the shape a host runs under is the loop's own dispatch,
    not a copy filed at admission time. A refused admission
    raises: no shape exists for it, and none may be invented
    -- this raise is the mechanical form of "never silently
    plain".
    """
    if not admission.admitted:
        raise Error(
            "MtpHeadSupport: refused file has no drafter shape ("
            + mtp_refusal_line(admission) + ")"
        )
    return dispatch_proposer(SLOT_HEAD, admission.proposer_kind)


def mtp_refusal_line(admission: MtpAdmission) raises -> String:
    """One filed line naming a refusal: file, verdict, reason.

    For an uncensused file the verdict word is NOT_PROVEN --
    the file has no J-076 verdict and none is invented for
    the line. For an admitted file the line states the
    admission instead (the function is the admission's
    one-line record either way, so a host files exactly one
    line per request).
    """
    if admission.admitted:
        return (
            String("ADMITTED file=")
            + admission.file_name
            + " verdict=WITH_MTP heads="
            + String(admission.head_count())
            + " proposer="
            + String(admission.proposer_kind)
        )
    var verdict_word = String("NOT_PROVEN")
    if admission.has_census:
        verdict_word = verdict_name(admission.census_verdict)
    elif admission.reason_code == MTP_REFUSE_EMPTY_FILE_NAME:
        verdict_word = String("NO_FILE_NAMED")
    return (
        String("REFUSED file=")
        + admission.file_name
        + " verdict="
        + verdict_word
        + " reason="
        + mtp_reason_name(admission.reason_code)
        + " -- MTP requested; not run plain"
    )


def mtp_head_k_cap(kind: Int) raises -> Int:
    """A head-slot proposer's k cap, from J-071's account.

    Read from plan_proposer every time, never restated: if
    J-071's band or a head shape ever moves, admission moves
    with it (the J-074 pattern for the cross-model cap).
    """
    return plan_proposer(kind).max_k
