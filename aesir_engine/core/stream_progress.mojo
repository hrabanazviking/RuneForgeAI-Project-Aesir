"""Server streaming + progress: the stream protocol for
J-059's prompt-read progress account (Janas road J-107).

The roadmap text: "Server: streaming + progress. Long
prompt reads stream progress (J-059) through the API;
clients see the read advance instead of silence." J-059
built and proved the progress account (core/
prompt_progress.mojo: the pre-registered discipline --
watched iff >= 1024 prompt tokens AND >= 4 chunks,
boundary-only records, a 10% step throttle, the final
100% record exactly once -- plus the flat JSON event
form) and named the server's gap exactly: on every
streaming route begin_turn blocks for the whole read and
the stream head is sent only after it returns, so a
streaming client sits in silence -- not even headers --
for the whole read (J-059 section 2; J-099 T07/T18).

This module is the protocol layer J-107 builds on that
account, in the road's established shape (pure logic,
unit-tested at the lightest target; the serve executes
the decisions; no session or socket lives here):

- STREAM KINDS. The live serve streams three ways:
  the native route (POST /v1/generate) and the Ollama
  routes (/api/generate, /api/chat) as NDJSON lines, and
  the OpenAI routes (/v1/chat/completions,
  /v1/completions) as SSE data events. The kind states
  only the framing; the progress payload is one shape
  on every kind.
- FRAMING. progress_frame(kind, record) renders one
  EMITTED record for the wire: the payload is J-059's
  render_progress_event(record) verbatim -- one flat
  JSON object {"event":"prefill_progress",...} -- framed
  as payload + newline on the NDJSON kinds, and as
  "data: " + payload + blank line on the SSE kind. The
  payload is an Aesir extension event, NOT a
  chat.completion.chunk: a client distinguishes it by
  its event field (the OpenAI shape defines no progress
  event; answered-locally in the J-107 doc section 8).
- THE SEQUENCE. progress_frames(kind, total, width,
  final_elapsed_ms) is one completed read's whole
  framed sequence, in boundary order: exactly the
  J-059 plan's records_expected frames for a watched
  read, zero for a silent one. The serve sends the
  sequence after begin_turn returns and before the
  first decode chunk (the J-107 protocol, doc section
  0.3): the frames are the read's true record -- exact
  totals under the exact discipline -- emitted batched
  after the blocking read, in the same after-the-fact
  honesty class as the native route's timings_ms total.
  They do NOT arrive spread across the read; arrival
  during the read needs the session sink (J-059's W1),
  which is deferred with its recipe (doc sections
  0.4/5), re-cited at the J-118 gate.
- ELAPSED HONESTY (J-059's M7 rule). No prefill loop
  supplies a per-boundary timestamp tonight, so non-
  final records carry NO elapsed_ms -- the layer never
  invents a boundary time. The final record carries
  final_elapsed_ms when the caller supplies its own
  measured whole-read milliseconds (>= 0), and no
  timestamp otherwise. -1 states unstated, exactly as
  in prompt_progress.
- THE USAGE DECISION (J-106 K5, closed by J-107).
  stream_usage_requested(stream, include_usage) is the
  one place the streaming-usage rule lives: a streamed
  OpenAI response carries its usage chunk iff the
  request both streams and set
  stream_options.include_usage. The chunk's formatters
  live with the Gate in server/openai.mojo; this layer
  owns only the decision.

HOST CONTRACT. cli/native_serve.mojo's serve_loaded,
on every streaming generation route: (1) sends the
stream head BEFORE begin_turn (the OpenAI chat route's
role chunk follows the head, also before begin_turn),
with response_started / stream_kind set first so a
failed read is answered by the streamed-error path;
(2) after begin_turn, times the read (every route now
splits prefill, as the native route already did),
takes session.status().prompt_tokens and the serve's
own prefill_batch width, and sends progress_frames(...)
before the decode loop; (3) on the OpenAI routes, when
stream_usage_requested holds, sends the Gate's usage
chunk after the final finish chunk and before
data: [DONE]. Non-streaming requests are untouched.
This module executes nothing, opens no device, and
contains no speed; faithfulness grading for any live
leg is the road's raw-oracle discipline (ids first --
progress must be text-invisible -- then teacher-forcing
rank + logit gap; never llama-cli --single-turn).
"""
from core.prompt_progress import (
    ProgressRecord,
    plan_prompt_progress,
    progress_record,
    render_progress_event,
)


comptime STREAM_NATIVE_NDJSON = 0
comptime STREAM_OLLAMA_NDJSON = 1
comptime STREAM_OPENAI_SSE = 2


def stream_kind_name(code: Int) -> String:
    if code == STREAM_NATIVE_NDJSON:
        return String("native_ndjson")
    if code == STREAM_OLLAMA_NDJSON:
        return String("ollama_ndjson")
    if code == STREAM_OPENAI_SSE:
        return String("openai_sse")
    return String("UNKNOWN")


def progress_frame(kind: Int, record: ProgressRecord) raises -> String:
    """The wire form of one emitted progress record.
    Callers frame only records with emit == True; this
    function refuses a silent boundary so a surface
    cannot accidentally send one."""
    if not record.emit:
        raise Error("StreamProgress: a non-emitted record has no frame")
    var payload = render_progress_event(record)
    if kind == STREAM_OPENAI_SSE:
        return String("data: ") + payload + String("\n\n")
    if kind == STREAM_NATIVE_NDJSON or kind == STREAM_OLLAMA_NDJSON:
        return payload + String("\n")
    raise Error("StreamProgress: unknown stream kind")


def progress_frames(
    kind: Int, total_tokens: Int, chunk_width: Int, final_elapsed_ms: Int = -1
) raises -> List[String]:
    """One completed read's framed progress sequence, in
    boundary order, under J-059's discipline exactly:
    zero frames for a silent read; the plan's expected
    count for a watched one; the final frame unique and
    last. final_elapsed_ms is the caller's measured
    whole-read time for the final record only (-1 states
    unstated, as in prompt_progress); a negative below
    -1 is refused by progress_record."""
    if kind != STREAM_NATIVE_NDJSON and kind != STREAM_OLLAMA_NDJSON \
            and kind != STREAM_OPENAI_SSE:
        raise Error("StreamProgress: unknown stream kind")
    var plan = plan_prompt_progress(total_tokens, chunk_width)
    var frames = List[String]()
    if not plan.watched:
        return frames^
    for k in range(1, plan.chunks + 1):
        var elapsed = final_elapsed_ms if k == plan.chunks else -1
        var record = progress_record(plan, k, elapsed)
        if record.emit:
            frames.append(progress_frame(kind, record))
    return frames^


def stream_usage_requested(stream: Bool, include_usage: Bool) -> Bool:
    """The J-106 K5 rule: a streamed OpenAI response
    carries its usage chunk iff the request both streams
    and asked for usage. A non-streamed response already
    carries usage in its body (J-106), so the flag has
    no effect there."""
    return stream and include_usage
