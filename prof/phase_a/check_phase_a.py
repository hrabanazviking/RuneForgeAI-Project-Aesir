#!/usr/bin/env python3
"""H016 PRÓF (TEST-ONLY): Phase-A evidence aggregator.

Verifies every Phase-A artifact exists, is non-empty, and cross-references
correctly, so the Phase-A gate review can be machine-checked.

- File I/O only: imports no engine module, shells out to nothing.
- Exits 0 on PASS, non-zero on any FAIL.
- Usage: python3 prof/phase_a/check_phase_a.py [repo_root]
"""

import json
import os
import sys

REPO = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

results = []


def check(name, cond, detail=""):
    results.append((name, bool(cond), detail))
    status = "PASS" if cond else "FAIL"
    print(f"[{status}] {name}" + (f" — {detail}" if detail and not cond else ""))


def read(path):
    with open(os.path.join(REPO, path), "r", encoding="utf-8") as f:
        return f.read()


def exists_nonempty(path):
    p = os.path.join(REPO, path)
    return os.path.isfile(p) and os.path.getsize(p) > 0


# --- H001: toolchain native ---
check("H001 native log exists/non-empty",
      exists_nonempty("data/phase_a/toolchain_native_attempt.log"))
check("H001 verdict doc exists/non-empty",
      exists_nonempty("docs/phase_a/MOJO_TOOLCHAIN_VERDICT.md"))

# --- H002: cross-compile ---
check("H002 cross log exists/non-empty",
      exists_nonempty("data/phase_a/toolchain_cross_attempt.log"))
check("H002 recipe doc exists/non-empty",
      exists_nonempty("docs/phase_a/CROSS_COMPILE_RECIPE.md"))

# --- H003: PCIe census ---
check("H003 census dir exists with files",
      os.path.isdir(os.path.join(REPO, "data/phase_a/pcie_census"))
      and len(os.listdir(os.path.join(REPO, "data/phase_a/pcie_census"))) > 0)
check("H003 census notes exist/non-empty",
      exists_nonempty("data/phase_a/pcie_census/CENSUS_NOTES.md"))

# --- H004: mechanism verdict ---
check("H004 verdict doc exists/non-empty",
      exists_nonempty("docs/phase_a/MECHANISM_VERDICT.md"))
try:
    mv = read("docs/phase_a/MECHANISM_VERDICT.md")
    check("H004 cites census BDF 0001:01:00.0", "0001:01:00.0" in mv)
    check("H004 names the Hailo device", "hailo" in mv.lower())
except OSError as e:
    check("H004 cross-ref readable", False, str(e))

# --- H005/H006: plunder guides ---
check("H005 transport guide exists/non-empty",
      exists_nonempty("docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md"))
check("H006 HEF guide exists/non-empty",
      exists_nonempty("docs/plunder/HAILO_HEF_CONTAINER_GUIDE.md"))

# --- H007: NEON baseline ---
check("H007 baseline JSON exists/non-empty",
      exists_nonempty("data/phase_a/neon_baseline.json"))
check("H007 spike source exists/non-empty",
      exists_nonempty("spikes/phase_a/neon_fp16_matmul.mojo"))
try:
    nb = json.loads(read("data/phase_a/neon_baseline.json"))
    check("H007 JSON has median_gflops", "median_gflops" in nb)
    check("H007 JSON has 11 runs",
          isinstance(nb.get("runs_ns_per_matmul"), list)
          and len(nb["runs_ns_per_matmul"]) == 11)
    check("H007 max_abs_err is 0.0",
          nb.get("correctness", {}).get("max_abs_err") == 0.0)
except (OSError, json.JSONDecodeError) as e:
    check("H007 JSON valid", False, str(e))

# --- H008: loader port check ---
check("H008 port-check JSON exists/non-empty",
      exists_nonempty("data/phase_a/loader_port_check.json"))
check("H008 issues doc exists/non-empty",
      exists_nonempty("docs/phase_a/LOADER_PORT_ISSUES.md"))
check("H008 spike source exists/non-empty",
      exists_nonempty("spikes/phase_a/gguf_parse_spike.mojo"))
try:
    lp = json.loads(read("data/phase_a/loader_port_check.json"))
    files = lp.get("arm64_parse", {}).get("files", [])
    check("H008 JSON covers 3 test files", len(files) == 3)
    check("H008 all arch outputs match",
          all(f.get("arch_outputs_match") for f in files) and len(files) == 3)
except (OSError, json.JSONDecodeError) as e:
    check("H008 JSON valid", False, str(e))

# --- H009: version pins ---
check("H009 version pins exist/non-empty",
      exists_nonempty("data/phase_a/VERSION_PINS.md"))

# --- H010: gate review ---
check("H010 gate review exists/non-empty",
      exists_nonempty("docs/phase_a/PHASE_A_GATE_REVIEW.md"))
try:
    gr = read("docs/phase_a/PHASE_A_GATE_REVIEW.md")
    check("H010 has GATE VERDICT section", "GATE VERDICT" in gr)
    check("H010 tables H001-H009", all(f"H00{i}" in gr for i in range(1, 10)))
except OSError as e:
    check("H010 cross-ref readable", False, str(e))

# --- H011: npu_gate retirement ---
check("H011 retirement doc exists/non-empty",
      exists_nonempty("docs/phase_a/NPU_GATE_RETIREMENT.md"))
check("H011 npu_gate.mojo is gone",
      not os.path.exists(os.path.join(REPO, "aesir_engine/core/npu_gate.mojo")))

# --- H012/H013: VFIO/UIO probes ---
for probe in ("vfio_probe.json", "uio_probe.json"):
    p = f"data/phase_a/{probe}"
    check(f"H012/13 {probe} exists/non-empty", exists_nonempty(p))
    try:
        json.loads(read(p))
        check(f"H012/13 {probe} valid JSON", True)
    except (OSError, json.JSONDecodeError) as e:
        check(f"H012/13 {probe} valid JSON", False, str(e))

# --- H014: firmware catalogue ---
check("H014 firmware catalogue exists/non-empty",
      exists_nonempty("data/phase_a/firmware_catalogue.json"))
try:
    fc = json.loads(read("data/phase_a/firmware_catalogue.json"))
    check("H014 catalogue has non-empty files list",
          isinstance(fc, dict) and isinstance(fc.get("files"), list)
          and len(fc["files"]) > 0)
except (OSError, json.JSONDecodeError) as e:
    check("H014 catalogue valid JSON", False, str(e))

# --- H015: POSIX baseline ---
check("H015 output log exists/non-empty",
      exists_nonempty("data/phase_a/posix_baseline/output.log"))
check("H015 spike source exists/non-empty",
      exists_nonempty("spikes/phase_a/posix_baseline.mojo"))
try:
    log = read("data/phase_a/posix_baseline/output.log")
    check("H015 log shows H015_ALL_SYSCALLS_OK",
          "H015_ALL_SYSCALLS_OK" in log)
except OSError as e:
    check("H015 log readable", False, str(e))

# --- summary ---
fails = [name for name, ok, _ in results if not ok]
print(f"\n{len(results) - len(fails)}/{len(results)} checks passed")
if fails:
    print("FAILURES:")
    for name in fails:
        print(f"  - {name}")
    sys.exit(1)
print("PHASE_A_EVIDENCE_PASS")
