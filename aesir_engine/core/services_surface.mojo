"""Services surface: what Aesir-the-engine can do for a
host beyond generate, as one pure, tested layer (Janas
road J-112).

The roadmap text: "Services surface. Janas exposes its
own services through chat and MCP; Aesir's equivalent
inventoried (what Aesir-the-engine can do for a host
beyond generate: tokenize, grade, census, bench) and
exposed through the same two doors, each service a
tested behaviour." The J-112 doc (docs/janas/
J112_SERVICES_SURFACE.md) is the normative text; this
header records the design pre-registered in its
section 0 before any code was built. No Janas material
was consulted beyond the road's own filed records; no
Janas source code was opened.

THE INVENTORY (doc section 0.2, from the tree). This
module is the registry: svc_services() lists every
service-shaped capability the inspection found, with
its availability class and its one-line reason --
including the ones that are REFUSED (embed: no
embedding data path exists), CLI_ONLY (the bench
sweep: a minutes-long measurement run that stays on
the CLI door), NOT EXPOSED as a named service
(segment: the tokenizer's internal pre-tokenization
split -- a real pure function, llama3_segments /
qwen_segments, but never presented as tokenize, which
it is not), and DEFERRED (the in-chat MCP client door,
T22: dispositioned in doc section 0.4 with its named
future home). An inventory that hid its refusals
would be a fake surface.

THE SERVICES THIS LAYER ANSWERS.
- census: the J-103 known-models catalogue as a
  population (count, total bytes, per-quantization
  counts, per-entry lines), aggregated over
  layer-local ServiceModelFact records the host
  converts from KnownModelEntry -- this layer never
  imports the CLI layer (the J-109 dependency
  direction).
- grade: the road's raw-oracle grading rule, DELEGATED
  to core/prefill_grade.mojo (step_class /
  grade_prefill_cell / verdict_name are imported,
  never re-implemented): a caller supplies per-step
  records (teacher-forcing rank + logit gap in
  milli-logits) and its own explicit comparator-valid
  statement, and the service returns the mechanical
  step class and cell verdict. Inconsistent records
  (rank 0 with a nonzero gap; positive rank with a
  zero gap) are refused as broken transcriptions,
  exactly as the grading layer refuses them. A caller
  who does not state the comparator check gets the
  COMPARATOR_ARTIFACT verdict, never a free FAITHFUL.
- bench (report form): the host's live device
  inventory description composed with the filed
  per-model evidence table (core/machine_report's
  model_table over filed_model_rows, rendered by the
  host), with the sweep's CLI-only reason on its
  face. The layer composes host-supplied text; it
  observes no device and files no number.
- tokenize (formatting only): tokenize itself is
  MODEL_BOUND -- a tokenizer is constructed from a
  loaded GGUF, and every live session carries one.
  This layer owns the chat form's parse
  (svc_parse_tokenize) and the result format
  (svc_format_tokenize); the chat host executes the
  resident session's own tokenizer, and the MCP layer
  dispatches the bound/unbound verdicts (J-112's
  extension of core/mcp_tools.mojo). The layer never
  tokenizes anything itself and never presents
  segmentation as token ids.

HOST CONTRACT. (1) Chat: cli/cuda_chat.mojo's two
chat_control bodies route "/services tokenize ..."
to the session branch (parse here, encode through
session.tokenizer, format here) and every other
"/services" form to services_chat_response with the
catalogue facts, the observed inventory description,
and the filed model table. (2) MCP: core/
mcp_tools.mojo converts its McpModelFact records to
ServiceModelFact for the census and delegates grade
to svc_grade_step_text; its bench verdict is
host-executed (the host observes + renders, then
completes through the layer's bench completion
builder with this module's svc_bench_text as the
payload shape). This module executes nothing, opens
no device, loads no model, and contains no speed;
any live service exchange is graded under the road's
honesty rules and its deferred legs are filed in the
J-112 doc, re-cited at the J-118 gate.
"""

from core.prefill_grade import (
    STEP_DIVERGENT,
    STEP_EXACT,
    STEP_NEAR_TIE,
    grade_prefill_cell,
    step_class,
    verdict_name,
)


# ------------------------------------------------------------------
# Availability classes.
# ------------------------------------------------------------------

comptime SVC_AVAILABLE = 0
comptime SVC_MODEL_BOUND = 1
comptime SVC_REFUSED = 2
comptime SVC_CLI_ONLY = 3
comptime SVC_DEFERRED = 4
comptime SVC_NOT_EXPOSED = 5


def svc_availability_name(code: Int) -> String:
    if code == SVC_AVAILABLE:
        return String("AVAILABLE")
    if code == SVC_MODEL_BOUND:
        return String("MODEL_BOUND")
    if code == SVC_REFUSED:
        return String("REFUSED")
    if code == SVC_CLI_ONLY:
        return String("CLI_ONLY")
    if code == SVC_DEFERRED:
        return String("DEFERRED")
    if code == SVC_NOT_EXPOSED:
        return String("NOT_EXPOSED")
    return String("UNKNOWN")


struct ServiceEntry(Copyable, ImplicitlyCopyable):
    var name: String
    var mcp_tool: String
    var chat_form: String
    var availability: Int
    var reason: String

    def __init__(
        out self,
        name: String,
        mcp_tool: String,
        chat_form: String,
        availability: Int,
        reason: String,
    ):
        self.name = name
        self.mcp_tool = mcp_tool
        self.chat_form = chat_form
        self.availability = availability
        self.reason = reason

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.mcp_tool = existing.mcp_tool
        self.chat_form = existing.chat_form
        self.availability = existing.availability
        self.reason = existing.reason


struct ServiceModelFact(Copyable, ImplicitlyCopyable):
    """One catalogue entry, layer-local (the host
    converts from KnownModelEntry / McpModelFact)."""

    var name: String
    var tag: String
    var quantization: String
    var size_bytes: Int

    def __init__(
        out self,
        name: String,
        tag: String,
        quantization: String,
        size_bytes: Int,
    ):
        self.name = name
        self.tag = tag
        self.quantization = quantization
        self.size_bytes = size_bytes

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.tag = existing.tag
        self.quantization = existing.quantization
        self.size_bytes = existing.size_bytes


# ------------------------------------------------------------------
# The registry (doc section 0.2).
# ------------------------------------------------------------------


def svc_services() -> List[ServiceEntry]:
    var services = List[ServiceEntry]()
    services.append(ServiceEntry(
        String("generate"), String("aesir_generate"),
        String("the chat conversation itself"), SVC_MODEL_BOUND,
        String(
            "runs the engine facade over a bound model;"
            " the MCP dispatch is proven (J-109) and its"
            " live leg is deferred to the J-118 gate"),
    ))
    services.append(ServiceEntry(
        String("tokenize"), String("aesir_tokenize"),
        String("/services tokenize <text>"), SVC_MODEL_BOUND,
        String(
            "a tokenizer is built from a loaded GGUF, so"
            " token ids need a bound session: chat"
            " executes the resident session's tokenizer;"
            " the MCP dispatch mirrors generate (J-109)"),
    ))
    services.append(ServiceEntry(
        String("grade"), String("aesir_grade"),
        String("/services grade <rank> <gap_milli> [valid]"),
        SVC_AVAILABLE,
        String(
            "the raw-oracle grading rule (teacher-forcing"
            " rank + logit gap) as a pure function of"
            " caller-supplied records, delegated to"
            " core/prefill_grade"),
    ))
    services.append(ServiceEntry(
        String("census"), String("aesir_census"),
        String("/services census"), SVC_AVAILABLE,
        String(
            "the known-models catalogue as a population"
            " (count, total bytes, per-quantization"
            " counts, per-entry lines) from the J-103"
            " catalogue records; model info per record"
            " is aesir_model_info (J-109)"),
    ))
    services.append(ServiceEntry(
        String("bench_report"), String("aesir_bench"),
        String("/services bench"), SVC_AVAILABLE,
        String(
            "the machine report's service form: the"
            " host's live device inventory plus the filed"
            " per-model evidence table (J-101)"),
    ))
    services.append(ServiceEntry(
        String("bench_sweep"), String(""),
        String(""), SVC_CLI_ONLY,
        String(
            "the configuration sweep (J-100) is a"
            " minutes-long measurement run; it stays on"
            " the CLI door (aesir bench [--report]) so a"
            " conversational or stdio host is never"
            " blocked for its whole duration"),
    ))
    services.append(ServiceEntry(
        String("embed"), String("aesir_embed"),
        String(""), SVC_REFUSED,
        String(
            "no embedding data path exists in Aesir"
            " (J-106/T13); the tool refuses rather than"
            " returning a fake vector"),
    ))
    services.append(ServiceEntry(
        String("segment"), String(""),
        String(""), SVC_NOT_EXPOSED,
        String(
            "pre-tokenization text splits exist inside"
            " the tokenizers (llama3_segments /"
            " qwen_segments) but are not token ids; not"
            " exposed as a named service, and never"
            " presented as tokenize"),
    ))
    services.append(ServiceEntry(
        String("mcp_client"), String(""),
        String("/services mcp"), SVC_DEFERRED,
        String(
            "the in-chat MCP client door (T22) is"
            " dispositioned in the J-112 doc section"
            " 0.4: it lives in the CUDA generation loop,"
            " which this road cannot prove by compilation"
            " alone, and no named external MCP server"
            " waits; named home: a dedicated slice,"
            " re-cited at the J-118 gate"),
    ))
    return services^


def svc_inventory_text() -> String:
    var services = svc_services()
    var out = String("aesir services (")
    out += String(len(services))
    out += String(" inventoried):")
    for entry in services:
        out += String("\n- ") + entry.name
        out += String(" [") + svc_availability_name(entry.availability)
        out += String("]")
        if entry.mcp_tool.byte_length() > 0:
            out += String(" mcp: ") + entry.mcp_tool
        if entry.chat_form.byte_length() > 0:
            out += String(" chat: ") + entry.chat_form
        out += String(" -- ") + entry.reason
    return out


def svc_mcp_client_disposition() -> String:
    return String(
        "mcp client (T22): DEFERRED -- a chat session does"
        " not consume external MCP tools in this build."
        " The standalone MCP client is proven (J-109"
        " section 0.5, against this engine's own MCP"
        " host); the in-chat door lives in the CUDA"
        " generation loop (tool call emitted, confirmed"
        " by the user, executed, result re-entered as"
        " context), which cannot be proven by compilation"
        " alone, and no named external MCP server waits"
        " to be consumed. Disposition and named future"
        " home: J-112 doc section 0.4, re-cited at the"
        " J-118 gate."
    )


# ------------------------------------------------------------------
# Census.
# ------------------------------------------------------------------


def svc_census_text(facts: List[ServiceModelFact]) -> String:
    var total_bytes = 0
    for fact in facts:
        total_bytes += fact.size_bytes
    var out = String("known-models census: ")
    out += String(len(facts))
    out += String(" entries, ")
    out += String(total_bytes)
    out += String(" bytes total")
    # Per-quantization counts, in first-appearance order.
    var quants = List[String]()
    var counts = List[Int]()
    for fact in facts:
        var found = -1
        for i in range(len(quants)):
            if quants[i] == fact.quantization:
                found = i
        if found < 0:
            quants.append(fact.quantization)
            counts.append(1)
        else:
            counts[found] += 1
    for i in range(len(quants)):
        out += String("\n- quantization ")
        out += quants[i]
        out += String(": ")
        out += String(counts[i])
    for fact in facts:
        out += String("\n- ") + fact.name + String(":") + fact.tag
        out += String(" (") + fact.quantization
        out += String(", ") + String(fact.size_bytes)
        out += String(" bytes)")
    out += String(
        "\nsource: known-models catalogue records (J-103);"
        " this is the catalogue population, not a scan of"
        " locally present files"
    )
    return out


# ------------------------------------------------------------------
# Grade (delegated to core/prefill_grade -- never re-implemented).
# ------------------------------------------------------------------


def svc_step_class_name(code: Int) -> String:
    if code == STEP_EXACT:
        return String("EXACT")
    if code == STEP_NEAR_TIE:
        return String("NEAR_TIE")
    if code == STEP_DIVERGENT:
        return String("DIVERGENT")
    return String("UNKNOWN")


def svc_grade_step_text(
    rank: Int, gap_milli: Int, comparator_valid: Bool
) raises -> String:
    """Grades one teacher-forcing step record by the
    road's raw-oracle rule. Raises exactly where the
    grading layer raises (an inconsistent record is a
    broken transcription, refused rather than graded);
    callers turn the raise into their door's refusal."""
    var cls = step_class(rank, gap_milli)
    var ranks = List[Int]()
    ranks.append(rank)
    var gaps = List[Int]()
    gaps.append(gap_milli)
    var summary = grade_prefill_cell(ranks, gaps, comparator_valid)
    var valid = String("true") if comparator_valid else String("false")
    return (
        String("grade: rank ") + String(rank)
        + String(", gap_milli ") + String(gap_milli)
        + String(" -> step ") + svc_step_class_name(cls)
        + String("; cell verdict ")
        + verdict_name(summary.verdict)
        + String(" (comparator_valid: ") + valid
        + String("; rule: core/prefill_grade -- rank 0 is"
                 " exact; the near-tie band is rank <= 2 with"
                 " gap < 1000 milli-logits; an unstated or"
                 " failed comparator check grades"
                 " COMPARATOR_ARTIFACT)")
    )


# ------------------------------------------------------------------
# Bench (report form).
# ------------------------------------------------------------------


def svc_bench_text(device_describe: String, model_table_text: String) -> String:
    var out = String(
        "bench report (the report form of aesir bench"
        " --report, J-101):\n"
    )
    out += device_describe
    out += String("\n")
    out += model_table_text
    out += String(
        "the configuration sweep itself is CLI-only"
        " (aesir bench [--report], J-100): a minutes-long"
        " measurement run that no conversational or stdio"
        " host is blocked on; this service answers the"
        " report, not the sweep"
    )
    return out


# ------------------------------------------------------------------
# Tokenize (parse + format; execution is the host's session).
# ------------------------------------------------------------------


def svc_is_tokenize_command(command: String) -> Bool:
    return command == "/services tokenize" or command.startswith(
        "/services tokenize "
    )


def svc_parse_tokenize(command: String) raises -> String:
    """The text after '/services tokenize ' -- the chat's
    standing usage pattern (a bare form is refused)."""
    var prefix = String("/services tokenize")
    if not command.startswith(prefix + " "):
        raise Error("Usage: /services tokenize <text>")
    var path = String(command[byte=len(prefix.bytes()) + 1:]).strip()
    if path == "":
        raise Error("Usage: /services tokenize <text>")
    return String(path)


def svc_format_tokenize(text: String, ids: List[Int]) -> String:
    var out = String("tokenize (the resident session's tokenizer): ")
    out += String(len(ids))
    out += String(" tokens for \"")
    out += text
    out += String("\"\nids: [")
    for i in range(len(ids)):
        if i > 0:
            out += String(", ")
        out += String(ids[i])
    out += String("]")
    return out


# ------------------------------------------------------------------
# The chat answers.
# ------------------------------------------------------------------


def _svc_parse_nonnegative(text: String) -> Int:
    """A bounded decimal count; -1 for anything that is
    not plain digits in range."""
    var raw = text.as_bytes()
    if len(raw) == 0:
        return -1
    var parsed = 0
    for index in range(len(raw)):
        var byte_value = raw[index]
        if byte_value < 48 or byte_value > 57:
            return -1
        var digit = Int(byte_value - 48)
        if parsed > (2147483647 - digit) // 10:
            return -1
        parsed = parsed * 10 + digit
    return parsed


def _svc_grade_chat_response(command: String) -> String:
    var words = command.split(" ")
    if len(words) != 4 and len(words) != 5:
        return String(
            "Usage: /services grade <rank> <gap_milli> [valid]"
            " -- rank and gap_milli are non-negative integers"
            " (the gap in milli-logits); 'valid' states the"
            " comparator check passed"
        )
    var rank = _svc_parse_nonnegative(String(words[2]))
    var gap = _svc_parse_nonnegative(String(words[3]))
    if rank < 0 or gap < 0:
        return String(
            "grade refused: rank and gap_milli must be"
            " non-negative integers, got '"
            + String(words[2]) + "' and '" + String(words[3]) + "'"
        )
    var comparator_valid = False
    if len(words) == 5:
        if String(words[4]) == "valid":
            comparator_valid = True
        elif String(words[4]) == "invalid":
            comparator_valid = False
        else:
            return String(
                "grade refused: the comparator statement must"
                " be 'valid' or 'invalid', got '"
                + String(words[4]) + "'"
            )
    try:
        return svc_grade_step_text(rank, gap, comparator_valid)
    except e:
        return String("grade refused: ") + String(e)


def services_chat_response(
    command: String,
    facts: List[ServiceModelFact],
    device_describe: String,
    model_table_text: String,
) -> String:
    """The chat host's one call for every '/services'
    form except tokenize (which the session branch
    executes). Every answer is this layer's text; a
    form this layer does not know is refused by name."""
    if command == "/services":
        return svc_inventory_text()
    if command == "/services census":
        return svc_census_text(facts)
    if command == "/services grade" or command.startswith(
        "/services grade "
    ):
        return _svc_grade_chat_response(command)
    if command == "/services bench":
        return svc_bench_text(device_describe, model_table_text)
    if command == "/services mcp":
        return svc_mcp_client_disposition()
    return String(
        "Unknown services form: "
        + command
        + " -- use /services (inventory), /services census,"
        " /services grade <rank> <gap_milli> [valid],"
        " /services bench, /services mcp, or"
        " /services tokenize <text>"
    )
