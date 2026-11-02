#!/usr/bin/env python3
"""J-120 inspect: mechanically re-derive every load-bearing claim in
docs/janas/J120_LORA_MERGE_CONVERSION.md from the tree at the branch
tip plus the filed test output. Read-only. Exit 0 iff all pass."""
import hashlib, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CAMPAIGN = os.path.expanduser("~/workspace/model-tests/janas")
DOC = os.path.join(HERE, "J120_LORA_MERGE_CONVERSION.md")
OUT = os.path.join(HERE, "j120_test_output.txt")
CORE = os.path.join(REPO, "aesir_engine", "core", "lora_convert.mojo")
TEST = os.path.join(REPO, "aesir_engine", "tests", "test_lora_convert.mojo")

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

core = read(CORE)
for sym in ["lc_parse_safetensors", "lc_build_safetensors", "lc_parse_adapter_config",
            "lc_merge_model", "lc_gguf_name_for_hf", "lc_convert_base",
            "lc_read_gguf", "lc_convert_from_gguf", "lc_refuse_quantize",
            "lc_c05_scope_text"]:
    check("core defines " + sym, ("def " + sym) in core)
check("core merge scale is alpha/rank", "alpha / Float32(self.rank)" in core or "self.alpha / Float32(self.rank)" in core)
check("core refuses unsupported dtype by name", "safetensors dtype not supported" in core)
check("core refuses incomplete pair by name", "adapter pair incomplete" in core)
check("core refuses rank mismatch by name", "rank mismatch" in core)
check("core refuses quantized from-gguf tensor by name", "quantized tensor cannot be" in core)
check("core states BF16-only C05 scope", "BF16-only scope (C05)" in core)
test = read(TEST)
check("test suite has a test-local slow_merge", "def slow_merge" in test)
check("test suite has 9 test groups", len(re.findall(r"^def test_", test, re.M)) == 9,
      str(len(re.findall(r"^def test_", test, re.M))))

for f in ["j120_convert.mojo", "j120_reread.mojo", "j120_fixtures.py", "j120_verify.py"]:
    check("artefact present docs/janas/" + f, os.path.exists(os.path.join(HERE, f)))
fx = read(os.path.join(HERE, "j120_fixtures.py"))
check("fixtures carry protocol geometry hidden 8", '"model.embed_tokens.weight", [8, 8]' in fx)
check("fixtures carry protocol geometry ffn 16", '"model.layers.0.mlp.gate_proj.weight", [16, 8]' in fx)
check("fixtures target q_proj and gate_proj", fx.count("lora_A.default.weight") == 2 and "gate_proj" in fx)
conv = read(os.path.join(HERE, "j120_convert.mojo"))
check("convert driver geometry hidden 8 / ffn 16 / rope 4", "128, 8, 16, 1, 2, 1, 4," in conv)
rr = read(os.path.join(HERE, "j120_reread.mojo"))
for lvl in ["PackedGGUF", "inspect_metadata", "mmap_and_load", "VALIDATED"]:
    check("reread driver covers " + lvl, lvl in rr)
check("reread census gate bytes 256", 'names.append("blk.0.ffn_gate.weight"); cols.append(8); rows.append(16); kinds.append(30); sizes.append(256)' in rr)
vf = read(os.path.join(HERE, "j120_verify.py"))
check("verify recomputes slow merge with Float32 rounding", "def slow_merge" in vf and "def f32" in vf)
check("verify checks hidden 8", 'meta.get("hidden") == 8' in vf)

out = read(OUT)
check("unit suite ALL PASS (9 groups)", "ALL PASS: lora convert (9 groups)" in out)
check("filed output has at least 9 PASS lines", len(re.findall(r"^PASS: ", out, re.M)) >= 9)
check("convert driver ALL PASS filed", "CONVERT DRIVER: ALL PASS" in out)
check("convert census filed (GGUF BYTES: 3200)", "GGUF BYTES: 3200" in out)
check("from-gguf byte-identical filed", "FROM-GGUF RE-EMISSION: BYTE-IDENTICAL" in out)
check("verify ALL PASS 41 checks filed", "VERIFY: ALL PASS (41 checks)" in out)
check("verify merged elements 192 filed", "merged elements verified: 192" in out)
check("reread ALL PASS filed", "REREAD DRIVER: ALL PASS" in out)
check("reread level 3 VALIDATED filed", "state VALIDATED" in out)
check("merged.gguf sha filed", "c26af51dd9ebbea7a31635d3354ebb2dcf570dd69bd5df576ca01f1c1c7e2c6a" in out)

doc = read(DOC)
for tok in ["BF16-only", "VALIDATED", "NOT PROVEN", "DEFERRED", "repl.mojo", "G-119-1",
            "192", "41 checks", "9 groups"]:
    check("doc states " + tok, tok in doc)
check("doc sections 1+ filed", "## 1." in doc and "## 11." in doc)

pairs = [
    ("J120_LORA_MERGE_CONVERSION.md", "J120_LORA_MERGE_CONVERSION.md"),
    ("j120_test_output.txt", "j120_test_output.txt"),
    ("j120_inspect.py", "j120_inspect.py"),
    ("j120_convert.mojo", "j120_convert.mojo"),
    ("j120_reread.mojo", "j120_reread.mojo"),
    ("j120_fixtures.py", "j120_fixtures.py"),
    ("j120_verify.py", "j120_verify.py"),
]
for repo_f, camp_f in pairs:
    rp, cp = os.path.join(HERE, repo_f), os.path.join(CAMPAIGN, camp_f)
    check("campaign copy sha-identical: " + camp_f,
          os.path.exists(cp) and sha(rp) == sha(cp))
check("campaign copy sha-identical: lora_convert.mojo",
      sha(CORE) == sha(os.path.join(CAMPAIGN, "lora_convert.mojo")))
check("campaign copy sha-identical: test_lora_convert.mojo",
      sha(TEST) == sha(os.path.join(CAMPAIGN, "test_lora_convert.mojo")))

st = subprocess.run(["git", "-C", REPO, "status", "--porcelain"],
                    capture_output=True, text=True).stdout
check("no README.md touched in worktree", "README" not in st, st.strip()[:60])

print("TOTAL %d PASS %d FAIL %d" % (count[0], count[0] - len(fails), len(fails)))
sys.exit(1 if fails else 0)
