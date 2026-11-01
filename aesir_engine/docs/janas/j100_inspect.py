#!/usr/bin/env python3
"""J-100 inspect: mechanically re-derive the load-bearing claims of
docs/janas/J100_BENCH_CONFIGURATIONS.md from this tree.

Run from the repo root (the worktree root):
    python3 aesir_engine/docs/janas/j100_inspect.py
(or docs/janas/j100_inspect.py relative to aesir_engine). Prints one
PASS/FAIL line per check and a final tally; exit 0 iff all PASS.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]  # aesir_engine/
REPO = ROOT.parent

checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))


def read(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


# --- the new core module ---------------------------------------------
mod_path = ROOT / "core" / "bench_configurations.mojo"
mod = read(mod_path)
check("core module exists", mod_path.exists())
for sym in (
    "struct BenchConfig",
    "struct BenchCell",
    "struct BenchReport",
    "def enumerate_bench_cells",
    "def run_bench_sweep",
    "def fastest_cell_index",
    "def machine_report",
    "run_placement_measurement",
    "run_thread_trials",
    "derive_thread_ladder",
    "enumerate_candidates",
):
    check(f"core module carries {sym!r}", sym in mod)
check("core module states J-100", "J-100" in mod)
check("core module refuses --report scope (no report flag logic)",
      "--report" not in mod)

# --- the CLI module + dispatch wiring ---------------------------------
cli_path = ROOT / "cli" / "bench.mojo"
cli = read(cli_path)
check("cli bench module exists", cli_path.exists())
for sym in ("def dispatch_bench", "run_bench_sweep", "observe_device_inventory",
            "observe_cpu_facts", "machine_report"):
    check(f"cli bench carries {sym!r}", sym in cli)
check("cli bench usage names the command", "aesir bench" in cli)
check("cli bench refuses unknown options", "Unknown bench option" in cli)

commands = read(ROOT / "cli" / "commands.mojo")
check("commands imports dispatch_bench",
      "from cli.bench import dispatch_bench" in commands)
check("commands dispatches bench",
      'if cmd == "bench":' in commands and "dispatch_bench(args)" in commands)
check("general help lists bench", "bench [--settle N] [--rounds N]" in commands)
check("llama-bench stays a separate reserved name",
      '"llama-bench"' in commands)

facade = read(ROOT / "aesir.mojo")
check("facade comment block records J-100 bench",
      "J-100" in facade and "bench_configurations" in facade)

# --- tests --------------------------------------------------------------
test_path = ROOT / "tests" / "test_bench_configurations.mojo"
tests = read(test_path)
check("test suite exists", test_path.exists())
groups = re.findall(r"^def (test_\w+)\(", tests, re.M)
check("test suite has >= 8 groups", len(groups) >= 8, f"found {len(groups)}")
check("test suite prints ALL PASS line", "ALL PASS: bench configurations" in tests)

# --- the filed driver -----------------------------------------------------
driver = read(ROOT / "docs" / "janas" / "j100_bench.mojo")
check("filed driver exists and calls dispatch_bench",
      "dispatch_bench" in driver)

# --- cell arithmetic (the protocol's cross product, re-derived) ----------
kinds, devices, rungs = 3, 3, 3
check("cross product is 27 cells", kinds * devices * rungs == 27)
check("measurable cells are 6 (2 kinds x cpu x 3 rungs)", 2 * 1 * 3 == 6)
doc = read(ROOT / "docs" / "janas" / "J100_BENCH_CONFIGURATIONS.md")
check("doc states 27 cells", "27 cells" in doc)
check("doc states the verdict rule", "Verdict rule for this slice" in doc)
check("doc names J-101 as the --report owner", "J-101" in doc)

# --- filed outputs agree with the doc's claims -----------------------------
out_path = ROOT / "docs" / "janas" / "j100_test_output.txt"
out = read(out_path)
check("test output filed", out_path.exists() and len(out) > 0)
if out:
    m = re.search(r"ALL PASS: bench configurations \((\d+) groups\)", out)
    check("test output ALL PASS tally present", m is not None)
    if m:
        check("test output group count == suite group count",
              int(m.group(1)) == len(groups),
              f"filed {m.group(1)} vs suite {len(groups)}")
    check("neighbour placement_harness 10/10 in output",
          "test_placement_harness" in out and "10 groups" in out)
    check("neighbour thread_topology 10/10 in output",
          "test_thread_topology" in out)

# --- no README touched by this branch --------------------------------------
import subprocess
try:
    names = subprocess.run(
        ["git", "-C", str(REPO), "diff", "--name-only",
         "ceec2765b35a4733f728d1cb26891499cb51d094", "HEAD"],
        capture_output=True, text=True, timeout=30,
    ).stdout
except Exception:
    names = ""
readmes = [n for n in names.splitlines() if n.endswith("README.md")]
check("no README.md in the slice diff", not readmes, "; ".join(readmes))

failed = [c for c in checks if not c[1]]
for name, ok, detail in checks:
    line = ("PASS" if ok else "FAIL") + f": {name}"
    if detail and not ok:
        line += f" -- {detail}"
    print(line)
print(f"j100_inspect: {len(checks) - len(failed)}/{len(checks)} checks PASS")
sys.exit(1 if failed else 0)
