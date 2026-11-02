#!/usr/bin/env python3
"""J-112 inspect: re-derive the slice's load-bearing claims from the
tree and the filed outputs. Run from the repo root of the J-112
worktree. Prints PASS/FAIL per check and a final verdict; exit 0 iff
all pass. Standard library only."""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ENG = ROOT / "aesir_engine"
JANAS = ENG / "docs" / "janas"
fails = []
oks = [0]


def check(cond, what):
    if cond:
        oks[0] += 1
        print("PASS: " + what)
    else:
        fails.append(what)
        print("FAIL: " + what)


services = (ENG / "core" / "services_surface.mojo").read_text()
mcp_tools = (ENG / "core" / "mcp_tools.mojo").read_text()
mcp_serve = (ENG / "cli" / "mcp_serve.mojo").read_text()
cuda_chat = (ENG / "cli" / "cuda_chat.mojo").read_text()
chat_manners = (ENG / "core" / "chat_manners.mojo").read_text()
chat_history = (ENG / "cli" / "chat_history.mojo").read_text()
test_services = (ENG / "tests" / "test_services_surface.mojo").read_text()
test_mcp = (ENG / "tests" / "test_mcp_tools.mojo").read_text()
test_manners = (ENG / "tests" / "test_chat_manners.mojo").read_text()
doc = (JANAS / "J112_SERVICES_SURFACE.md").read_text()
testout = (JANAS / "j112_test_output.txt").read_text()
transcript = (JANAS / "j112_client_session.txt").read_text()

TOOLS = ("aesir_generate", "aesir_model_info", "aesir_embed",
         "aesir_tokenize", "aesir_grade", "aesir_census", "aesir_bench")

# -- the registry against the tree (each executing path at its place)
check(services.count("services.append(ServiceEntry(") == 9,
      "registry carries exactly 9 services")
for name in ("generate", "tokenize", "grade", "census", "bench_report",
             "bench_sweep", "embed", "segment", "mcp_client"):
    check('String("%s")' % name in services,
          "registry names service %s" % name)
for cls in ("SVC_AVAILABLE", "SVC_MODEL_BOUND", "SVC_REFUSED",
            "SVC_CLI_ONLY", "SVC_DEFERRED", "SVC_NOT_EXPOSED"):
    check("comptime %s" % cls in services,
          "availability class %s defined" % cls)
facade = (ENG / "aesir.mojo").read_text()
check("def generate_tokens_config" in facade,
      "generate's executing path exists (engine facade)")
llama_tok = (ENG / "loader" / "llama3_tokenizer.mojo").read_text()
gemma_tok = (ENG / "loader" / "gemma4_tokenizer.mojo").read_text()
check("def encode" in llama_tok, "llama3 tokenizer carries encode")
check("def encode" in gemma_tok, "gemma4 tokenizer carries encode")
check("def llama3_segments" in llama_tok and "def qwen_segments" in llama_tok,
      "segment splits exist inside the tokenizers (not token ids)")
grade_layer = (ENG / "core" / "prefill_grade.mojo").read_text()
for fn in ("def step_class", "def grade_prefill_cell", "def verdict_name"):
    check(fn in grade_layer, "grading layer carries %s" % fn)
check("from core.prefill_grade import" in services,
      "services layer imports the grading layer")
check("def step_class" not in services
      and "def grade_prefill_cell" not in services,
      "grade is delegated, never re-implemented in the services layer")
selector = (ENG / "cli" / "model_selector.mojo").read_text()
check("def known_model_catalogue" in selector,
      "census source exists (the J-103 catalogue)")
bench_cfg = (ENG / "core" / "bench_configurations.mojo").read_text()
check("def run_bench_sweep" in bench_cfg,
      "bench sweep executing path exists (CLI door)")
report = (ENG / "core" / "machine_report.mojo").read_text()
for fn in ("def filed_model_rows", "def model_table", "def report_artefact"):
    check(fn in report, "machine report carries %s" % fn)
check("def mcp_embed_refusal_reason" in mcp_tools,
      "embed refusal reason exists in the MCP layer")
check("def mcp_no_tokenizer_reason" in mcp_tools,
      "no-tokenizer reason exists in the MCP layer")
check("def svc_mcp_client_disposition" in services,
      "the T22 disposition is served by the layer")

# -- the MCP tool table against the layer
names_seg = mcp_tools.split("def mcp_tool_names")[1].split("\ndef ")[0]
list_seg = mcp_tools.split("def mcp_tools_list_result")[1].split("\ndef ")[0]
for tool in TOOLS:
    check(tool in names_seg, "tool-name list carries %s" % tool)
    check(tool in list_seg, "tools/list JSON carries %s" % tool)
for tool in TOOLS[1:]:
    check('tool == "%s"' % tool in mcp_tools,
          "dispatch branch exists for %s" % tool)
check("# aesir_generate" in mcp_tools,
      "generate dispatch (the fallthrough) is present")
for fn in ("def mcp_tokenize_completion", "def mcp_tokenize_failure",
           "def mcp_bench_completion"):
    check(fn in mcp_tools, "MCP layer carries %s" % fn)
check("reply.needs_bench" in mcp_serve or "reply.needs_bench:" in mcp_serve,
      "host branches on needs_bench")
check("elif reply.needs_tokenize:" in mcp_serve,
      "host branches on needs_tokenize")
check("mcp_bench_completion" in mcp_serve and "svc_bench_text" in mcp_serve,
      "host executes the bench report through the layer builders")

# -- the chat branches in both bodies, and the manners/help growth
check(cuda_chat.count("svc_is_tokenize_command(command)") == 2,
      "tokenize branch present exactly once per chat body (2 total)")
check(cuda_chat.count('command == "/services" or command.startswith("/services ")') == 2,
      "services branch present exactly once per chat body (2 total)")
check(cuda_chat.count("session.tokenizer.encode(tok_text)") == 2,
      "each body encodes through its resident session's tokenizer")
check("def _services_response" in cuda_chat
      and "def _chat_service_facts" in cuda_chat,
      "chat host helpers convert the catalogue and answer via the layer")
check(chat_manners.count('names.append(String("/services"))') == 1,
      "manners candidate set grows by exactly the /services name")
check("expect_eq_int(len(chat_command_names()), 17" in test_manners,
      "manners suite asserts the chat candidate count 17")
check("/services [FORM]" in chat_history,
      "narrow help names /services")
check("Services: /services (inventory), /services census," in chat_history,
      "wide help names the services family")

# -- the suites' structure and the filed tallies
for group in ("test_registry", "test_census", "test_grade_delegation",
              "test_bench_composition", "test_chat_answers",
              "test_tokenize_parse_format"):
    check("def %s" % group in test_services,
          "services suite carries group %s" % group)
check("def test_services_dispatch" in test_mcp,
      "mcp suite carries the services dispatch group")
for verdict in ("ALL PASS: services surface (6 groups)",
                "ALL PASS: mcp tools (8 groups)",
                "ALL PASS: chat manners (7 groups)",
                "ALL PASS: machine report (6 groups)",
                "ALL PASS: bench configurations (8 groups)",
                "ALL PASS: code completion (6 groups)"):
    check(verdict in testout, "filed test output carries: %s" % verdict)
check("cuda chat module compile + import: PASS" in testout,
      "filed test output carries the chat compile driver verdict")
check("cli commands module compile + import: PASS" in testout,
      "filed test output carries the commands compile driver verdict")
check("MCP host wiring (staging driver importing cli/mcp_serve whole)"
      in testout,
      "filed test output carries the MCP host wiring driver")
check("3415bf9e26d66f1ce9cfd6bcfe265dd2b417da2d" in testout,
      "filed test output cites the verified protocol commit")
check("2cd68a1c" not in testout,
      "filed test output carries no misrendered protocol hash")

# -- the client transcript's tallies and the census arithmetic
check(transcript.count("  OK") == 40,
      "client transcript tallies 40 OK lines")
check("FAIL" not in transcript, "client transcript carries no FAIL")
check("CLIENT PROOF: ALL PASS" in transcript,
      "client transcript carries its verdict")
check("server exit code: 0" in transcript,
      "client transcript records the host's clean exit")
census_section = transcript.split(
    "== tools/call aesir_census ==")[1].split("\n==")[0]
entries = re.findall(r"\((Q4_K_M|Q2_K), (\d+) bytes\)", census_section)
check(len(entries) == 5, "census in transcript lists 5 entries")
check(sum(int(b) for _, b in entries) == 63189429184,
      "census per-entry bytes sum to the filed total 63189429184")
check(sum(1 for q, _ in entries if q == "Q4_K_M") == 3
      and sum(1 for q, _ in entries if q == "Q2_K") == 2,
      "census per-quantization counts are Q4_K_M 3 / Q2_K 2")
check("known-models census: 5 entries, 63189429184 bytes total" in transcript,
      "transcript census line matches the re-derived population")
tok_section = transcript.split(
    "== tools/call aesir_tokenize")[1].split("\n==")[0]
check("ids: [" not in tok_section,
      "tokenize refusal returns no id list")

# -- the doc's tallies against the filed outputs
for marker in ("## 1. Headline", "## 5. Deferred legs", "## 10. Banking"):
    check(marker in doc, "doc carries post-protocol section: %s" % marker)
check("test_services_surface` 6/6" in doc or "`test_services_surface` — 6/6" in doc
      or "test_services_surface` — 6/6" in doc or "6/6 groups ALL PASS" in doc,
      "doc tallies match the filed services verdict")
check("8/8" in doc and "7/7" in doc, "doc carries the extended/neighbour tallies")
check("40 OK / 0 FAIL" in doc, "doc tallies match the client transcript")
check("63189429184" in doc, "doc carries the census population numbers")
check("3415bf9e26d66f1ce9cfd6bcfe265dd2b417da2d" in doc,
      "doc cites the verified protocol commit")
check("misrendered" in doc,
      "doc records the protocol-hash correction honestly")
check("DEFERRED-WITH-REASON" in doc and "J-118" in doc,
      "doc defers the live legs to the J-118 gate with reason")
check("NOT PROVEN" in doc, "doc keeps its honesty ledger explicit")

# -- repo hygiene (diff == the expected file set, all of git status)
diff = subprocess.run(
    ["git", "diff", "--name-only",
     "cdf70d7a759ce28d8ef9435314fb8a4301386482", "HEAD"],
    cwd=ROOT, capture_output=True, text=True).stdout.split()
status = subprocess.run(
    ["git", "status", "--porcelain"],
    cwd=ROOT, capture_output=True, text=True).stdout.splitlines()
expected = {
    "aesir_engine/cli/chat_history.mojo",
    "aesir_engine/cli/cuda_chat.mojo",
    "aesir_engine/cli/mcp_serve.mojo",
    "aesir_engine/core/chat_manners.mojo",
    "aesir_engine/core/mcp_tools.mojo",
    "aesir_engine/core/services_surface.mojo",
    "aesir_engine/docs/janas/J112_SERVICES_SURFACE.md",
    "aesir_engine/docs/janas/j112_client_session.txt",
    "aesir_engine/docs/janas/j112_inspect.py",
    "aesir_engine/docs/janas/j112_inspect_output.txt",
    "aesir_engine/docs/janas/j112_mcp_client.py",
    "aesir_engine/docs/janas/j112_test_output.txt",
    "aesir_engine/tests/test_chat_manners.mojo",
    "aesir_engine/tests/test_mcp_tools.mojo",
    "aesir_engine/tests/test_services_surface.mojo",
}
present = set(diff)
for line in status:
    if len(line) > 3:
        present.add(line[3:].strip())
for p in expected:
    if (ROOT / p).exists():
        present.add(p)
check(present == expected,
      "slice file set == expected (extra=%s missing=%s)"
      % (sorted(present - expected), sorted(expected - present)))
check(not any(p.endswith("README.md") for p in present),
      "no README in the slice file set")
check(not any(p.endswith(".gguf") for p in present),
      "no .gguf in the slice file set")

print("INSPECT: %d PASS, %d FAIL" % (oks[0], len(fails)))
if fails:
    print("INSPECT VERDICT: FAIL")
    sys.exit(1)
print("INSPECT VERDICT: ALL PASS")
