"""Vocabulary restriction: the constrained-generation
demonstrator -- output restricted to a permitted word
list, as one pure, tested layer (Janas road J-113).

The roadmap text: "`janas-nsm` is a research instrument
(semantic-prime explication with output restriction).
Aesir's analogue decided in the open: a
constrained-generation demonstrator (restrict output to
a word list -- a generally useful engine feature for
grammars/lexicons) built as the transferable core; the
NSM dressing itself REFUSED-or-DEFERRED in the
concordance with reasons." The J-113 doc (docs/janas/
J113_NSM_QUESTION.md) is the normative text; this
header records the design pre-registered in its
section 0 before any code was built. No Janas material
was consulted beyond the road's own filed records; no
Janas source code was opened.

THE VERDICT (doc section 0.2). The NSM dressing is
REFUSED -- the final concordance form of row 69, not a
deferral: (1) its weights/data are CC BY-NC-SA and
Janas itself does not ship them; (2) it is a
single-paper instrument (one model + one adapter, one
paper's scoring apparatus), not an engine capability;
(3) no Aesir consumer exists; (4) its own published
measurement (legality +0.15, neighbour-discrimination
-6.0 points under strict restriction; the default
writes freely) does not recommend the workflow;
(5) the semantic-prime apparatus is the dressing --
the transferable core is the restriction mechanism,
graded separately at row 70 (WANTED). Re-open criteria
are filed in the doc and served by vr_nsm_disposition.

THE DEMONSTRATOR (doc section 0.3). This layer is the
row-70 core proven as pure decisions over DECODED
TOKEN TEXT, in core/grammar.mojo's grain: the layer
decides, hosts execute. It works on token text a
caller supplies, never on token IDs alone (the grammar
layer's standing rule: token IDs contain no lexical
information). Nothing here touches a sampler, a
session, or a socket; the exact sampler enforcement,
its measured cost, and the chat + server surface are
J-114's named scope, and this layer is the decision
core that build must reproduce over logits.

- The word list: vr_parse_word_list builds a
  PermittedVocab from a spec whose words are separated
  by whitespace, commas, or semicolons; entries are
  de-duplicated preserving first order; matching is
  exact and case-sensitive (a lexicon means what it
  says). Bounds on the layer's face: at most
  VR_MAX_ENTRIES distinct entries, each at most
  VR_MAX_WORD_BYTES bytes; an empty or over-bound spec
  is refused.
- The restrictor: VocabRestrictor mirrors the grammar
  automaton's shape over the accepted text -- it
  carries the trailing partial word (bytes since the
  last separator) and the completed-word count.
  Separators are exactly the whitespace bytes (space,
  tab, newline, carriage return) -- answered-locally
  (doc section 0.3): punctuation is part of the word
  as surfaced, so a lexicon that wants "hello," lists
  "hello,"; invented punctuation rules would silently
  change what the list means. is_token_valid admits a
  decoded token text iff every word it completes is
  permitted (completing an empty word -- consecutive
  separators -- is a no-op) and the trailing partial
  word is a prefix of at least one permitted word (or
  empty), so an admitted token never strands
  generation outside the list. advance_state validates
  then commits; a refused token mutates nothing.
  is_accepting: the text so far could end here (the
  partial word is empty or itself permitted).
- Selection: allowed_indices / first_allowed are the
  pure selection form -- which of a step's candidate
  token texts may be taken. The test suite's simulated
  loop drives them step by step and files the result
  as SIMULATED evidence: it proves this layer's
  decisions, not a sampler.
- The audit: vr_audit_text grades a FINISHED text
  against a list (whitespace-split, exact match:
  totals, permitted count, first offender) without
  pretending to have constrained its generation -- the
  free-written case.
"""

comptime VR_MAX_ENTRIES = 8192
comptime VR_MAX_WORD_BYTES = 64


def _vr_is_list_separator(byte: Int) -> Bool:
    """Word-list spec separators: whitespace, comma,
    semicolon."""
    return (
        byte == 32 or byte == 9 or byte == 10 or byte == 13
        or byte == 44 or byte == 59
    )


def _vr_is_space(byte: Int) -> Bool:
    """Text separators for the restrictor and the audit:
    exactly the whitespace bytes."""
    return byte == 32 or byte == 9 or byte == 10 or byte == 13


struct PermittedVocab(Copyable):
    """A permitted word list: distinct entries in
    first-seen order, matched exactly."""

    var entries: List[String]

    def __init__(out self):
        self.entries = List[String]()

    def __copyinit__(out self, existing: Self):
        self.entries = existing.entries.copy()


def vr_contains(vocab: PermittedVocab, word: String) -> Bool:
    """Exact, case-sensitive membership."""
    for entry in vocab.entries:
        if entry == word:
            return True
    return False


def vr_word_count(vocab: PermittedVocab) -> Int:
    return len(vocab.entries)


def vr_parse_word_list(spec: String) raises -> PermittedVocab:
    """Parses a word-list spec (words separated by
    whitespace, commas, or semicolons) into a
    PermittedVocab: de-duplicated preserving first
    order. Refuses an empty result, an entry over
    VR_MAX_WORD_BYTES bytes, and more than
    VR_MAX_ENTRIES distinct entries."""
    var vocab = PermittedVocab()
    var bytes = spec.as_bytes()
    var n = len(bytes)
    var i = 0
    while i < n:
        while i < n and _vr_is_list_separator(Int(bytes[i])):
            i += 1
        if i >= n:
            break
        var start = i
        while i < n and not _vr_is_list_separator(Int(bytes[i])):
            i += 1
        var word = String(spec[byte=start:i])
        if word.byte_length() > VR_MAX_WORD_BYTES:
            raise Error(
                "VocabRestriction: word over "
                + String(VR_MAX_WORD_BYTES) + " bytes: " + word)
        if not vr_contains(vocab, word):
            if len(vocab.entries) >= VR_MAX_ENTRIES:
                raise Error(
                    "VocabRestriction: word list over "
                    + String(VR_MAX_ENTRIES) + " distinct entries")
            vocab.entries.append(word)
    if len(vocab.entries) == 0:
        raise Error("VocabRestriction: word list is empty")
    return vocab^


def vr_render_word_list(vocab: PermittedVocab) -> String:
    """The canonical form: entries joined by ", " in
    list order. Parsing it returns the same list."""
    var out = String("")
    for idx in range(len(vocab.entries)):
        if idx > 0:
            out += ", "
        out += vocab.entries[idx]
    return out^


def _vr_is_prefix_of_any(vocab: PermittedVocab, partial: String) -> Bool:
    if partial.byte_length() == 0:
        return True
    for entry in vocab.entries:
        if entry.startswith(partial):
            return True
    return False


struct _VrWalk(Copyable):
    var valid: Bool
    var partial: String
    var completed: Int

    def __init__(out self, valid: Bool, partial: String, completed: Int):
        self.valid = valid
        self.partial = partial
        self.completed = completed

    def __copyinit__(out self, existing: Self):
        self.valid = existing.valid
        self.partial = existing.partial
        self.completed = existing.completed


struct VocabRestrictor(Copyable):
    """The token-text restrictor over one PermittedVocab:
    the accepted text's trailing partial word and its
    completed-word count (core/grammar.mojo's automaton
    shape, for a word list)."""

    var vocab: PermittedVocab
    var partial_word: String
    var completed_words: Int

    def __init__(out self, vocab: PermittedVocab):
        self.vocab = vocab.copy()
        self.partial_word = String("")
        self.completed_words = 0

    def __copyinit__(out self, existing: Self):
        self.vocab = existing.vocab.copy()
        self.partial_word = existing.partial_word
        self.completed_words = existing.completed_words

    def _walk(self, token_text: String) -> _VrWalk:
        """Simulates appending token_text. Pure --
        reads self, mutates nothing."""
        var cur = self.partial_word
        var completed = 0
        var bytes = token_text.as_bytes()
        for idx in range(len(bytes)):
            var byte = Int(bytes[idx])
            if _vr_is_space(byte):
                if cur.byte_length() > 0:
                    if not vr_contains(self.vocab, cur):
                        return _VrWalk(False, cur, completed)
                    completed += 1
                    cur = String("")
            else:
                cur += String(token_text[byte=idx:idx + 1])
        if not _vr_is_prefix_of_any(self.vocab, cur):
            return _VrWalk(False, cur, completed)
        return _VrWalk(True, cur, completed)

    def is_token_valid(self, token_text: String) -> Bool:
        """True iff appending this decoded token text
        keeps every completed word permitted and the
        trailing partial word a prefix of a permitted
        word (or empty). Empty token text is invalid,
        exactly as in the grammar layer."""
        if token_text.byte_length() == 0:
            return False
        var result = self._walk(token_text)
        return result.valid

    def advance_state(mut self, token_text: String) raises:
        """Validates, then commits one decoded token
        text. A refused token raises and mutates
        nothing."""
        if token_text.byte_length() == 0:
            raise Error("VocabRestriction: empty token text")
        var result = self._walk(token_text)
        if not result.valid:
            raise Error(
                "VocabRestriction: token text violates the "
                "permitted word list")
        self.partial_word = result.partial
        self.completed_words += result.completed

    def is_accepting(self) -> Bool:
        """The accepted text could end here: the partial
        word is empty or itself a permitted word."""
        if self.partial_word.byte_length() == 0:
            return True
        return vr_contains(self.vocab, self.partial_word)

    def allowed_indices(
        self, candidate_texts: List[String]) -> List[Int]:
        """The indices of the candidate token texts this
        restrictor would admit from its current state --
        the pure selection form J-114's sampler mask
        must reproduce."""
        var allowed = List[Int]()
        for idx in range(len(candidate_texts)):
            if self.is_token_valid(candidate_texts[idx]):
                allowed.append(idx)
        return allowed^

    def first_allowed(self, candidate_texts: List[String]) -> Int:
        """The first admitted candidate's index, or -1
        when no candidate may be taken."""
        for idx in range(len(candidate_texts)):
            if self.is_token_valid(candidate_texts[idx]):
                return idx
        return -1


struct VocabAudit(Copyable):
    """A finished text graded against a word list."""

    var total_words: Int
    var permitted_words: Int
    var has_offender: Bool
    var first_offender: String

    def __init__(
        out self,
        total_words: Int,
        permitted_words: Int,
        has_offender: Bool,
        first_offender: String,
    ):
        self.total_words = total_words
        self.permitted_words = permitted_words
        self.has_offender = has_offender
        self.first_offender = first_offender

    def __copyinit__(out self, existing: Self):
        self.total_words = existing.total_words
        self.permitted_words = existing.permitted_words
        self.has_offender = existing.has_offender
        self.first_offender = existing.first_offender


def vr_audit_text(vocab: PermittedVocab, text: String) -> VocabAudit:
    """Grades a finished text against the list:
    whitespace-split, exact match; totals, permitted
    count, and the first offending word (if any). This
    audits a text; it does not constrain one."""
    var total = 0
    var permitted = 0
    var has_offender = False
    var first_offender = String("")
    var bytes = text.as_bytes()
    var n = len(bytes)
    var i = 0
    while i < n:
        while i < n and _vr_is_space(Int(bytes[i])):
            i += 1
        if i >= n:
            break
        var start = i
        while i < n and not _vr_is_space(Int(bytes[i])):
            i += 1
        var word = String(text[byte=start:i])
        total += 1
        if vr_contains(vocab, word):
            permitted += 1
        elif not has_offender:
            has_offender = True
            first_offender = word
    return VocabAudit(total, permitted, has_offender, first_offender)


def vr_nsm_disposition() -> String:
    """The NSM verdict as served text (doc section
    0.2): REFUSED, with its reasons and re-open
    criteria, stated where a user of this layer
    looks."""
    return String(
        "NSM dressing (janas-nsm): REFUSED -- final "
        "concordance form (J-113). Reasons: (1) its "
        "weights/data are CC BY-NC-SA and are not "
        "shipped by Janas itself; (2) it is a "
        "single-paper research instrument (one model "
        "+ one adapter, one paper's scoring), not an "
        "engine capability; (3) no Aesir consumer "
        "exists; (4) its own published measurement "
        "does not recommend the workflow (strict "
        "restriction: legality +0.15, "
        "neighbour-discrimination -6.0 points; the "
        "default writes freely); (5) the "
        "semantic-prime apparatus is the dressing -- "
        "the transferable core is vocabulary "
        "restriction, which this layer demonstrates "
        "and J-114 builds. Re-open only if: a named "
        "Aesir consumer asks for NSM explication by "
        "name, weights/data under shippable terms "
        "are actually obtainable, and Volmarr rules "
        "the road re-opened.")
