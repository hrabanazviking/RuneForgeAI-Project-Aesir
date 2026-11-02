"""Long-prompt watching: the progress account for one prompt
read (Janas road J-059).

The roadmap text: "Progress reporting for long prompt reads
(the chat shows how far the read has got, Janas-style), wired
into Aesir's CLI and server streaming." In Aesir's terms a
prompt read is the prefill phase J-053 dissected: the host
engine's chunk loop (aesir.mojo _run_generation, chunks of
_prefill_batch_cap, default 256), the CUDA sessions'
begin_turn loops (width 1, or width-4 tiles on the one
admitted profile), and the streamed MoE session's per-token
step loop. Tonight NONE of those loops reports anything
while it reads (the slice doc's inspection, section 2, is
first-hand): the host prints the prompt's token count before
the loop and nothing inside it; the CUDA sessions poll their
control channel per token and emit nothing; the server's
native route times prefill only as one timings_ms total
after the fact, and its streaming head is sent only after
the blocking begin_turn returns, so a streaming client sits
in silence for the whole read. There is no progress
callback, hook, or record anywhere in the tree. This module
is the missing record layer, in the J-031/J-053 style: pure
arithmetic, nothing timed by itself, no speed claimed. It
also carries J-057's O2 (per-boundary timestamps) in its
recorded form: a boundary record may carry the caller's
monotonic elapsed milliseconds for that boundary, which is
the in-engine shape of J-053's F3 / J-054's M7 prefill
instrumentation when a live surface wires it.

THE REPORTING DISCIPLINE, PRE-REGISTERED (stated here and
in the slice doc before any filed shape was run through
it). A prompt read earns progress records, and emits them,
under exactly these rules:

  (R1) EARNED. A read is WATCHED iff its total prompt
       tokens >= PROGRESS_MIN_TOKENS (1024, the first of
       J-053's baseline lengths at which a read is long by
       the road's own table) AND its chunk count >=
       PROGRESS_MIN_CHUNKS (4). Below either bound the read
       is SILENT: no record is ever emitted for it, on any
       surface. A short prompt that finishes before a human
       can read a progress line must not be dressed in
       progress spam to look instrumented.
  (R2) BOUNDARY-ONLY. Records exist only at chunk
       boundaries: after chunk k completes (k = 1..chunks),
       never inside a chunk, never per token. tokens_done
       is therefore exactly the tokens the executor has
       actually read at that boundary -- a record never
       reports a token not yet read.
  (R3) STEP THROTTLE. Even at boundaries, a record is
       EMITTED only when the read crosses its next 10%
       step: emit at boundary k iff floor(bp(k) / 1000) >
       floor(bp(k-1) / 1000), where bp is the floored
       basis-point fraction -- plus the final boundary,
       always (R4). A watched read therefore emits at most
       10 records however fine its chunks are: at the host
       cap of 256 a 4096-token read emits 10; at width 1
       (the CUDA and MoE loops) the same read also emits
       10, not 4096. The step, not the chunk width, is the
       throttle, so no surface can spam by being narrow.
  (R4) FINAL EXACTLY ONCE. The boundary that completes
       the read emits the one final record: tokens_done ==
       total, fraction exactly 10000 bp (100%), is_final.
       No earlier boundary can carry those values (done <
       total before the last chunk), and no record exists
       after it (boundaries stop at chunks).
  (R5) MONOTONIC. tokens_done strictly increases and the
       fraction never decreases across emitted records, by
       construction: boundaries are ordered and done is
       min(k * width, total).

The discipline grades COUNTS, never time. It says when a
surface may speak and what the record must contain; it
claims no wall, no tok/s, and no latency for any surface.
Only the deferred live leg (slice doc section 7) can show
records on a real read.

SURFACE SHAPES (the host contract, per surface; the slice
doc section 3 states which pieces are missing and why no
live surface consumes this yet):

  * Host CLI (aesir.mojo _run_generation): after each
    _forward_batch / _forward_position prefill step, the
    loop holds (total = len(tokens), width = batch_cap,
    chunks_completed). It builds the plan once before the
    loop and, for each boundary, takes progress_record();
    when record.emit, it prints render_progress_line() to
    the same stdout the loop already prints its token count
    to. Width-1 fallback: width = 1 (the step throttle
    keeps it to <= 10 lines).
  * CUDA sessions (llama3_cuda / gemma4_cuda begin_turn):
    total is prompt_tokens (set before the loop), width is
    1 or 4 (the tile), chunks_completed advances per token
    or per tile. The sessions emit nothing themselves; the
    record is returned to / held for the hosting surface
    (the server, below; a CUDA chat CLI would print the
    line). Wiring this needs a progress sink on the session
    -- a missing piece, named in the doc, NOT faked here.
  * Server streaming (cli/native_serve.mojo): on the
    streaming routes the host sends
    render_progress_event() as one NDJSON / SSE data line
    per emitted record BETWEEN the stream head and the
    first generated chunk. Tonight that is impossible
    without the sink above: begin_turn blocks for the whole
    read and the stream head is sent only after it returns
    (doc section 2). The event shape is fixed here so
    J-107 (server streaming + progress) builds against a
    proven record, not a sketch.
  * MoE session (moe_session.mojo step): width 1, the
    harness driving step() owns the boundary count; same
    record, same throttle.

Garbage is refused where detectable (non-positive totals
or widths; a boundary outside 1..chunks is refused by
progress_record). Faithfulness grading for any live leg is
the road's raw-oracle discipline: ids first, then
teacher-forcing rank + logit gap against a CPU comparator
on the raw prompt; never llama-cli --single-turn. Progress
reporting must be text-invisible: a watched read produces
the same ids as a silent one, or the wiring is a defect.
"""

# The reporting discipline's constants, pre-registered.
comptime PROGRESS_MIN_TOKENS = 1024
comptime PROGRESS_MIN_CHUNKS = 4
comptime PROGRESS_STEP_BASIS_POINTS = 1000


struct ProgressPlan(Copyable, ImplicitlyCopyable):
    """One prompt read's progress shape under the
    pre-registered discipline: the chunk geometry, whether
    the read is watched at all, and exactly how many
    records the discipline emits for it (computed by
    walking the boundaries once, here, so a surface can
    state the count before the read starts)."""

    var total_tokens: Int
    var chunk_width: Int
    var chunks: Int
    var final_chunk_width: Int
    var watched: Bool
    var records_expected: Int

    def __init__(
        out self,
        total_tokens: Int,
        chunk_width: Int,
        chunks: Int,
        final_chunk_width: Int,
        watched: Bool,
        records_expected: Int,
    ):
        self.total_tokens = total_tokens
        self.chunk_width = chunk_width
        self.chunks = chunks
        self.final_chunk_width = final_chunk_width
        self.watched = watched
        self.records_expected = records_expected


struct ProgressRecord(Copyable, ImplicitlyCopyable):
    """The progress state at one chunk boundary. emit is
    the discipline's word for this boundary: False means
    the surface stays silent here (unwatched read, or no
    10% step crossed). elapsed_ms is the caller's
    per-boundary timestamp (J-057's O2): >= 0 states the
    monotonic milliseconds from the read's start to this
    boundary as the caller measured them; -1 states that
    no timestamp was supplied -- the record never invents
    one."""

    var emit: Bool
    var tokens_done: Int
    var total_tokens: Int
    var fraction_basis_points: Int
    var percent: Int
    var chunk_index: Int
    var chunk_count: Int
    var is_final: Bool
    var elapsed_ms: Int

    def __init__(
        out self,
        emit: Bool,
        tokens_done: Int,
        total_tokens: Int,
        fraction_basis_points: Int,
        percent: Int,
        chunk_index: Int,
        chunk_count: Int,
        is_final: Bool,
        elapsed_ms: Int,
    ):
        self.emit = emit
        self.tokens_done = tokens_done
        self.total_tokens = total_tokens
        self.fraction_basis_points = fraction_basis_points
        self.percent = percent
        self.chunk_index = chunk_index
        self.chunk_count = chunk_count
        self.is_final = is_final
        self.elapsed_ms = elapsed_ms


def _boundary_done(plan: ProgressPlan, chunks_completed: Int) -> Int:
    """Tokens actually read after chunks_completed chunks:
    exact for the ragged final chunk, never above total."""
    var done = chunks_completed * plan.chunk_width
    if done > plan.total_tokens:
        done = plan.total_tokens
    return done


def _boundary_bp(plan: ProgressPlan, chunks_completed: Int) -> Int:
    """Floored basis-point fraction read at a boundary."""
    return _boundary_done(plan, chunks_completed) * 10000 // plan.total_tokens


def _boundary_emits(plan: ProgressPlan, chunks_completed: Int) -> Bool:
    """The discipline at one boundary (R1-R4): unwatched
    reads never emit; the final boundary always emits;
    any other boundary emits iff it crosses the next 10%
    step the previous boundary had not reached."""
    if not plan.watched:
        return False
    if chunks_completed == plan.chunks:
        return True
    var step_now = _boundary_bp(plan, chunks_completed) // PROGRESS_STEP_BASIS_POINTS
    var step_prev = _boundary_bp(plan, chunks_completed - 1) // PROGRESS_STEP_BASIS_POINTS
    return step_now > step_prev


def plan_prompt_progress(total_tokens: Int, chunk_width: Int) raises -> ProgressPlan:
    """State one prompt read's progress shape. chunk_width
    is the surface's own prefill width (host cap, 256 by
    default; 4 for the admitted CUDA tile; 1 for the
    width-1 loops). The watched test and the expected
    record count are the pre-registered discipline applied
    to this shape, nothing else."""
    if total_tokens <= 0 or chunk_width <= 0:
        raise Error("PromptProgress: token count and chunk width must be positive")
    var chunks = (total_tokens + chunk_width - 1) // chunk_width
    var final_width = total_tokens - (chunks - 1) * chunk_width
    var watched = (
        total_tokens >= PROGRESS_MIN_TOKENS and chunks >= PROGRESS_MIN_CHUNKS
    )
    var plan = ProgressPlan(total_tokens, chunk_width, chunks, final_width, watched, 0)
    var records = 0
    if watched:
        for k in range(1, chunks + 1):
            if _boundary_emits(plan, k):
                records += 1
    return ProgressPlan(total_tokens, chunk_width, chunks, final_width, watched, records)


def progress_record(
    plan: ProgressPlan, chunks_completed: Int, elapsed_ms: Int = -1
) raises -> ProgressRecord:
    """The record for the boundary after chunks_completed
    chunks (1..chunks). The caller supplies elapsed_ms
    from its own monotonic clock when it has one (O2);
    the default -1 states no timestamp. A boundary
    outside the read is refused: a surface may not report
    progress for chunks that do not exist."""
    if chunks_completed < 1 or chunks_completed > plan.chunks:
        raise Error("PromptProgress: boundary outside the read's chunks")
    if elapsed_ms < -1:
        raise Error("PromptProgress: elapsed_ms must be -1 (unstated) or >= 0")
    var done = _boundary_done(plan, chunks_completed)
    var bp = done * 10000 // plan.total_tokens
    return ProgressRecord(
        _boundary_emits(plan, chunks_completed),
        done,
        plan.total_tokens,
        bp,
        bp // 100,
        chunks_completed,
        plan.chunks,
        chunks_completed == plan.chunks,
        elapsed_ms,
    )


def render_progress_line(record: ProgressRecord) -> String:
    """The CLI form of one emitted record: one line, the
    read's own numbers, nothing decorative. The final
    record says so; a supplied timestamp rides at the end.
    Callers render only records with emit == True."""
    var line = String("prompt read: ") + String(record.tokens_done) + String(
        "/"
    ) + String(record.total_tokens) + String(" tokens (") + String(
        record.percent
    ) + String("%) chunk ") + String(record.chunk_index) + String("/") + String(
        record.chunk_count
    )
    if record.is_final:
        line += String(" -- read complete")
    if record.elapsed_ms >= 0:
        line += String(" -- ") + String(record.elapsed_ms) + String(" ms")
    return line


def render_progress_event(record: ProgressRecord) -> String:
    """The server-streaming form of one emitted record:
    one JSON object for one NDJSON line (or one SSE data
    payload), flat fields in the native route's own style.
    done is true only on the final record. Callers send
    only records with emit == True."""
    var event = String('{"event":"prefill_progress","tokens_done":') + String(
        record.tokens_done
    ) + String(',"prompt_tokens":') + String(record.total_tokens) + String(
        ',"percent":'
    ) + String(record.percent) + String(',"chunk":') + String(
        record.chunk_index
    ) + String(',"chunks":') + String(record.chunk_count) + String(
        ',"done":'
    ) + (String("true") if record.is_final else String("false"))
    if record.elapsed_ms >= 0:
        event += String(',"elapsed_ms":') + String(record.elapsed_ms)
    event += String("}")
    return event
