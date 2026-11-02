#!/usr/bin/env python3
"""J-113 inspect: re-derive the slice's load-bearing claims from the
tree and the filed outputs. Run from the repo root of the J-113
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


module = (ENG / "core" / "vocab_restriction.mojo").read_text()
test = (ENG / "tests" / "test_vocab_restriction.mojo").read_text()
grammar = (ENG / "core" / "grammar.mojo").read_text()
facade = (ENG / "aesir.mojo").read_text()
doc = (JANAS / "J113_NSM_QUESTION.md").read_text()
testout = (JANAS / "j113_test_output.txt").read_text()

# -- the section 0.1 inventory facts, re-derived from the tree
mojo_files = list(ENG.rglob("*.mojo"))
nsm_holders = sorted(
    str(p.relative_to(ENG)) for p in mojo_files
    if "nsm" in p.read_text().lower())
check(len(mojo_files) > 100, "scan ran over the engine tree (%d files)"
      % len(mojo_files))
check(nsm_holders == ["core/vocab_restriction.mojo",
                     "tests/test_vocab_restriction.mojo"],
      "NSM appears only in the J-113 layer and its test (got %s)"
      % (nsm_holders,))
vr_holders = sorted(
    str(p.relative_to(ENG)) for p in mojo_files
    if "PermittedVocab" in p.read_text())
check(vr_holders == ["core/vocab_restriction.mojo",
                     "tests/test_vocab_restriction.mojo"],
      "permitted-vocabulary handling exists only in the new layer "
      "and its test (got %s)" % (vr_holders,))
check("grammar-constrained model generation is not implemented" in facade,
      "the facade's grammar entry still raises not-implemented "
      "(no sampler enforcement was smuggled in; J-114 owns it)")
check("def generate_tokens_with_grammar" in facade,
      "the facade grammar entry exists at its cited place")
check("def is_token_valid" in grammar and "def advance_state" in grammar,
      "the grammar grain (token-text validity + advance) exists")
check("class GBNFGrammar" in grammar or "struct GBNFGrammar" in grammar,
      "the bounded GBNF grammar layer exists")

# -- the layer's pure form and its API
import_lines = [ln for ln in module.splitlines()
                if ln.startswith("from ") or ln.startswith("import ")]
check(import_lines == [],
      "the layer imports nothing from the engine (pure)")
for fn in ("def vr_parse_word_list", "def vr_contains",
           "def vr_word_count", "def vr_render_word_list",
           "def vr_audit_text", "def vr_nsm_disposition"):
    check(fn in module, "layer carries %s" % fn)
for fn in ("def is_token_valid", "def advance_state",
           "def is_accepting", "def allowed_indices",
           "def first_allowed"):
    check(fn in module, "restrictor carries %s" % fn)
check("struct PermittedVocab" in module
      and "struct VocabRestrictor" in module
      and "struct VocabAudit" in module,
      "the layer's three structs are present")
check("comptime VR_MAX_ENTRIES = 8192" in module,
      "the entry bound is 8192 on the layer's face")
check("comptime VR_MAX_WORD_BYTES = 64" in module,
      "the word byte bound is 64 on the layer's face")
check("startswith(partial)" in module or "entry.startswith" in module,
      "the trailing-partial rule is the permitted-prefix rule")

# -- the verdict, in layer and doc alike
for needle in ("REFUSED", "CC BY-NC-SA", "single-paper",
               "no Aesir consumer", "Re-open only if", "J-114"):
    check(needle in module, "layer disposition carries: %s" % needle)
check("## 0.2 The NSM verdict: REFUSED" in doc,
      "doc section 0.2 files the REFUSED verdict")
check("row 69" in doc and "row 70" in doc,
      "doc cites concordance rows 69 (dressing) and 70 (core)")
check("DEFERRED" in doc and "J-118" in doc,
      "doc defers the live leg to the J-118 gate with reason")
check("NOT PROVEN" in doc, "doc keeps its honesty ledger explicit")

# -- the suites' structure and the filed tallies
for group in ("test_parse_render", "test_membership_bounds",
              "test_restrictor", "test_selection",
              "test_simulated_loop", "test_audit_disposition"):
    check("def %s" % group in test,
          "suite carries group %s" % group)
for verdict in ("ALL PASS: vocab restriction (6 groups)",
                "ALL PASS: code completion (6 groups)",
                "Boolean JSON token trie: PASS"):
    check(verdict in testout, "filed test output carries: %s" % verdict)
check("the cat sat on the mat" in testout,
      "filed test output records the demonstrated text")
check("SIMULATED" in testout,
      "filed test output names the loop SIMULATED")
check("f7defd6d91ea6e0c388ca407e5a04f79cc16d04b" in testout,
      "filed test output cites the verified protocol commit")
check("f7defd6d91ea6e0c388ca407e5a04f79cc16d04b" in doc,
      "doc cites the verified protocol commit")
for marker in ("## 1. Headline", "## 5. Deferred legs", "## 10. Banking"):
    check(marker in doc, "doc carries post-protocol section: %s" % marker)

# -- repo hygiene (diff == the expected file set, all of git status)
diff = subprocess.run(
    ["git", "diff", "--name-only",
     "0a52d91506dbf86643fe838f9ebff9bc720087e4", "HEAD"],
    cwd=ROOT, capture_output=True, text=True).stdout.split()
status = subprocess.run(
    ["git", "status", "--porcelain"],
    cwd=ROOT, capture_output=True, text=True).stdout.splitlines()
expected = {
    "aesir_engine/core/vocab_restriction.mojo",
    "aesir_engine/docs/janas/J113_NSM_QUESTION.md",
    "aesir_engine/docs/janas/j113_inspect.py",
    "aesir_engine/docs/janas/j113_inspect_output.txt",
    "aesir_engine/docs/janas/j113_test_output.txt",
    "aesir_engine/tests/test_vocab_restriction.mojo",
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
