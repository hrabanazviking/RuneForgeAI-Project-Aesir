#!/usr/bin/env python3
"""J-123 inspect: mechanically re-derive every load-bearing claim in
docs/janas/J123_QWEN3NEXT_VERIFICATION.md from the tree at the branch
tip plus the filed outputs. Read-only. Exit 0 iff all pass."""
import hashlib, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CAMPAIGN = os.path.expanduser("~/workspace/model-tests/janas")
DOC = os.path.join(HERE, "J123_QWEN3NEXT_VERIFICATION.md")
OUT = os.path.join(HERE, "j123_test_output.txt")
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

for f in ["j123_census.py", "j123_fixtures.py", "j123_reread.mojo",
          "j123_refuse.mojo", "j123_reverify.py", "j123_reverify_output.txt",
          "j123_test_output.txt"]:
    check("artefact present docs/janas/" + f, os.path.exists(os.path.join(HERE, f)))
for f in ["core/qwen3next_layout.mojo", "tests/test_qwen3next_layout.mojo"]:
    check("artefact present aesir_engine/" + f, os.path.exists(os.path.join(ENG, f)))

gguf = read(os.path.join(ENG, "loader", "gguf.mojo"))
for tok in ["_validate_qwen3next_tensors", '"qwen3next"',
            "expert_shared_feed_forward_length", "qwen3next_common_suffixes",
            "qwen3next_is_attention_layer", "qwen3next_ssm_suffixes",
            "GGUF qwen3next shared expert metadata is incomplete",
            "GGUF qwen3next SSM metadata is incomplete"]:
    check("loader gguf.mojo states " + tok, tok in gguf)
check("shared-width key parsed before plain feed_forward_length rule",
      gguf.index('".expert_shared_feed_forward_length") and scalar_type') <
      gguf.index('".feed_forward_length") and scalar_type'))

packed = read(os.path.join(ENG, "loader", "packed_gguf.mojo"))
for tok in ["dims == 3", "rows = rows * experts",
            "Packed GGUF: invalid expert tensor extent"]:
    check("packed_gguf.mojo states " + tok, tok in packed)

layout = read(os.path.join(ENG, "core", "qwen3next_layout.mojo"))
for tok in ["qwen3next_is_attention_layer", "qwen3next_common_suffixes",
            "qwen3next_ssm_suffixes", "qwen3next_attention_suffixes",
            "qwen3next_total_tensor_count", "843"]:
    check("qwen3next_layout.mojo states " + tok, tok in layout)

moe = read(os.path.join(ENG, "core", "moe_session.mojo"))
check("moe_session still admits only olmoe (session gate shut)",
      'arch != "olmoe"' in moe and "qwen3next" not in moe)

rev = read(os.path.join(HERE, "j123_reverify_output.txt"))
check("reverify filed output 26 checks FAIL 0 ALL PASS",
      "TOTAL 26 checks, FAIL 0" in rev and "ALL PASS" in rev)
check("reverify filed pin verbatim",
      "f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd" in
      read(os.path.join(HERE, "j123_reverify.py")))

out = read(OUT)
for tok in ["test_qwen3next_layout: ALL PASS (6 groups)",
            "census witness 843 (36x18 + 12x16 + 3), fixture 73/72",
            "SUMMARY arch qwen3next tensors 73",
            "SUMMARY arch qwen3next tensors 72",
            "SUMMARY arch qwen3next tensors 39",
            "SUMMARY qwen3next blocks 4 attention 1 ssm 3",
            "GGUF validated: 73 tensors, 29 metadata entries, architecture qwen3next",
            "GGUF validated: 72 tensors, 29 metadata entries, architecture qwen3next",
            "REFUSAL: GGUF is missing required tensor: blk.1.ssm_out.weight",
            "REFUSAL: GGUF is missing required tensor: blk.2.ffn_gate_shexp.weight",
            "REFUSAL: GGUF is missing required tensor: blk.0.post_attention_norm.weight",
            "GGUFSeer malformed-model rejection & FAILED state transition: PASS",
            "ALL PASS: mtp census classifier (8 groups)",
            "730dadae10b033c22b2e2345d2a478d717043a5c3f225e5977ba1b433ec77005",
            "7f8f0070aae658a4aca5f4209b9d7e70eea0a539ede251a8251328252f29008b",
            "TOTAL 26 checks, FAIL 2"]:
    check("test output states " + tok[:58], tok in out)
check("test output re-read drivers ALL PASS x3",
      out.count("REREAD DRIVER: ALL PASS") >= 3, str(out.count("REREAD DRIVER: ALL PASS")))
check("test output refusal drivers ALL PASS x3",
      out.count("REFUSAL DRIVER: ALL PASS") == 3, str(out.count("REFUSAL DRIVER: ALL PASS")))

doc = read(DOC)
for tok in ["DEFERRED-WITH-REASON", "NOT PROVEN", "J-133", "J-136",
            "repl.mojo", "G-119-1", "7172a693", "MEASURED-INDICATIVE",
            "blk.0.post_attention_norm.weight", "PackedGGUF",
            "moe_session", "f73551b5"]:
    check("doc states " + tok, tok in doc)
check("doc sections 1+ filed", "## 1." in doc and "## 10." in doc)

pairs = [
    ("J123_QWEN3NEXT_VERIFICATION.md", "J123_QWEN3NEXT_VERIFICATION.md"),
    ("j123_census.py", "j123_census.py"),
    ("j123_fixtures.py", "j123_fixtures.py"),
    ("j123_reread.mojo", "j123_reread.mojo"),
    ("j123_refuse.mojo", "j123_refuse.mojo"),
    ("j123_reverify.py", "j123_reverify.py"),
    ("j123_reverify_output.txt", "j123_reverify_output.txt"),
    ("j123_test_output.txt", "j123_test_output.txt"),
    ("j123_inspect.py", "j123_inspect.py"),
]
for repo_f, camp_f in pairs:
    rp, cp = os.path.join(HERE, repo_f), os.path.join(CAMPAIGN, camp_f)
    check("campaign copy sha-identical: " + camp_f,
          os.path.exists(cp) and sha(rp) == sha(cp))
for eng_f, camp_f in [("core/qwen3next_layout.mojo", "qwen3next_layout.mojo"),
                      ("tests/test_qwen3next_layout.mojo", "test_qwen3next_layout.mojo")]:
    rp, cp = os.path.join(ENG, eng_f), os.path.join(CAMPAIGN, camp_f)
    check("campaign copy sha-identical: " + camp_f,
          os.path.exists(cp) and sha(rp) == sha(cp))

st = subprocess.run(["git", "-C", REPO, "status", "--porcelain"],
                    capture_output=True, text=True).stdout
check("no README.md touched in worktree", "README" not in st, st.strip()[:60])

print("TOTAL %d PASS %d FAIL %d" % (count[0], count[0] - len(fails), len(fails)))
sys.exit(1 if fails else 0)
