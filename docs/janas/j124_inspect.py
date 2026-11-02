#!/usr/bin/env python3
"""J-124 inspect: mechanically re-derive every load-bearing claim in
docs/janas/J124_QWEN36_VERIFICATION.md from the tree at the branch
tip plus the filed outputs. Read-only. Exit 0 iff all pass."""
import hashlib, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CAMPAIGN = os.path.expanduser("~/workspace/model-tests/janas")
DOC = os.path.join(HERE, "J124_QWEN36_VERIFICATION.md")
OUT = os.path.join(HERE, "j124_test_output.txt")
ENG = os.path.join(REPO, "aesir_engine")

fails = []
count = [0]
def check(name, ok, detail=""):
    count[0] += 1
    print(("PASS " if ok else "FAIL ") + name + ((" -- " + detail) if detail else ""))
    if not ok:
        fails.append(name)

def read(p):
    return open(p, encoding="utf-8", errors="replace").read()

def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()

for f in ["j124_census.py", "j124_fixtures.py", "j124_reread.mojo",
          "j124_refuse.mojo", "j124_reverify.py", "j124_reverify_output.txt",
          "j124_test_output.txt"]:
    check("artefact present docs/janas/" + f, os.path.exists(os.path.join(HERE, f)))
for f in ["core/qwen35moe_layout.mojo", "tests/test_qwen35moe_layout.mojo"]:
    check("artefact present aesir_engine/" + f, os.path.exists(os.path.join(ENG, f)))

gguf = read(os.path.join(ENG, "loader", "gguf.mojo"))
for tok in ["_validate_qwen35moe_tensors", '"qwen35moe"',
            "qwen35moe_common_suffixes", "qwen35moe_is_attention_layer",
            "qwen35moe_ssm_suffixes",
            "GGUF qwen35moe shared expert metadata is incomplete",
            "GGUF qwen35moe SSM metadata is incomplete",
            "GGUF qwen35moe expert routing metadata is incomplete"]:
    check("loader gguf.mojo states " + tok, tok in gguf)

layout = read(os.path.join(ENG, "core", "qwen35moe_layout.mojo"))
for tok in ["qwen35moe_is_attention_layer", "qwen35moe_common_suffixes",
            "qwen35moe_ssm_suffixes", "qwen35moe_attention_suffixes",
            "qwen35moe_total_tensor_count", "693"]:
    check("qwen35moe_layout.mojo states " + tok, tok in layout)

moe = read(os.path.join(ENG, "core", "moe_session.mojo"))
check("moe_session still admits only olmoe (session gate shut)",
      'arch != "olmoe"' in moe and "qwen35moe" not in moe)
inf = read(os.path.join(ENG, "core", "inference.mojo"))
check("inference gate shut for qwen35moe (dense qwen35 forward only)",
      "qwen35moe" not in inf and 'architecture == "qwen35"' in inf)

rev = read(os.path.join(HERE, "j124_reverify_output.txt"))
check("reverify filed output 32 checks FAIL 0 ALL PASS",
      "TOTAL 32 checks, FAIL 0" in rev and "ALL PASS" in rev)

out = read(OUT)
for tok in ["test_qwen35moe_layout: ALL PASS (6 groups)",
            "directory arithmetic 693 (30x18 + 10x15 + 3), fixture 72",
            "SUMMARY arch qwen35moe tensors 72",
            "SUMMARY arch qwen35moe tensors 76",
            "SUMMARY arch qwen35moe tensors 39",
            "SUMMARY arch qwen35moe tensors 73",
            "SUMMARY qwen35moe blocks 4 attention 1 ssm 3",
            "SUMMARY mtp nextn 4 mtp 0 assistant 0 verdict WITH_MTP",
            "SUMMARY mtp nextn 0 mtp 0 assistant 0 verdict NO_MTP",
            "GGUF validated: 72 tensors, 29 metadata entries, architecture qwen35moe",
            "GGUF validated: 76 tensors, 29 metadata entries, architecture qwen35moe",
            "REFUSAL: GGUF is missing required tensor: blk.1.ssm_out.weight",
            "REFUSAL: GGUF is missing required tensor: blk.2.ffn_gate_shexp.weight",
            "REFUSAL: GGUF is missing required tensor: blk.0.post_attention_norm.weight",
            "REFUSAL: GGUF required tensor has an invalid shape: blk.3.attn_q.weight actual: 16x16 expected: 32x16",
            "GGUFSeer malformed-model rejection & FAILED state transition: PASS",
            "ALL PASS: mtp census classifier (8 groups)",
            "test_qwen3next_layout: ALL PASS (6 groups)",
            "TOTAL 32 checks, FAIL 2"]:
    check("test output states " + tok[:58], tok in out)
check("test output re-read drivers ALL PASS x2",
      out.count("REREAD DRIVER: ALL PASS") == 2, str(out.count("REREAD DRIVER: ALL PASS")))
check("test output refusal drivers ALL PASS x4",
      out.count("REFUSAL DRIVER: ALL PASS") == 4, str(out.count("REFUSAL DRIVER: ALL PASS")))

doc = read(DOC)
for tok in ["DEFERRED-WITH-REASON", "NOT PROVEN", "J-133", "J-134", "J-136",
            "repl.mojo", "G-119-1", "215efa37", "693",
            "blk.0.post_attention_norm.weight", "blk.3.attn_q.weight",
            "moe_session", "ABSENT-FILE"]:
    check("doc states " + tok, tok in doc)
check("doc sections 1+ filed", "## 1." in doc and "## 10." in doc)

pairs = [
    ("J124_QWEN36_VERIFICATION.md", "J124_QWEN36_VERIFICATION.md"),
    ("j124_census.py", "j124_census.py"),
    ("j124_fixtures.py", "j124_fixtures.py"),
    ("j124_reread.mojo", "j124_reread.mojo"),
    ("j124_refuse.mojo", "j124_refuse.mojo"),
    ("j124_reverify.py", "j124_reverify.py"),
    ("j124_reverify_output.txt", "j124_reverify_output.txt"),
    ("j124_test_output.txt", "j124_test_output.txt"),
    ("j124_inspect.py", "j124_inspect.py"),
]
for repo_f, camp_f in pairs:
    rp, cp = os.path.join(HERE, repo_f), os.path.join(CAMPAIGN, camp_f)
    check("campaign copy sha-identical: " + camp_f,
          os.path.exists(cp) and sha(rp) == sha(cp))
for eng_f, camp_f in [("core/qwen35moe_layout.mojo", "qwen35moe_layout.mojo"),
                      ("tests/test_qwen35moe_layout.mojo", "test_qwen35moe_layout.mojo")]:
    rp, cp = os.path.join(ENG, eng_f), os.path.join(CAMPAIGN, camp_f)
    check("campaign copy sha-identical: " + camp_f,
          os.path.exists(cp) and sha(rp) == sha(cp))

st = subprocess.run(["git", "-C", REPO, "status", "--porcelain"],
                    capture_output=True, text=True).stdout
check("no README.md touched in worktree", "README" not in st, st.strip()[:60])

print("TOTAL %d PASS %d FAIL %d" % (count[0], count[0] - len(fails), len(fails)))
sys.exit(1 if fails else 0)
