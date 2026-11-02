"""Constrained generation: exact enforcement of
J-113's permitted-vocabulary restriction at sampling
time, plus its chat and server doors (Janas road
J-114).

The roadmap text: "Constrained generation. Output
restricted to a permitted vocabulary set (the
transferable core of J-113): exact enforcement in the
sampler, measured cost, chat + server surface." The
J-114 doc (docs/janas/J114_CONSTRAINED_GENERATION.md)
is the normative text; this header records the design
pre-registered in its section 0 before any code was
built. No Janas material was consulted beyond the
road's own filed records; no Janas source code was
opened.

THE DECISION IS J-113's, NEVER RE-IMPLEMENTED. Every
admission decision in this module and in core/
sampler.mojo's restricted entry is
VocabRestrictor.is_token_valid over decoded token
text, in candidate order. cg_masked_indices therefore
equals the restrictor's own allowed_indices over the
same texts by construction (same predicate, same
order), and the unit suite proves the equality on
concrete sets in several restrictor states. Sampling
never advances the restrictor: the caller commits the
emitted token's text through advance_state after
emission (validate-then-commit), so a refused token
is never emitted and there is nothing to roll back.

THE SAMPLER (core/sampler.mojo). apply_vocab_
restriction is the restriction form of the sampler's
standing apply_token_mask (disallowed candidates are
forced to -1e9, admitted ones untouched; a candidate/
text count mismatch raises). sample_token_from_
logits_restricted is sample_token_from_logits' exact
sibling: greedy and sampled paths mirror the
unrestricted function's rules over the admitted set
only, suppressed IDs are excluded in both paths, and
it returns -1 when no candidate is admitted -- never
a disallowed token, never a fallback.

COST. The restriction's per-token price is the
validity scan: a full pass over the candidate texts
with no early exit (the greedy sampler path scans
once, the sampled path twice -- max scan + collect).
cg_scan_account states the deterministic part exactly
(candidates scanned, candidate-text bytes); the wall
cost is measured by the filed driver docs/janas/
j114_cost.mojo (baseline greedy max-scan vs the
restricted validity scan, same candidate lists,
settle round discarded, median of five) and filed as
MEASURED-INDICATIVE module-level numbers -- never a
generation speed, never tok/s.

HOST CONTRACT. (1) Chat: cli/cuda_chat.mojo's two
chat_control bodies route "/constrain" forms to
cg_constrain_response (validate + canonicalise a
user-supplied list under J-113's bounds; audit a
finished text against a list). The chat door states
its own binding status: the CUDA chat's generation
loop runs the device sampler, whose token-text
binding is deferred to the J-118 gate (J-114 doc
section 0.7) -- the door validates, canonicalises
and audits tonight; it does not claim the CUDA loop
generates restricted. (2) Server: server/openai.
mojo's OpenAIRequest carries the Aesir extension
field vocab_restriction; cli/native_serve.mojo
validates a field-carrying request through
cg_serve_vocab_response and refuses it before any
generation, because the resident CUDA serve session
cannot enforce a token-text restriction in this
build -- the serve refuses rather than generating
unrestricted under a stated restriction (the J-109
honest-refusal precedent). (3) CPU-line generation
(core/inference.mojo's line, whose sampler this
slice enforces) calls sample_token_from_logits_
restricted with the tokenizer's decoded texts per
vocabulary ID and commits each emitted text through
advance_state; its live leg is the J-118 gate's
(deferred, J-114 doc section 0.7).
"""

from core.sampler import TokenCandidate, apply_vocab_restriction
from core.vocab_restriction import (
    VocabRestrictor,
    vr_audit_text,
    vr_parse_word_list,
    vr_render_word_list,
    vr_word_count,
)


# ------------------------------------------------------------------
# The candidate layer (the sampler mask, host form).
# ------------------------------------------------------------------


def cg_masked_indices(
    candidates: List[TokenCandidate],
    candidate_texts: List[String],
    restrictor: VocabRestrictor,
) raises -> List[Int]:
    """The candidate positions apply_vocab_restriction
    leaves unmasked. Equals the restrictor's
    allowed_indices(candidate_texts) exactly whenever
    the candidates are in the texts' order: the same
    predicate in the same order. Raises on a count
    mismatch, exactly as the sampler mask does."""
    if len(candidates) != len(candidate_texts):
        raise Error(
            "ConstrainedGeneration: candidate/text count "
            "mismatch: " + String(len(candidates))
            + " candidates, " + String(len(candidate_texts))
            + " texts")
    var kept = List[Int]()
    for idx in range(len(candidates)):
        if restrictor.is_token_valid(candidate_texts[idx]):
            kept.append(idx)
    return kept^


def cg_apply_vocab_mask(
    mut candidates: List[TokenCandidate],
    candidate_texts: List[String],
    restrictor: VocabRestrictor,
) raises -> Int:
    """The sampler's own mask, delegated: disallowed
    candidates forced to -1e9, admitted count returned.
    This function adds no decision of its own."""
    return apply_vocab_restriction(candidates, candidate_texts, restrictor)


def cg_greedy_choice(
    candidates: List[TokenCandidate],
    candidate_texts: List[String],
    restrictor: VocabRestrictor,
) raises -> Int:
    """The admitted candidate position with the highest
    logit (ties keep the lowest position), or -1 when
    no candidate is admitted."""
    if len(candidates) != len(candidate_texts):
        raise Error(
            "ConstrainedGeneration: candidate/text count "
            "mismatch: " + String(len(candidates))
            + " candidates, " + String(len(candidate_texts))
            + " texts")
    var best = -1
    var best_logit = Float32(0.0)
    for idx in range(len(candidates)):
        if not restrictor.is_token_valid(candidate_texts[idx]):
            continue
        if best < 0 or candidates[idx].logit > best_logit:
            best = idx
            best_logit = candidates[idx].logit
    return best


# ------------------------------------------------------------------
# The deterministic scan account.
# ------------------------------------------------------------------


struct ScanAccount(Copyable, ImplicitlyCopyable):
    """The restriction scan's deterministic account over
    one step's candidate texts: the scan is a full pass
    with no early exit, so candidates_scanned is the
    set size and text_bytes the summed text bytes. The
    admitted count is the mask's own return, measured
    per state -- never part of this account, which is
    state-free."""

    var candidates_scanned: Int
    var text_bytes: Int

    def __init__(out self, candidates_scanned: Int, text_bytes: Int):
        self.candidates_scanned = candidates_scanned
        self.text_bytes = text_bytes

    def __copyinit__(out self, existing: Self):
        self.candidates_scanned = existing.candidates_scanned
        self.text_bytes = existing.text_bytes


def cg_scan_account(candidate_texts: List[String]) -> ScanAccount:
    var total_bytes = 0
    for text in candidate_texts:
        total_bytes += text.byte_length()
    return ScanAccount(len(candidate_texts), total_bytes)


# ------------------------------------------------------------------
# The chat door (pure answers; the host emits).
# ------------------------------------------------------------------


def cg_is_constrain_command(command: String) -> Bool:
    return command == "/constrain" or command.startswith("/constrain ")


def cg_constrain_status() -> String:
    return String(
        "constrained generation (J-114): output can be "
        "restricted to a permitted word list (J-113's "
        "layer: at most 8192 distinct words, each at "
        "most 64 bytes, exact case-sensitive match). "
        "Enforcement is exact in the sampler: core/"
        "sampler.mojo's restricted entry admits only "
        "tokens whose decoded text the restrictor "
        "admits, commits each emitted text through "
        "advance_state, and stops (-1) rather than "
        "emitting a disallowed token. Forms: /constrain "
        "list <words> (validate + canonicalise a word "
        "list), /constrain audit <words> :: <text> "
        "(grade a finished text against a list). "
        "Binding honesty: this chat's generation loop "
        "runs the CUDA device sampler; its token-text "
        "binding is NOT PROVEN in this build and is "
        "deferred to the J-118 gate (J-114 doc section "
        "0.7) -- this door validates, canonicalises "
        "and audits; it does not claim this chat "
        "generates restricted.")


def _cg_list_response(spec: String) -> String:
    var trimmed = String(spec.strip())
    if trimmed.byte_length() == 0:
        return String(
            "Usage: /constrain list <words> -- the words "
            "are separated by whitespace, commas, or "
            "semicolons")
    try:
        var vocab = vr_parse_word_list(trimmed)
        return (
            String("constrain list: ") + String(vr_word_count(vocab))
            + String(" permitted words (canonical): ")
            + vr_render_word_list(vocab)
            + String(" -- the exact list a restricted "
                     "generation enforces (bounds: 8192 "
                     "entries, 64 bytes per word)"))
    except e:
        return String("constrain list refused: ") + String(e)


def _cg_audit_response(rest: String) -> String:
    var bytes = rest.as_bytes()
    var sep = -1
    var i = 0
    while i + 3 < len(bytes):
        if (Int(bytes[i]) == 32 and Int(bytes[i + 1]) == 58
                and Int(bytes[i + 2]) == 58 and Int(bytes[i + 3]) == 32):
            sep = i
            break
        i += 1
    if sep < 0:
        return String(
            "Usage: /constrain audit <words> :: <text> -- "
            "the word list and the text are separated by "
            "' :: '")
    var spec = String(rest[byte=0:sep])
    var text = String(rest[byte=sep + 4:])
    if String(spec.strip()).byte_length() == 0 or text.byte_length() == 0:
        return String(
            "Usage: /constrain audit <words> :: <text> -- "
            "both the word list and the text are required")
    try:
        var vocab = vr_parse_word_list(spec)
        var audit = vr_audit_text(vocab, text)
        var out = String("constrain audit: ")
        out += String(audit.total_words) + String(" words, ")
        out += String(audit.permitted_words) + String(" permitted")
        if audit.has_offender:
            out += String(", first offender: ") + audit.first_offender
        else:
            out += String(", no offender")
        out += String(
            " -- this grades a finished text against the "
            "list; it does not constrain one")
        return out
    except e:
        return String("constrain audit refused: ") + String(e)


def cg_constrain_response(command: String) -> String:
    """The chat host's one call for every '/constrain'
    form. Every answer is this layer's text; a form
    this layer does not know is refused by name. Never
    raises: refusals are text, in the services manner."""
    if command == "/constrain":
        return cg_constrain_status()
    if command == "/constrain list" or command.startswith(
        "/constrain list "
    ):
        var prefix = String("/constrain list")
        if command.byte_length() <= len(prefix.bytes()):
            return _cg_list_response("")
        return _cg_list_response(
            String(command[byte=len(prefix.bytes()) + 1:]))
    if command == "/constrain audit" or command.startswith(
        "/constrain audit "
    ):
        var prefix = String("/constrain audit")
        if command.byte_length() <= len(prefix.bytes()):
            return _cg_audit_response("")
        return _cg_audit_response(
            String(command[byte=len(prefix.bytes()) + 1:]))
    return String(
        "Unknown constrain form: "
        + command
        + " -- use /constrain (status), /constrain list "
        "<words>, or /constrain audit <words> :: <text>")


# ------------------------------------------------------------------
# The server door (validation + the honest refusal).
# ------------------------------------------------------------------


def cg_serve_vocab_response(spec: String) -> String:
    """The native serve's answer text for a request
    carrying the vocab_restriction extension field: a
    valid list is canonicalised and counted, then the
    refusal is stated -- the resident CUDA serve
    session cannot enforce a token-text restriction
    in this build, so the serve refuses rather than
    generating unrestricted under a stated restriction
    (J-114 doc section 0.5). An invalid list returns
    the parser's refusal. Never raises."""
    try:
        var vocab = vr_parse_word_list(spec)
        return (
            String("vocab_restriction: list valid (")
            + String(vr_word_count(vocab))
            + String(" permitted words: ")
            + vr_render_word_list(vocab)
            + String(") -- generation refused: the "
                     "resident CUDA serve session cannot "
                     "enforce a token-text restriction "
                     "in this build (J-114 doc section "
                     "0.5); no unrestricted generation "
                     "was run under a stated restriction"))
    except e:
        return String("vocab_restriction refused: ") + String(e)
