#!/usr/bin/env python3
"""J-116 adapter-shaped replica client proof.

A faithful re-implementation of the STREAM LOOP of Yggdrasil's
Aesir adapter (its road's Y-024), `AesirAdapter.generate()` in
~/workspace/yggdrasil-build/src/yggdrasil/aesir_adapter.py,
replicated behaviour-for-behaviour from the source read
first-hand in this slice:

  - blank lines are skipped;
  - a line that is not valid JSON raises engine_error
    ("streamed a malformed NDJSON line");
  - a record that is not a dict, or whose "text" is not a
    string, raises engine_error ("streamed a record without
    a text string") -- THE RULE UNDER TEST;
  - a record with done true is the terminal record and ends
    the loop;
  - a nonempty text record is appended and yielded as a token;
  - a stream that ends without its terminal record raises
    engine_error ("ended without its terminal record");
  - the result's run_ms prefers the terminal record's service
    timings (timings_ms prefill + decode) over the wall clock.

This replica is evidence about the adapter's RULE on the real
frame SHAPE; it is not Yggdrasil's shipped code and proves
nothing about that code having changed (J-116 doc section 1).

Two rule variants are run over identical streams:

  CURRENT -- the loop exactly as the adapter ships it today.
  RECIPE  -- the filed adapter-side change (J-116 doc section
             1.3): a record carrying a string "event" field is
             a progress record -- counted, skipped, and never
             mistaken for the terminal record even though the
             final progress frame carries done:true (the skip
             is checked BEFORE the terminal test).

The streams are built from the REAL frame shape: the progress
frames are byte-shaped exactly as core/prompt_progress.mojo's
render_progress_event renders them (fields event,
tokens_done, prompt_tokens, percent, chunk, chunks, done,
and elapsed_ms on the final frame only), framed as payload +
newline per core/stream_progress.mojo's native NDJSON kind;
the text and terminal records are shaped exactly as
cli/native_serve.mojo's native streamed branch sends them
(text records {"text": ..., "done": false}; one terminal
{"text": "", "done": true, finish_reason, prompt_tokens,
generated_tokens, context_used, backend, cpu_offload, model,
model_digest, timings_ms {prefill, decode}}).

Cases: (a) short-prompt stream, zero progress frames;
(b) watched long-prompt stream, progress frames first;
(c) stream with no terminal record; (d) malformed line.
Prints one line per case/variant; the inspect reads them.
"""
import json


class ReplicaError(Exception):
    def __init__(self, message, error_code="engine_error"):
        super().__init__(message)
        self.error_code = error_code


def progress_frame(tokens_done, total, percent, chunk, chunks, final=False, elapsed=None):
    frame = {
        "event": "prefill_progress",
        "tokens_done": tokens_done,
        "prompt_tokens": total,
        "percent": percent,
        "chunk": chunk,
        "chunks": chunks,
        "done": final,
    }
    if elapsed is not None:
        frame["elapsed_ms"] = elapsed
    # The Mojo renderer emits flat fields in this exact order
    # with no spaces; json.dumps with these separators and this
    # insertion order reproduces that byte shape.
    return json.dumps(frame, separators=(",", ":"))


def text_record(text):
    return json.dumps({"text": text, "done": False}, separators=(",", ":"))


TERMINAL = json.dumps(
    {
        "text": "",
        "done": True,
        "finish_reason": "stop",
        "prompt_tokens": 4096,
        "generated_tokens": 2,
        "context_used": 4098,
        "backend": "cuda",
        "cpu_offload": 0,
        "model": "resident-model",
        "model_digest": "sha256:replica",
        "timings_ms": {"prefill": 1200, "decode": 40},
    },
    separators=(",", ":"),
)


def run_stream(lines, *, recipe=False):
    """The adapter's stream loop, replicated. Returns a dict
    with the assembled text, the terminal record, the service
    run_ms, and (recipe variant) the progress records seen."""
    chunks = []
    final = None
    progress_seen = 0
    for line in lines:
        if not line or not line.strip():
            continue
        try:
            piece = json.loads(line)
        except json.JSONDecodeError:
            raise ReplicaError("streamed a malformed NDJSON line")
        if recipe and isinstance(piece, dict) and isinstance(piece.get("event"), str):
            # THE RECIPE: progress records are counted and
            # skipped before any text or terminal test.
            progress_seen += 1
            continue
        if not isinstance(piece, dict) or not isinstance(piece.get("text"), str):
            raise ReplicaError("streamed a record without a text string")
        if piece.get("done"):
            final = piece
            break
        if piece["text"]:
            chunks.append(piece["text"])
    if final is None:
        raise ReplicaError("stream ended without its terminal record - incomplete")
    timings = final.get("timings_ms") or {}
    run_ms = None
    if isinstance(timings.get("prefill"), (int, float)) and isinstance(
        timings.get("decode"), (int, float)
    ):
        run_ms = float(timings["prefill"]) + float(timings["decode"])
    return {
        "text": "".join(chunks),
        "prompt_tokens": final.get("prompt_tokens"),
        "generated_tokens": final.get("generated_tokens"),
        "model_digest": final.get("model_digest"),
        "run_ms": run_ms,
        "progress_seen": progress_seen,
    }


SHORT_STREAM = [text_record("Hello "), text_record("mesh"), TERMINAL]
LONG_STREAM = [
    progress_frame(1024, 4096, 25, 1, 4),
    progress_frame(2048, 4096, 50, 2, 4),
    progress_frame(3072, 4096, 75, 3, 4),
    progress_frame(4096, 4096, 100, 4, 4, final=True, elapsed=1200),
    text_record("Hello "),
    text_record("mesh"),
    TERMINAL,
]
NO_TERMINAL = [text_record("Hello "), text_record("mesh")]
MALFORMED = [text_record("Hello "), "{not json", TERMINAL]


def attempt(label, lines, recipe):
    try:
        result = run_stream(lines, recipe=recipe)
        print(
            f"{label} recipe={recipe}: COMPLETED text={result['text']!r} "
            f"prompt_tokens={result['prompt_tokens']} "
            f"generated_tokens={result['generated_tokens']} "
            f"digest={result['model_digest']} run_ms={result['run_ms']} "
            f"progress_seen={result['progress_seen']}"
        )
    except ReplicaError as exc:
        print(f"{label} recipe={recipe}: RAISED {exc.error_code}: {exc}")


def main():
    attempt("case-a-short", SHORT_STREAM, recipe=False)
    attempt("case-a-short", SHORT_STREAM, recipe=True)
    attempt("case-b-long", LONG_STREAM, recipe=False)
    attempt("case-b-long", LONG_STREAM, recipe=True)
    attempt("case-c-no-terminal", NO_TERMINAL, recipe=False)
    attempt("case-c-no-terminal", NO_TERMINAL, recipe=True)
    attempt("case-d-malformed", MALFORMED, recipe=False)
    attempt("case-d-malformed", MALFORMED, recipe=True)


if __name__ == "__main__":
    main()
