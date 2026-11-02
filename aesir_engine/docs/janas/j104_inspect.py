#!/usr/bin/env python3
"""J-104 inspect: mechanically re-derive the saved-configuration
slice's load-bearing claims from this tree.

Run from the repo root (the worktree root). Every check prints
PASS or FAIL; the summary line states the tally. Claims covered:
the saved-config module's store shape, path rule, validation
reuse (J-036 placement parse, J-018 byte grammar), the one-story
reconciliation layer order, the command family, the separate
erase paths, the chat wiring (import, exactly two config
branches, each before its body's /save branch), the help text,
the test suite's group structure, the doc's load-bearing
phrases, the filed test output's tallies, and repo hygiene
(no README, no .gguf in the slice diff).
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AESIR = ROOT / "aesir_engine"
BASE = "dca5ec058fc57da6cbff067ebf6423fe08893e2d"

results = []


def check(name, ok):
    results.append((name, bool(ok)))
    print(("PASS" if ok else "FAIL") + ": " + name)


def read(path):
    return Path(path).read_text(encoding="utf-8")


module = read(AESIR / "core/saved_config.mojo")
cuda_chat = read(AESIR / "cli/cuda_chat.mojo")
chat_history = read(AESIR / "cli/chat_history.mojo")
test = read(AESIR / "tests/test_saved_config.mojo")
doc = read(AESIR / "docs/janas/J104_SAVED_CONFIGURATION.md")
test_output = read(AESIR / "docs/janas/j104_test_output.txt")

# --- the store -------------------------------------------------------------
check("store header literal AESIR_SAVED_CONFIG_V1", 'SAVED_HEADER = "AESIR_SAVED_CONFIG_V1"' in module)
check("file name saved-config.v1", 'SAVED_FILE_NAME = "saved-config.v1"' in module)
check("env-first path rule names AESIR_SAVED_CONFIG_FILE", '"AESIR_SAVED_CONFIG_FILE"' in module)
check("path rule uses AESIR_CACHE_HOME", '"AESIR_CACHE_HOME"' in module)
check("serialise + strict parse present", "def serialize_saved_config" in module and "def parse_saved_config" in module)
check("parse pins the 16-line format", "len(lines) != 16" in module)
check("disk surface present (load/save/store/erase)", all(
    s in module for s in (
        "def load_saved_config", "def save_saved_config",
        "def store_saved_config", "def erase_saved_config",
    )))
check("empty configuration refused at serialise", "stating no field is not" in module)
check("placement validation reuses J-036 parse_placement_value", "parse_placement_value(text, pass_kind)" in module)
check("cap grammar reuses J-018 parse_byte_size", "from core.expert_cache import parse_byte_size" in module and "parse_byte_size(value)" in module)
check("draft k default reuses J-072 LOOP_K_INITIAL", "from core.speculative_loop import LOOP_K_INITIAL" in module and "out_config.draft_k = LOOP_K_INITIAL" in module)

# --- the one story -----------------------------------------------------------
check("reconciliation functions present", all(
    s in module for s in (
        "def resolve_kind_story", "def resolve_draft_story",
        "def resolve_cap_story", "def config_story_report",
    )))
region = module[module.index("def resolve_kind_story"):module.index("def _learned_draft_text")]
order = [region.index('"' + layer + '"') for layer in ("session hand", "saved hand", "preset", "learned", "auto")]
check("kind resolution layer order session>saved>preset>learned>auto", order == sorted(order))
check("story names the lookup outcome (never silent)", "lookup_status_name(lookup.status)" in module)
check("story carries the separate-erase-paths sentence", "separate erase paths" in module)
check("story carries the J-027 expert-map sentence", "expert maps: none" in module)
check("saved module never erases the learned file", "erase_learned" not in module)
check("show form reads the learned file read-only", "load_learned_file(learned_file_path())" in module)

# --- the command family ------------------------------------------------------
check("command family present (parse/apply/response)", all(
    s in module for s in (
        "def parse_config_command", "def apply_config_set",
        "def apply_config_clear", "def saved_config_command_response",
        "def config_command_usage",
    )))
check("field set complete", all(
    s in module for s in (
        'FIELD_PROMPT_ON = "prompt-on"', 'FIELD_DRAFTS_ON = "drafts-on"',
        'FIELD_REPLY_ON = "reply-on"', 'FIELD_DRAFT_SOURCE = "draft-source"',
        'FIELD_DRAFT_MTP = "draft-mtp"', 'FIELD_DRAFT_MODEL = "draft-model"',
        'FIELD_DRAFT_K = "draft-k"', 'FIELD_CACHE_CAP = "cache-cap"',
    )))

# --- chat wiring ---------------------------------------------------------------
check("cuda_chat imports the host entry", "from core.saved_config import saved_config_command_response" in cuda_chat)
check("exactly two /save-config branches", cuda_chat.count('command == "/save-config"') == 2)
positions = []
idx = 0
ok_order = True
for _ in range(2):
    branch = cuda_chat.index('command == "/save-config"', idx)
    save = cuda_chat.index('command.startswith("/save")', branch)
    positions.append((branch, save))
    if not branch < save:
        ok_order = False
    idx = save
check("each config branch precedes its body's /save branch", ok_order)
check("help names /save-config in both widths", chat_history.count("/save-config") >= 2)

# --- test suite ------------------------------------------------------------------
check("test suite has 8 group prints + ALL PASS line", test.count('print("PASS:') == 8 and "ALL PASS: saved configuration (8 groups)" in test)
check("test takes the preset from J-047 preset_intent", "from core.manual_override import MODE_ECO, ModeOption, preset_intent" in test)
check("test exercises the exact-key lookup", "lookup_learned(learned, _machine(), _model())" in test)

# --- doc --------------------------------------------------------------------------
for phrase in (
    "session hand > saved hand > preset > learned > auto",
    "DEFERRED-WITH-REASON",
    "NOT PROVEN",
    "4ca75cc237de872a7e69777872ec1077f9e93e92",
    "LOOP_K_INITIAL",
    "J-118 Part VII gate",
    "T04",
    "AESIR_SAVED_CONFIG_V1",
):
    check("doc carries: " + phrase, phrase in doc)

# --- filed test output ---------------------------------------------------------
for tally in (
    "ALL PASS: saved configuration (8 groups)",
    "ALL PASS: learned file (13 groups)",
    "ALL PASS: draft configuration surface (17 groups)",
    "ALL PASS: manual override supremacy (16 groups)",
    "ALL PASS: placement options (10 groups)",
    "ALL PASS: model getting (5 groups)",
    "ALL PASS: chat picker (7 groups)",
    "ALL PASS: machine report (6 groups)",
    "ALL PASS: bench configurations (8 groups)",
    "ALL PASS: placement measurement harness (10 groups)",
    "ALL PASS: thread topology trials (10 groups)",
    "cuda chat module compile + import: PASS",
    "model browser unit: PASS",
    "model preference codec and validation: PASS",
):
    check("test output carries: " + tally, tally in test_output)
check("test output carries 9 expert-cache PASS lines", test_output.count("PASS: expert cache") == 9)

# --- repo hygiene ------------------------------------------------------------------
diff = subprocess.run(
    ["git", "-C", str(ROOT), "diff", "--name-only", BASE],
    capture_output=True, text=True,
).stdout.splitlines()
status = subprocess.run(
    ["git", "-C", str(ROOT), "status", "--porcelain"],
    capture_output=True, text=True,
).stdout.splitlines()
changed = set(diff) | {line[3:] for line in status if line.strip()}
check("no README in the slice diff", not any(p.endswith("README.md") for p in changed))
check("no .gguf in the slice diff", not any(p.endswith(".gguf") for p in changed))
expected = {
    "aesir_engine/core/saved_config.mojo",
    "aesir_engine/cli/cuda_chat.mojo",
    "aesir_engine/cli/chat_history.mojo",
    "aesir_engine/tests/test_saved_config.mojo",
    "aesir_engine/docs/janas/J104_SAVED_CONFIGURATION.md",
    "aesir_engine/docs/janas/j104_inspect.py",
    "aesir_engine/docs/janas/j104_inspect_output.txt",
    "aesir_engine/docs/janas/j104_test_output.txt",
}
check("slice diff is exactly the expected file set", changed == expected)

passed = sum(1 for _, ok in results if ok)
print("j104 inspect: %d/%d PASS" % (passed, len(results)))
sys.exit(0 if passed == len(results) else 1)
