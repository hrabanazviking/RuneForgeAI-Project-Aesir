"""Speculative acceptance measurement (Janas road J-075).

The roadmap text: "Acceptance measurement. Acceptance rate
by text type (prose, code, structured) per pair; the
instrumentation permanent, the numbers filed; the Italian-
prose lesson (acceptance can collapse by language)
reproduced on Aesir's own pairs."

THE INSTRUMENT, stated before any building (the slice doc,
docs/janas/J075_ACCEPTANCE_MEASUREMENT.md section 1, is its
normative text). This module is PERMANENT INSTRUMENTATION,
not a new account: it binds to J-071's verify account and
J-072's loop accounts and duplicates neither. A round enters
the ledger ONLY as a J-071 VerifyAccount that
account_is_consistent() accepts, filed under the account's
own proposer kind; the ledger adds nothing to a round and
recomputes nothing J-071 already derived -- it AGGREGATES
accounts, per pair and per text type, so acceptance can be
read off filed records rather than reconstructed.

DEFINITIONS (pre-registered, binding on every reader):

- ACCEPTANCE RATE of a row = tokens accepted / tokens
  drafted, over the row's rounds: sum(accepted_count) /
  sum(k) from the filed VerifyAccounts. The bonus/correction
  token a round emits (accepted + 1) is NOT an accepted
  draft token and never enters either side. Rates are
  carried exactly as the integer pair (accepted, drafted)
  and as basis points (accepted * 10000 // drafted); a row
  with zero drafted has no rate (rate_basis_points refuses).
- A PAIR is (proposer kind, pair id). The kind is J-071's
  proposer-kind code, read off the account itself. The pair
  id is the host's cross-model pair index: 0 for every
  non-cross-model proposer (an MTP head, an assistant model,
  and conversation guesses draft for their own session's
  target -- there is one pair per kind), and for
  PROPOSER_CROSS_MODEL the index of the J-074 pairing
  verdict the rounds ran under (pair id 1 is the road's
  first pair, Qwen3-0.6B -> Qwen3-4B, J-074 section 4).
  Rounds of different kinds, or of different pair ids,
  never share a row.
- TEXT TYPE is one of prose / code / structured, assigned
  by classify_text() from a stated feature record -- never
  by a reader's impression of the text (see the classifier
  below). LANGUAGE is a second, independent dimension,
  assigned for PROSE rows only (english / italian / other);
  code and structured rows carry LANG_NOT_APPLICABLE by
  rule, so a prose language can never hide inside a code
  row, and a language collapse can never hide inside a
  prose aggregate: the table keeps (kind, pair, type,
  language) rows separate, and any aggregate a reader forms
  is formed FROM the rows, in the open.

THE CLASSIFIER (mechanical, deterministic, Aesir-local --
answered-locally, doc section 7: the filed public docs name
the text types and the Italian lesson but state no
classification rule). The host counts a fixed feature
record over the round's prompt + generated text (the exact
counting rules are the module header's, so two hosts count
the same text identically):

- code_fences: occurrences of a triple-backtick fence.
- semicolons, braces, brackets, colons: character counts.
- code_keyword_hits: whole-word occurrences of the fixed
  list {def, fn, function, return, import, class, var, let,
  const, static, void, int} (case-sensitive).
- starts_structured: the first non-whitespace character is
  '{' or '['.
- italian_hits / english_hits: whole-word occurrences of
  the fixed marker lists (case-insensitive) -- italian:
  {il, lo, la, di, che, e, non, un, una, del, della, sono,
  per, con, anche, questo}; english: {the, of, and, a, in,
  is, you, that, it, he, was, for, on, are, with}.

Rules, in order (the first match is the verdict):

1. STRUCTURED: starts_structured AND colons >= 1 AND
   (braces + brackets) >= 2.
2. CODE: code_fences >= 1, OR code_keyword_hits >= 2, OR
   (semicolons >= 2 AND braces >= 1).
3. PROSE: everything else.
Language (prose only): ITALIAN when italian_hits >= 2 AND
italian_hits > english_hits; ENGLISH when english_hits >= 2
AND english_hits > italian_hits; OTHER otherwise (a tie, or
neither list reaching 2 -- the row is filed, never forced
into a language it did not evidence). For code/structured
the language is NOT_APPLICABLE regardless of marker hits.

THE PER-ROUND DISTRIBUTION: every row carries a histogram
of the rounds' accepted counts (bin a = rounds whose
accepted_count == a, a in 0..15). From a filed row a reader
reproduces: rounds = sum(bins); accepted = sum(a * bin[a]);
and with the row's drafted total, the rate. The histogram
is also the shape J-079's adaptive-depth tuning will read.

WHAT THIS MODULE IS NOT: it executes no forward, times
nothing, opens no device, and contains no speed. Its
numbers are exactly as honest as the accounts fed into it:
accounts from a live pair ground a live rate; accounts from
synthetic fixtures ground a SIMULATED rate, a property of
the fixture, never of a model pair (doc section 4). No
proposer implementation, verify-pass executor, or session
wiring exists in this tree (J-074 section 2, unchanged):
require_draft_check_use() still fails closed, so tonight
the ledger is exercised over synthetic accounts only and
every real-pair row is NOT PROVEN (doc section 6).

HOST CONTRACT (binding on the first live host): (1) run
rounds under J-072's host contract and file every round's
VerifyAccount; (2) count the feature record over each
round's text by the counting rules above and classify with
classify_text -- never hand-label a row; (3) record each
account with record_round_classified (or record_round with
a classify_text verdict) under the round's true pair id --
for cross-model rounds, the J-074 verdict's pair index;
(4) file the ledger's rows with the run's evidence: a rate
is quotable only with its (accepted, drafted) pair and its
row's (kind, pair id, text type, language); (5) never quote
an aggregate without its rows -- the Italian-prose lesson
is precisely that aggregates hide collapses.
"""

from core.speculative_verify import (
    PROPOSER_CROSS_MODEL,
    VerifyAccount,
    account_is_consistent,
    plan_proposer,
)

# Text types (classify_text's verdicts).
comptime TEXT_PROSE = 0
comptime TEXT_CODE = 1
comptime TEXT_STRUCTURED = 2

# Languages (prose rows only; LANG_NOT_APPLICABLE elsewhere).
comptime LANG_ENGLISH = 0
comptime LANG_ITALIAN = 1
comptime LANG_OTHER = 2
comptime LANG_NOT_APPLICABLE = 3

# The deepest accepted count a round can carry (k <= 15, so
# accepted_count <= 15): the histogram's bin count.
comptime ACCEPT_HIST_BINS = 16

# The road's first cross-model pair (J-074 section 4).
comptime PAIR_ID_NONE = 0
comptime PAIR_ID_QWEN3_06B_TO_4B = 1


def text_type_name(code: Int) raises -> String:
    if code == TEXT_PROSE:
        return String("prose")
    if code == TEXT_CODE:
        return String("code")
    if code == TEXT_STRUCTURED:
        return String("structured")
    raise Error("SpeculativeAcceptance: unknown text type code")


def language_name(code: Int) raises -> String:
    if code == LANG_ENGLISH:
        return String("english")
    if code == LANG_ITALIAN:
        return String("italian")
    if code == LANG_OTHER:
        return String("other")
    if code == LANG_NOT_APPLICABLE:
        return String("not_applicable")
    raise Error("SpeculativeAcceptance: unknown language code")


struct TextFeatures(Copyable, ImplicitlyCopyable):
    """One round's text, counted by the header's fixed rules.

    Every field is a host-side count over the round's prompt
    + generated text, using exactly the character, fence,
    keyword, and marker lists the header states. The
    classifier reads only this record, so classification is
    a pure function of stated features: the same text,
    counted by the stated rules, classifies identically on
    every host, and a filed record can be re-classified by
    any reader to check the row it was filed under.
    """

    var code_fences: Int
    var semicolons: Int
    var braces: Int
    var brackets: Int
    var colons: Int
    var code_keyword_hits: Int
    var starts_structured: Bool
    var italian_hits: Int
    var english_hits: Int

    def __init__(
        out self,
        code_fences: Int,
        semicolons: Int,
        braces: Int,
        brackets: Int,
        colons: Int,
        code_keyword_hits: Int,
        starts_structured: Bool,
        italian_hits: Int,
        english_hits: Int,
    ):
        self.code_fences = code_fences
        self.semicolons = semicolons
        self.braces = braces
        self.brackets = brackets
        self.colons = colons
        self.code_keyword_hits = code_keyword_hits
        self.starts_structured = starts_structured
        self.italian_hits = italian_hits
        self.english_hits = english_hits


struct TextClass(Copyable, ImplicitlyCopyable):
    """classify_text's verdict: a text type and a language."""

    var text_type: Int
    var language: Int

    def __init__(out self, text_type: Int, language: Int):
        self.text_type = text_type
        self.language = language


def classify_text(features: TextFeatures) raises -> TextClass:
    """Classify one feature record under the header's rules.

    The rules run in their stated order; the first match is
    the verdict. Negative counts are refused (a count is a
    count). Language is decided for prose only; a code or
    structured verdict carries LANG_NOT_APPLICABLE whatever
    the marker counts say.
    """
    if (
        features.code_fences < 0
        or features.semicolons < 0
        or features.braces < 0
        or features.brackets < 0
        or features.colons < 0
        or features.code_keyword_hits < 0
        or features.italian_hits < 0
        or features.english_hits < 0
    ):
        raise Error("SpeculativeAcceptance: feature counts must be non-negative")
    # Rule 1: structured.
    if (
        features.starts_structured
        and features.colons >= 1
        and features.braces + features.brackets >= 2
    ):
        return TextClass(TEXT_STRUCTURED, LANG_NOT_APPLICABLE)
    # Rule 2: code.
    if (
        features.code_fences >= 1
        or features.code_keyword_hits >= 2
        or (features.semicolons >= 2 and features.braces >= 1)
    ):
        return TextClass(TEXT_CODE, LANG_NOT_APPLICABLE)
    # Rule 3: prose; the language dimension applies here only.
    if features.italian_hits >= 2 and features.italian_hits > features.english_hits:
        return TextClass(TEXT_PROSE, LANG_ITALIAN)
    if features.english_hits >= 2 and features.english_hits > features.italian_hits:
        return TextClass(TEXT_PROSE, LANG_ENGLISH)
    return TextClass(TEXT_PROSE, LANG_OTHER)


struct AcceptanceRow(Copyable):
    """One (pair, text type, language) row of the ledger.

    Totals are accumulated from filed VerifyAccounts only:
    rounds, drafted = sum(k), accepted = sum(accepted_
    count). hist[a] counts the rounds whose accepted_count
    was exactly a, so the row's rounds and accepted totals
    are reproducible from the distribution alone (see
    row_totals_reproduce).
    """

    var proposer_kind: Int
    var pair_id: Int
    var text_type: Int
    var language: Int
    var rounds: Int
    var drafted: Int
    var accepted: Int
    var hist: List[Int]

    def __init__(
        out self,
        proposer_kind: Int,
        pair_id: Int,
        text_type: Int,
        language: Int,
    ):
        self.proposer_kind = proposer_kind
        self.pair_id = pair_id
        self.text_type = text_type
        self.language = language
        self.rounds = 0
        self.drafted = 0
        self.accepted = 0
        self.hist = List[Int]()
        for _ in range(ACCEPT_HIST_BINS):
            self.hist.append(0)

    def __copyinit__(out self, existing: Self):
        self.proposer_kind = existing.proposer_kind
        self.pair_id = existing.pair_id
        self.text_type = existing.text_type
        self.language = existing.language
        self.rounds = existing.rounds
        self.drafted = existing.drafted
        self.accepted = existing.accepted
        self.hist = existing.hist.copy()

    def copy(self) -> Self:
        var copied = Self(
            self.proposer_kind, self.pair_id, self.text_type, self.language
        )
        copied.rounds = self.rounds
        copied.drafted = self.drafted
        copied.accepted = self.accepted
        copied.hist = self.hist.copy()
        return copied^


def _validate_row_key(
    proposer_kind: Int, pair_id: Int, text_type: Int, language: Int
) raises:
    """The row-key discipline, shared by record and lookup.

    The kind must be one of J-071's proposers (plan_proposer
    refuses the rest); a pair id is meaningful only for the
    cross-model kind (any other kind files under
    PAIR_ID_NONE -- a head or conversation round has no
    second model to index); prose rows carry a real
    language, never NOT_APPLICABLE; non-prose rows carry
    exactly NOT_APPLICABLE.
    """
    _ = plan_proposer(proposer_kind)
    if pair_id < 0:
        raise Error("SpeculativeAcceptance: pair id must be non-negative")
    if proposer_kind != PROPOSER_CROSS_MODEL and pair_id != PAIR_ID_NONE:
        raise Error(
            "SpeculativeAcceptance: only cross-model rounds carry a pair id;"
            " other proposers file under PAIR_ID_NONE"
        )
    if text_type == TEXT_PROSE:
        if (
            language != LANG_ENGLISH
            and language != LANG_ITALIAN
            and language != LANG_OTHER
        ):
            raise Error(
                "SpeculativeAcceptance: a prose row carries english, italian,"
                " or other -- never not_applicable"
            )
    elif text_type == TEXT_CODE or text_type == TEXT_STRUCTURED:
        if language != LANG_NOT_APPLICABLE:
            raise Error(
                "SpeculativeAcceptance: code and structured rows carry"
                " not_applicable language by rule"
            )
    else:
        raise Error("SpeculativeAcceptance: unknown text type")


struct AcceptanceLedger(Copyable):
    """The permanent acceptance ledger: rows, keyed as stated.

    Rows are created on first record and never merged after
    the fact: separation by (kind, pair id, text type,
    language) is the instrument's whole point.
    """

    var rows: List[AcceptanceRow]

    def __init__(out self):
        self.rows = List[AcceptanceRow]()

    def __copyinit__(out self, existing: Self):
        self.rows = List[AcceptanceRow]()
        for i in range(len(existing.rows)):
            self.rows.append(existing.rows[i].copy())

    def copy(self) -> Self:
        var copied = Self()
        for i in range(len(self.rows)):
            copied.rows.append(self.rows[i].copy())
        return copied^

    def find_row(
        self, proposer_kind: Int, pair_id: Int, text_type: Int, language: Int
    ) -> Int:
        """The row's index, or -1 when no such row was filed."""
        for i in range(len(self.rows)):
            var r = self.rows[i].copy()
            if (
                r.proposer_kind == proposer_kind
                and r.pair_id == pair_id
                and r.text_type == text_type
                and r.language == language
            ):
                return i
        return -1


def record_round(
    mut ledger: AcceptanceLedger,
    pair_id: Int,
    text_type: Int,
    language: Int,
    account: VerifyAccount,
) raises:
    """File one round's J-071 account into its row.

    The account is the ONLY source: its proposer kind keys
    the row, its k is the round's drafted count, its
    accepted_count the round's accepted count. Refusals: an
    account account_is_consistent() rejects (a broken
    account grounds no rate, J-071's verdict rule); a row
    key failing _validate_row_key. A refused record changes
    nothing in the ledger.
    """
    if not account_is_consistent(account):
        raise Error(
            "SpeculativeAcceptance: an inconsistent verify account grounds"
            " no acceptance record; restate the account or the round"
        )
    _validate_row_key(account.proposer_kind, pair_id, text_type, language)
    var idx = ledger.find_row(account.proposer_kind, pair_id, text_type, language)
    if idx == -1:
        ledger.rows.append(
            AcceptanceRow(account.proposer_kind, pair_id, text_type, language)
        )
        idx = len(ledger.rows) - 1
    var row = ledger.rows[idx].copy()
    row.rounds += 1
    row.drafted += account.k
    row.accepted += account.accepted_count
    row.hist[account.accepted_count] += 1
    ledger.rows[idx] = row^


def record_round_classified(
    mut ledger: AcceptanceLedger,
    pair_id: Int,
    features: TextFeatures,
    account: VerifyAccount,
) raises:
    """Classify the round's text, then record the account.

    The host's one-call path (host contract step 3): the
    row a round lands in is classify_text's verdict over
    the stated feature record, never a hand label.
    """
    var cls = classify_text(features)
    record_round(ledger, pair_id, cls.text_type, cls.language, account)


def rate_basis_points(row: AcceptanceRow) raises -> Int:
    """The row's acceptance rate, in basis points (exact).

    accepted * 10000 // drafted, over the row's filed
    totals. A row with no drafted tokens has no rate and is
    refused, never reported as 0 or 100%.
    """
    if row.drafted <= 0:
        raise Error(
            "SpeculativeAcceptance: a row with no drafted tokens has no rate"
        )
    if row.accepted < 0 or row.accepted > row.drafted:
        raise Error("SpeculativeAcceptance: row totals are inconsistent")
    return row.accepted * 10000 // row.drafted


def row_totals_reproduce(row: AcceptanceRow) -> Bool:
    """True when the row's distribution reproduces its totals.

    rounds == sum(hist) and accepted == sum(a * hist[a]):
    any reader holding only the filed distribution can
    recompute the row's rounds and accepted count exactly,
    and with the filed drafted total, its rate.
    """
    var rounds = 0
    var accepted = 0
    for a in range(len(row.hist)):
        rounds += row.hist[a]
        accepted += a * row.hist[a]
    return rounds == row.rounds and accepted == row.accepted


def ledger_totals(
    ledger: AcceptanceLedger,
    proposer_kind: Int,
    pair_id: Int,
) raises -> AcceptanceRow:
    """One pair's totals across ALL its rows (the aggregate).

    Returned as a synthetic row (text_type/language -1,
    never filed in the ledger) so a reader can set the
    aggregate's rate beside its rows' rates and SEE what
    the aggregate hides -- the Italian-prose lesson is a
    statement about exactly this comparison. The kind/pair
    key is validated as on recording; a pair with no rows
    yields an empty synthetic row (whose rate refuses).
    """
    _validate_row_key(proposer_kind, pair_id, TEXT_PROSE, LANG_ENGLISH)
    var total = AcceptanceRow(proposer_kind, pair_id, -1, -1)
    for i in range(len(ledger.rows)):
        var r = ledger.rows[i].copy()
        if r.proposer_kind == proposer_kind and r.pair_id == pair_id:
            total.rounds += r.rounds
            total.drafted += r.drafted
            total.accepted += r.accepted
            for a in range(ACCEPT_HIST_BINS):
                total.hist[a] += r.hist[a]
    return total^
