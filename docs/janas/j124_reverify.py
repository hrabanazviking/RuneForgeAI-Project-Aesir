#!/usr/bin/env python3
"""J-124 stage (a) re-verification: the J-076 / census ground for
Qwen3.6 (arch qwen35moe), re-derived first-hand.

Re-reads the J-076 census doc, the J-077 admission record, the
Part I census + delta table (campaign copies), the S-065 master
acquisition ledger, the VM model store, and THIS tree's
loader/session/inference code; re-checks the ABSENT-FILE /
NOT PROVEN ground, the census rows that route this family to
J-124, and the pre-build state of qwen35moe admission in this
tree. Run BEFORE the J-124 build: its pre-build checks assert
the admission does NOT yet exist. Pure stdlib. Exit 0 iff all
checks PASS.
"""
import glob, os, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]  # repo root
JANAS = ROOT / "docs" / "janas"
CAMP = pathlib.Path(os.path.expanduser("~/workspace/model-tests/janas"))
WAVE = pathlib.Path(os.path.expanduser("~/workspace/model-tests/wave"))
fails = []
total = [0]
def check(name, cond):
    total[0] += 1
    print(("PASS " if cond else "FAIL ") + name)
    if not cond: fails.append(name)

j076 = (JANAS / "J076_MTP_CENSUS_IN_FILES.md").read_text()
j077out = (JANAS / "j077_admission_output.txt").read_text()
census = (CAMP / "CENSUS.md").read_text()
delta = (CAMP / "DELTA_TABLE.md").read_text()
s065md = (WAVE / "S065_MASTER_ACQUISITION_LEDGER.md").read_text()
s065csv = (WAVE / "s065" / "acquisition_ledger.csv").read_text()
gguf = (ROOT / "aesir_engine" / "loader" / "gguf.mojo").read_text()
moe = (ROOT / "aesir_engine" / "core" / "moe_session.mojo").read_text()
inf = (ROOT / "aesir_engine" / "core" / "inference.mojo").read_text()
mtp = (ROOT / "aesir_engine" / "core" / "mtp_census.mojo").read_text()

# The J-076 ground for qwen35moe, verbatim.
check("J-076: qwen35moe row names no file and no pin",
      "No file and no pin in any Aesir record" in j076)
check("J-076: qwen35moe verdict ABSENT-FILE / NOT PROVEN",
      "**ABSENT-FILE / NOT PROVEN**" in j076 and "qwen35moe" in j076)
check("J-076: census phrase 'GGUF keeps its MTP block' for qwen35moe",
      "GGUF keeps its MTP block" in j076)
check("J-076: 193-row ledger has no qwen35moe row (per J-076)",
      "the 193-row acquisition ledger (S-065) has no `qwen35moe` row" in j076)
check("J-076 section 5: families enter only as pinned, named acquisitions",
      "enter only as pinned, named acquisitions" in j076)
# The census / concordance rows that route this slice.
check("CENSUS: qwen35moe row names Qwen3.6-35B-A3B",
      "`qwen35moe`" in census and "Qwen3.6-35B-A3B" in census)
check("CENSUS: qwen35moe classed Qwen3.5-MoE",
      "Qwen3.5-MoE class" in census)
check("DELTA row 81: Qwen3.5 MoE / Qwen3.6 MoE routed to J-124/J-125",
      "Qwen3.5 MoE / Qwen3.6 MoE" in delta and "J-124" in delta)
# The acquisition ledger itself, re-searched this run.
check("S-065 ledger is the 193-row ledger", "193 rows ledgered" in s065md)
check("S-065 ledger md: zero qwen35moe occurrences",
      s065md.count("qwen35moe") == 0)
check("S-065 ledger csv: zero qwen35moe occurrences",
      s065csv.count("qwen35moe") == 0)
check("S-065 ledger csv: zero Qwen3.6 occurrences",
      s065csv.count("Qwen3.6") == 0)
# J-077's standing refusal of the unproven case.
check("J-077 admission output refuses qwen35moe as NOT PROVEN",
      "REFUSED file=qwen35moe" in j077out and "NOT_PROVEN" in j077out)
# The VM store, enumerated this run: no qwen35moe file exists here.
wave_ggufs = sorted(os.path.basename(p) for p in
                    glob.glob(str(WAVE / "**" / "*.gguf"), recursive=True))
check("VM wave store holds exactly the 7 Zen files",
      len(wave_ggufs) == 7 and all(n.startswith("zen-4b") for n in wave_ggufs))
root_ggufs = sorted(os.path.basename(p) for p in
                    glob.glob(os.path.expanduser("~/workspace/*.gguf")))
check("VM workspace root holds only tinyllama.Q4_0.gguf",
      root_ggufs == ["tinyllama.Q4_0.gguf"])
heretic = glob.glob(os.path.expanduser(
    "~/workspace/model-tests/qwen35-2b-heretic/*.gguf"))
check("qwen35-2b-heretic dir holds no .gguf (bench record only)",
      heretic == [])
check("no store file name carries qwen35moe / 35b / 3.6",
      not any(("qwen35moe" in n or "35b" in n.lower() or "3.6" in n)
              for n in wave_ggufs + root_ggufs))
# Pre-build tree state (this script runs before the J-124 build):
check("pre-build: no qwen35moe anywhere in loader gguf.mojo",
      "qwen35moe" not in gguf)
check("pre-build: no _validate_qwen35moe_tensors in loader",
      "_validate_qwen35moe_tensors" not in gguf)
check("loader has qwen35 dense hybrid precedent branch",
      "_validate_qwen35_tensors" in gguf)
check("loader has qwen3next hybrid-MoE precedent branch (J-123)",
      "_validate_qwen3next_tensors" in gguf)
check("loader has olmoe MoE precedent branch",
      "_validate_olmoe_tensors" in gguf)
check("loader parses .expert_count suffix", '".expert_count"' in gguf)
check("loader parses .ssm.inner_size suffix", '".ssm.inner_size"' in gguf)
check("loader parses expert_shared_feed_forward_length (J-123 field)",
      "expert_shared_feed_forward_length" in gguf)
check("pre-build: moe_session admits only olmoe", 'arch != "olmoe"' in moe)
check("pre-build: qwen35moe absent from moe_session", "qwen35moe" not in moe)
check("inference admits the qwen35 dense arch",
      'architecture == "qwen35"' in inf)
check("pre-build: qwen35moe absent from inference", "qwen35moe" not in inf)
check("J-076 classifier present (core/mtp_census.mojo)",
      "classify_tensor_name" in mtp and "nextn" in mtp)
# Directory arithmetic at the public-record geometry (doc 0.4):
# 40 blocks, interval 4 -> 30 SSM x 18 + 10 attention x 15 + 3 globals.
check("census arithmetic 30*18+10*15+3 == 693", 30*18 + 10*15 + 3 == 693)
check("fixture arithmetic 3*18+1*15+3 == 72", 3*18 + 1*15 + 3 == 72)
print(f"TOTAL {total[0]} checks, FAIL {len(fails)}")
print("ALL PASS" if not fails else "FAILURES: " + ", ".join(fails))
sys.exit(0 if not fails else 1)
