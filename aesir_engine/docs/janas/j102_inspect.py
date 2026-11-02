#!/usr/bin/env python3
"""J-102 inspect: mechanically re-derive the load-bearing claims of
docs/janas/J102_CHAT_PICKER.md from this tree.

Run from the repo root (the worktree root):
    python3 aesir_engine/docs/janas/j102_inspect.py
Prints one PASS/FAIL line per check and a final tally; exit 0 iff
all PASS.
"""
import pathlib
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


# --- the picker module ---------------------------------------------------
sel_path = ROOT / "cli" / "model_selector.mojo"
sel = read(sel_path)
check("model_selector module exists", sel_path.exists())
for sym in (
    "struct KnownModelEntry",
    "def validate_known_model_entry",
    "def known_model_catalogue",
    "struct PickerEntry",
    "def picker_entries",
    "def render_model_picker_page",
    "def selected_picker_entry",
    "def first_run_decision",
    "def pull_args_for_entry",
    "def fetch_known_model",
    "def choose_model",
):
    check(f"model_selector carries {sym!r}", sym in sel)
check("catalogue provider returns an empty list in J-102 (honest zero)",
      "var entries = List[KnownModelEntry]()" in sel
      and "return entries^" in sel)
check("model_selector states the J-103 boundary", "J-103" in sel)
check("fetch glue calls download_hf_model (pull machinery, not a re-implementation)",
      "download_hf_model" in sel)
check("fetch glue registers via ingest_model", "ingest_model" in sel)
check("fetch glue imports HuggingFaceSeer", "HuggingFaceSeer" in sel)
check("decision rule names all three actions",
      all(s in sel for s in ('"run"', '"fetch"', '"refused"')))
check("decision rule refuses on digest mismatch", "digest mismatch" in sel)
check("decision rule refuses on size mismatch", "size mismatch" in sel)
check("existing installed-only picker functions untouched (still present)",
      all(s in sel for s in (
          "def choose_installed_model", "def prompt_installed_model",
          "def render_model_selector_page", "def selected_model_reference",
          "def installed_model_choices")))
check("cancel error text preserved for the chat caller",
      '"Model selection cancelled"' in sel)

# --- the pull grammar the argv builder must match -------------------------
commands = read(ROOT / "cli" / "commands.mojo")
check("commands still carries parse_pull_request", "def parse_pull_request" in commands)
check("commands still carries dispatch_pull", "def dispatch_pull" in commands)
for opt in ('"--revision"', '"--sha256"', '"--size"', '"--name"'):
    check(f"pull grammar accepts {opt}", opt in commands)
    check(f"picker argv builder emits {opt}", opt in sel)
check("dispatch_pull calls download_hf_model", "download_hf_model" in commands)
check("dispatch_pull registers via ingest_model", "ingest_model" in commands)

# --- the chat call site ----------------------------------------------------
chat = read(ROOT / "cli" / "cuda_chat.mojo")
check("cuda_chat imports choose_model", "choose_model" in chat)
check("cuda_chat calls choose_model at the no-reference site",
      "model_reference = choose_model(model_store, interrupt_fd)" in chat)
check("cuda_chat no longer calls choose_installed_model",
      "choose_installed_model" not in chat)

# --- tests -------------------------------------------------------------------
test_path = ROOT / "tests" / "test_chat_picker.mojo"
test = read(test_path)
check("chat picker suite exists", test_path.exists())
check("chat picker suite has 7 groups", test.count("def test_") == 7,
      f"count={test.count('def test_')}")
check("chat picker suite prints ALL PASS line",
      "ALL PASS: chat picker (7 groups)" in test)
check("suite states the honest-zero catalogue on its face",
      "zero entries" in test)

# --- doc ----------------------------------------------------------------------
doc = read(JANAS / "J102_CHAT_PICKER.md")
check("doc exists", doc != "")
for phrase in ("0. Protocol", "J-102 / J-103 boundary", "decision rule",
               "DEFERRED-WITH-REASON", "NOT PROVEN", "T03", "T10"):
    check(f"doc states {phrase!r}", phrase in doc)

# --- filed outputs --------------------------------------------------------------
test_out = read(JANAS / "j102_test_output.txt")
check("test output filed", test_out != "")
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

# --- no README in the slice -----------------------------------------------------
try:
    out = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=REPO, capture_output=True, text=True, timeout=30,
    )
    touched = [ln[3:] for ln in out.stdout.splitlines() if ln.strip()]
    check("no README.md in the slice diff",
          not any(p.endswith("README.md") for p in touched),
          ", ".join(touched[:8]))
except Exception as exc:  # git unavailable: the check FAILs, disposed in the doc
    check("no README.md in the slice diff", False, f"git status failed: {exc}")

failed = [c for c in checks if not c[1]]
for name, ok, detail in checks:
    line = ("PASS: " if ok else "FAIL: ") + name
    if detail and not ok:
        line += f" ({detail})"
    print(line)
print(f"j102_inspect: {len(checks) - len(failed)}/{len(checks)} checks PASS")
sys.exit(0 if not failed else 1)
