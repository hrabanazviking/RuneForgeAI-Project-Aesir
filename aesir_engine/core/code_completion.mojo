"""Code completion mode: the pure completion layer --
the server answering at an editor's cursor (Janas road
J-111).

The roadmap text: "Code completion mode. The server
answering at an editor's cursor: fill-in-the-middle
where the arch supports it, the sliding-window context
of J-097, latency measured against Janas's published
1.5-2.2 s class on the laptop line." The J-111 doc
(docs/janas/J111_CODE_COMPLETION.md) is the normative
text; this header records the design pre-registered in
its section 0 before any code was built. No Janas
material was consulted beyond the road's own filed
records and the published latency class the roadmap
itself cites; no Janas source code was opened.

(a) FIM HONESTY (doc section 0.1). Fill-in-the-middle
needs the model's FIM special tokens validated in the
tokenizer's control set, framed by the session, and
inside the admitted generation range. In this tree NO
architecture earns it: no FIM spelling exists in any
tokenizer, loader, or session; loader/
llama3_tokenizer.mojo validates exactly the Llama 3
and Qwen chat controls (its Qwen 2 admitted range ends
at the ordinary BPE limit, above which that family's
FIM spellings would sit); the Gemma 4 tokenizer
validates no FIM control either. cc_fim_supported is
therefore False for every recognised arch, and
cc_mode_for_arch returns CC_MODE_PREFIX_SUFFIX for
each -- the honest shape, graded as such, never a
faked FIM claim. The table is the seam: a future slice
that wires one arch's FIM controls end-to-end (with
its live grade) flips that arch here, and only here.

(b) THE PLAN. cc_plan(arch, prefix, suffix) builds a
CompletionPlan: the mode, the GENERATION PROMPT --
the prefix, exactly and only the prefix -- and the
suffix retained separately. The suffix is NEVER
concatenated into the generation prompt: a causal
model without FIM tokens cannot condition on text
after the cursor while generating at the cursor, and
placing the suffix in the prompt would put future
code causally before the generation point. The
suffix's two honest jobs are the window account (c)
and the overlap trim (d). Bounds: prefix and suffix
each <= CC_MAX_TEXT_BYTES (64 KiB, the parser's
standing text bound); both empty is refused (there
is no cursor in an empty document); an unrecognised
arch is refused by name.

(c) THE WINDOW COMPOSITION (J-097's first consumer).
cc_window_reuse(old_doc, new_doc, cursor_tokens)
prices a repeat completion request over an edited
document through J-097's own functions: the first
divergence by exact token comparison
(kw_first_divergence over the actual sequences) and
the reusable count under kw_reusable's final-token
and old-length caps -- then capped at the cursor:
positions at or after the cursor are suffix, not
generation context, so reuse never exceeds
cursor_tokens - 1 under the same final-token rule
applied to the generation prompt; an empty prefix
(cursor_tokens == 0) reuses 0. No line-count guess is
ever taken. This composition is an account: no live
session keeps rows by it tonight (the resident serve
session resets per request); live consumption is
deferred with its recipe (doc sections 0.3/0.5).

(d) THE OVERLAP TRIM. A prefix/suffix completion's
common failure is re-generating the opening of the
code that already follows the cursor. cc_trim_overlap
removes the longest span by which the finished
completion's ending equals the suffix's opening, so
inserted text does not duplicate the suffix: no
overlap leaves the completion unchanged, and a
completion that is entirely overlap trims to empty.
Byte-exact, on the texts as given.

(e) THE LATENCY GRADING. Janas's published
completion-latency class on its laptop line is
1.5-2.2 s -- a PUBLISHED figure from Janas's public
documentation, carried by the roadmap text. It is
this module's grading band only (CC_PUBLISHED_LOW_MS
/ CC_PUBLISHED_HIGH_MS): cc_latency_class grades a
CALLER-MEASURED millisecond count as
FASTER_THAN / WITHIN / SLOWER_THAN that band. This
module measures nothing, and no number graded here is
a Janas number or an estimate from one; a live Aesir
latency exists only from a run under the doc's
deferred-leg recipe (guarded laptop window, median
of 3 per cell, ids-first raw-oracle discipline for
any faithfulness grade, never llama-cli
--single-turn), re-cited at the J-118 gate.

HOST CONTRACT. (1) server/openai.mojo's OpenAIRequest
carries the suffix field; cli/native_serve.mojo's
completions branch plans through cc_plan for the
resident profile's arch and generates from the plan's
generation prompt, and overlap-trims the non-streamed
answer (streamed chunks are sent as generated and are
NOT trimmed -- an overlap is knowable only at the
end; the doc records the streamed form as untrimmed).
(2) A chat-completions request carrying a suffix is
refused at the serve: completion at a cursor is a
raw-completions shape. (3) core/openai_audit.mojo's
suffix row is PARTIAL by this slice: honoured as
prefix/suffix context, not as FIM.
"""

from core.kv_window import kw_first_divergence, kw_reusable

comptime CC_MODE_PREFIX_SUFFIX = 0
comptime CC_MODE_FIM = 1

comptime CC_LATENCY_FASTER = 0
comptime CC_LATENCY_WITHIN = 1
comptime CC_LATENCY_SLOWER = 2

# Janas's PUBLISHED completion-latency class (public
# documentation, carried by the roadmap text): the
# grading band only, never a measured Aesir number.
comptime CC_PUBLISHED_LOW_MS = 1500
comptime CC_PUBLISHED_HIGH_MS = 2200

# The parser's standing text bound, restated here so
# the pure layer and the parser cannot drift apart
# silently (the inspect pins the equality).
comptime CC_MAX_TEXT_BYTES = 65536


def cc_mode_name(code: Int) -> String:
    if code == CC_MODE_PREFIX_SUFFIX:
        return String("PREFIX_SUFFIX")
    if code == CC_MODE_FIM:
        return String("FIM")
    return String("UNKNOWN")


def cc_latency_name(code: Int) -> String:
    if code == CC_LATENCY_FASTER:
        return String("FASTER_THAN_PUBLISHED_CLASS")
    if code == CC_LATENCY_WITHIN:
        return String("WITHIN_PUBLISHED_CLASS")
    if code == CC_LATENCY_SLOWER:
        return String("SLOWER_THAN_PUBLISHED_CLASS")
    return String("UNKNOWN")


def cc_arch_names() -> List[String]:
    """The architectures the tree's registry recognises
    (core/model_registry.mojo's classify): the served
    three (llama, qwen3, gemma4) plus the recognised
    but NOT READY two (qwen2, mistral)."""
    var names = List[String]()
    names.append(String("llama"))
    names.append(String("qwen2"))
    names.append(String("qwen3"))
    names.append(String("gemma4"))
    names.append(String("mistral"))
    return names^


def cc_arch_recognised(arch: String) -> Bool:
    for name in cc_arch_names():
        if arch == name:
            return True
    return False


def cc_fim_supported(arch: String) raises -> Bool:
    """True FIM support, from the tree (doc section
    0.1): a recognised arch whose tokenizer validates,
    frames, and admits FIM special tokens. No arch in
    this tree meets that bar, so this is False for
    every recognised arch; an unrecognised arch is
    refused by name rather than graded."""
    if not cc_arch_recognised(arch):
        raise Error("CodeCompletion: unrecognised architecture: " + arch)
    return False


def cc_fim_reason(arch: String) raises -> String:
    """Why the arch carries no true FIM in this tree,
    in one plain sentence (doc section 0.1)."""
    if not cc_arch_recognised(arch):
        raise Error("CodeCompletion: unrecognised architecture: " + arch)
    if arch == "llama":
        return String(
            "no FIM special token is validated, framed, or admitted by "
            "the Llama 3 tokenizer path in this tree")
    if arch == "qwen2" or arch == "qwen3":
        return String(
            "the Qwen tokenizer path validates only the chat controls "
            "and admits no FIM special token in this tree (the Qwen 2 "
            "admitted range ends at the ordinary BPE limit)")
    if arch == "gemma4":
        return String(
            "the Gemma 4 tokenizer path validates no FIM special token "
            "in this tree")
    return String(
        "the arch is recognised but has no native profile or tokenizer "
        "path in this tree, and no FIM special token is validated")


def cc_mode_for_arch(arch: String) raises -> Int:
    """The completion mode one arch honestly carries:
    FIM where cc_fim_supported earns it (no arch yet),
    prefix/suffix otherwise."""
    if cc_fim_supported(arch):
        return CC_MODE_FIM
    return CC_MODE_PREFIX_SUFFIX


struct CompletionPlan:
    """One completion request, planned: the mode, the
    generation prompt (the prefix, exactly), and the
    suffix retained separately for the window account
    and the overlap trim. The suffix is never part of
    the generation prompt (header section (b))."""

    var mode: Int
    var generation_prompt: String
    var suffix: String
    var prefix_bytes: Int
    var suffix_bytes: Int

    def __init__(
        out self, mode: Int, generation_prompt: String, suffix: String
    ):
        self.mode = mode
        self.generation_prompt = generation_prompt
        self.suffix = suffix
        self.prefix_bytes = generation_prompt.byte_length()
        self.suffix_bytes = suffix.byte_length()


def cc_plan(arch: String, prefix: String, suffix: String) raises -> CompletionPlan:
    """Plan one editor-cursor completion request for a
    resident arch: the mode from the arch table, the
    generation prompt = the prefix exactly, the suffix
    retained separately. Refusals: unrecognised arch,
    either text over the standing bound, both texts
    empty (no cursor in an empty document)."""
    var mode = cc_mode_for_arch(arch)
    if prefix.byte_length() > CC_MAX_TEXT_BYTES:
        raise Error("CodeCompletion: prefix exceeds the 64 KiB text bound")
    if suffix.byte_length() > CC_MAX_TEXT_BYTES:
        raise Error("CodeCompletion: suffix exceeds the 64 KiB text bound")
    if prefix.byte_length() == 0 and suffix.byte_length() == 0:
        raise Error("CodeCompletion: an empty document has no cursor")
    return CompletionPlan(mode, prefix, suffix)


def cc_window_reuse(
    old_doc: List[Int], new_doc: List[Int], cursor_tokens: Int
) raises -> Int:
    """Reusable leading positions for a repeat
    completion over an edited document (header
    section (c)): J-097's divergence account over the
    actual token sequences, capped at the cursor under
    the final-token rule. cursor_tokens is the new
    document's prefix length in tokens (the generation
    prompt's length): it must lie inside the new
    document. An empty prefix reuses 0."""
    if cursor_tokens < 0 or cursor_tokens > len(new_doc):
        raise Error("CodeCompletion: cursor lies outside the new document")
    if cursor_tokens == 0:
        return 0
    var divergence = kw_first_divergence(old_doc, new_doc)
    var reuse = kw_reusable(len(old_doc), len(new_doc), divergence)
    return min(reuse, cursor_tokens - 1)


def cc_overlap_bytes(completion: String, suffix: String) -> Int:
    """The longest span (bytes) by which the
    completion's ending equals the suffix's opening:
    0 when there is none, at most the shorter text."""
    var limit = min(completion.byte_length(), suffix.byte_length())
    var size = limit
    while size > 0:
        var tail = String(
            completion[byte=completion.byte_length() - size:])
        var head = String(suffix[byte=:size])
        if tail == head:
            return size
        size -= 1
    return 0


def cc_trim_overlap(completion: String, suffix: String) -> String:
    """The completion with its suffix-overlap removed
    (header section (d)): unchanged when there is no
    overlap, empty when the completion is entirely
    overlap."""
    var overlap = cc_overlap_bytes(completion, suffix)
    if overlap == 0:
        return completion
    return String(completion[byte=:completion.byte_length() - overlap])


def cc_latency_class(elapsed_ms: Int) raises -> Int:
    """Grade one caller-measured completion latency
    against Janas's PUBLISHED 1.5-2.2 s class (header
    section (e)): below the band is FASTER, inside it
    (both ends inclusive) WITHIN, above it SLOWER. A
    negative measurement is refused, never graded."""
    if elapsed_ms < 0:
        raise Error("CodeCompletion: a latency measurement cannot be negative")
    if elapsed_ms < CC_PUBLISHED_LOW_MS:
        return CC_LATENCY_FASTER
    if elapsed_ms > CC_PUBLISHED_HIGH_MS:
        return CC_LATENCY_SLOWER
    return CC_LATENCY_WITHIN
