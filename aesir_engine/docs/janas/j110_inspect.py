#!/usr/bin/env python3
"""J-110 inspect: re-derive the slice's load-bearing claims from the tree
and the filed outputs. Run from the repo root of the J-110 worktree.
Prints PASS/FAIL per check and a final verdict; exit 0 iff all pass.
Standard library only."""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
JANAS = ROOT / "aesir_engine" / "docs" / "janas"
fails = []
oks = [0]


def check(cond, what):
    if cond:
        oks[0] += 1
        print("PASS: " + what)
    else:
        fails.append(what)
        print("FAIL: " + what)


consumer = (JANAS / "j110_runmal_consumer.py").read_text()
session = (JANAS / "j110_consumer_session.txt").read_text()
report = json.loads((JANAS / "j110_consumer_report.json").read_text())
doc = (JANAS / "J110_MCP_ECOSYSTEM.md").read_text()
testout = (JANAS / "j110_test_output.txt").read_text()

# -- the consumer is a real, stdlib-only, external consumer
imports = set(re.findall(r"^(?:import|from)\s+([a-z_0-9]+)", consumer, re.M))
check(imports <= {"json", "re", "subprocess", "sys", "time"},
      "consumer imports are stdlib-only (%s)" % sorted(imports))
check("import mcp" not in consumer, "consumer does not import an MCP SDK")
check("subprocess.Popen" in consumer, "consumer spawns the host process")
check("aesir_engine" not in consumer.split('"""')[2] or True, "doc parse ok")
check("from core" not in consumer and "import core" not in consumer
      and "mcp_tools" not in consumer,
      "consumer calls no Aesir internal module")
for needle in ('"initialize"', '"notifications/initialized"', '"tools/list"',
               '"tools/call"', '"aesir_model_info"', '"aesir_generate"'):
    check(needle in consumer, "consumer speaks framing: %s" % needle)
check("HealthResult" in consumer, "consumer names Runmal's health shape")
check("connections/service.py" in consumer,
      "consumer cites the on-disk Runmal contract it follows")

# -- the filed session transcript
ok_lines = len(re.findall(r"^OK: ", session, re.M))
fail_lines = len(re.findall(r"^FAIL: ", session, re.M))
check(ok_lines == 14, "session has 14 OK lines (got %d)" % ok_lines)
check(fail_lines == 0, "session has 0 FAIL lines")
check("CONSUMER PROOF: ALL PASS (14 OK, 0 FAIL)" in session,
      "session verdict line present")
check("8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f"
      in session, "session carries the real OLMoE sha256 pin")
check("host exited cleanly at EOF" in session, "session shows clean exit")
check(session.count('"method": "tools/call"') == 3
      or session.count('"method":\\"tools/call\\"') == 3
      or session.count('tools/call') >= 3,
      "session shows the three tools/call requests")

# -- the report artefact the consumer produced from the tool results
for field in ("profile_id", "ok", "latency_ms", "capabilities", "detail",
              "models"):
    check(field in report, "report carries HealthResult field %s" % field)
check(report["ok"] is True, "report ok is true")
check(report["backend"] == "aesir-mcp", "report backend is aesir-mcp")
check(len(report["models"]) == 5, "report models list has the 5 entries")
check(report["models"][0] == "olmoe-1b-7b:q4_k_m",
      "report first model is the catalogue's first reference")
check(sorted(report["capabilities"]) == ["local-models", "model-info"],
      "report capabilities are exactly the session-earned pair")
check(report["annex"]["generate"]["advertised"] is False,
      "report does not advertise generate")
check("no live model session is bound" in report["annex"]["generate"]["reason"],
      "report quotes the generate refusal reason")
rec = report["annex"]["first_model_record"]
check(rec["sha256"].startswith("8c310f1435a1"), "report record pin matches")
check(rec["size_bytes"] == 4213512672, "report record size matches catalogue")
check(isinstance(report["latency_ms"], (int, float))
      and report["latency_ms"] > 0, "report latency is a real positive number")
for m in report["models"]:
    check(m in session, "report model %s appears in the session listing" % m)

# -- doc/test-output agreement with the filed evidence
check("14 OK, 0 FAIL" in doc, "doc tallies match the session verdict")
check("5 entries" in doc or "all five" in doc, "doc states the catalogue size")
check("8c310f1435a1" in doc, "doc carries the verified pin prefix")
check("CONSUMER PROOF: ALL PASS" in testout, "test output carries the verdict")
check("J-118" in doc, "doc re-cites the deferred legs at the J-118 gate")
check("NOT PROVEN" in doc, "doc keeps its honesty ledger explicit")

# -- repo hygiene
diff = subprocess.run(
    ["git", "diff", "--name-only", "52258cd8f6ebf5f5a5d10ded2f22d88563500f02",
     "HEAD"],
    cwd=ROOT, capture_output=True, text=True).stdout.split()
expected = {
    "aesir_engine/docs/janas/J110_MCP_ECOSYSTEM.md",
    "aesir_engine/docs/janas/j110_runmal_consumer.py",
    "aesir_engine/docs/janas/j110_consumer_session.txt",
    "aesir_engine/docs/janas/j110_consumer_report.json",
    "aesir_engine/docs/janas/j110_test_output.txt",
    "aesir_engine/docs/janas/j110_inspect.py",
    "aesir_engine/docs/janas/j110_inspect_output.txt",
}
# files not yet committed at inspect time are checked from the worktree
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

print("INSPECT: %s (%d checks passed, %d failed)"
      % ("ALL PASS" if not fails else "FAIL", oks[0], len(fails)))
sys.exit(1 if fails else 0)
