#!/usr/bin/env python3
"""J-076 inspection recount: every census, classifier,
ledger, and deferred-recipe claim in
docs/janas/J076_MTP_CENSUS_IN_FILES.md as an assertion over
this tree, the filed census output, and the campaign
ledgers on this VM.
Run from the repo root. Exit 0 iff all checks pass.
"""
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CAMPAIGN = pathlib.Path("/home/hatch/workspace/model-tests")
checks = []


def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))


def read(rel):
    return (ROOT / rel).read_text(errors="replace")


mod = read("aesir_engine/core/mtp_census.mojo")
test = read("aesir_engine/tests/test_mtp_census.mojo")
script = read("docs/janas/j076_mtp_census.py")
record = read("docs/janas/j076_test_output.txt")
doc = read("docs/janas/J076_MTP_CENSUS_IN_FILES.md")
census = json.loads(read("docs/janas/j076_census_output.txt"))

# The classifier exists, with the stated rules, in both halves.
check("classifier defines classify_tensor_name",
      "def classify_tensor_name(" in mod)
check("classifier defines MtpCensus verdict", "def verdict(" in mod)
for pat in ('"nextn" in name', '"mtp" in name', '"assistant" in name'):
    check(f"module rule {pat}", pat in mod)
for pat in ('"nextn"', '"mtp"', '"assistant"'):
    check(f"script rule {pat}", pat in script)
check("script reads directory only (no tensor data claim)",
      "never tensor data" in script)
check("classifier contains no speed",
      all(w not in mod for w in ("tok/s", "benchmark", "time_ns")))

# The test defines its 8 groups.
check("census test defines its 8 groups", all(
    f"def {fn}(" in test for fn in (
        "test_nextn_names",
        "test_mtp_names",
        "test_assistant_names",
        "test_ordinary_names_no_head",
        "test_first_match_order",
        "test_census_aggregation",
        "test_verdicts",
        "test_names_round_trip",
    )))

# The filed census: shape and headline numbers.
check("census files 27 records", len(census) == 27, str(len(census)))
full = [r for r in census if r.get("n_tensors", 0) > 0]
vocab = [r for r in census if r.get("verdict") == "VOCAB_ONLY"]
check("census files 8 full model files", len(full) == 8, str(len(full)))
check("census files 19 vocab-only fixtures", len(vocab) == 19,
      str(len(vocab)))
check("total tensors read is 2987",
      sum(r["n_tensors"] for r in census) == 2987,
      str(sum(r["n_tensors"] for r in census)))
check("zero head hits in the whole census",
      sum(r["mtp_hit_count"] for r in census) == 0)
check("zero metadata mtp/nextn keys in the whole census",
      all(r["meta_mtp_keys"] == [] for r in census))
check("every full file verdict is NO_MTP",
      all(r["verdict"] == "NO_MTP" for r in full))
zen = [r for r in census if "zen-4b" in r["path"]]
check("seven zen files, 398 tensors each",
      len(zen) == 7 and all(r["n_tensors"] == 398 for r in zen))
check("zen arch is qwen3 in all seven",
      all(r["arch"] == "qwen3" for r in zen))

# Pin cross-checks against the campaign ledgers (independent records).
s060 = (CAMPAIGN / "wave/S060_DOWNLOAD_LEDGER.md").read_text(
    errors="replace")
for r in zen:
    check(f"zen pin matches S-060 -- {r['path'].split('/')[-1]}",
          r["sha256"] in s060)
tiny = [r for r in census if "tinyllama" in r["path"]]
check("tinyllama pin matches J-074's filed pin",
      len(tiny) == 1 and tiny[0]["sha256"]
      == "da3087fb14aede55fde6eb81a0e55e886810e43509ec82ecdc7aa5d62a03b556")
q35v = [r for r in census if "qwen35" in r["path"]]
check("qwen35 vocab fixture is VOCAB_ONLY with arch filed as qwen2",
      len(q35v) == 1 and q35v[0]["verdict"] == "VOCAB_ONLY"
      and q35v[0]["arch"] == "qwen2")
g4v = [r for r in census if "gemma-4" in r["path"]]
check("gemma-4 vocab fixture is VOCAB_ONLY, arch gemma4",
      len(g4v) == 1 and g4v[0]["verdict"] == "VOCAB_ONLY"
      and g4v[0]["arch"] == "gemma4")

# Ledger-level facts behind section 3.
ledger = (CAMPAIGN / "wave/s065/acquisition_ledger.csv").read_text(
    errors="replace")
check("acquisition ledger has 193 data rows",
      len([ln for ln in ledger.splitlines() if ln.strip()]) - 1 == 193)
low = ledger.lower()
check("no mtp/assistant filename in the acquisition ledger",
      "mtp" not in low and "assistant" not in low)
gemma_inv = (CAMPAIGN / "wave/s068/s068_inventory.csv").read_text(
    errors="replace").lower()
check("no mtp/assistant filename in the Gemma live inventory",
      "mtp" not in gemma_inv and "assistant" not in gemma_inv)
bench = (CAMPAIGN / "qwen35-2b-heretic/BENCH_REPORT.md").read_text(
    errors="replace")
check("qwen3.5-2b bench record files its size, no hash",
      "1,274,398,240 bytes" in bench and "sha256" not in bench.lower())
check("qwen3.5-2b file itself absent from its directory",
      not (CAMPAIGN / "qwen35-2b-heretic"
           / "Qwen3.5-2B-Claude-4.6-OS-Auto-Variable-HERETIC-"
             "UNCENSORED-THINKING.i1-Q4_K_M.gguf").exists())

# Live wiring still absent (Part V state unchanged by a census).
placement = read("aesir_engine/core/placement_options.mojo")
aesir = read("aesir_engine/aesir.mojo")
check("require_draft_check_use still fails closed",
      "draft-check passes do not exist in Aesir yet" in placement)
check("engine facade speculative_generate still raises not-implemented",
      "speculative_generate" in aesir and "not-implemented" in aesir)
import subprocess
imported_by = subprocess.run(
    ["grep", "-rl", "from core.mtp_census import",
     "--include=*.mojo", "."],
    capture_output=True, text=True, cwd=ROOT).stdout.split()
check("mtp_census imported only by its own test",
      imported_by == ["./aesir_engine/tests/test_mtp_census.mojo"],
      " ".join(imported_by))

# The filed test record carries the counts.
for line in (
    "ALL PASS: mtp census classifier (8 groups)",
    "ALL PASS: speculative acceptance measurement (10 groups)",
    "ALL PASS: speculative verification account (13 groups)",
    "ALL PASS: speculative draft loop (12 groups)",
    "ALL PASS: speculative token-identity proof (8 groups;",
    "ALL PASS: cross-model draft pairing (10 groups)",
    "CENSUS DETERMINISM: run1 sha256 == run2 sha256",
):
    check(f"test record -- {line[:52]}", line in record)

# Doc elements.
for name, needle in (
    ("verdict is CLOSED-WITH-DEFERRED-LEG", "CLOSED-WITH-DEFERRED-LEG"),
    ("headline tensors total 2987", "2,987 directory entries"),
    ("zen verdict PRESENT-NO-MTP proven", "PRESENT-NO-MTP, PROVEN"),
    ("qwen3-next pin re-cited", "f73551b5"),
    ("on-box leg is J-077's first act", "J-077's first act"),
    ("re-cite point is the J-086 gate", "J-086"),
    ("guarded idle-gap rule names the 204 heartbeat",
     "ROADMAP_204_STATE.md"),
    ("rules recorded as answered-locally", "answered-locally"),
    ("unread files file as NOT PROVEN", "never NO_MTP"),
):
    check(f"doc element -- {name}", needle in doc)

failed = 0
for name, ok, detail in checks:
    print(("PASS " if ok else "FAIL ") + name
          + (f" -- {detail}" if detail and not ok else ""))
    failed += 0 if ok else 1
print("== done ==")
print(f"({len(checks) - failed}/{len(checks)} checks PASS)")
sys.exit(1 if failed else 0)
