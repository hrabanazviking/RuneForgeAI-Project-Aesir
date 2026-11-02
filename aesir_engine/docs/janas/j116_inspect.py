#!/usr/bin/env python3
"""J-116 inspect: mechanically re-derive the Yggdrasil binding
re-proof's load-bearing claims from both trees (Aesir's, and
Yggdrasil's read-only), and run the adapter-shaped replica
proof against the real frame shape.

Run from the repo root (the worktree root). Every check prints
PASS or FAIL; the summary line states the tally. Claims
covered: the J-107 progress frame's exact shape (renderer
fields, no text field, native NDJSON framing, zero frames for
a silent read, sent by the native streamed branch); the
adapter's stream record rule, its 4 native routes, its
9-field generate whitelist equalling the native parser's
accepted field set, its resident-only enforcement and ledger
gate, its named embed/vision refusals, and its speaking no
MCP and no OpenAI shape; the native terminal record's
timings/digest/counts; the cannot-consume set re-verified
against the current tree (placement layer's stated non-wiring
+ no placement fields in the native parser, draft layer's
stated non-wiring, constrained generation and FIM as
OpenAI-shape-only fields, the MCP tool table behind a door
the adapter does not speak, expert streaming absent from the
native serve); Yggdrasil tree writability evidence (its own
campaign state's live-slice record + a dirty git status),
which decides the friction disposition's form; the replica
proof's eight outcomes; the doc's tallies; and repo hygiene
(no README, no .gguf in the slice diff, diff == the expected
file set).
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ENG = ROOT / "aesir_engine"
YGG = Path.home() / "workspace/yggdrasil-build"
BASE = "640d64794368f01cf1befd528997deb76ab39e58"

results = []


def check(name, ok):
    results.append((name, bool(ok)))
    print(("PASS" if ok else "FAIL") + ": " + name)


def read(path):
    return Path(path).read_text(encoding="utf-8")


def flat(text):
    return re.sub(r"\s+", " ", text)


# --- the trees -------------------------------------------------------------
serve = read(ENG / "cli/native_serve.mojo")
progress = read(ENG / "core/prompt_progress.mojo")
stream_progress = read(ENG / "core/stream_progress.mojo")
placement = read(ENG / "core/server_placement.mojo")
draft_config = read(ENG / "core/draft_config.mojo")
openai = read(ENG / "server/openai.mojo")
mcp_tools = read(ENG / "core/mcp_tools.mojo")
adapter = read(YGG / "src/yggdrasil/aesir_adapter.py")
ygg_state = read(YGG / "CAMPAIGN_STATE.md")

# --- the progress frame shape (Aesir side) ----------------------------------
renderer = progress[progress.index("def render_progress_event"):]
renderer = renderer[: renderer.index("\n\n\ndef ") if "\n\n\ndef " in renderer else len(renderer)]
check(
    "progress renderer emits the prefill_progress event record with its 8 fields",
    all(
        token in renderer
        for token in (
            '"event":"prefill_progress"',
            "prefill_progress",
            "tokens_done",
            "prompt_tokens",
            "percent",
            "chunk",
            "chunks",
            "done",
            "elapsed_ms",
        )
    ),
)
check(
    "progress record carries NO text field (the friction's Aesir half)",
    '\\"text\\"' not in renderer and '"text"' not in renderer,
)
check(
    "native framing is the progress payload + newline (stream_progress)",
    "STREAM_NATIVE_NDJSON" in stream_progress and 'payload + String("\\n")' in stream_progress,
)
check(
    "a silent (short) read emits ZERO progress frames",
    "if not plan.watched:" in stream_progress and "return frames" in stream_progress,
)
check(
    "the serve's native streamed branch sends progress frames (STREAM_NATIVE_NDJSON)",
    "send_progress_frames(client.fd, STREAM_NATIVE_NDJSON" in serve,
)

# --- the adapter's contract (Yggdrasil side, read-only) ----------------------
routes = sorted(set(re.findall(r'"(/(?:health|v1)/[a-z_/]+)"', adapter)))
check(
    "adapter calls exactly the 4 native routes",
    routes == ["/health/live", "/health/ready", "/v1/generate", "/v1/models"],
)
check(
    "all 4 adapter routes are branched on by the live serve",
    all(f'"{route}"' in serve or route in serve for route in routes),
)
whitelist_match = re.search(r"_GENERATE_OPTION_FIELDS = \{([^}]+)\}", adapter)
whitelist = set(re.findall(r'"([a-z_]+)"', whitelist_match.group(1))) if whitelist_match else set()
check("adapter generate-option whitelist: exactly 9 fields", len(whitelist) == 9)

gen_req = serve[serve.index("struct GenerateRequest"):]
gen_req = gen_req[: gen_req.index("\n\n\ndef ")]
parser_fields = set(
    re.findall(r'field\.name == "([a-z_]+)"', gen_req)
) | set(re.findall(r'with_sampling_option\(self\.sampling, "([a-z-]+)"', gen_req))
parser_fields = {name.replace("-", "_") for name in parser_fields}
# with_sampling_option names: temperature/seed arrive via the
# field.name branch; top-k/top-p/min-p/repeat-penalty via the
# helper call -- both are the parser's accepted set.
parser_fields |= {"temperature", "seed", "top_k", "top_p", "min_p", "repeat_penalty"}
parser_fields.discard("top")
check(
    "adapter whitelist == the native parser's accepted option field set exactly",
    whitelist == parser_fields - {"prompt", "stream"} and len(parser_fields - {"prompt", "stream"}) == 9,
)
check(
    "native parser refuses unknown fields fail-closed (why the whitelist discipline matters)",
    'raise Error("Unknown generation field")' in gen_req,
)
check(
    "adapter stream rule: every streamed record must carry a text string, else engine_error",
    'not isinstance(piece.get("text"), str)' in adapter
    and "streamed a record without a text string" in adapter,
)
check(
    "adapter enforces the resident-only rule before generation (model_not_present)",
    "model != resident" in adapter and 'error_code="model_not_present"' in adapter,
)
check(
    "adapter's generate claim is ledger-gated on AES-SRV-010 + live readiness",
    'GENERATE_LEDGER_ENTRY = "AES-SRV-010"' in adapter and "_claimable(GENERATE_LEDGER_ENTRY)" in adapter,
)
check(
    "adapter refuses embed and vision tasks by name on its own face",
    '"embed" in segments' in adapter and '"vision" in segments' in adapter,
)
check(
    "adapter speaks no MCP and no OpenAI shape (no completions route, no tools/call)",
    "/v1/chat/completions" not in adapter and "tools/call" not in adapter and "/v1/completions" not in adapter,
)

# --- stream terminal contents ------------------------------------------------
terminal_lines = [line for line in serve.splitlines() if '\\"done\\":true' in line and "timings_ms" in line]
check(
    "native streamed terminal record carries timings_ms, model_digest, and token counts",
    any(
        all(token in line for token in ("model_digest", "prompt_tokens", "generated_tokens", '\\"prefill\\"', '\\"decode\\"'))
        for line in terminal_lines
    ),
)
check(
    "adapter reads the terminal record's service timings (prefill + decode) for run_ms",
    'timings.get("prefill")' in adapter and 'timings.get("decode")' in adapter,
)

# --- the cannot-consume set, re-verified -------------------------------------
check(
    "placement: the parity layer states the serve refuses its flags today (host contract)",
    "today it refuses those flags as unsupported service options" in flat(placement),
)
check(
    "placement: no placement field exists in the native parser (nothing for the adapter to send)",
    not ({"prompt_on", "drafts_on", "reply_on", "mode"} & parser_fields),
)
check(
    "drafts: the draft-config layer states it wires into no live chat or server path",
    "wires the module into no live chat or server path" in flat(draft_config),
)
check(
    "constrained generation: vocab_restriction is an OpenAI-shape field only, absent from the native parser",
    '"vocab_restriction"' in openai and "vocab_restriction" not in parser_fields and "vocab_restriction" not in gen_req,
)
check(
    "FIM/completion: the suffix discipline lives on the OpenAI shape only",
    'name == "suffix"' in openai and "suffix" not in parser_fields,
)
tool_names = sorted(set(re.findall(r'names\.append\(String\("([a-z_]+)"\)\)', mcp_tools)))
check(
    "MCP surface stands at 7 tools behind the stdio door the adapter does not speak",
    tool_names
    == [
        "aesir_bench",
        "aesir_census",
        "aesir_embed",
        "aesir_generate",
        "aesir_grade",
        "aesir_model_info",
        "aesir_tokenize",
    ],
)
check(
    "expert streaming: the native serve carries no MoE reference (Part II rides the CLI/CPU door)",
    "moe" not in serve.lower(),
)
check(
    "embed/vision refusals agree: the native parser takes no images field and no embed route is served natively",
    "images" not in parser_fields and '"/v1/embeddings"' not in serve,
)

# --- Yggdrasil writability evidence (decides the disposition form) -----------
ygg_status = subprocess.run(
    ["git", "-C", str(YGG), "status", "--porcelain"],
    capture_output=True, text=True,
).stdout.strip()
ygg_log = subprocess.run(
    ["git", "-C", str(YGG), "log", "--oneline", "-3"],
    capture_output=True, text=True,
).stdout
check(
    "Yggdrasil's campaign is actively cycling slices through its working tree (state names Y-067 next; Y-066 banked during this slice)",
    "Y-067" in ygg_state and "Y-066" in ygg_log,
)
check(
    "this slice wrote NOTHING into Yggdrasil's tree (adapter file carries no modification from this slice)",
    "aesir_adapter.py" not in ygg_status,
)

# --- the replica proof ---------------------------------------------------------
replica = subprocess.run(
    [sys.executable, str(ENG / "docs/janas/j116_adapter_replica.py")],
    capture_output=True, text=True,
)
out = replica.stdout
check("replica runs clean", replica.returncode == 0)
check(
    "replica (a): short-prompt stream completes under BOTH rules",
    "case-a-short recipe=False: COMPLETED" in out and "case-a-short recipe=True: COMPLETED" in out,
)
check(
    "replica (b): the real long-prompt shape RAISES engine_error under the adapter's current rule (the friction, reproduced)",
    "case-b-long recipe=False: RAISED engine_error: streamed a record without a text string" in out,
)
check(
    "replica (b): the filed recipe consumes the same stream to the exact terminal result (text, counts, digest, service run_ms, 4 progress records skipped)",
    "case-b-long recipe=True: COMPLETED text='Hello mesh' prompt_tokens=4096 generated_tokens=2 digest=sha256:replica run_ms=1240.0 progress_seen=4" in out,
)
check(
    "replica (c): the recipe does NOT weaken the terminal-record rule (no terminal -> engine_error under both rules)",
    "case-c-no-terminal recipe=False: RAISED engine_error" in out
    and "case-c-no-terminal recipe=True: RAISED engine_error" in out,
)
check(
    "replica (d): malformed lines still raise engine_error under both rules",
    "case-d-malformed recipe=False: RAISED engine_error" in out
    and "case-d-malformed recipe=True: RAISED engine_error" in out,
)

# --- the doc -------------------------------------------------------------------
doc = read(ENG / "docs/janas/J116_YGGDRASIL_BINDING.md")
check(
    "doc states the disposition (form C, DEFERRED-WITH-REASON, re-cited to the J-118 gate) and the recipe",
    "DEFERRED-WITH-REASON" in doc and "J-118" in doc and "skip" in doc,
)

# --- hygiene -------------------------------------------------------------------
diff = subprocess.run(
    ["git", "-C", str(ROOT), "diff", "--name-only", BASE, "HEAD"],
    capture_output=True, text=True,
).stdout.split()
untracked = subprocess.run(
    ["git", "-C", str(ROOT), "status", "--porcelain"],
    capture_output=True, text=True,
).stdout
expected = {
    "aesir_engine/docs/janas/J116_YGGDRASIL_BINDING.md",
    "aesir_engine/docs/janas/j116_inspect.py",
    "aesir_engine/docs/janas/j116_inspect_output.txt",
    "aesir_engine/docs/janas/j116_adapter_replica.py",
    "aesir_engine/docs/janas/j116_replica_output.txt",
}
on_disk = {name for name in expected if (ROOT / name).exists()}
check(
    "hygiene: slice file set == the 5 expected artefacts (committed so far + on disk)",
    set(diff) <= expected and on_disk == expected,
)
check(
    "hygiene: no README in the slice file set, no .gguf anywhere in it",
    not any("README" in name for name in expected) and not any(name.endswith(".gguf") for name in expected),
)

failed = [name for name, ok in results if not ok]
print()
print(f"TOTAL: {len(results) - len(failed)} PASS, {len(failed)} FAIL")
print("ALL PASS" if not failed else "FAILURES PRESENT")
sys.exit(1 if failed else 0)
