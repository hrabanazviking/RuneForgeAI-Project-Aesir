#!/usr/bin/env python3
"""J-099 inspection: every load-bearing claim in
docs/janas/J099_TOOL_CENSUS_RECONCILIATION.md as an assertion over
the tree at this branch tip. Exit 0 iff all checks pass."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENG = ROOT / "aesir_engine"
checks = []


def check(name, ok):
    checks.append((name, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'}: {name}")


def read(rel):
    return (ROOT / rel).read_text(errors="ignore")


def all_mojo():
    return list(ENG.rglob("*.mojo"))


def word_hits(word):
    pat = re.compile(r"(?<![a-z])" + word + r"(?![a-z])", re.I)
    return [p for p in all_mojo() if pat.search(p.read_text(errors="ignore"))]


commands = read("aesir_engine/cli/commands.mojo")
main_mojo = read("aesir_engine/main.mojo")
cuda_chat = read("aesir_engine/cli/cuda_chat.mojo")
native_serve = read("aesir_engine/cli/native_serve.mojo")
openai = read("aesir_engine/server/openai.mojo")
api = read("aesir_engine/server/api.mojo")
local_protocol = read("aesir_engine/server/local_protocol.mojo")
llama3_cuda = read("aesir_engine/core/llama3_cuda.mojo")
gemma4_cuda = read("aesir_engine/core/gemma4_cuda.mojo")
aesir = read("aesir_engine/aesir.mojo")

# --- T01 chat core -------------------------------------------------------
cli_modules = sorted(p.name for p in (ENG / "cli").glob("*.mojo"))
check("cli/ holds 44 .mojo modules (exactly J-012's filed count)", len(cli_modules) == 44)
check("main.mojo dispatches chat via dispatch_command + prepare_chat_process",
      'cli_args[0] == "chat"' in main_mojo and "dispatch_command" in main_mojo)
check("commands dispatch contains chat and serve",
      'cmd == "chat"' in commands and 'cmd == "serve"' in commands)

# --- T02 slash family ----------------------------------------------------
for slash in ["/show", "/history", "/turn", "/clear", "/new", "/help",
              "/save", "/load", "/export", "/compose", "/edit",
              "/transcript", "/bye"]:
    check(f"cuda_chat handles {slash}", f'"{slash}"' in cuda_chat
          or f'"{slash} "' in cuda_chat or f'startswith("{slash}")' in cuda_chat)
cli_all = "\n".join(p.read_text(errors="ignore")
                    for p in (ENG / "cli").glob("*.mojo"))
for absent in ["/experts", "/save-config", "/load-config", "/del-config",
               "/stats", "/about", "/markdown"]:
    check(f"no {absent} command anywhere in cli/", absent not in cli_all)

# --- T03 picker ----------------------------------------------------------
check("model_selector module exists",
      (ENG / "cli/model_selector.mojo").exists())
check("help: omit model to choose an installed catalog model",
      "Omit model to choose an installed catalog model interactively"
      in commands)

# --- T04 learned / saved config ------------------------------------------
check("core/learned_file.mojo exists (J-044)",
      (ENG / "core/learned_file.mojo").exists())
check("draft config persists via the learned file (J-083)",
      "store_learned_entry" in read("aesir_engine/core/draft_config.mojo"))
check("native_settings resolver exists",
      (ENG / "cli/native_settings.mojo").exists()
      and "resolve_native_settings"
      in read("aesir_engine/cli/native_settings.mojo"))
check("no /save-config command in the whole engine tree",
      not word_hits("save-config") and "save-config" not in
      "\n".join(p.read_text(errors="ignore") for p in all_mojo()))

# --- T05 recap ------------------------------------------------------------
check("no recap/summarisation in cli/",
      "recap" not in cli_all.lower())

# --- T06 manners ----------------------------------------------------------
interrupts = read("aesir_engine/cli/interrupts.mojo")
check("interrupts module wires SIGINT cancellation",
      "SIGINT" in interrupts and "prepare_chat_process" in interrupts)
check("unknown commands/options refused by name",
      "unknown command: " in commands and "unknown run option: " in commands)
check("no did-you-mean suggestion machinery in cli/",
      "did you mean" not in cli_all.lower())

# --- T07 progress ----------------------------------------------------------
check("core/prompt_progress.mojo exists with both render forms (J-059)",
      "render_progress_line" in read("aesir_engine/core/prompt_progress.mojo")
      and "render_progress_event"
      in read("aesir_engine/core/prompt_progress.mojo"))
importers = [str(p.relative_to(ROOT)) for p in all_mojo()
             if "from core.prompt_progress import" in p.read_text(errors="ignore")]
check("prompt_progress imported only by its own test (no live consumer)",
      importers == ["aesir_engine/tests/test_prompt_progress.mojo"])

# --- T08/T09 bench ---------------------------------------------------------
harness = read("aesir_engine/core/placement_harness.mojo")
check("placement harness sweeps with settle rounds (J-038)",
      "run_placement_measurement" in harness and "settle_rounds" in harness)
check("no bench command in the CLI dispatch",
      'cmd == "bench"' not in commands and 'cmd == "get"' not in commands
      and 'cmd == "mcp"' not in commands)
check("device_inventory carries the bench-style device_line (J-037)",
      "def device_line" in read("aesir_engine/core/device_inventory.mojo"))
check("hardware list + compute plan|explain commands exist",
      'cmd == "hardware"' in commands and 'cmd == "compute"' in commands)

# --- T10 get/pull -----------------------------------------------------------
check("pull command dispatched", 'cmd == "pull"' in commands)
check("pull is pinned: revision + sha256 + size in help",
      "--sha256 <digest> --size <bytes>" in commands
      and "--revision <commit-sha>" in commands)
check("pull resumes verified partial downloads (help)",
      "resume verified partial downloads" in commands)
check("HuggingFaceSeer downloads with the pin",
      "download_hf_model" in read("aesir_engine/loader/huggingface.mojo"))

# --- T11/T12 server core + wider surface ------------------------------------
for route in ["/v1/chat/completions", "/v1/completions", "/v1/models",
              "/health", "/v1/generate", "/api/generate", "/api/chat"]:
    check(f"native_serve routes {route}", f'"{route}"' in native_serve)
for absent in ["/v1/responses", "/v1/files", "/v1/batches",
               "/v1/vector_stores", "/v1/assistants"]:
    check(f"native_serve has no {absent} route", f'"{absent}"' not in native_serve)
check("legacy api.mojo is the disconnected 501 scaffold",
      "legacy_route_response" in api and '"/infill"' in api
      and '"/tokenize"' in api)
check("live serve answers unknown routes 404 (not the 501 class)",
      "status = 404" in native_serve)

# --- T13 embeddings -----------------------------------------------------------
check("no /v1/embeddings route in native_serve",
      '"/v1/embeddings"' not in native_serve)
check("openai embeddings formatter is an error-only stub",
      "embedding formatting without real vector data" in openai)
check("health reports embeddings:false",
      '\\"embeddings\\":false' in native_serve)

# --- T14 prefix reuse -----------------------------------------------------------
check("llama3 CUDA session has exact prefix reuse",
      "reusable_prompt_prefix" in llama3_cuda and "cached_tokens" in llama3_cuda)
check("gemma4 CUDA session has no prefix reuse",
      "reusable_prompt_prefix" not in gemma4_cuda)
check("serve exposes --no-prefix-cache and health exact_prefix_reuse",
      "--no-prefix-cache" in native_serve and "exact_prefix_reuse" in native_serve)
check("no cached_tokens accounting in serve responses",
      "cached_tokens" not in native_serve)

# --- T15 browser page -----------------------------------------------------------
serve_all = native_serve + "\n".join(
    p.read_text(errors="ignore") for p in (ENG / "server").glob("*.mojo"))
check("no HTML page served anywhere in cli/server surfaces",
      "text/html" not in serve_all and "text/html" not in cli_all)

# --- T16 security manners ---------------------------------------------------------
check("local_protocol refuses Origin/Referer/Sec-Fetch-Site with 403",
      '"origin"' in local_protocol and "self.status = 403" in local_protocol)
check("local_protocol checks Host and Bearer (constant-time)",
      "constant_time_equal" in local_protocol
      and '"authorization"' in local_protocol)
check("serve requires --api-key-file", "--api-key-file" in native_serve)
check("no TLS in the server surface", "tls" not in native_serve.lower()
      and "certificate" not in native_serve.lower())

# --- T17 grammar / schema -----------------------------------------------------------
check("core/grammar.mojo bounded GBNF module exists",
      (ENG / "core/grammar.mojo").exists()
      and "GBNF" in read("aesir_engine/core/grammar.mojo"))
check("server holds a Boolean JSON response_format",
      "_parse_response_format" in openai or "_parse_boolean_schema" in openai)
check("engine facade grammar entry still raises not-implemented",
      "grammar-constrained model generation is not implemented" in aesir)

# --- T18 streaming ---------------------------------------------------------------------
check("SSE + NDJSON streaming in native_serve",
      "text/event-stream" in native_serve
      and "application/x-ndjson" in native_serve)
oai = native_serve.find('head.path == "/v1/chat/completions"')
seg = native_serve[oai:oai + 4000] if oai >= 0 else ""
check("OpenAI route still calls begin_turn before send_stream_head (J-059)",
      seg.find("begin_turn") >= 0 and seg.find("send_stream_head") > seg.find("begin_turn"))

# --- T20 server placement unwired ---------------------------------------------------------
check("core/server_placement.mojo exists (J-049)",
      (ENG / "core/server_placement.mojo").exists())
check("native_serve consumes no placement layer (unwired)",
      "server_placement" not in native_serve and "prompt_on" not in native_serve)

# --- T21/T22 MCP ------------------------------------------------------------------------------
check("no MCP anywhere in the engine tree (word scan)", not word_hits("mcp"))

# --- T25-T27 converters ---------------------------------------------------------------------------
check("no HF->GGUF converter module in aesir_engine",
      not list(ENG.rglob("*hf2gguf*")) and not list(ENG.rglob("*gguf2*")))
check("mmproj vision read path + vision inspect command exist",
      (ENG / "loader/mmproj.mojo").exists() and 'cmd == "vision"' in commands)

# --- T29 checker --------------------------------------------------------------------------------------
check("verify command rehashes via the durable store",
      'command == "verify"' in commands and "verify_model" in commands)
check("doctor and inspect commands exist",
      'cmd == "doctor"' in commands and 'cmd == "inspect"' in commands)

# --- T30 NSM ------------------------------------------------------------------------------------------------
check("no NSM anywhere in the engine tree (word scan)", not word_hits("nsm"))

# --- T32 completion ------------------------------------------------------------------------------------------------
check("openai parser refuses unknown fields (suffix has no home)",
      "Unsupported OpenAI request field: " in openai
      and '"suffix"' not in openai)
check("core/kv_window.mojo exists (J-097) with no serve consumer",
      (ENG / "core/kv_window.mojo").exists() and "kv_window" not in native_serve)

# --- T33-T36 library / examples ------------------------------------------------------------------------------------------------
check("engine facade offers generate/generate_chat/generate_image_chat",
      "def generate_chat(" in aesir and "def generate_image_chat(" in aesir
      and "def extract_query_embedding(" in aesir)
check("facade reserved stubs raise (speculative/grammar/ingest)",
      "speculative" in aesir and "not implemented" in aesir)
check("no examples directory in the repo",
      not list(ROOT.glob("examples")) and not list(ENG.glob("examples")))
check("no Node module or FreeBASIC binding files",
      not list(ROOT.rglob("*.node")) and not list(ROOT.rglob("*.bi")))

# --- the filed table's own tallies ------------------------------------------------------------------------------------------------
doc = read("docs/janas/J099_TOOL_CENSUS_RECONCILIATION.md")
rows = []
for line in doc.splitlines():
    m = re.match(r"\| (T\d\d) \|", line)
    if m:
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        rows.append(cells)
check("delta table has exactly 37 rows", len(rows) == 37)
verdicts = {}
changed = 0
owners_ok = True
for cells in rows:
    v = cells[3]
    verdicts[v] = verdicts.get(v, 0) + 1
    if cells[4] == "CHANGED":
        changed += 1
    if not re.search(r"(J-1(0[0-9]|1[0-9])|NONE)", cells[6]):
        owners_ok = False
check("verdict tally PRESENT 2 / PARTIAL 22 / ABSENT 7 / REFUSED-candidate 6",
      verdicts.get("PRESENT") == 2 and verdicts.get("PARTIAL") == 22
      and verdicts.get("ABSENT") == 7
      and verdicts.get("REFUSED-candidate") == 6)
check("changed-since-J-012 tally is 15 CHANGED / 22 STEADY",
      changed == 15 and len(rows) - changed == 22)
check("every row names a Part VII/VIII owner or NONE", owners_ok)

print(f"\n{sum(1 for _, ok in checks if ok)}/{len(checks)} checks PASS")
if any(not ok for _, ok in checks):
    sys.exit(1)
