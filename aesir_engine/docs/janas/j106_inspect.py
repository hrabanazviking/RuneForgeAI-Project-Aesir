#!/usr/bin/env python3
"""J-106 inspect: mechanically re-derive the OpenAI-shape
audit slice's load-bearing claims from this tree.

Run from the repo root (the worktree root). Every check prints
PASS or FAIL; the summary line states the tally. Claims covered:
the audit module's tables equal their extracted surfaces (the
parser's honoured field set plus the C1/C2 closures; the message
roles in the parser; the serve's route branches incl. the
retrieve and 501 branches and the C6 id prefixes; the three
formatters' prompt_tokens_details; the status field and the
Llama pass-through; the legacy scaffold's non-liveness left
alone); the doc's section 2 tables equal the module's tables;
the test suite's group structure; the filed test output's
tallies; and repo hygiene (no README, no .gguf in the slice
diff, diff == the expected file set).
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AESIR = ROOT / "aesir_engine"
BASE = "fde780603396066b410a4c32995326e9f09c0464"

results = []


def check(name, ok):
    results.append((name, bool(ok)))
    print(("PASS" if ok else "FAIL") + ": " + name)


def read(path):
    return Path(path).read_text(encoding="utf-8")


def appends_of(source, func):
    start = source.index("def " + func)
    end = source.index("return names^", start)
    return re.findall(r'names\.append\(String\("([^"]+)"\)\)', source[start:end])


def verdict_sets(source, func):
    """(honoured, partial) name sets from one verdict def."""
    start = source.index("def " + func)
    end = source.index("return FIELD_REFUSED", start)
    body = source[start:end]
    groups = re.findall(r'\(([^)]*)\)\s*:\s*\n\s*return FIELD_(HONOURED|PARTIAL)', body)
    honoured, partial = set(), set()
    for names, kind in groups:
        found = set(re.findall(r'name == "([^"]+)"', names))
        (honoured if kind == "HONOURED" else partial).update(found)
    single = re.search(r'if name == "([^"]+)":\s*\n\s*return FIELD_PARTIAL', body)
    if single:
        partial.add(single.group(1))
    return honoured, partial


module = read(AESIR / "core/openai_audit.mojo")
parser_src = read(AESIR / "server/openai.mojo")
serve = read(AESIR / "cli/native_serve.mojo")
genctl = read(AESIR / "core/generation_control.mojo")
llama = read(AESIR / "core/llama3_cuda.mojo")
gemma = read(AESIR / "core/gemma4_cuda.mojo")
scaffold = read(AESIR / "server/api.mojo")
test = read(AESIR / "tests/test_openai_audit.mojo")
doc = read(AESIR / "docs/janas/J106_OPENAI_SHAPE_AUDIT.md")
test_output = read(AESIR / "docs/janas/j106_test_output.txt")

# --- the audit module's tables -------------------------------------------------
chat_names = appends_of(module, "chat_field_names")
chat_h, chat_p = verdict_sets(module, "chat_field_verdict")
check("chat table: 31 fields, 8 honoured / 4 partial / 19 refused",
      len(chat_names) == 31 and len(chat_h) == 8 and len(chat_p) == 4
      and len(set(chat_names) - chat_h - chat_p) == 19)
comp_names = appends_of(module, "completion_field_names")
comp_h, comp_p = verdict_sets(module, "completion_field_verdict")
check("completion table: 19 fields, 8 honoured / 1 partial / 10 refused",
      len(comp_names) == 19 and len(comp_h) == 8 and len(comp_p) == 1
      and len(set(comp_names) - comp_h - comp_p) == 10)
msg_names = appends_of(module, "message_field_names")
role_names = appends_of(module, "message_role_names")
check("message tables: 7 fields (2 honoured), 6 roles (4 honoured)",
      len(msg_names) == 7 and len(role_names) == 6
      and 'if name == "role" or name == "content":' in module
      and '"system" or name == "developer"' in module)
served = appends_of(module, "served_route_names")
refused = appends_of(module, "refused_route_names")
families = appends_of(module, "kept_404_route_families")
check("route table: 8 served / 6 refused-501 / 8 kept families",
      len(served) == 8 and len(refused) == 6 and len(families) == 8
      and "GET /v1/models/{id}" in served
      and "POST /v1/embeddings" in refused
      and "POST /v1/audio/transcriptions" in refused)

# --- the parser surface ----------------------------------------------------------
init = parser_src[parser_src.index("def __init__"):parser_src.index("def _parse_tool_function")]
parser_fields = set(re.findall(r'name == "([^"]+)"', init))
check("parser honoured set == audit honoured+partial union (13)",
      parser_fields == (chat_h | chat_p | comp_h | comp_p)
      and len(parser_fields) == 13)
check("C1: max_completion_tokens parsed + precedence after parse",
      '"max_completion_tokens"' in init
      and "if self.completion_budget > 0:" in parser_src
      and "self.max_tokens = self.completion_budget" in parser_src
      and parser_src.index("if self.completion_budget > 0:")
      > parser_src.index("Trailing OpenAI JSON content"))
check("C2: developer role aliased to system in the message parser",
      'if role == "system" or role == "developer":' in parser_src
      and "system, developer, user, and assistant roles" in parser_src)
check("parser still refuses strangers by name",
      'raise Error("Unsupported OpenAI request field: " + name)' in parser_src
      and 'raise Error("Unsupported OpenAI message field: " + name)' in parser_src)

# --- the formatters + status (C3) --------------------------------------------------
check("C3: prompt_tokens_details.cached_tokens on all three usage formatters",
      parser_src.count("prompt_tokens_details") == 3
      and parser_src.count("_validate_cached_tokens") == 4
      and parser_src.count("cached_tokens: Int = 0") == 3)
check("C4: format_model_object exists beside the catalog formatter",
      "def format_model_object" in parser_src
      and "def format_model_catalog" in parser_src)
check("C3: status gains the defaulted trailing cached_tokens",
      "var cached_tokens: Int" in genctl and "cached_tokens: Int = 0" in genctl)
check("C3: Llama status passes its reused count; Gemma untouched-honest",
      "self.reused_prompt_tokens)" in llama
      and "cached_tokens" not in gemma)

# --- the serve wiring (C4/C5/C6) -----------------------------------------------------
check("serve imports the audit refusal rule",
      "from core.openai_audit import ROUTE_REFUSED_501, route_verdict, "
      "unsupported_route_body" in serve)
check("C5: 501 branch before the standing 404, body preserved",
      "elif route_verdict(head.method, head.path) == ROUTE_REFUSED_501:" in serve
      and serve.index("ROUTE_REFUSED_501:") < serve.index("status = 404", serve.index("ROUTE_REFUSED_501:"))
      and '"Not Implemented"' in serve)
check("C4: models retrieve branch with the standing match rule",
      'head.path.startswith("/v1/models/")' in serve
      and "OpenAIGate.format_model_object(" in serve
      and serve.count("ollama_model_matches(wanted,") >= 2)
check("C6: chatcmpl- on chat, cmpl- kept on raw completions",
      '"chatcmpl-aesir-" + String(sequence)' in serve
      and '"cmpl-aesir-" + String(sequence)' in serve)
check("C3: serve passes the status cached count into all three formatters",
      serve.count("state.cached_tokens") == 3)

# --- the legacy scaffold left alone ---------------------------------------------------
check("legacy scaffold still the disconnected 501-for-model-routes scaffold",
      "legacy_route_response" in scaffold and "501" in scaffold
      and "native_serve" not in scaffold)

# --- the doc's section 2 tables equal the module's tables ------------------------------
section2 = doc[doc.index("## 2."):doc.index("## 3.")]


def doc_rows(start_marker, end_marker):
    part = section2[section2.index(start_marker):section2.index(end_marker)]
    return dict(re.findall(r"\| `([^`]+)` \| (HONOURED|PARTIAL|REFUSED) \|", part))


def as_map(names, honoured, partial):
    return {n: ("HONOURED" if n in honoured else
                "PARTIAL" if n in partial else "REFUSED") for n in names}


check("doc 2.1 chat table == module chat table",
      doc_rows("### 2.1", "### 2.2") == as_map(chat_names, chat_h, chat_p))
check("doc 2.2 completion table == module completion table",
      doc_rows("### 2.2", "### 2.3") == as_map(comp_names, comp_h, comp_p))
msg_h = {"role", "content"}
check("doc 2.3 message field table == module table",
      doc_rows("### 2.3", "### 2.4") == as_map(msg_names, msg_h, set()))
role_h = {"system", "developer", "user", "assistant"}
check("doc 2.4 role table == module table",
      doc_rows("### 2.4", "### 2.5") == as_map(role_names, role_h, set()))
routes_part = section2[section2.index("### 2.5"):]
doc_served = set(re.findall(r"\| `(?:GET|POST) [^`]+` \| SERVED \|", routes_part))
doc_refused = set(re.findall(r"\| `(?:GET|POST) [^`]+` \| REFUSED_501 \|", routes_part))
check("doc 2.5 route rows: 8 SERVED + 6 REFUSED_501 present",
      len(doc_served) == 8 and len(doc_refused) == 6
      and "/v1/fine_tuning" in routes_part and "KEPT_404" in routes_part)

# --- test suite ---------------------------------------------------------------------------
check("test suite has 7 group prints + ALL PASS line",
      test.count('print("PASS:') == 7
      and "ALL PASS: openai audit (7 groups)" in test)
check("test pins the table counts 31/19/8/6 + the closures",
      all(s in test for s in (
          'expect_eq_int(len(names), 31', 'expect_eq_int(len(names), 19',
          'expect_eq_int(len(served_route_names()), 8',
          'expect_eq_int(len(refused_route_names()), 6',
          "max_completion_tokens takes precedence",
          "developer role lands as system",
      )))

# --- doc --------------------------------------------------------------------------------------
for phrase in (
    "DEFERRED-WITH-REASON",
    "NOT PROVEN",
    "J-118 Part VII gate",
    "T20",
    "fde780603396066b410a4c32995326e9f09c0464",
):
    check("doc carries: " + phrase, phrase in doc)

# --- filed test output ---------------------------------------------------------------------------
for tally in (
    "ALL PASS: openai audit (7 groups)",
    "native serve + openai audit modules compile + import: PASS",
    "PASS bounded JSON and HTTP rejection",
    "ALL PASS: server placement parity (17 groups)",
    "OpenAI REST API Gateway: PASS",
):
    check("test output carries: " + tally, tally in test_output)

# --- repo hygiene -----------------------------------------------------------------------------------
diff = subprocess.run(
    ["git", "-C", str(ROOT), "diff", "--name-only", BASE],
    capture_output=True, text=True,
).stdout.splitlines()
status = subprocess.run(
    ["git", "-C", str(ROOT), "status", "--porcelain"],
    capture_output=True, text=True,
).stdout.splitlines()
changed = set(diff) | {line[3:] for line in status if line.strip()}
check("no README in the slice diff", not any(p.endswith("README.md") for p in changed))
check("no .gguf in the slice diff", not any(p.endswith(".gguf") for p in changed))
expected = {
    "aesir_engine/core/openai_audit.mojo",
    "aesir_engine/tests/test_openai_audit.mojo",
    "aesir_engine/server/openai.mojo",
    "aesir_engine/cli/native_serve.mojo",
    "aesir_engine/core/generation_control.mojo",
    "aesir_engine/core/llama3_cuda.mojo",
    "aesir_engine/docs/janas/J106_OPENAI_SHAPE_AUDIT.md",
    "aesir_engine/docs/janas/j106_inspect.py",
    "aesir_engine/docs/janas/j106_inspect_output.txt",
    "aesir_engine/docs/janas/j106_test_output.txt",
}
check("slice diff is exactly the expected file set", changed == expected)

passed = sum(1 for _, ok in results if ok)
print("j106 inspect: %d/%d PASS" % (passed, len(results)))
sys.exit(0 if passed == len(results) else 1)
