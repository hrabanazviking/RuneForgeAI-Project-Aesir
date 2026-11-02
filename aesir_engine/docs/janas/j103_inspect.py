#!/usr/bin/env python3
"""J-103 inspect: mechanically re-derive the load-bearing claims of
docs/janas/J103_MODEL_GETTING.md from this tree.

Run from the repo root (the worktree root):
    python3 aesir_engine/docs/janas/j103_inspect.py
Prints one PASS/FAIL line per check and a final tally; exit 0 iff
all PASS.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]  # aesir_engine/
REPO = ROOT.parent
JANAS = ROOT / "docs" / "janas"

checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))


def read(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


# The provenance table (doc section 2): (reference, repository, filename,
# revision, sha256, size_bytes, quantization) per curated entry.
EXPECTED = [
    ("olmoe-1b-7b:q4_k_m", "allenai/OLMoE-1B-7B-0924-Instruct-GGUF",
     "olmoe-1b-7b-0924-instruct-q4_k_m.gguf",
     "02ab6ea6894a8418eb14f6d8ee1bfb08bd298080",
     "8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f",
     4213512672, "Q4_K_M"),
    ("granite-3.1-3b-a800m:q4_k_m", "bartowski/granite-3.1-3b-a800m-instruct-GGUF",
     "granite-3.1-3b-a800m-instruct-Q4_K_M.gguf",
     "be9a36f042806cb586bc65556c527079782b78e0",
     "48e0edcd578fd4462f26127f04c651d0e650741110185297741089aea01a82b3",
     2016888384, "Q4_K_M"),
    ("qwen1.5-moe-a2.7b-chat:q2_k", "tensorblock/Qwen1.5-MoE-A2.7B-Chat-GGUF",
     "Qwen1.5-MoE-A2.7B-Chat-Q2_K.gguf",
     "2b36b746552a7c99c814ee43120f318391e608c5",
     "cce008140714bb8b76185c0e2db802c60ce62182fa2eddb86ac53303b7525986",
     5890164032, "Q2_K"),
    ("olmoe-1b-7b:q2_k", "bartowski/OLMoE-1B-7B-0924-Instruct-GGUF",
     "OLMoE-1B-7B-0924-Instruct-Q2_K.gguf",
     "7448e4317d367a3d6838fe367fe996758da6fc6e",
     "0b6554d40b4ae1ed84c20f0411b7869c10da264e826b8f185758cfd02e782b33",
     2562763584, "Q2_K"),
    ("qwen3-next-80b-a3b:q4_k_m", "unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF",
     "Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf",
     "6688872b7a4e5eb8a121ceea08009530a024ba1d",
     "f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd",
     48506100512, "Q4_K_M"),
]

# --- the dataset module ---------------------------------------------------
data_path = ROOT / "cli" / "known_models.mojo"
data = read(data_path)
check("dataset module exists (cli/known_models.mojo)", data_path.exists())
check("dataset module is data behind known_models_dataset()",
      "def known_models_dataset() -> List[KnownModelEntry]:" in data)
blocks = re.findall(
    r'KnownModelEntry\(\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*'
    r'"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*(\d+),\s*"([^"]+)",?\s*\)',
    data,
)
check("dataset constructs exactly 5 entries", len(blocks) == 5,
      f"found {len(blocks)}")
parsed = [
    (f"{b[0]}:{b[1]}", b[2], b[3], b[4], b[5], int(b[6]), b[7])
    for b in blocks
]
for want in EXPECTED:
    check(f"dataset entry {want[0]} matches the provenance table field-for-field",
          want in parsed)
refs = [p[0] for p in parsed]
check("dataset references are unique", len(set(refs)) == len(refs))
for p in parsed:
    check(f"entry {p[0]} revision is 40 lowercase hex",
          re.fullmatch(r"[0-9a-f]{40}", p[3]) is not None)
    check(f"entry {p[0]} sha256 is 64 lowercase hex",
          re.fullmatch(r"[0-9a-f]{64}", p[4]) is not None)
    check(f"entry {p[0]} filename is a bare .gguf",
          p[2].endswith(".gguf") and "/" not in p[2] and "\\" not in p[2])
check("dataset states its provenance rule (no invented pins)",
      "not included" in data and "is ever invented" in data)

# --- the provider + get logic in model_selector ----------------------------
sel = read(ROOT / "cli" / "model_selector.mojo")
check("known_model_catalogue delegates to the dataset",
      "return known_models_dataset()" in sel)
check("model_selector imports the dataset module",
      "from cli.known_models import known_models_dataset" in sel)
check("provider no longer returns the honest-zero list",
      "J-102 defines the shape and the contract; the list is honestly empty"
      not in sel)
for sym in ("def find_known_model", "def get_decision", "def get_known_model"):
    check(f"model_selector carries {sym!r}", sym in sel)
check("get_known_model reuses fetch_known_model (pull machinery)",
      "fetch_known_model(entry, model_store, destination)" in sel)
check("fetch glue still calls download_hf_model", "download_hf_model" in sel)
check("fetch glue still registers via ingest_model", "ingest_model" in sel)
check("J-102 decision rule untouched (three actions present)",
      all(s in sel for s in ('"run"', '"fetch"', '"refused"')))
check("J-102 entry shape untouched (KnownModelEntry fields)",
      all(s in sel for s in (
          "struct KnownModelEntry", "def validate_known_model_entry",
          "def picker_entries", "def first_run_decision",
          "def pull_args_for_entry", "def choose_model")))

# --- the get command surface in cli/commands --------------------------------
commands = read(ROOT / "cli" / "commands.mojo")
for sym in ("def parse_get_request", "def dispatch_get"):
    check(f"commands carries {sym!r}", sym in commands)
check("dispatch_command routes cmd == \"get\" to dispatch_get",
      'if cmd == "get":' in commands and "dispatch_get(args)" in commands)
check("commands imports the get surface from model_selector",
      "from cli.model_selector import get_known_model, known_model_catalogue"
      in commands)
check("help names the get command", "get <name[:tag]>" in commands)
check("pull surface untouched (parse + dispatch still present)",
      "def parse_pull_request" in commands and "def dispatch_pull" in commands)

# --- tests ---------------------------------------------------------------------
get_test_path = ROOT / "tests" / "test_model_get.mojo"
get_test = read(get_test_path)
check("model get suite exists", get_test_path.exists())
check("model get suite has 5 groups", get_test.count("def test_") == 5,
      f"count={get_test.count('def test_')}")
check("model get suite prints ALL PASS line",
      "ALL PASS: model getting (5 groups)" in get_test)
for want in EXPECTED:
    check(f"model get suite carries provenance pin for {want[0]}",
          want[4] in get_test and want[3] in get_test)
picker_test = read(ROOT / "tests" / "test_chat_picker.mojo")
check("chat picker suite asserts the real catalogue (J-103 update)",
      "5 curated entries, all pin-valid; J-103 data" in picker_test)
check("chat picker suite no longer asserts the honest zero",
      "expected zero entries today" not in picker_test)
check("chat picker suite still has 7 groups",
      picker_test.count("def test_") == 7)

# --- doc ----------------------------------------------------------------------
doc = read(JANAS / "J103_MODEL_GETTING.md")
check("doc exists", doc != "")
for phrase in ("0. Protocol", "pin-provenance", "DEFERRED-WITH-REASON",
               "NOT PROVEN", "T10", "J-015", "J-032"):
    check(f"doc states {phrase!r}", phrase in doc)
for want in EXPECTED:
    check(f"doc provenance table carries {want[0]} pins",
          want[3] in doc and want[4] in doc and str(want[5]) in doc)

# --- filed outputs --------------------------------------------------------------
test_out = read(JANAS / "j103_test_output.txt")
check("test output filed", test_out != "")
check("test output: model getting 5/5",
      "ALL PASS: model getting (5 groups)" in test_out)
check("test output: chat picker 7/7",
      "ALL PASS: chat picker (7 groups)" in test_out)
check("test output: machine report 6/6",
      "ALL PASS: machine report (6 groups)" in test_out)
check("test output: bench configurations 8/8",
      "ALL PASS: bench configurations (8 groups)" in test_out)
check("test output: neighbours 10/10 + 10/10",
      "placement measurement harness (10 groups)" in test_out
      and "thread topology trials (10 groups)" in test_out)
check("test output: model browser PASS", "model browser unit: PASS" in test_out)

# --- repo hygiene: no models committed, no README in the slice ------------------
try:
    out = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=REPO, capture_output=True, text=True, timeout=30,
    )
    touched = [ln[3:] for ln in out.stdout.splitlines() if ln.strip()]
    check("no README.md in the slice diff",
          not any(p.endswith("README.md") for p in touched),
          ", ".join(touched[:8]))
    check("no .gguf model bytes in the slice diff",
          not any(p.endswith(".gguf") for p in touched),
          ", ".join(touched[:8]))
except Exception as exc:  # git unavailable: the check FAILs, disposed in the doc
    check("no README.md in the slice diff", False, f"git status failed: {exc}")
    check("no .gguf model bytes in the slice diff", False,
          f"git status failed: {exc}")

failed = [c for c in checks if not c[1]]
for name, ok, detail in checks:
    line = ("PASS: " if ok else "FAIL: ") + name
    if detail and not ok:
        line += f" ({detail})"
    print(line)
print(f"j103_inspect: {len(checks) - len(failed)}/{len(checks)} checks PASS")
sys.exit(0 if not failed else 1)
