#!/usr/bin/env python3
"""J-101 inspect: mechanically re-derive the load-bearing claims of
docs/janas/J101_MACHINE_REPORT.md from this tree.

Run from the repo root (the worktree root):
    python3 aesir_engine/docs/janas/j101_inspect.py
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


# --- the new core module ---------------------------------------------
mod_path = ROOT / "core" / "machine_report.mojo"
mod = read(mod_path)
check("core module exists", mod_path.exists())
for sym in (
    "struct ModelRow",
    "def filed_model_rows",
    "def model_table",
    "def device_refusal_summary",
    "def report_artefact",
    "machine_report(report)",
    "device_line()",
):
    check(f"core module carries {sym!r}", sym in mod)
check("core module states J-101", "J-101" in mod)
check("core module states the evidence rule", "NOT PROVEN" in mod and "never" in mod)
for cited in ("2.389 tok/s", "2.556 tok/s", "J-030", "MEASURED-INDICATIVE",
              "J-091", "58720256", "CAP_REFUSED", "J-032", "blocker B2"):
    check(f"filed row cites {cited!r}", cited in mod)

# --- J-100's module is extended, not forked ----------------------------
bench_mod = read(ROOT / "core" / "bench_configurations.mojo")
check("J-100 core still carries machine_report", "def machine_report" in bench_mod)
check("J-100 core still refuses nothing of J-101's render",
      "report_artefact" not in bench_mod)

# --- the CLI ------------------------------------------------------------
cli_path = ROOT / "cli" / "bench.mojo"
cli = read(cli_path)
check("cli bench module exists", cli_path.exists())
check("cli accepts --report flag", '"--report"' in cli)
check("cli refuses --report with --pass", "refuses --pass" in cli)
check("cli calls report_artefact", "report_artefact" in cli)
check("cli calls filed_model_rows", "filed_model_rows" in cli)
check("cli still calls machine_report (J-100 path intact)",
      "machine_report(report)" in cli)
check("cli usage names --report", "[--report]" in cli)

# --- dispatch wiring unchanged -------------------------------------------
commands = read(ROOT / "cli" / "commands.mojo")
check("commands imports dispatch_bench", "dispatch_bench" in commands)
check("commands dispatches bench", '"bench"' in commands)

# --- facade comment -------------------------------------------------------
facade = read(ROOT / "aesir.mojo")
check("facade comment block records J-101", "J-101" in facade and "machine_report.mojo" in facade)

# --- tests ------------------------------------------------------------------
mr_test_path = ROOT / "tests" / "test_machine_report.mojo"
mr_test = read(mr_test_path)
check("machine report suite exists", mr_test_path.exists())
check("machine report suite has 6 groups", mr_test.count("def test_") == 6)
check("machine report suite prints ALL PASS line",
      "ALL PASS: machine report (6 groups)" in mr_test)
bc_test = read(ROOT / "tests" / "test_bench_configurations.mojo")
check("bench configurations suite exists", bc_test != "")
check("bench configurations suite has 8 groups", bc_test.count("def test_") == 8)
check("J-100 suite group 7 updated in-scope (J-101 change recorded)",
      "J-101 in-scope change" in bc_test and "--report + --pass" in bc_test.replace("+", " + ") or "--report+--pass" in bc_test)
check("J-100 suite no longer asserts --report alone refused",
      '["bench", "--report"]' not in bc_test)

# --- driver -------------------------------------------------------------------
driver = read(JANAS / "j101_bench.mojo")
check("filed driver exists and calls bench_main", "bench_main" in driver)

# --- doc ----------------------------------------------------------------------
doc = read(JANAS / "J101_MACHINE_REPORT.md")
check("doc exists", doc != "")
for phrase in ("0. Protocol", "evidence rule", "DEFERRED-WITH-REASON",
               "purplelongship", "NOT PROVEN", "J-100", "section 5",
               "FIXTURE"):
    check(f"doc states {phrase!r}", phrase in doc)

# --- filed outputs --------------------------------------------------------------
test_out = read(JANAS / "j101_test_output.txt")
check("test output filed", test_out != "")
check("test output: machine report 6/6", "ALL PASS: machine report (6 groups)" in test_out)
check("test output: bench configurations 8/8",
      "ALL PASS: bench configurations (8 groups)" in test_out)
check("test output: neighbour placement_harness 10/10", "10/10" in test_out)
fixture = read(JANAS / "j101_example_vm_fixture.txt")
check("VM fixture example filed", fixture != "")
check("VM fixture example labelled FIXTURE", "FIXTURE" in fixture)
check("fixture example carries the model table",
      "per-model read/write" in fixture and "OLMoE Q4_K_M" in fixture)
check("fixture example carries refusal reasons",
      "device lines with refusal reasons" in fixture)

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
print(f"j101_inspect: {len(checks) - len(failed)}/{len(checks)} checks PASS")
sys.exit(0 if not failed else 1)
