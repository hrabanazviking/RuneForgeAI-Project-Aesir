#!/usr/bin/env python3
"""J-114 inspect: re-derive the slice's load-bearing claims from the
tree and the filed outputs. Run from the repo root of the J-114
worktree. Prints PASS/FAIL per check and a final verdict; exit 0 iff
all pass. Standard library only."""

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


sampler = (ENG / "core" / "sampler.mojo").read_text()
cg = (ENG / "core" / "constrained_generation.mojo").read_text()
vr = (ENG / "core" / "vocab_restriction.mojo").read_text()
chat = (ENG / "cli" / "cuda_chat.mojo").read_text()
manners = (ENG / "core" / "chat_manners.mojo").read_text()
manners_test = (ENG / "tests" / "test_chat_manners.mojo").read_text()
history = (ENG / "cli" / "chat_history.mojo").read_text()
openai = (ENG / "server" / "openai.mojo").read_text()
serve = (ENG / "cli" / "native_serve.mojo").read_text()
audit = (ENG / "core" / "openai_audit.mojo").read_text()
doc = (JANAS / "J114_CONSTRAINED_GENERATION.md").read_text()
testout = (JANAS / "j114_test_output.txt").read_text()
costout = (JANAS / "j114_cost_output.txt").read_text()
costdrv = (JANAS / "j114_cost.mojo").read_text()
suite = (ENG / "tests" / "test_constrained_generation.mojo").read_text()

# -- the sampler enforcement, in the tree
check("def apply_vocab_restriction" in sampler,
      "sampler carries the vocab restriction mask")
check("def sample_token_from_logits_restricted" in sampler,
      "sampler carries the restricted sampling entry")
check("def sample_token_from_logits(" in sampler,
      "the unrestricted sampler entry is still present")
check("from .vocab_restriction import VocabRestrictor" in sampler,
      "sampler's restriction decision is J-113's restrictor (imported)")
check("return -1" in sampler and "never a disallowed token" in sampler,
      "the restricted entry's -1 refusal is stated in the sampler")
check(sampler.count("is_token_valid") >= 3,
      "the sampler decides through is_token_valid (%d sites)"
      % sampler.count("is_token_valid"))

# -- the candidate layer delegates; no second decision implementation
check("from core.vocab_restriction import" in cg
      and "VocabRestrictor" in cg,
      "cg layer imports J-113's restrictor")
check("return apply_vocab_restriction(" in cg,
      "cg_apply_vocab_mask delegates to the sampler mask")
check("entry.startswith" not in cg and "_vr_is_prefix" not in cg,
      "cg layer contains no second prefix/membership implementation")
check("def cg_masked_indices" in cg and "def cg_greedy_choice" in cg
      and "def cg_scan_account" in cg,
      "cg layer carries the masked-indices / greedy / scan-account forms")
check("def cg_constrain_response" in cg
      and "def cg_serve_vocab_response" in cg,
      "cg layer carries both door answers")
check("NOT PROVEN" in cg,
      "the chat door's binding honesty is on the layer's face")

# -- the chat door
check(chat.count("elif cg_is_constrain_command(command):") == 2,
      "both chat_control bodies carry the /constrain branch exactly once")
check("from core.constrained_generation import" in chat,
      "cuda_chat imports the cg layer")
check('String("/constrain")' in manners,
      "manners candidate set carries /constrain")
check('len(chat_command_names()), 18' in manners_test,
      "manners test pins the grown candidate count (18)")
check("/constrain audit WORDS :: TEXT" in history
      and "/constrain [FORM]" in history,
      "chat help carries the constrain forms (wide + narrow)")

# -- the server door
check("var vocab_restriction: String" in openai
      and "var has_vocab_restriction: Bool" in openai,
      "OpenAIRequest carries the extension field + flag")
check('name == "vocab_restriction"' in openai,
      "the parser parses the field by name")
check("self.has_vocab_restriction" in openai
      and "not composed with vocab_restriction" in openai,
      "the parser refuses the tool and Boolean-format combinations")
check("from core.constrained_generation import cg_serve_vocab_response"
      in serve, "the serve imports the cg validation/refusal text")
check(serve.count("request.has_vocab_restriction") == 1,
      "the serve's OpenAI branch answers the field exactly once")
check("vocab_restriction" not in audit,
      "the audit's canonical tables are unchanged (extension not filed "
      "as a public-shape field)")

# -- the suite's structure and the filed tallies
for group in ("test_mask_agreement", "test_greedy_sampler",
              "test_sampled_sampler", "test_enforcement_loop",
              "test_scan_account", "test_chat_surface",
              "test_server_surface"):
    check("def %s" % group in suite, "suite carries group %s" % group)
for verdict in ("ALL PASS: constrained generation (7 groups)",
                "ALL PASS: vocab restriction (6 groups)",
                "ALL PASS: code completion (6 groups)",
                "ALL PASS: chat manners (7 groups)",
                "ALL PASS: openai audit (7 groups)",
                "ALL PASS: speculative sampling correctness (17 groups)",
                "Boolean JSON token trie: PASS",
                "cuda chat module compile + import: PASS",
                "native serve module compile + import: PASS"):
    check(verdict in testout, "filed test output carries: %s" % verdict)
check("the cat sat on the mat" in testout,
      "filed test output records the loop's produced text")
check("test_inference" in testout and "pristine" in testout,
      "the unbuilt neighbour is named with its verified reason")
check("3a7e5a62e4381d9741b16e7b3bd16c4a49550164" in testout,
      "filed test output cites the verified protocol commit")
check("3a7e5a62e4381d9741b16e7b3bd16c4a49550164" in doc,
      "doc cites the verified protocol commit")

# -- the cost evidence
check(costout.count("COST DRIVER DONE") == 2,
      "cost output files both driver runs")
for needle in ("size=256", "size=1024", "size=4096",
               "admitted_per_scan=160", "admitted_per_scan=640",
               "admitted_per_scan=2560", "MEASURED-INDICATIVE"):
    check(needle in costout, "cost output carries: %s" % needle)
check("def monotonic_ns" in costdrv
      and "cg_apply_vocab_mask" in costdrv,
      "the cost driver times the real mask through a monotonic clock")
check("tok/s is claimed anywhere" in doc or "never tok/s" in costout
      or "never a generation speed" in costout,
      "the cost filing claims no tok/s")

# -- the doc's post-protocol shape
for marker in ("## 1. Headline", "## 5. Deferred legs",
               "## 9. NOT PROVEN list", "## 10. Banking"):
    check(marker in doc, "doc carries post-protocol section: %s" % marker)
check("DEFERRED-WITH-REASON" in doc and "J-118" in doc,
      "doc defers the live legs to the J-118 gate with reasons")
check("sample_token_from_logits_restricted" in doc,
      "doc names the enforcement entry it files")

# -- repo hygiene (diff == the expected file set, all of git status)
diff = subprocess.run(
    ["git", "diff", "--name-only",
     "5ddf19460eec88f86abd0e3f53b1f756bd5c8985", "HEAD"],
    cwd=ROOT, capture_output=True, text=True).stdout.split()
status = subprocess.run(
    ["git", "status", "--porcelain"],
    cwd=ROOT, capture_output=True, text=True).stdout.splitlines()
expected = {
    "aesir_engine/cli/chat_history.mojo",
    "aesir_engine/cli/cuda_chat.mojo",
    "aesir_engine/cli/native_serve.mojo",
    "aesir_engine/core/chat_manners.mojo",
    "aesir_engine/core/constrained_generation.mojo",
    "aesir_engine/core/sampler.mojo",
    "aesir_engine/docs/janas/J114_CONSTRAINED_GENERATION.md",
    "aesir_engine/docs/janas/j114_cost.mojo",
    "aesir_engine/docs/janas/j114_cost_output.txt",
    "aesir_engine/docs/janas/j114_inspect.py",
    "aesir_engine/docs/janas/j114_inspect_output.txt",
    "aesir_engine/docs/janas/j114_test_output.txt",
    "aesir_engine/server/openai.mojo",
    "aesir_engine/tests/test_chat_manners.mojo",
    "aesir_engine/tests/test_constrained_generation.mojo",
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
