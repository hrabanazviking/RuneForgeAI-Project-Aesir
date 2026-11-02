"""OpenAI-shape audit: the server surface's diff against the
OpenAI chat-completions shape, as one pure, tested layer
(Janas road J-106).

The roadmap text: "Server: OpenAI-shape audit. Aesir's HTTP
API audited against the OpenAI chat-completions shape Janas's
server follows: the diff list (fields honoured, ignored,
refused), each closed or consciously kept." J-099's census
assigned this slice rows T11 (the field diff), T12 (the wider
surface, incl. the 404-vs-501 question), T13 (embeddings),
T14 (cached_tokens accounting), T16 (TLS disposition), T17
(schema holding), T19 (speech routes in the refusal class)
and T20 (the unwired J-049 placement parity layer: wire it
or file why not). The J-014 gate note adds: J-106 audits
Janas's full documented server surface with the speech
routes kept OUT by that gate's refusal -- the speech routes
are answered in the honest refusal class, never built.

THE HEADLINE THE TABLES BELOW STATE. Aesir's OpenAI parser
(server/openai.mojo's OpenAIRequest) is bounded and fail-
closed: a field it does not honour is refused by name
("Unsupported OpenAI request field: " + name), a duplicate
or a seventeenth field is refused, and a narrowed field's
narrowing is itself a refusal (n != 1, a non-auto
tool_choice, a non-boolean schema). So on this surface
NOTHING IS SILENTLY IGNORED -- the ignored column of the
diff is empty by construction, and every row is HONOURED,
PARTIAL (a stated subset honoured, the rest refused), or
REFUSED. Janas's documented server (filed census, J-008)
takes the opposite road on unknown operations -- every
unserved operation has a route answering 501 with its
reason -- and this slice closes Aesir's one asymmetry with
that shape: the inference-adjacent routes a client probes
(embeddings, the speech family, responses, moderations)
now answer 501 with a reason in the live serve instead of
an indistinguishable 404, while the administrative
families (files, uploads, batches, vector stores, evals,
assistants, images, fine-tuning) stay 404, consciously
kept: Aesir has no storage or administration plane at all,
and a 501 there would promise a surface whose absence is
structural, not temporary (doc section 8 records the
ruling; the J-118 gate re-cites it).

WHAT THIS SLICE CLOSES (each wired, each tested):
- max_completion_tokens is honoured (OpenAIRequest): the
  modern budget field, taking precedence over max_tokens
  when both are sent, exactly OpenAI's stated relation.
  Aesir has no reasoning channel, so Janas's answer-only
  vs reasoning-inclusive distinction collapses to the one
  completion budget -- recorded answered-locally in the
  doc, not silently.
- The developer message role is honoured as the system
  role it aliases (OpenAIRequest's message parser).
- cached_tokens accounting (T14): the session status now
  carries the turn's reused-prefix count (the Llama 3
  session's own reused_prompt_tokens; the Gemma 4 session
  reports 0 -- it has no prefix reuse, J-099 T14), and the
  OpenAI usage objects carry it as
  usage.prompt_tokens_details.cached_tokens, caller-
  observed like every other Gate field.
- GET /v1/models/{id} retrieves one catalog model object
  (the list route's single-object sibling).
- Chat-completion responses carry the chatcmpl- id prefix
  the shape specifies for them; raw completions keep
  cmpl-.
- The 501 refusal class above (route_verdict +
  unsupported_route_body are the serve's rule for it).

WHAT IS CONSCIOUSLY KEPT (the doc's diff tables carry the
reason per row): general JSON-schema holding beyond the
strict boolean form (T17), logprobs, stop sequences, the
additive penalties, logit_bias, the placement request
fields (T20 -- filed why-not in the doc, the J-049 host
contract re-cited to the J-118 gate), TLS (T16 --
loopback-only plain HTTP, the stated shape), the wider
administrative families at 404, and the speech family
refused outright under the J-014 gate (T19).

J-107 EVOLUTION (recorded, not silent): streaming usage
chunks were KEPT refused above (K5) with the note that
honouring stream_options.include_usage rides J-107's
streaming leg. J-107 is that leg: stream_options is now
PARTIAL in both field tables (include_usage honoured --
a streamed response gains a usage chunk after its
finish chunk when the client asked; every other
stream_options key is refused by name), and the tallies
move to chat 8 honoured / 5 partial / 18 refused and
completions 8 / 2 / 9. The J-106 doc's section 2 rows
for stream_options are superseded by the J-107 doc.

HOST CONTRACT. cli/native_serve.mojo's serve loop consults
route_verdict for the 501 class (a refused route answers
501 with unsupported_route_body's reason, preserved body,
before the standing 404) and serves the models/{id}
retrieve; the OpenAI routes pass the status's cached count
into OpenAIGate's formatters. This module owns no socket,
no session, and no model; it states the audit's tables and
the refusal class's bodies, and the slice's inspect pins
the tables against the parser, the serve loop, and the
formatters so the audit cannot silently rot.
"""


def _escape_json_text(text: String) -> String:
    """The minimal JSON string escaping the refusal body
    needs (quote, backslash, control bytes), local to this
    module so the audit layer imports no server module --
    the layering stays core-pure, as with chat_manners."""
    var out = String("")
    var hex = String("0123456789abcdef")
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        var byte = Int(bytes[i])
        if byte == 34:
            out += "\\\""
        elif byte == 92:
            out += "\\\\"
        elif byte < 32:
            out += "\\u00"
            out += String(hex[byte=byte // 16 : byte // 16 + 1])
            out += String(hex[byte=byte % 16 : byte % 16 + 1])
        else:
            out += String(text[byte=i : i + 1])
    return out


# --- field verdicts ----------------------------------------------------------

comptime FIELD_HONOURED = 0
comptime FIELD_PARTIAL = 1
comptime FIELD_REFUSED = 2


def field_verdict_name(code: Int) -> String:
    if code == FIELD_HONOURED:
        return String("HONOURED")
    if code == FIELD_PARTIAL:
        return String("PARTIAL")
    if code == FIELD_REFUSED:
        return String("REFUSED")
    return String("UNKNOWN")


def chat_field_names() -> List[String]:
    """The OpenAI chat-completions request fields, in the
    audit's canonical order (the public shape's field list,
    as filed in the road's census of Janas's documented
    server plus the shape's own standard fields)."""
    var names = List[String]()
    names.append(String("model"))
    names.append(String("messages"))
    names.append(String("temperature"))
    names.append(String("top_p"))
    names.append(String("seed"))
    names.append(String("max_tokens"))
    names.append(String("max_completion_tokens"))
    names.append(String("stream"))
    names.append(String("n"))
    names.append(String("response_format"))
    names.append(String("tools"))
    names.append(String("tool_choice"))
    names.append(String("stream_options"))
    names.append(String("stop"))
    names.append(String("presence_penalty"))
    names.append(String("frequency_penalty"))
    names.append(String("logit_bias"))
    names.append(String("logprobs"))
    names.append(String("top_logprobs"))
    names.append(String("user"))
    names.append(String("metadata"))
    names.append(String("store"))
    names.append(String("service_tier"))
    names.append(String("parallel_tool_calls"))
    names.append(String("reasoning_effort"))
    names.append(String("modalities"))
    names.append(String("audio"))
    names.append(String("prediction"))
    names.append(String("web_search_options"))
    names.append(String("functions"))
    names.append(String("function_call"))
    return names^


def chat_field_verdict(name: String) -> Int:
    """One chat-completions field's verdict in this tree.
    A name outside the canonical list is REFUSED: the
    parser refuses every field it does not honour, by
    name -- which is also this function's answer for any
    unlisted name, so the table and the parser agree on
    strangers by construction."""
    if (name == "model" or name == "messages" or name == "temperature"
            or name == "top_p" or name == "seed" or name == "max_tokens"
            or name == "max_completion_tokens" or name == "stream"):
        return FIELD_HONOURED
    if (name == "n" or name == "response_format" or name == "tools"
            or name == "tool_choice" or name == "stream_options"):
        return FIELD_PARTIAL
    return FIELD_REFUSED


def completion_field_names() -> List[String]:
    """The OpenAI raw-completions request fields, in the
    audit's canonical order."""
    var names = List[String]()
    names.append(String("model"))
    names.append(String("prompt"))
    names.append(String("temperature"))
    names.append(String("top_p"))
    names.append(String("seed"))
    names.append(String("max_tokens"))
    names.append(String("max_completion_tokens"))
    names.append(String("stream"))
    names.append(String("n"))
    names.append(String("suffix"))
    names.append(String("echo"))
    names.append(String("best_of"))
    names.append(String("logprobs"))
    names.append(String("stream_options"))
    names.append(String("stop"))
    names.append(String("presence_penalty"))
    names.append(String("frequency_penalty"))
    names.append(String("logit_bias"))
    names.append(String("user"))
    return names^


def completion_field_verdict(name: String) -> Int:
    """One raw-completions field's verdict. The route
    shares OpenAIRequest with the chat route, so the
    honoured set is the same core; suffix is J-111's FIM
    question, refused here until that slice."""
    if (name == "model" or name == "prompt" or name == "temperature"
            or name == "top_p" or name == "seed" or name == "max_tokens"
            or name == "max_completion_tokens" or name == "stream"):
        return FIELD_HONOURED
    if name == "n" or name == "stream_options":
        return FIELD_PARTIAL
    return FIELD_REFUSED


def message_field_names() -> List[String]:
    """The fields of one chat message object."""
    var names = List[String]()
    names.append(String("role"))
    names.append(String("content"))
    names.append(String("name"))
    names.append(String("tool_calls"))
    names.append(String("tool_call_id"))
    names.append(String("refusal"))
    names.append(String("audio"))
    return names^


def message_field_verdict(name: String) -> Int:
    if name == "role" or name == "content":
        return FIELD_HONOURED
    return FIELD_REFUSED


def message_role_names() -> List[String]:
    """The message roles the shape names."""
    var names = List[String]()
    names.append(String("system"))
    names.append(String("developer"))
    names.append(String("user"))
    names.append(String("assistant"))
    names.append(String("tool"))
    names.append(String("function"))
    return names^


def message_role_verdict(name: String) -> Int:
    """developer is honoured as the system role it aliases
    (closed by this slice); tool and function messages
    belong to a tool-result round trip Aesir's one-shot
    Gemma tool shape does not run, and are refused."""
    if (name == "system" or name == "developer" or name == "user"
            or name == "assistant"):
        return FIELD_HONOURED
    return FIELD_REFUSED


# --- route verdicts ----------------------------------------------------------

comptime ROUTE_SERVED = 0
comptime ROUTE_REFUSED_501 = 1
comptime ROUTE_KEPT_404 = 2


def route_verdict_name(code: Int) -> String:
    if code == ROUTE_SERVED:
        return String("SERVED")
    if code == ROUTE_REFUSED_501:
        return String("REFUSED_501")
    if code == ROUTE_KEPT_404:
        return String("KEPT_404")
    return String("UNKNOWN")


def served_route_names() -> List[String]:
    """The live serve's OpenAI-shape + native routes, as
    "METHOD path" keys. GET /v1/models/{id} is the retrieve
    pattern this slice closes; the health trio and the
    native generate route are Aesir's own additions, listed
    so the audit's served set is the serve's whole truth."""
    var names = List[String]()
    names.append(String("POST /v1/chat/completions"))
    names.append(String("POST /v1/completions"))
    names.append(String("GET /v1/models"))
    names.append(String("GET /v1/models/{id}"))
    names.append(String("GET /health"))
    names.append(String("GET /health/live"))
    names.append(String("GET /health/ready"))
    names.append(String("POST /v1/generate"))
    return names^


def refused_route_names() -> List[String]:
    """The routes the live serve answers 501 with a reason:
    known OpenAI-shape operations this service does not
    run. The speech family is here under the J-014 gate's
    refusal -- answered, never built."""
    var names = List[String]()
    names.append(String("POST /v1/embeddings"))
    names.append(String("POST /v1/audio/transcriptions"))
    names.append(String("POST /v1/audio/translations"))
    names.append(String("POST /v1/audio/speech"))
    names.append(String("POST /v1/responses"))
    names.append(String("POST /v1/moderations"))
    return names^


def kept_404_route_families() -> List[String]:
    """The wider OpenAI surface's administrative families,
    consciously kept at the standing 404 (doc section 8):
    no storage or administration plane exists here."""
    var names = List[String]()
    names.append(String("/v1/files"))
    names.append(String("/v1/uploads"))
    names.append(String("/v1/batches"))
    names.append(String("/v1/vector_stores"))
    names.append(String("/v1/evals"))
    names.append(String("/v1/assistants"))
    names.append(String("/v1/images"))
    names.append(String("/v1/fine_tuning"))
    return names^


def route_key(method: String, path: String) -> String:
    return method + " " + path


def is_model_retrieve(method: String, path: String) -> Bool:
    """GET /v1/models/{id}: exactly one non-empty segment
    after the list route's prefix, no deeper path."""
    if method != "GET" or not path.startswith("/v1/models/"):
        return False
    var rest = String(path[byte=11:])
    return rest.byte_length() > 0 and "/" not in rest


def route_verdict(method: String, path: String) -> Int:
    """The live serve's disposition for one request line,
    as the audit rules it: the served set (incl. the
    retrieve pattern), the 501 refusal class, and the
    standing 404 for everything else -- the kept families
    and strangers alike."""
    var key = route_key(method, path)
    for served in served_route_names():
        if key == served:
            return ROUTE_SERVED
    if is_model_retrieve(method, path):
        return ROUTE_SERVED
    for refused in refused_route_names():
        if key == refused:
            return ROUTE_REFUSED_501
    return ROUTE_KEPT_404


def refusal_reason(method: String, path: String) -> String:
    """The 501 reason for one refused route, in Aesir's own
    terms. Reasons are plain sentences without quotes or
    backslashes, so the body builder below needs no JSON
    escaping of its own text; the route key is escaped
    where it is echoed."""
    var key = route_key(method, path)
    if key == "POST /v1/embeddings":
        return String(
            "embeddings are not served: no embedding data path exists "
            "in this service (a second, embedding-model kind is not "
            "loaded); the route is refused honestly, not faked")
    if key == "POST /v1/audio/transcriptions" or key == "POST /v1/audio/translations":
        return String(
            "speech-to-text is refused: a second model kind with no "
            "Aesir consumer, kept out by the road's standing refusal; "
            "the route is answered in the refusal class, never built")
    if key == "POST /v1/audio/speech":
        return String(
            "speech synthesis is refused: no speech pipeline exists "
            "in this service and none is roaded; the route is "
            "answered in the refusal class, never built")
    if key == "POST /v1/responses":
        return String(
            "the Responses API is not served: it is a stateful "
            "items surface and this service is a stateless "
            "single-model chat/completions surface; kept out "
            "consciously, re-cited at the Part VII gate")
    if key == "POST /v1/moderations":
        return String(
            "moderations are not served: no classifier model or "
            "held-schema moderation path exists in this service; "
            "the route is refused honestly, not faked")
    return String("this route is not served by this service")


def unsupported_route_body(method: String, path: String) raises -> String:
    """The 501 body, in Aesir's standing error shape
    ({error:{code,message}} -- the doc records the kept
    divergence from OpenAI's typed error object)."""
    return (
        "{\"error\":{\"code\":501,\"message\":\""
        + _escape_json_text(refusal_reason(method, path))
        + " (route: " + _escape_json_text(route_key(method, path))
        + ")\"}}"
    )
