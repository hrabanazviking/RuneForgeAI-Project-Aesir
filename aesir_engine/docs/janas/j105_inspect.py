#!/usr/bin/env python3
"""J-105 inspect: mechanically re-derive the chat-manners
slice's load-bearing claims from this tree.

Run from the repo root (the worktree root). Every check prints
PASS or FAIL; the summary line states the tally. Claims covered:
the manners module's decision literals and host functions; both
interactive loops using the result form + classifier (and not
the collapsing wrapper for the prompt); the post-turn rule in
both loops; the suggestion wiring at all three refusal sites
(CLI command, both chat_control bodies, chat option); the
env-warning call at chat start; the candidate sets equal to
their surfaces' extracted sets; the known env set equal to the
extracted read-site census plus the documented three; the
section 0.5 write-census set equal to the doc's section 3
table; the loader's read-only flags; the test suite's group
structure; the doc's load-bearing phrases; the filed test
output's tallies (including the completion re-run); and repo
hygiene (no README, no .gguf in the slice diff).
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AESIR = ROOT / "aesir_engine"
BASE = "8e9da5269271d3cf066d24ee120d1ac5f0e55564"

results = []


def check(name, ok):
    results.append((name, bool(ok)))
    print(("PASS" if ok else "FAIL") + ": " + name)


def read(path):
    return Path(path).read_text(encoding="utf-8")


def appends_of(source, func):
    """The String literals appended inside one def, in order."""
    start = source.index("def " + func)
    end = source.index("return names^", start)
    return re.findall(r'names\.append\(String\("([^"]+)"\)\)', source[start:end])


module = read(AESIR / "core/chat_manners.mojo")
cuda_chat = read(AESIR / "cli/cuda_chat.mojo")
commands = read(AESIR / "cli/commands.mojo")
interrupts = read(AESIR / "cli/interrupts.mojo")
gguf = read(AESIR / "loader/gguf.mojo")
stream_reader = read(AESIR / "core/stream_reader.mojo")
test = read(AESIR / "tests/test_chat_manners.mojo")
doc = read(AESIR / "docs/janas/J105_CHAT_MANNERS.md")
test_output = read(AESIR / "docs/janas/j105_test_output.txt")

# --- the manners layer -------------------------------------------------------
check("prompt-line decision literals present", all(
    s in module for s in (
        "comptime LINE_SUBMIT = 0", "comptime LINE_LEAVE = 1",
        "comptime LINE_REPROMPT = 2", "comptime LINE_SUBMIT_FINAL = 3",
        "comptime POST_TURN_STAY = 0", "comptime POST_TURN_STAY_NOTED = 1",
    )))
check("classify + post-turn functions present", all(
    s in module for s in (
        "def classify_prompt_line", "def post_turn_action",
        "if interrupted:", 'return LINE_REPROMPT',
        'finish_reason == "cancelled"',
    )))
check("suggestion functions present", all(
    s in module for s in (
        "def edit_distance", "def suggest_match", "def suggestion_suffix",
        "; did you mean '",
    )))
check("env audit functions present", all(
    s in module for s in (
        "def audit_env_name", "def audit_env_names", "def env_manner_warnings",
        "/proc/self/environ", "is set but is never read; did you mean ",
    )))
check("write classifier present, model checked first", all(
    s in module for s in (
        "def classify_write_destination", "def path_is_under",
        "WRITE_REFUSED_MODEL", "WRITE_ALLOWED_CACHE", "WRITE_ALLOWED_CHOSEN",
        "WRITE_REFUSED_STRAY",
    )) and module.index("model_paths") < module.index("path_is_under(path, cache_home)"))

# --- wiring: the prompt loops --------------------------------------------------
check("cuda_chat imports the manners decisions", all(
    s in cuda_chat for s in (
        "from core.chat_manners import", "classify_prompt_line",
        "env_manner_warnings", "post_turn_action", "suggest_chat_command",
        "suggest_chat_option", "suggestion_suffix",
    )))
check("both loops read via the result form", cuda_chat.count(
    "var line = read_chat_line_result(interrupt_fd)") == 2)
check("both loops act on classify_prompt_line", cuda_chat.count(
    "var line_action = classify_prompt_line(") == 2)
check("both loops re-prompt on LINE_REPROMPT", cuda_chat.count(
    "if line_action == LINE_REPROMPT:") == 2)
check("post-turn rule in both loops", cuda_chat.count(
    "if post_turn_action(") == 2 and cuda_chat.count(
    "POST_TURN_STAY_NOTED") >= 2)
check("no post-turn break-on-interrupt remains", (
    "consume_interrupts(interrupt_fd)\n                    and session.finish_reason"
    not in cuda_chat) and (
    "consume_interrupts(interrupt_fd)\n                        and session.finish_reason"
    not in cuda_chat))
check("result-form helper beside the wrapper", (
    "def read_chat_line_result" in cuda_chat
    and "return read_interruptible_line_result(interrupt_fd)" in cuda_chat))
check("interrupts wrapper docstring corrected (no session-end claim)", (
    "chat treats interruption and EOF as session end" not in interrupts
    and "since J-105 the chat distinguishes" in interrupts))

# --- wiring: suggestions + env at start ---------------------------------------
check("CLI unknown-command refusal gains a suggestion", (
    "suggestion_suffix(suggest_cli_command(cmd))" in commands
    and '"unknown command: " + cmd' in commands))
check("both chat_control refusals name the word + suggest", cuda_chat.count(
    "suggestion_suffix(suggest_chat_command(first_word(command)))") == 2
    and cuda_chat.count('"Unknown chat command: " + first_word(command)') == 2)
check("unknown-option refusal gains a suggestion", (
    "suggestion_suffix(suggest_chat_option(flag))" in cuda_chat
    and '"Unknown chat option: " + flag' in cuda_chat))
check("env warnings printed at chat start, before model choice", (
    "for manner_warning in env_manner_warnings():" in cuda_chat
    and cuda_chat.index("for manner_warning in env_manner_warnings():")
    < cuda_chat.index("choose_model(model_store, interrupt_fd)")))

# --- candidate sets equal to their surfaces ------------------------------------
cli_module = appends_of(module, "cli_command_names")
dispatch = commands[commands.index(
    "def dispatch_command(args: List[String], mut store"):]
cli_surface = set(re.findall(r'cmd == "([^"]+)"', dispatch))
catalog = commands[commands.index("def _is_catalog_command"):commands.index(
    "def dispatch_catalog_command")]
cli_surface |= set(re.findall(r'command == "([^"]+)"', catalog))
pref = commands[commands.index("def _is_preference_command"):commands.index(
    "def dispatch_preference_command")]
cli_surface |= set(re.findall(r'"([a-z\-]+)"', pref.split("return", 1)[1]))
cli_surface -= {"-h", "--help", "-v", "--version"}
check("CLI candidate set == dispatch + catalog + preference surfaces",
      set(cli_module) == cli_surface and len(cli_module) == 41)

chat_module = appends_of(module, "chat_command_names")
chat_surface = set()
idx = 0
for _ in range(2):
    s = cuda_chat.index("def chat_control", idx)
    e = cuda_chat.find("\ndef ", s + 10)
    if e == -1:
        e = len(cuda_chat)
    body = cuda_chat[s:e]
    chat_surface |= set(re.findall(r'command == "([^"]+)"', body))
    chat_surface |= {x.rstrip() for x in re.findall(
        r'command\.startswith\("([^"]+)"\)', body)}
    idx = e
chat_surface |= set(re.findall(r'prompt == "([^"]+)"', cuda_chat))
chat_surface |= {x for x in re.findall(
    r'prompt\.startswith\("([^"]+)"\)', cuda_chat) if len(x) > 1}
chat_surface |= {"/bye"} if 'text == "/bye"' in module else set()
check("chat candidate set == chat_control + loop surfaces + /bye",
      set(chat_module) == chat_surface and len(chat_module) == 16)

option_module = appends_of(module, "chat_option_names")
dispatch_chat = cuda_chat[cuda_chat.index("def _dispatch_cuda_chat"):]
dispatch_chat = dispatch_chat[:dispatch_chat.index("sampling.validate()")]
option_surface = set(re.findall(r'flag == "(--[a-z\-]+)"', dispatch_chat))
check("option candidate set == chat parser flag literals",
      set(option_module) == option_surface and len(option_module) == 18)

# --- env census ------------------------------------------------------------------
env_pat = re.compile(
    r'(?:_env_int|_env_str|_draft_env_value|_kv_env_str|_learned_env_value'
    r'|_mode_env_value|_saved_env_value|_parse_kill_env)\b[^)]*?"(AESIR_[A-Z_]+)"')
read_names = set()
for sub in ("core", "cli", "server", "loader"):
    for path in (AESIR / sub).rglob("*.mojo"):
        if path.name == "chat_manners.mojo":
            continue
        read_names |= set(env_pat.findall(path.read_text(encoding="utf-8")))
known_module = appends_of(module, "known_env_names")
documented_module = appends_of(module, "documented_env_names")
check("known env set == read-site census (21) + documented three",
      set(known_module) == read_names and len(known_module) == 21
      and set(documented_module) == {
          "AESIR_EXPERT_CACHE_BYTES", "AESIR_DENSE_LAYER_CACHE_BYTES",
          "AESIR_PREFILL_BATCH"}
      and len(read_names) == 21)

# --- write census (protocol section 0.5) -----------------------------------------
prims = ('external_call["open64"', 'external_call["open"',
         'external_call["rename"', 'external_call["unlink"',
         'external_call["mkdir"')
census = set()
for sub in ("cli", "core", "server", "loader"):
    for path in (AESIR / sub).rglob("*.mojo"):
        text = path.read_text(encoding="utf-8")
        if any(p in text for p in prims) or re.search(
                r'\bopen\([^)]*,\s*"[wa]"', text):
            census.add(str(path.relative_to(AESIR)))
section3 = doc[doc.index("## 3."):doc.index("## 4.")]
doc_census = set(re.findall(r"\| `((?:cli|core|server|loader)/[^`]+)` \|", section3))
check("write-census set == doc section 3 table (%d files)" % len(census),
      doc_census == census)

# --- loader read-only evidence -----------------------------------------------------
check("GGUF loader opens read-only (526336, O_RDONLY comment)", (
    "Int32(526336)" in gguf and "O_RDONLY | O_NONBLOCK | O_CLOEXEC" in gguf))
check("GGUF mapping is PROT_READ (mmap prot 1)", "Int32(1), Int32(1), self.fd" in gguf)
check("stream reader is read-only + pread", (
    "comptime _O_RDONLY = 0" in stream_reader
    and 'external_call["pread"' in stream_reader))

# --- test suite ---------------------------------------------------------------------
check("test suite has 7 group prints + ALL PASS line", (
    test.count('print("PASS:') == 7
    and "ALL PASS: chat manners (7 groups)" in test))
check("test pins the candidate counts 41/16/18 + known env 24", all(
    s in test for s in (
        'expect_eq_int(len(cli_command_names()), 41',
        'expect_eq_int(len(chat_command_names()), 16',
        'expect_eq_int(len(chat_option_names()), 18',
        'expect_eq_int(len(known_env_names()), 24',
    )))

# --- doc -----------------------------------------------------------------------------
for phrase in (
    "DEFERRED-WITH-REASON",
    "NOT PROVEN",
    "J-118 Part VII gate",
    "T06",
    "8e9da5269271d3cf066d24ee120d1ac5f0e55564",
    "cli 41",
):
    check("doc carries: " + phrase, phrase in doc)

# --- filed test output -----------------------------------------------------------------
for tally in (
    "ALL PASS: chat manners (7 groups)",
    "cuda chat + commands modules compile + import: PASS",
    "ALL PASS: saved configuration (8 groups)",
    "ALL PASS: learned file (13 groups)",
    "ALL PASS: draft configuration surface (17 groups)",
    "ALL PASS: chat picker (7 groups)",
    "ALL PASS: model getting (5 groups)",
    "ALL PASS: machine report (6 groups)",
    "ALL PASS: bench configurations (8 groups)",
    "candidate sets (cli 41, chat 16, options 18",
    "completion re-run: test_chat_manners 7/7 PASS on the final tree (cli 41)",
):
    check("test output carries: " + tally, tally in test_output)

# --- repo hygiene ----------------------------------------------------------------------
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
    "aesir_engine/core/chat_manners.mojo",
    "aesir_engine/cli/commands.mojo",
    "aesir_engine/cli/cuda_chat.mojo",
    "aesir_engine/cli/interrupts.mojo",
    "aesir_engine/tests/test_chat_manners.mojo",
    "aesir_engine/docs/janas/J105_CHAT_MANNERS.md",
    "aesir_engine/docs/janas/j105_inspect.py",
    "aesir_engine/docs/janas/j105_inspect_output.txt",
    "aesir_engine/docs/janas/j105_test_output.txt",
}
check("slice diff is exactly the expected file set", changed == expected)

passed = sum(1 for _, ok in results if ok)
print("j105 inspect: %d/%d PASS" % (passed, len(results)))
sys.exit(0 if passed == len(results) else 1)
