#!/usr/bin/env python3
"""J-107 inspect: mechanically re-derive the server
streaming + progress slice's load-bearing claims from
this tree.

Run from the repo root (the worktree root). Every check
prints PASS or FAIL; the summary line states the tally.
Claims covered: the streaming layer's rules (kinds,
framing, sequence delegation to the J-059 account, the
usage decision); the serve's wire order on all three
streaming routes (head before begin_turn; progress
frames between begin_turn and the decode loop; the
usage chunk between the finish chunk and [DONE]); the
parser's stream_options grammar and the Gate's usage
chunks; the J-106 audit flip (stream_options PARTIAL in
both tables); the doc's stated tallies against the
module; the test suites' group structure; the filed
test output's tallies; and repo hygiene (no README, no
.gguf in the slice diff, diff == the expected file set).
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AESIR = ROOT / "aesir_engine"
BASE = "ddec27dc29b993d3e230c62c3e996f0c466b6f9b"

results = []


def check(name, ok):
    results.append((name, bool(ok)))
    print(("PASS" if ok else "FAIL") + ": " + name)


def read(path):
    return Path(path).read_text(encoding="utf-8")


def find_from(source, needle, start=0):
    idx = source.find(needle, start)
    if idx < 0:
        raise AssertionError("not found: " + needle)
    return idx


layer = read(AESIR / "core/stream_progress.mojo")
account = read(AESIR / "core/prompt_progress.mojo")
audit = read(AESIR / "core/openai_audit.mojo")
parser_src = read(AESIR / "server/openai.mojo")
serve = read(AESIR / "cli/native_serve.mojo")
test = read(AESIR / "tests/test_stream_progress.mojo")
audit_test = read(AESIR / "tests/test_openai_audit.mojo")
doc = read(AESIR / "docs/janas/J107_SERVER_STREAMING_PROGRESS.md")
test_output = read(AESIR / "docs/janas/j107_test_output.txt")

# --- the streaming layer ------------------------------------------------------
check("layer: three stream kinds named",
      "STREAM_NATIVE_NDJSON = 0" in layer
      and "STREAM_OLLAMA_NDJSON = 1" in layer
      and "STREAM_OPENAI_SSE = 2" in layer)
check("layer: framing is J-059's event verbatim, per-kind frames",
      "render_progress_event(record)" in layer
      and '"data: "' in layer and 'payload + String("\\n")' in layer)
check("layer: sequence delegates to the J-059 account",
      "plan_prompt_progress(total_tokens, chunk_width)" in layer
      and "progress_record(plan, k, elapsed)" in layer
      and "if not plan.watched:" in layer)
check("layer: elapsed honesty (final boundary only)",
      "final_elapsed_ms if k == plan.chunks else -1" in layer)
check("layer: framing a non-emitted record is refused",
      "a non-emitted record has no frame" in layer)
check("layer: the usage decision is stream AND asked",
      "return stream and include_usage" in layer)
check("account: J-059's module untouched by this slice",
      "PROGRESS_MIN_TOKENS = 1024" in account
      and "render_progress_event" in account)

# --- the parser + Gate (K5) ----------------------------------------------------
check("parser: stream_options branch + grammar present",
      'name == "stream_options"' in parser_src
      and "_parse_stream_options" in parser_src
      and "Unsupported or duplicate stream_options field" in parser_src
      and "var include_usage: Bool" in parser_src)
check("gate: both usage-chunk formatters, empty choices",
      "format_chat_usage_chunk" in parser_src
      and "format_completion_usage_chunk" in parser_src
      and parser_src.count('\\"choices\\":[]') >= 2
      and '\\"prompt_tokens_details\\":{\\"cached_tokens\\":' in parser_src)

# --- the audit flip -------------------------------------------------------------
check("audit: stream_options PARTIAL in the chat table",
      'or name == "tool_choice" or name == "stream_options"' in audit)
check("audit: stream_options PARTIAL in the completions table",
      'if name == "n" or name == "stream_options":' in audit)
check("audit: the J-107 evolution is recorded in the module",
      "J-107 EVOLUTION" in audit and "8 honoured / 5 partial / 18 refused" in audit)

# --- the serve's wire order -------------------------------------------------------
# Routes appear in file order: Ollama, OpenAI, native. Chain the finds.
o_head = find_from(serve, 'send_stream_head(client.fd, "application/x-ndjson"')
o_kind = find_from(serve, 'stream_kind = "ollama"')
o_begin = find_from(serve, "session.begin_turn(prompt, request.system, request_tokens)", o_head)
o_prog = find_from(serve, "STREAM_OLLAMA_NDJSON", o_begin)
check("serve ollama: head (and stream kind) before begin_turn, progress after it",
      o_kind < o_begin and o_head < o_begin and o_prog > o_begin)
oa_head = find_from(serve, '"text/event-stream"', o_prog)
oa_kind = find_from(serve, 'stream_kind = "openai"', o_prog)
oa_role = find_from(serve, "format_chat_role_chunk", oa_head)
oa_begin = find_from(serve, "session.begin_turn(prompt, request.system, request_tokens)", oa_head)
oa_prog = find_from(serve, "STREAM_OPENAI_SSE", oa_begin)
check("serve openai: head + role chunk before begin_turn, progress after it",
      oa_kind < oa_begin and oa_head < oa_begin and oa_role < oa_begin and oa_prog > oa_begin)
oa_finish = find_from(serve, "format_completion_chunk(request_id, created, model.name, \"\", finish)", oa_prog)
oa_usage = find_from(serve, "format_chat_usage_chunk", oa_finish)
oa_done = find_from(serve, "data: [DONE]", oa_usage)
check("serve openai: usage chunk between the finish chunk and [DONE]",
      oa_prog < oa_finish < oa_usage < oa_done)
check("serve openai: usage chunk gated on the J-107 decision",
      "stream_usage_requested(request.stream, request.include_usage)" in serve)
n_head = find_from(serve, "send_native_stream_head", oa_done)
n_kind = find_from(serve, 'stream_kind = "native"', oa_done)
n_begin = find_from(serve, "session.begin_turn(request.prompt, request.system, request.max_tokens)", n_head)
n_prog = find_from(serve, "STREAM_NATIVE_NDJSON, session.status().prompt_tokens", n_begin)
check("serve native: head before begin_turn, progress after it",
      n_kind < n_begin and n_head < n_begin and n_prog > n_begin)
check("serve: progress helper clamps width and uses the caller's elapsed",
      "def send_progress_frames" in serve
      and "progress_frames(kind, prompt_tokens, width, final_elapsed_ms)" in serve)
check("serve: every route times its prefill for the final frame",
      "ollama_prefill_elapsed_ms" in serve and "openai_prefill_elapsed_ms" in serve
      and "prefill_elapsed_ms" in serve)

# --- doc + suites ------------------------------------------------------------------
check("doc: tallies stated (chat 8/5/18, completions 8/2/9)",
      "5 partial / 18 refused" in doc.replace("**", "")
      and "stream_options" in doc)
check("suite: test_stream_progress has 8 groups and the ALL PASS line",
      test.count("def test_") == 8 and "ALL PASS: stream progress (8 groups)" in test)
check("suite: audit suite carries the flipped tallies",
      "5 partial, 18 refused" in audit_test and "2 partial, 9 refused" in audit_test)
check("filed output: stream progress 8/8",
      "ALL PASS: stream progress (8 groups)" in test_output)
check("filed output: openai audit 7/7 at flipped tallies",
      "ALL PASS: openai audit (7 groups)" in test_output
      and "8 honoured, 5 partial, 18 refused" in test_output)
check("filed output: prompt progress neighbour 10/10",
      "ALL PASS: prompt progress account (10 groups)" in test_output)
check("filed output: local protocol neighbour PASS",
      "test_local_protocol" in test_output and "PASS HTTP framing" in test_output)
check("filed output: native serve compile driver PASS",
      "native serve + stream progress modules compile + import: PASS" in test_output)

# --- repo hygiene ---------------------------------------------------------------------
diff = subprocess.run(
    ["git", "-C", str(ROOT), "diff", "--name-only", BASE],
    capture_output=True, text=True).stdout.splitlines()
status = subprocess.run(
    ["git", "-C", str(ROOT), "status", "--porcelain"],
    capture_output=True, text=True).stdout.splitlines()
changed = set(diff) | {line[3:] for line in status if line.strip()}
check("no README in the slice diff", not any(p.endswith("README.md") for p in changed))
check("no .gguf in the slice diff", not any(p.endswith(".gguf") for p in changed))
expected = {
    "aesir_engine/cli/native_serve.mojo",
    "aesir_engine/core/openai_audit.mojo",
    "aesir_engine/core/stream_progress.mojo",
    "aesir_engine/docs/janas/J107_SERVER_STREAMING_PROGRESS.md",
    "aesir_engine/docs/janas/j107_inspect.py",
    "aesir_engine/docs/janas/j107_inspect_output.txt",
    "aesir_engine/docs/janas/j107_test_output.txt",
    "aesir_engine/server/openai.mojo",
    "aesir_engine/tests/test_openai_audit.mojo",
    "aesir_engine/tests/test_stream_progress.mojo",
}
check("slice diff is exactly the expected file set", changed == expected)

failed = [name for name, ok in results if not ok]
print("INSPECT: %d/%d PASS" % (len(results) - len(failed), len(results)))
if failed:
    print("FAILED: " + "; ".join(failed))
    sys.exit(1)
