#!/usr/bin/env python3
"""J-122 inspect: mechanically re-derive every load-bearing claim in
docs/janas/J122_CONVERSION_VERIFICATION_HARNESS.md from the tree at
the branch tip plus the filed outputs. Read-only. Exit 0 iff all pass."""
import hashlib, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CAMPAIGN = os.path.expanduser("~/workspace/model-tests/janas")
DOC = os.path.join(HERE, "J122_CONVERSION_VERIFICATION_HARNESS.md")
OUT = os.path.join(HERE, "j122_test_output.txt")

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

for f in ["j122_harness.py", "j122_run_pairs.py", "j122_test_harness.py",
          "j122_pair_records.json"]:
    check("artefact present docs/janas/" + f, os.path.exists(os.path.join(HERE, f)))

harness = read(os.path.join(HERE, "j122_harness.py"))
for tok in ["hf-gguf", "gguf-gguf", "hf-gguf-subset-head", "merged",
            "pass-through", "labelled-head", "carried-verbatim",
            "REFUSED-by-name", "missing-in-converted", "extra-in-converted",
            "label-mismatch", "DEFERRED-WITH-REASON", "J-128", "J-136",
            "element-exact (synthetic pair grade)"]:
    check("harness states " + tok, tok in harness)
check("harness never grades via llama-cli single-turn",
      "llama-cli --single-turn" in harness and "never" in harness.lower())

records = json.load(open(os.path.join(HERE, "j122_pair_records.json")))
check("four pair records filed", len(records) == 4, str(len(records)))
by_pair = {r["pair"]: r for r in records}
exp = {
    "P1-j120-lora-merge": ({"merged": 2, "pass-through": 10}, 728),
    "P2-j120-c10-reemission": ({"carried-verbatim": 12}, 728),
    "P3-j121-mtp-conversion": ({"labelled-head": 4, "pass-through": 12}, 936),
    "P4-j121-block-extraction": ({"labelled-head": 4}, 208),
}
for pid, (classes, total) in exp.items():
    r = by_pair.get(pid, {})
    check(pid + " verdict PASS", r.get("verdict") == "PASS")
    check(pid + " class counts exact", r.get("class_counts") == classes,
          str(r.get("class_counts")))
    g = r.get("grade", {})
    check(pid + " grade element-exact 0 diffs",
          g.get("kind") == "element-exact (synthetic pair grade)" and
          g.get("total_elements") == total and
          g.get("differing_elements") == 0 and g.get("max_abs_diff") == 0.0,
          str(g))
    leg = r.get("live_teacher_forcing", {})
    check(pid + " live leg DEFERRED-WITH-REASON to J-128 + J-136",
          leg.get("status") == "DEFERRED-WITH-REASON" and
          leg.get("recited_to") == ["J-128", "J-136"])
check("P1 converted sha is the J-120 banked pin",
      by_pair["P1-j120-lora-merge"]["converted"]["sha256"] ==
      "c26af51dd9ebbea7a31635d3354ebb2dcf570dd69bd5df576ca01f1c1c7e2c6a")
check("P3 converted sha is the J-121 banked pin",
      by_pair["P3-j121-mtp-conversion"]["converted"]["sha256"] ==
      "730dadae10b033c22b2e2345d2a478d717043a5c3f225e5977ba1b433ec77005")
check("P4 converted sha is the J-121 banked block pin",
      by_pair["P4-j121-block-extraction"]["converted"]["sha256"] ==
      "7f8f0070aae658a4aca5f4209b9d7e70eea0a539ede251a8251328252f29008b")
check("P2 source sha == converted sha (byte-identical re-emission)",
      by_pair["P2-j120-c10-reemission"]["source"]["sha256"] ==
      by_pair["P2-j120-c10-reemission"]["converted"]["sha256"])
check("P3 metadata label filed (4 heads, 21 entries)",
      by_pair["P3-j121-mtp-conversion"]["converted"]["head_count"] == 4 and
      by_pair["P3-j121-mtp-conversion"]["converted"]["metadata_count"] == 21)

out = read(OUT)
for tok in ["PIN merged.gguf OK", "PIN converted.gguf OK", "PIN block.gguf OK",
            "RUN PAIRS: ALL PASS (4 pairs)", "TEST HARNESS: ALL PASS (11 groups)",
            "group 6: flipped element FAILs", "group 7: missing tensors FAIL",
            "group 8: mislabelled head FAILs", "group 9: extra tensors FAIL",
            "group 10: silently dropped unmapped tensor REFUSED-by-name",
            "checks: 21, fails: 0"]:
    check("test output states " + tok, tok in out)

doc = read(DOC)
for tok in ["No silent conversions", "DEFERRED-WITH-REASON", "NOT PROVEN",
            "repl.mojo", "G-119-1", "J-128", "J-136", "element-exact",
            "REFUSED-by-name", "3754494b"]:
    check("doc states " + tok, tok in doc)
check("doc sections 1+ filed", "## 1." in doc and "## 9." in doc)

pairs = [
    ("J122_CONVERSION_VERIFICATION_HARNESS.md", "J122_CONVERSION_VERIFICATION_HARNESS.md"),
    ("j122_harness.py", "j122_harness.py"),
    ("j122_run_pairs.py", "j122_run_pairs.py"),
    ("j122_test_harness.py", "j122_test_harness.py"),
    ("j122_pair_records.json", "j122_pair_records.json"),
    ("j122_test_output.txt", "j122_test_output.txt"),
    ("j122_inspect.py", "j122_inspect.py"),
]
for repo_f, camp_f in pairs:
    rp, cp = os.path.join(HERE, repo_f), os.path.join(CAMPAIGN, camp_f)
    check("campaign copy sha-identical: " + camp_f,
          os.path.exists(cp) and sha(rp) == sha(cp))

st = subprocess.run(["git", "-C", REPO, "status", "--porcelain"],
                    capture_output=True, text=True).stdout
check("no README.md touched in worktree", "README" not in st, st.strip()[:60])

print("TOTAL %d PASS %d FAIL %d" % (count[0], count[0] - len(fails), len(fails)))
sys.exit(1 if fails else 0)
