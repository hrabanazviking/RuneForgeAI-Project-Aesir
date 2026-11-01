#!/usr/bin/env python3
"""J-083 inspection recount: every load-bearing claim in
docs/janas/J083_DRAFT_CONFIG_SURFACE.md as an assertion over
the tree and the filed records. Exit 0 iff all checks pass."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = []


def check(name, ok):
    checks.append((name, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'}: {name}")


def read(rel):
    return (ROOT / rel).read_text()


module = read("aesir_engine/core/draft_config.mojo")
suite = read("aesir_engine/tests/test_draft_config.mojo")
learned = read("aesir_engine/core/learned_file.mojo")
doc = read("docs/janas/J083_DRAFT_CONFIG_SURFACE.md")
evidence = read("docs/janas/j083_test_output.txt")
options = read("aesir_engine/core/placement_options.mojo")
facade = read("aesir_engine/aesir.mojo")

check("new module exists and names J-083", "J-083" in module)
check("verdict/refusal rules are in the module header before the code",
      module.index("THE VERDICT / REFUSAL RULES") < module.index("def draft_source_name"))
check("contradictory-sources refusal exists by name",
      "REFUSE_CONTRADICTORY_SOURCES" in module)
check("contradictory-mtp refusal exists by name",
      "REFUSE_CONTRADICTORY_MTP" in module)
check("--no-mtp + --draft stated NOT a contradiction in the header",
      "--no-mtp with --draft is NOT a contradiction" in module)
check("k cap is read through J-071 plan_proposer, never restated",
      "plan_proposer" in module and "def draft_k_cap" in module
      and "max_k" in module)
check("k default binds J-072 LOOP_K_INITIAL by import, not restated",
      "from core.speculative_loop import LOOP_K_INITIAL" in module
      and "LOOP_K_INITIAL = " not in module)
check("pair gate binds J-074 evaluate_pair by import and call",
      "evaluate_pair" in module and "validate_draft_model_pair" in module)
check("mtp gate binds J-077 evaluate_mtp_admission by import and call",
      "evaluate_mtp_admission" in module and "validate_mtp_source" in module)
check("use gate fails closed for every configuration (blockers named)",
      "def require_draft_config_use" in module
      and "G-PROPOSER" in module and "G-EXECUTOR" in module
      and "REFUSE_NO_SOURCE" in module)
check("chat and server entries are wrappers over the ONE resolver",
      "def resolve_chat_draft_config" in module
      and "def resolve_server_draft_config" in module
      and module.count("resolve_draft_config(scan_draft_args(args), draft_env_inputs())") == 2)
check("module wires no session (no cli import; header states it)",
      "from cli" not in module and "no live chat or server path" in module)

check("learned file carries the V2 header beside V1",
      'LEARNED_HEADER_V2 = "AESIR_LEARNED_PLACEMENT_V2"' in learned
      and 'LEARNED_HEADER = "AESIR_LEARNED_PLACEMENT_V1"' in learned)
check("V2 serialisation writes the five fixed-order draftcfg lines",
      all(s in learned for s in (
          "draftcfg_present=", "draftcfg_source=", "draftcfg_mtp=",
          "draftcfg_model_hex=", "draftcfg_k=")))
check("parser accepts both versions (is_v2 branch present)",
      "is_v2" in learned and "LEARNED_HEADER_V2" in learned)

check("use gate still fails closed (J-036, unedited by this slice)",
      "raise Error(" in options and "draft-check passes do not exist" in options)
check("facade speculative_generate still raises not-implemented",
      "speculative model generation and KV reconciliation are not implemented"
      in facade)

check("suite has 17 groups", suite.count("def test_") == 17)
check("suite drives both surface wrappers (parity by construction)",
      "resolve_chat_draft_config" in suite
      and "resolve_server_draft_config" in suite)
check("doc numbers match the filed test output numbers",
      all(s in evidence for s in (
          "ALL PASS: draft configuration surface (17 groups)",
          "ALL PASS: learned file (13 groups)",
          "ALL PASS: speculative verification account (13 groups)",
          "ALL PASS: speculative draft loop (12 groups)",
          "ALL PASS: draft-check placement auto choice (12 groups)",
          "ALL PASS: speculative placement (13 groups)"))
      and all(s in doc for s in ("17/17", "13/13", "12/12")))

failed = [n for n, ok in checks if not ok]
print(f"== {len(checks) - len(failed)}/{len(checks)} checks PASS ==")
sys.exit(1 if failed else 0)
