#!/usr/bin/env python3
"""J-115 inspect: mechanically re-derive the library surface
audit's load-bearing claims from this tree (and, read-only, from
the standing consumer's tree).

Run from the repo root (the worktree root). Every check prints
PASS or FAIL; the summary line states the tally. Claims covered:
the CLI dispatch's answering and refusing command sets; the live
serve's route tables (served / 501-refused / Ollama shape) against
its own branch literals; the placement and draft layers' stated
non-wiring into the live serve; the constrained-generation field's
door (OpenAI shape only, not the native parser); the MCP tool
table and the J-112 services registry with its per-service
states; the AesirEngine facade's public entries and which of them
raise on their faces; the module classification (executables vs
importable library modules); the C-ABI evidence (no exported
host-facing surface, no headers/bindings artefacts, the only C
ABIs in the tree facing downward to devices/helpers); the Python
evidence (no in-process binding machinery, filed stdlib client
proofs as the process-door evidence); the Yggdrasil adapter's
contract read from its own tree (four native routes, its option
whitelist equalling the native parser's accepted field set, its
named embed/vision refusals, its stream record rule against the
J-107 progress frame shape); the doc's tallies against the filed
outputs; and repo hygiene (no README, no .gguf in the slice diff,
diff == the expected file set).
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ENG = ROOT / "aesir_engine"
YGG = Path.home() / "workspace/yggdrasil-build"
BASE = "e3d093b3724f8bbc9c7460742811a134c46a2489"

results = []


def check(name, ok):
    results.append((name, bool(ok)))
    print(("PASS" if ok else "FAIL") + ": " + name)


def read(path):
    return Path(path).read_text(encoding="utf-8")


def flat(text):
    return re.sub(r"\s+", " ", text)


main_src = read(ENG / "main.mojo")
commands = read(ENG / "cli/commands.mojo")
serve = read(ENG / "cli/native_serve.mojo")
openai_parser = read(ENG / "server/openai.mojo")
audit_mod = read(ENG / "core/openai_audit.mojo")
mcp_tools = read(ENG / "core/mcp_tools.mojo")
services = read(ENG / "core/services_surface.mojo")
facade = read(ENG / "aesir.mojo")
draft_config = read(ENG / "core/draft_config.mojo")
progress = read(ENG / "core/prompt_progress.mojo")
pixi = read(ENG / "pixi.toml")
doc = read(ENG / "docs/janas/J115_LIBRARY_SURFACE_AUDIT.md")

# --- CLI surface -------------------------------------------------------------
check("CLI entry: main.mojo dispatches through cli.commands dispatch_command",
      "from cli.commands import dispatch_command" in main_src
      and "dispatch_command(cli_args)" in main_src)
store_dispatch = commands[commands.index(
    'def dispatch_command(args: List[String], mut store: RuneModelStore)'):]
store_dispatch = store_dispatch[:store_dispatch.index(
    'raise Error(', store_dispatch.index('cmd == "onnx"'))]
cli_cmds = set(re.findall(r'cmd == "([^"]+)"', store_dispatch))
expected_cli = {"help", "-h", "--help", "-v", "--version", "pull", "get",
                "mcp", "inspect", "vision", "doctor", "keygen", "chat",
                "serve", "ps", "stop", "hardware", "compute", "bench",
                "config", "run", "daemon", "push", "swarm", "llama-cli",
                "llama-server", "llama-bench", "exl2", "onnx"}
check("CLI dispatch: 29 cmd== names in the store dispatch (26 expected + "
      "help/version aliases counted)", cli_cmds == expected_cli)
catalog_src = commands[commands.index("def _is_catalog_command"):]
catalog_src = catalog_src[:2000]
catalog_cmds = set(re.findall(r'command == "([^"]+)"', catalog_src))
check("CLI catalog group: list/ls/show/create/verify/catalog/gc/cp/rm/delete",
      catalog_cmds == {"list", "ls", "show", "create", "verify", "catalog",
                       "gc", "cp", "rm", "delete"})
pref_src = commands[commands.index("def dispatch_preference_command"):]
pref_cmds = set(re.findall(r'command == "([^"]+)"', pref_src[:6000]))
check("CLI preference group: repair-preferences/aliases/favorites/alias/"
      "unalias/favorite",
      {"repair-preferences", "aliases", "favorites", "alias", "unalias",
       "favorite"} <= pref_cmds)
check("CLI refusals on their faces: daemon unsupported, push not implemented, "
      "swarm not implemented",
      'raise Error("daemon is unsupported' in commands
      and "is not implemented" in commands)
multi = read(ENG / "cli/multi_engine.mojo")
check("CLI compat names (llama/exl2/onnx) dispatch to rejecting surfaces",
      flat(multi).count("rejecting the") >= 3)

# --- HTTP server surface -----------------------------------------------------
def appends_of(source, func):
    start = source.index("def " + func)
    end = source.index("return names^", start)
    return re.findall(r'names\.append\(String\("([^"]+)"\)\)', source[start:end])


served = appends_of(audit_mod, "served_route_names")
check("server served routes (openai_audit table): exactly 9",
      served == ["GET /", "POST /v1/chat/completions", "POST /v1/completions",
                 "GET /v1/models", "GET /v1/models/{id}", "GET /health",
                 "GET /health/live", "GET /health/ready", "POST /v1/generate"])
refused = appends_of(audit_mod, "refused_route_names")
check("server 501-refused routes: exactly 6 (embeddings, 3 speech, responses, "
      "moderations)",
      refused == ["POST /v1/embeddings", "POST /v1/audio/transcriptions",
                  "POST /v1/audio/translations", "POST /v1/audio/speech",
                  "POST /v1/responses", "POST /v1/moderations"])
serve_paths = set(re.findall(r'head\.path == "([^"]+)"', serve))
check("live serve branches carry every served route path",
      {"/", "/v1/chat/completions", "/v1/completions", "/v1/models",
       "/health", "/health/live", "/health/ready", "/v1/generate"}
      <= serve_paths)
check("live serve Ollama shape: /api/version /api/tags /api/ps /api/show "
      "/api/generate /api/chat",
      {"/api/version", "/api/tags", "/api/ps", "/api/show", "/api/generate",
       "/api/chat"} <= serve_paths)
check("placement NOT wired into the live serve: native_serve imports no "
      "server_placement and no request parser carries prompt_on",
      "server_placement" not in serve
      and "prompt_on" not in openai_parser
      and "prompt_on" not in read(ENG / "server/local_protocol.mojo"))
check("draft config layer states its own non-wiring on its face",
      "wires the module into no live chat or server path"
      in flat(draft_config))
gen_req = serve[serve.index("struct GenerateRequest"):]
gen_req = gen_req[:gen_req.index("def local_response")]
native_fields = (set(re.findall(r'field\.name == "([^"]+)"', gen_req))
                 | set(re.findall(r'field\.name == "([^"]+)" or', gen_req)))
native_numbers = set(re.findall(r'field\.name == "([^"]+)"', gen_req))
check("native GenerateRequest: no vocab_restriction / placement / draft field",
      "vocab_restriction" not in gen_req and "prompt_on" not in gen_req
      and "draft" not in gen_req)
check("constrained generation's server door is the OpenAI shape only: "
      "vocab_restriction parsed in server/openai.mojo and answered in the "
      "serve's OpenAI branch",
      'name == "vocab_restriction"' in openai_parser
      and "has_vocab_restriction" in serve
      and "cg_serve_vocab_response" in serve)

# --- MCP + services surface --------------------------------------------------
tool_names = None
start = mcp_tools.index('names.append(String("aesir_generate"))')
tool_block = mcp_tools[mcp_tools.rindex("def ", 0, start):start + 400]
tool_names = re.findall(r'names\.append\(String\("([^"]+)"\)\)', tool_block)
check("MCP tool table: exactly 7 tools",
      tool_names == ["aesir_generate", "aesir_model_info", "aesir_embed",
                     "aesir_tokenize", "aesir_grade", "aesir_census",
                     "aesir_bench"])
check("MCP host door: CLI 'mcp' dispatches dispatch_mcp in cli/commands.mojo",
      "def dispatch_mcp" in commands and 'cmd == "mcp"' in commands)
svc_block = services[services.index("def svc_services()"):]
svc_block = svc_block[:svc_block.index("def svc_census_text")]
svc_entries = re.findall(
    r'ServiceEntry\(\s*String\("([^"]+)"\), String\("([^"]*)"\),\s*'
    r'String\("[^"]*"\),\s*(SVC_[A-Z_]+)', svc_block)
svc_map = {name: state for name, _tool, state in svc_entries}
check("services registry: exactly 9 entries",
      len(svc_entries) == 9)
check("services states: generate/tokenize MODEL_BOUND, grade/census/"
      "bench_report AVAILABLE, bench_sweep CLI_ONLY, embed REFUSED, "
      "segment NOT_EXPOSED, mcp_client DEFERRED",
      svc_map == {"generate": "SVC_MODEL_BOUND", "tokenize": "SVC_MODEL_BOUND",
                  "grade": "SVC_AVAILABLE", "census": "SVC_AVAILABLE",
                  "bench_report": "SVC_AVAILABLE",
                  "bench_sweep": "SVC_CLI_ONLY", "embed": "SVC_REFUSED",
                  "segment": "SVC_NOT_EXPOSED", "mcp_client": "SVC_DEFERRED"})

# --- Mojo-native facade ------------------------------------------------------
eng_start = facade.index("struct AesirEngine:")
eng_src = facade[eng_start:]
# public method names: def at 4-space indent, not starting with _
pub_defs = re.findall(r"\n    def ([a-z][a-z_0-9]*)\(", eng_src)
pub_defs = [d for d in pub_defs if not d.startswith("_")]
expected_pub = ["extract_query_embedding", "ingest_document", "save_checkpoint",
                "load_checkpoint", "join_swarm_cluster",
                "dispatch_swarm_inference", "speculative_generate",
                "generate_tokens_with_grammar", "generate_tokens_config",
                "generate_tokens", "generate_image_chat", "generate",
                "generate_stream", "generate_chat", "generate_session"]
check("AesirEngine facade: exactly 15 public entries", pub_defs == expected_pub)


def def_body(src, name):
    start = src.index("    def " + name + "(")
    nxt = src.find("\n    def ", start + 1)
    return src[start:] if nxt == -1 else src[start:nxt]


raising = [d for d in expected_pub
           if "not implemented" in def_body(eng_src, d)
           or "is unavailable" in def_body(eng_src, d)]
check("facade entries raising on their faces: exactly the 5 reserved ones "
      "(ingest, swarm join, swarm inference, speculative, grammar)",
      raising == ["ingest_document", "join_swarm_cluster",
                  "dispatch_swarm_inference", "speculative_generate",
                  "generate_tokens_with_grammar"])
check("live serve is itself a Mojo host of the facade module: native_serve "
      "imports the CUDA sessions from aesir",
      "from aesir import (Gemma4CUDASession, Llama3CUDASession" in serve)

# --- module classification ---------------------------------------------------
mods = [p for p in ENG.rglob("*.mojo")
        if "tests" not in p.parts and "docs" not in p.parts]
exe = [p for p in mods if "def main()" in p.read_text(errors="ignore")]
check("module classification: 215 modules excl. tests/docs, exactly 1 "
      "executable (main.mojo), 214 importable library modules",
      len(mods) == 215 and len(exe) == 1 and exe[0].name == "main.mojo"
      and len(mods) - len(exe) == 214)
pkgs = {}
for p in mods:
    pkgs.setdefault(p.relative_to(ENG).parts[0], 0)
    pkgs[p.relative_to(ENG).parts[0]] += 1
check("package shape: core 141, cli 47, loader 15, server 8, top-level 4",
      pkgs.get("core") == 141 and pkgs.get("cli") == 47
      and pkgs.get("loader") == 15 and pkgs.get("server") == 8
      and sum(v for k, v in pkgs.items()
              if k.endswith(".mojo")) == 4)

# --- C ABI / FFI evidence ----------------------------------------------------
tracked = subprocess.run(["git", "ls-files", "aesir_engine"],
                         cwd=ROOT, capture_output=True, text=True).stdout
tracked_files = [ln.strip() for ln in tracked.splitlines() if ln.strip()]
bad_ext = [f for f in tracked_files
           if re.search(r"\.(h|hpp|bi|ts|tsx|js|mjs|cjs|node)$", f)]
check("no C headers, no .bi, no TypeScript/JavaScript/.node artefacts "
      "anywhere under aesir_engine", bad_ext == [])
mojo_all = ""
for p in ENG.rglob("*.mojo"):
    if "docs" not in p.parts:
        mojo_all += p.read_text(errors="ignore")
check("no @export anywhere in the engine's Mojo modules (excl. docs)",
      "@export" not in mojo_all)
check("pixi.toml carries no package/build target and no shared-library "
      "product", ".so" not in pixi and "[package]" not in pixi
      and "shared" not in pixi)
check("FFI consumption is heavy (Mojo calling libc): >50 external_call sites "
      "outside docs", mojo_all.count("external_call") > 50)
stub = read(ENG / "hailo10h_stub.c")
hailo_names = sorted(set(re.findall(r"aesir_hailo10h_[a-z_0-9]+", stub)))
check("the one named C ABI in the tree is the downward Hailo device bridge: "
      "6 aesir_hailo10h_* entries, fail-closed stub",
      hailo_names == ["aesir_hailo10h_clear_context", "aesir_hailo10h_close",
                      "aesir_hailo10h_describe", "aesir_hailo10h_free_text",
                      "aesir_hailo10h_generate", "aesir_hailo10h_open"]
      and "Fail-closed stub for the Hailo-10H C ABI" in stub)
image_c = read(ENG / "image_decode.c")
thread_c = read(ENG / "thread_par.c")
check("the other C surfaces are internal shims: libaesir_image (2 entries, "
      "dlopen'd by the loader) and the thread_par shim (2 entries)",
      sorted(set(re.findall(r"aesir_image_[a-z_]+", image_c)))
      == ["aesir_image_decode", "aesir_image_free"]
      and sorted(set(re.findall(r"aesir_par_[a-z_]+", thread_c)))
      == ["aesir_par_cpu_count", "aesir_par_for"]
      and "libaesir_image" in read(ENG / "loader/image_codecs.mojo"))

# --- Python evidence ---------------------------------------------------------
py_engine = [f for f in tracked_files
             if f.endswith(".py") and "/docs/janas/" not in f]
check("no Python file under aesir_engine outside docs/janas (the filed "
      "client proofs)", py_engine == [])
check("no Python-interop machinery in the engine's Mojo modules: no "
      "PythonObject, no 'from python import'",
      "PythonObject" not in mojo_all and "from python import" not in mojo_all)
check("filed Python process-door proofs exist: j109/j110/j112 clients",
      all((ENG / "docs/janas" / n).exists() for n in
          ["j109_mcp_client.py", "j110_runmal_consumer.py",
           "j112_mcp_client.py"]))

# --- Yggdrasil adapter (read-only, its own tree) ------------------------------
adapter = read(YGG / "src/yggdrasil/aesir_adapter.py")
routes = sorted(set(re.findall(r'"(/(?:health|v1)/[a-z_]+)"', adapter)))
check("Yggdrasil adapter calls exactly the 4 native routes",
      routes == ["/health/live", "/health/ready", "/v1/generate",
                 "/v1/models"])
wl = adapter[adapter.index("_GENERATE_OPTION_FIELDS"):]
wl = wl[:wl.index("}")]
whitelist = set(re.findall(r'"([a-z_]+)"', wl))
check("adapter generate-option whitelist: exactly 9 fields",
      whitelist == {"system", "max_tokens", "timeout_ms", "temperature",
                    "top_k", "top_p", "min_p", "repeat_penalty", "seed"})
parser_fields = set(re.findall(r'field\.name == "([^"]+)"', gen_req))
check("adapter whitelist == the native parser's accepted field set exactly",
      whitelist == parser_fields - {"prompt", "stream"})
check("adapter refuses embed and vision tasks by name on its own face",
      '"embed" in segments' in adapter and '"vision" in segments' in adapter)
check("adapter speaks no MCP and no OpenAI shape: no /v1/chat/completions, "
      "no tools/call in its source",
      "/v1/chat/completions" not in adapter
      and "tools/call" not in adapter)
check("adapter stream rule: every streamed record must carry a text string",
      "streamed a record without a text string" in adapter)
render = progress[progress.index("def render_progress_event"):]
render = render[:600]
check("J-107 native progress frame shape: an event record with no text "
      "field (the adapter friction, filed for J-116)",
      '"event":"prefill_progress"' in render.replace(" ", "")
      and '"text"' not in render)

# --- doc tallies ---------------------------------------------------------------
check("doc states the audit tallies (215/214/1, 15/5, 9/6 routes, 7 tools, "
      "9 services, 9 whitelist fields)",
      all(s in doc for s in ["215 modules", "214", "15 public entries",
                             "9 served routes", "6 refused",
                             "7 MCP tools", "9 services", "9 fields"]))

# --- hygiene -------------------------------------------------------------------
diff = subprocess.run(["git", "diff", "--name-only", BASE, "HEAD"],
                      cwd=ROOT, capture_output=True, text=True).stdout
status = subprocess.run(["git", "status", "--porcelain"],
                        cwd=ROOT, capture_output=True, text=True).stdout
changed = {ln.strip() for ln in diff.splitlines() if ln.strip()}
changed |= {ln[3:].strip() for ln in status.splitlines() if ln.strip()}
expected = {"aesir_engine/docs/janas/J115_LIBRARY_SURFACE_AUDIT.md",
            "aesir_engine/docs/janas/j115_inspect.py",
            "aesir_engine/docs/janas/j115_inspect_output.txt"}
check("hygiene: slice file set == the 3 expected artefacts",
      changed == expected)
check("hygiene: no README in the slice file set, no .gguf anywhere in it",
      not any("README" in f for f in changed)
      and not any(f.endswith(".gguf") for f in changed))

fails = [n for n, ok in results if not ok]
print()
print("TOTAL: %d PASS, %d FAIL" % (len(results) - len(fails), len(fails)))
print("ALL PASS" if not fails else "FAILURES: " + "; ".join(fails))
sys.exit(0 if not fails else 1)
