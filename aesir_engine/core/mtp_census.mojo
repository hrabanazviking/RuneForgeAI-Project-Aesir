"""MTP census classifier (Janas road J-076).

The roadmap text: "MTP census in files. Which GGUF files in
Aesir's wave carry prediction-head tensors (the Qwen3.5/3.6/Next
and Gemma assistant cases from Janas's docs, checked against the
actual files, sha-pinned)."

This module is the census's PERMANENT, mechanical half: the
tensor-name classification rules, stated once, that the filed
census script (docs/janas/j076_mtp_census.py) applies to real
GGUF tensor directories and that J-077's head support consumes
(a file's head is found by these rules or the file is refused
by name -- never silently plain). The module reads no file,
opens no device, and contains no speed: it classifies names
a host hands it from a directory the host read.

THE RULES (pre-registered; Aesir-local -- answered-locally,
doc section 7: Janas's public docs, as censused in Part I,
name the cases -- a prediction block in the Qwen3.5/3.6 GGUF,
a separately converted block for Qwen3-Next, a separate
assistant file for Gemma 4 -- but state no tensor-name rule;
the names below are the GGUF naming forms for those cases,
stated here so two readers classify the same directory
identically):

- HEAD_NEXTN: the name contains "nextn" -- the next-layer /
  next-token prediction block's tensors (the form a converted
  Qwen3-Next / Qwen3.5 prediction block carries in GGUF).
- HEAD_MTP: the name contains "mtp" -- a multi-token
  prediction block carried under its own name.
- HEAD_ASSISTANT: the name contains "assistant" -- assistant-
  drafter tensors carried inside a file (the Gemma case in
  Janas's docs is a SEPARATE file taken as the --mtp file;
  an in-file assistant tensor would classify here, and the
  separate-file case is a filename question the census doc
  grades from the acquisition ledgers, not a tensor question).
- HEAD_NONE: everything else -- the ordinary directory
  (token_embd, blk.N.*, output*) carries no head.

Matching is on the name as filed. GGUF tensor names are
lowercase in every directory this road has read (J-015's two
full directories, J-074's files); the census script lowercases
defensively before applying the same substrings, and the two
agree on every name either has seen.

A FILE VERDICT aggregates a whole directory:
- VERDICT_VOCAB_ONLY: zero tensors -- no head can hide in an
  empty directory, and the file is not a model file at all.
- VERDICT_NO_MTP: a non-empty directory, fully read, with
  zero head-classified tensors -- proven absent FOR THAT FILE.
- VERDICT_WITH_MTP: at least one head-classified tensor;
  the per-kind counts are the census row.
A file that was never read has NO verdict in this module --
absence of a file is filed by the census doc as ABSENT-FILE /
NOT PROVEN, never as NO_MTP.
"""


comptime HEAD_NONE = 0
comptime HEAD_NEXTN = 1
comptime HEAD_MTP = 2
comptime HEAD_ASSISTANT = 3

comptime VERDICT_NO_MTP = 0
comptime VERDICT_WITH_MTP = 1
comptime VERDICT_VOCAB_ONLY = 2


def classify_tensor_name(name: String) -> Int:
    """The head kind one tensor name evidences, by the rules
    in this module's header. First match wins, in the order
    nextn, mtp, assistant -- a name carrying two markers
    files under the first, and the census script applies the
    identical order."""
    if "nextn" in name:
        return HEAD_NEXTN
    if "mtp" in name:
        return HEAD_MTP
    if "assistant" in name:
        return HEAD_ASSISTANT
    return HEAD_NONE


def head_kind_name(kind: Int) -> String:
    if kind == HEAD_NEXTN:
        return String("nextn")
    if kind == HEAD_MTP:
        return String("mtp")
    if kind == HEAD_ASSISTANT:
        return String("assistant")
    return String("none")


def verdict_name(verdict: Int) -> String:
    if verdict == VERDICT_WITH_MTP:
        return String("WITH_MTP")
    if verdict == VERDICT_VOCAB_ONLY:
        return String("VOCAB_ONLY")
    return String("NO_MTP")


struct MtpCensus(Copyable, Movable):
    """One file's census row, accumulated tensor by tensor
    from a directory a host read. Counts only; the names
    themselves stay in the host's filed directory record."""

    var n_tensors: Int
    var nextn_count: Int
    var mtp_count: Int
    var assistant_count: Int

    def __init__(out self):
        self.n_tensors = 0
        self.nextn_count = 0
        self.mtp_count = 0
        self.assistant_count = 0

    def record(mut self, name: String):
        self.n_tensors += 1
        var kind = classify_tensor_name(name)
        if kind == HEAD_NEXTN:
            self.nextn_count += 1
        elif kind == HEAD_MTP:
            self.mtp_count += 1
        elif kind == HEAD_ASSISTANT:
            self.assistant_count += 1

    def head_count(self) -> Int:
        return self.nextn_count + self.mtp_count + self.assistant_count

    def has_head(self) -> Bool:
        return self.head_count() > 0

    def verdict(self) -> Int:
        if self.n_tensors == 0:
            return VERDICT_VOCAB_ONLY
        if self.has_head():
            return VERDICT_WITH_MTP
        return VERDICT_NO_MTP
