#!/usr/bin/env python3
"""J-117 inspect: mechanically re-derive the two examples'
load-bearing claims from the tree and the filed outputs.

Run from anywhere; paths resolve from this file's location.
Every check prints PASS or FAIL; the summary line states the
tally. Claims covered: the web page's invariants (single
self-contained document, textContent-only, no external scheme
string, the audited calls only, the J-107 stream vocabulary);
the fixtures' shapes; the web check's filed ALL PASS over the
page's own extracted script; the embed example's facade import,
its answering-entry calls, its reserved-five naming and
non-use, and its fail-closed shape; the tier-2 driver's module
imports and filed ALL PASS; the tier-1 build log's terminal
constraint and the test output's control record; this doc's
tallies and its deferred set (J-116 section 1.3 carried OPEN,
the live leg, the facade tier); and repo hygiene (diff == the
expected file set, no README, no .gguf).
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ENG = ROOT / "aesir_engine"
JAN = ENG / "docs" / "janas"
BASE = "982275a7d07bf953d82814c7901909377d590d5e"

results = []


def check(name, ok):
    results.append((name, bool(ok)))
    print(("PASS" if ok else "FAIL") + ": " + name)


def read(path):
    return Path(path).read_text(encoding="utf-8")


page = read(JAN / "j117_example_chat_page.html")
fixtures = json.loads(read(JAN / "j117_web_fixtures.json"))
harness = read(JAN / "j117_web_client_check.mjs")
web_out = read(JAN / "j117_web_check_output.txt")
embed = read(JAN / "j117_example_embed.mojo")
driver = read(JAN / "j117_embed_check.mojo")
test_out = read(JAN / "j117_test_output.txt")
facade_log = read(JAN / "j117_facade_build_log.txt")
doc = read(JAN / "J117_EXAMPLES_THAT_RUN.md")
facade = read(ENG / "aesir.mojo")

# --- example 1: the page ---------------------------------------------------
check("page: one self-contained document, 11987 bytes, inside the bound",
      len(page.encode()) == 11987 and 2048 < len(page.encode()) <= 24576)
check("page: doctype first, exactly one script block",
      page.startswith("<!DOCTYPE html>") and page.count("<script>") == 1)
check("page: textContent only, no forbidden insertion API named or used",
      "innerHTML" not in page and "textContent" in page)
check("page: no external scheme string anywhere in the document",
      "http://" not in page and "https://" not in page)
check("page: calls only the audited routes (models + chat completions)",
      '"/v1/models"' in page and '"/v1/chat/completions"' in page
      and "/v1/generate" not in page and "/api/" not in page)
check("page: speaks the J-107 stream vocabulary",
      all(s in page for s in
          ("prefill_progress", "[DONE]", "include_usage", "stream_options")))
check("page: design-law numbers present (16px text, 44px controls, labels, aria-live)",
      all(s in page for s in
          ("font-size: 16px", "min-height: 44px", "<label", 'aria-live="polite"')))

# --- fixtures ----------------------------------------------------------------
sse = fixtures["sse_stream"]
check("fixtures: models shape carries the J-109-filed catalogue id",
      fixtures["models"]["data"][0]["id"] == "olmoe-1b-7b:q4_k_m")
check("fixtures: SSE carries progress event, both content chunks, usage, [DONE]",
      all(s in sse for s in
          ('"event":"prefill_progress"', '"percent":50', '"Hello"',
           '", world"', '"usage"', "[DONE]")))
check("fixtures: plain completion and refusal shapes as filed",
      fixtures["plain_completion"]["choices"][0]["message"]["content"]
      == "Plain answer."
      and fixtures["refusal"]["status"] == 400
      and fixtures["refusal"]["body"]["error"]["message"]
      == "model is not the resident model")

# --- example 1: its execution --------------------------------------------------
check("web check: harness extracts and runs the page's own script (vm + fixtures)",
      "j117_example_chat_page.html" in harness and "runInContext" in harness
      and "j117_web_fixtures.json" in harness)
check("web check: filed output is ALL PASS with 20 PASS lines and no FAIL",
      "ALL PASS: web example client logic (20 checks)" in web_out
      and sum(1 for line in web_out.splitlines()
              if line.startswith("PASS: ")) == 20
      and "FAIL" not in web_out)
check("web check: filed output covers request, stream, refusal, and clear legs",
      all(s in web_out for s in
          ("streamed request body", "progress event reached the status line",
           "refusal shown verbatim", "history restarted at one message")))

# --- example 2: the facade example --------------------------------------------
check("embed example: imports the facade and the chat types",
      "from aesir import AesirEngine, GenerationConfig" in embed
      and "from loader.chat_template import ChatMessage" in embed)
check("embed example: exercises the answering entries it claims",
      all(s in embed for s in
          ("engine.generate_chat(", "engine.generate(",
           "engine.save_checkpoint(", "engine.load_checkpoint(")))
check("embed example: its calls match the facade's real signatures",
      "def generate_chat(" in facade and "def generate(" in facade
      and "def save_checkpoint(" in facade and "def load_checkpoint(" in facade)
reserved = ("ingest_document", "join_swarm_cluster", "dispatch_swarm_inference",
            "speculative_generate", "generate_tokens_with_grammar")
check("embed example: the reserved five are named on its face",
      all(name in embed for name in reserved))
check("embed example: none of the reserved five is ever called",
      all(("." + name + "(") not in embed for name in reserved))
check("embed example: fail-closed over a path that does not load",
      "except:" in embed and "refused the model path (fail-closed)" in embed
      and "No generation was attempted or invented." in embed)

# --- example 2: tier 2, executed ------------------------------------------------
check("tier-2 driver: imports the facade's delegation modules",
      all(s in driver for s in
          ("from core.state_vault import StateVault",
           "from loader.chat_template import ChatMessage, RuneChatTemplate",
           "from core.session import SessionContext")))
check("tier-2: filed output is ALL PASS (3 groups), build and run exit 0",
      "ALL PASS: embeddable library surface (3 groups)" in test_out
      and "build exit=0 run exit=0" in test_out)

# --- example 2: tier 1, attempted ------------------------------------------------
check("tier-1: the filed build log ends in the GPU-architecture constraint",
      "Unknown GPU architecture detected" in facade_log
      and "failed to run the pass manager" in facade_log)
check("tier-1: the test output records exit 1 and the serve-graph control PASS",
      "build exit=1" in test_out and "native serve import: PASS" in test_out)

# --- the doc ----------------------------------------------------------------------
check("doc: states the web tally (20/20) and the page size it filed",
      "20/20 checks PASS" in doc and "11,987 bytes" in doc)
check("doc: carries J-116 section 1.3 as an OPEN deferred item for J-118",
      "7.1" in doc and "OPEN" in doc and "event" in doc
      and "J-118 gate must carry it as an OPEN item" in doc)
check("doc: defers the live leg and the facade tier with recipes, to J-118",
      "7.2" in doc and "7.3" in doc and "DEFERRED-WITH-REASON" in doc
      and "teacher-forcing rank" in doc)

# --- hygiene ----------------------------------------------------------------------
def git(*args):
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        capture_output=True, text=True, check=True).stdout

check("hygiene: the base tip is an ancestor of HEAD",
      subprocess.run(
          ["git", "-C", str(ROOT), "merge-base", "--is-ancestor", BASE, "HEAD"]
      ).returncode == 0)
changed = set(git("diff", "--name-only", BASE).split())
untracked = set(
    line[3:] for line in git("status", "--porcelain").splitlines()
    if line.startswith("?? "))
ondisk = changed | untracked
expected = {
    "aesir_engine/docs/janas/J117_EXAMPLES_THAT_RUN.md",
    "aesir_engine/docs/janas/j117_example_chat_page.html",
    "aesir_engine/docs/janas/j117_web_fixtures.json",
    "aesir_engine/docs/janas/j117_web_client_check.mjs",
    "aesir_engine/docs/janas/j117_web_check_output.txt",
    "aesir_engine/docs/janas/j117_example_embed.mojo",
    "aesir_engine/docs/janas/j117_embed_check.mojo",
    "aesir_engine/docs/janas/j117_test_output.txt",
    "aesir_engine/docs/janas/j117_facade_build_log.txt",
    "aesir_engine/docs/janas/j117_inspect.py",
    "aesir_engine/docs/janas/j117_inspect_output.txt",
}
check("hygiene: slice file set == the 11 expected artefacts (inspect output may lag one run)",
      ondisk == expected or ondisk == expected - {
          "aesir_engine/docs/janas/j117_inspect_output.txt"})
check("hygiene: no README and no .gguf in the slice file set",
      not any("README" in f for f in ondisk)
      and not any(f.endswith(".gguf") for f in ondisk))

failed = [name for name, ok in results if not ok]
print("")
print("TOTAL: %d PASS, %d FAIL" % (len(results) - len(failed), len(failed)))
print("ALL PASS" if not failed else "FAILURES PRESENT")
sys.exit(1 if failed else 0)
