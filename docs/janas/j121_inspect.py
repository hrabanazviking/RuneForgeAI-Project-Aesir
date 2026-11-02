#!/usr/bin/env python3
"""J-121 inspect: mechanically re-derive every load-bearing claim in
docs/janas/J121_MTP_PRESERVATION.md from the tree at the branch
tip plus the filed test output. Read-only. Exit 0 iff all pass."""
import hashlib, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CAMPAIGN = os.path.expanduser("~/workspace/model-tests/janas")
DOC = os.path.join(HERE, "J121_MTP_PRESERVATION.md")
OUT = os.path.join(HERE, "j121_test_output.txt")
CORE = os.path.join(REPO, "aesir_engine", "core", "lora_convert.mojo")
TEST = os.path.join(REPO, "aesir_engine", "tests", "test_mtp_preservation.mojo")
CENSUS = os.path.join(REPO, "aesir_engine", "core", "mtp_census.mojo")

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
for sym in ["lc_mtp_head_kind", "lc_mtp_head_kind_name", "lc_extract_mtp_block",
            "lc_convert_base", "lc_read_gguf", "lc_convert_from_gguf"]:
    check("core defines " + sym, ("def " + sym) in core)
check("core states J-076 mirror", "conversion-side" in core and "classify_tensor_name" in core)
check("core mirror order nextn before mtp", core.index('"nextn" in name') < core.index('"mtp" in name'))
check("core emits head_count label", '"aesir.mtp.head_count"' in core)
check("core emits head_tensors label", '"aesir.mtp.head_tensors"' in core)
check("core label conditional on heads", "if len(head_names) > 0:" in core)
check("core keeps J-120 refusal text", "no GGUF name mapping for HF tensor: " in core)
check("core extraction refusal by name", "MTP extraction found no prediction-head" in core)
check("conversion records heads", "var head_names: List[String]" in core)
census = read(CENSUS)
check("J-076 classifier order nextn before mtp", census.index('"nextn" in name') < census.index('"mtp" in name'))

test = read(TEST)
check("test suite has 9 test groups", len(re.findall(r"^def test_", test, re.M)) == 9,
      str(len(re.findall(r"^def test_", test, re.M))))
check("test suite binds J-076 classifier", "classify_tensor_name" in test)
check("test suite binds J-077 admission", "evaluate_mtp_admission" in test)
check("test suite binds MtpCensus", "MtpCensus" in test)

for f in ["j121_convert.mojo", "j121_reread.mojo", "j121_fixtures.py", "j121_verify.py"]:
    check("artefact present docs/janas/" + f, os.path.exists(os.path.join(HERE, f)))
fx = read(os.path.join(HERE, "j121_fixtures.py"))
for n in ["model.nextn.eh_proj.weight", "model.nextn.shared_head_norm.weight",
          "model.mtp.fc.weight", "model.assistant.head_norm.weight"]:
    check("fixtures carry head tensor " + n, n in fx)
check("fixtures carry protocol geometry hidden 8", '"model.embed_tokens.weight", [8, 8]' in fx)
check("fixtures carry eh_proj [8, 16]", '"model.nextn.eh_proj.weight", [8, 16]' in fx)
conv = read(os.path.join(HERE, "j121_convert.mojo"))
check("convert driver geometry hidden 8 / ffn 16 / rope 4", "128, 8, 16, 1, 2, 1, 4," in conv)
check("convert driver checks determinism", "DETERMINISM" in conv)
check("convert driver extracts block", "lc_extract_mtp_block" in conv)
rr = read(os.path.join(HERE, "j121_reread.mojo"))
for lvl in ["PackedGGUF", "inspect_metadata", "mmap_and_load", "VALIDATED"]:
    check("reread driver covers " + lvl, lvl in rr)
check("reread census gate kv 21", 'expect(seer.kv_count == 21' in rr)
check("reread census gate heads", "model.nextn.eh_proj.weight" in rr and "model.assistant.head_norm.weight" in rr)
vf = read(os.path.join(HERE, "j121_verify.py"))
check("verify implements J-076 rules itself", "def head_kind" in vf)
check("verify checks head label", "aesir.mtp.head_tensors" in vf)

out = read(OUT)
check("unit suite ALL PASS (9 groups)", "ALL PASS: mtp preservation (9 groups)" in out)
check("convert driver ALL PASS filed", "CONVERT DRIVER: ALL PASS" in out)
check("convert census filed (GGUF BYTES: 4128)", "GGUF BYTES: 4128" in out)
check("determinism filed", "DETERMINISM: SECOND CONVERSION BYTE-IDENTICAL" in out)
check("from-gguf byte-identical filed", "FROM-GGUF RE-EMISSION: BYTE-IDENTICAL" in out)
check("verify ALL PASS 70 checks filed", "VERIFY: ALL PASS (70 checks)" in out)
check("verify head elements 208 filed", "head elements verified: 208" in out)
check("verify total elements 936 filed", "total elements verified: 936" in out)
check("reread ALL PASS filed", "REREAD DRIVER: ALL PASS" in out)
check("reread level 3 VALIDATED filed", "state VALIDATED, 16 tensors" in out)
check("neighbour lora ALL PASS filed", "ALL PASS: lora convert (9 groups)" in out)
check("neighbour census ALL PASS filed", "ALL PASS: mtp census classifier (8 groups)" in out)
check("neighbour support ALL PASS filed", "ALL PASS: mtp head support (10 groups)" in out)
check("converted.gguf sha filed", "730dadae10b033c22b2e2345d2a478d717043a5c3f225e5977ba1b433ec77005" in out)
check("J-120 regression sha filed", "c26af51dd9ebbea7a31635d3354ebb2dcf570dd69bd5df576ca01f1c1c7e2c6a" in out)

doc = read(DOC)
for tok in ["WITH_MTP", "VALIDATED", "NOT PROVEN", "DEFERRED-WITH-REASON", "repl.mojo",
            "G-119-1", "936", "208", "70 checks", "9 groups", "range-request"]:
    check("doc states " + tok, tok in doc)
check("doc sections 1+ filed", "## 1." in doc and "## 11." in doc)

pairs = [
    ("J121_MTP_PRESERVATION.md", "J121_MTP_PRESERVATION.md"),
    ("j121_test_output.txt", "j121_test_output.txt"),
    ("j121_inspect.py", "j121_inspect.py"),
    ("j121_convert.mojo", "j121_convert.mojo"),
    ("j121_reread.mojo", "j121_reread.mojo"),
    ("j121_fixtures.py", "j121_fixtures.py"),
    ("j121_verify.py", "j121_verify.py"),
]
for repo_f, camp_f in pairs:
    rp, cp = os.path.join(HERE, repo_f), os.path.join(CAMPAIGN, camp_f)
    check("campaign copy sha-identical: " + camp_f,
          os.path.exists(cp) and sha(rp) == sha(cp))
check("campaign copy sha-identical: lora_convert.mojo",
      sha(CORE) == sha(os.path.join(CAMPAIGN, "lora_convert.mojo")))
check("campaign copy sha-identical: test_mtp_preservation.mojo",
      sha(TEST) == sha(os.path.join(CAMPAIGN, "test_mtp_preservation.mojo")))

st = subprocess.run(["git", "-C", REPO, "status", "--porcelain"],
                    capture_output=True, text=True).stdout
check("no README.md touched in worktree", "README" not in st, st.strip()[:60])

print("TOTAL %d PASS %d FAIL %d" % (count[0], count[0] - len(fails), len(fails)))
sys.exit(1 if fails else 0)
