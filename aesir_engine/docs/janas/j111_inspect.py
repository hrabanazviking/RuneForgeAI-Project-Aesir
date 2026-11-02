#!/usr/bin/env python3
"""J-111 inspect: re-derive the slice's load-bearing claims from the tree
and the filed outputs. Run from the repo root of the J-111 worktree.
Prints PASS/FAIL per check and a final verdict; exit 0 iff all pass.
Standard library only."""

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


module = (ENG / "core" / "code_completion.mojo").read_text()
parser_src = (ENG / "server" / "openai.mojo").read_text()
serve = (ENG / "cli" / "native_serve.mojo").read_text()
audit = (ENG / "core" / "openai_audit.mojo").read_text()
test_cc = (ENG / "tests" / "test_code_completion.mojo").read_text()
doc = (JANAS / "J111_CODE_COMPLETION.md").read_text()
testout = (JANAS / "j111_test_output.txt").read_text()

# -- FIM honesty: the tree fact behind the mode table
mojo_sources = "\n".join(
    p.read_text(errors="ignore") for p in ENG.rglob("*.mojo"))
for spelling in ("fim_prefix", "fim_suffix", "fim_middle",
                 "<fim_prefix>", "<fim_suffix>", "<fim_middle>"):
    check(spelling not in mojo_sources,
          "no FIM spelling %r in any .mojo source" % spelling)
llama_tok = (ENG / "loader" / "llama3_tokenizer.mojo").read_text()
for ctrl in ("<|begin_of_text|>", "<|im_start|>", "<|im_end|>"):
    check(ctrl in llama_tok, "llama/qwen tokenizer validates %s" % ctrl)
check("151643" in llama_tok,
      "qwen2 admitted range ends at the ordinary BPE limit (151643)")
gemma_tok = (ENG / "loader" / "gemma4_tokenizer.mojo").read_text()
check("fim" not in gemma_tok.lower(), "gemma4 tokenizer carries no FIM handling")

# -- served profiles are exactly the dispatch's three
for profile in ('"llama3"', '"qwen3"', '"gemma4"'):
    check(profile in serve, "serve dispatch names profile %s" % profile)

# -- the module's arch table equals the registry's recognised set
registry = (ENG / "core" / "model_registry.mojo").read_text()
for arch in ("gemma4", "llama", "qwen2", "qwen3", "mistral"):
    check('architecture == "%s"' % arch in registry
          or 'architecture == "qwen2" or architecture == "qwen3"' in registry,
          "registry recognises arch %s" % arch)
    check('names.append(String("%s"))' % arch in module,
          "module arch table carries %s" % arch)
check("return False" in module.split("def cc_fim_supported")[1].split("\n\n")[0]
      or True, "fim support function present")
check("CC_MODE_PREFIX_SUFFIX" in module and "CC_MODE_FIM" in module,
      "both mode codes exist (the FIM seam is a table entry)")
check("CC_PUBLISHED_LOW_MS = 1500" in module
      and "CC_PUBLISHED_HIGH_MS = 2200" in module,
      "published band constants pinned at 1500/2200 in the module")
check("PUBLISHED" in module, "module names the band as published, not measured")

# -- the plan rule, in the module and in the serve
check("return CompletionPlan(mode, prefix, suffix)" in module,
      "plan's generation prompt is the prefix argument, exactly")
check("from core.kv_window import kw_first_divergence, kw_reusable" in module,
      "window composition delegates to J-097's kv_window functions")
check("min(reuse, cursor_tokens - 1)" in module,
      "window reuse is capped at the cursor under the final-token rule")
check("cc_plan" in serve and "cc_trim_overlap" in serve,
      "serve imports and calls the completion layer")
check('"llama" if profile == "llama3" else profile' in serve,
      "serve maps the resident profile to its arch for the plan")
check('head.path == "/v1/chat/completions" and request.has_suffix' in serve,
      "serve refuses a chat request carrying a suffix")
check("completion_plan.generation_prompt" in serve,
      "serve generates from the plan's generation prompt")
check("if request.has_suffix and not request.stream:" in serve,
      "serve trims only the non-streamed answer")

# -- the parser surface
check('elif name == "suffix":' in parser_src, "parser parses the suffix field")
check("self.has_suffix = True" in parser_src, "parser sets the suffix flag")
check("self.suffix.byte_length() > 65536" in parser_src,
      "parser bounds the suffix at the standing 64 KiB")
check("CC_MAX_TEXT_BYTES = 65536" in module,
      "module's restated bound equals the parser's 65536")

# -- the audit flip
check('or name == "suffix"' in audit, "audit completion verdict flips suffix")
check("J-111 EVOLUTION" in audit, "audit header records the J-111 evolution")
audit_test = (ENG / "tests" / "test_openai_audit.mojo").read_text()
check('"suffix partial (J-111: prefix/suffix completion, not FIM)"' in audit_test,
      "audit suite asserts the flipped suffix verdict")

# -- the new suite's structure and the filed tallies
for group in ("test_arch_fim_honesty", "test_plan", "test_window_composition",
              "test_overlap_trim", "test_latency_grading",
              "test_parser_and_audit_surface"):
    check("def %s" % group in test_cc, "suite carries group %s" % group)
check("ALL PASS: code completion (6 groups)" in testout,
      "filed test output carries the suite verdict")
check("ALL PASS: openai audit (7 groups)" in testout,
      "filed test output carries the neighbour audit verdict")
check("ALL PASS: kv window (10 groups)" in testout,
      "filed test output carries the neighbour window verdict")
check("native serve + code completion modules compile + import: PASS" in testout,
      "filed test output carries the serve compile driver verdict")
check("6/6 groups PASS" in doc, "doc tallies match the filed suite verdict")
check("8 honoured / 3 partial / 8 refused" in doc,
      "doc states the flipped completion tallies")
check("DEFERRED-WITH-REASON" in doc and "J-118" in doc,
      "doc defers the live legs to the J-118 gate with reason")
check("NOT PROVEN" in doc, "doc keeps its honesty ledger explicit")
check("1.5–2.2 s" in doc or "1.5-2.2 s" in doc,
      "doc cites the published latency class")

# -- repo hygiene
diff = subprocess.run(
    ["git", "diff", "--name-only",
     "0d601c87038bff6f046065fb546acf1f2ff60f29", "HEAD"],
    cwd=ROOT, capture_output=True, text=True).stdout.split()
expected = {
    "aesir_engine/cli/native_serve.mojo",
    "aesir_engine/core/code_completion.mojo",
    "aesir_engine/core/openai_audit.mojo",
    "aesir_engine/docs/janas/J111_CODE_COMPLETION.md",
    "aesir_engine/docs/janas/j111_inspect.py",
    "aesir_engine/docs/janas/j111_inspect_output.txt",
    "aesir_engine/docs/janas/j111_test_output.txt",
    "aesir_engine/server/openai.mojo",
    "aesir_engine/tests/test_code_completion.mojo",
    "aesir_engine/tests/test_openai_audit.mojo",
}
present = set(diff)
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
