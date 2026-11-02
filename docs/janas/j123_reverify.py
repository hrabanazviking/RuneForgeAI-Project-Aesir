#!/usr/bin/env python3
"""J-123 stage (a) re-verification: J-032's ground, re-derived first-hand.

Re-reads the J-032 doc, the J-022 attempt artefact, and THIS tree's
loader/session code; re-checks the pin, the refusal, the header facts,
and the pre-build state of blockers B2a/B2b. Run BEFORE the J-123
build: its B2 checks assert the admission does NOT yet exist.
Pure stdlib. Exit 0 iff all checks PASS.
"""
import pathlib, re, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]  # repo root (docs/janas -> docs -> root)
JANAS = ROOT / "docs" / "janas"
fails = []
total = [0]
def check(name, cond):
    total[0] += 1
    print(("PASS " if cond else "FAIL ") + name)
    if not cond: fails.append(name)

j032 = (JANAS / "J032_80B_CLASS_TARGET.md").read_text()
j022att = (JANAS / "j022_qwen3next_attempt.txt").read_text()
gguf = (ROOT / "aesir_engine" / "loader" / "gguf.mojo").read_text()
moe = (ROOT / "aesir_engine" / "core" / "moe_session.mojo").read_text()

PIN = "f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd"
check("pin sha256 filed verbatim in J-032 doc", PIN in j032)
check("pin size 48,506,100,512 filed in J-032 doc", "48,506,100,512" in j032)
check("source repo unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF filed", "unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF" in j032)
check("refusal text verbatim in J-022 attempt artefact", "GGUF is missing required tensor: blk.0.attn_q.weight" in j022att)
check("attempt EXIT=1 in artefact", "EXIT=1" in j022att)
for fact in ["qwen3next", "48 blocks", "512 experts", "843 tensors"]:
    check(f"header fact '{fact}' in J-032 doc", fact in j032)
for fact in ["ssm.conv_kernel", "ssm.state_size", "ssm.group_count", "ssm.time_step_rank", "ssm.inner_size"]:
    check(f"SSM key {fact} in J-032 doc", fact in j032)
check("B2a named in J-032 doc", "B2a" in j032)
check("B2b named in J-032 doc", "B2b" in j032)
check("J-032 verdict NOT PROVEN", "NOT PROVEN" in j032)
# Pre-build tree state (this script runs before the J-123 build):
check("pre-build: no qwen3next branch in loader gguf.mojo", "qwen3next" not in gguf)
check("pre-build: moe_session admits only olmoe", 'arch != "olmoe"' in moe)
check("pre-build: qwen3next absent from moe_session", "qwen3next" not in moe)
check("loader has qwen35 hybrid precedent branch", "_validate_qwen35_tensors" in gguf)
check("loader has olmoe MoE precedent branch", "_validate_olmoe_tensors" in gguf)
check("loader parses .expert_count suffix", '".expert_count"' in gguf)
check("loader parses .ssm.inner_size suffix", '".ssm.inner_size"' in gguf)
check("loader does NOT yet parse expert_shared_feed_forward_length", "expert_shared_feed_forward_length" not in gguf)
# census arithmetic witness: 36*18 + 12*16 + 3 == 843
check("census arithmetic 36*18+12*16+3 == 843", 36*18 + 12*16 + 3 == 843)
print(f"TOTAL {total[0]} checks, FAIL {len(fails)}")
print("ALL PASS" if not fails else "FAILURES: " + ", ".join(fails))
sys.exit(0 if not fails else 1)
