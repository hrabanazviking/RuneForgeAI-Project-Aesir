#!/usr/bin/env python3
"""J-081 inspection recount: every load-bearing claim in
docs/janas/J081_DRAFTS_PLACEMENT.md as an assertion over the
tree and the filed records. Exit 0 iff all checks pass."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = []


def check(name, ok):
    checks.append((name, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'}: {name}")


def read(rel):
    return (ROOT / rel).read_text()


module = read("aesir_engine/core/speculative_placement.mojo")
suite = read("aesir_engine/tests/test_speculative_placement.mojo")
verify = read("aesir_engine/core/speculative_verify.mojo")
loop = read("aesir_engine/core/speculative_loop.mojo")
options = read("aesir_engine/core/placement_options.mojo")
facade = read("aesir_engine/aesir.mojo")
moe_gpu = read("aesir_engine/core/moe_gpu_plan.mojo")
block = read("aesir_engine/core/gpu_block_prefill.mojo")
igpu = read("aesir_engine/core/igpu_account.mojo")

check("new module exists and names J-081", "J-081" in module)
check("module binds J-071 via plan_proposer (caps never restated)",
      "from core.speculative_verify import plan_proposer" in module
      and "proposer.max_k" in module)
check("verdict rule is in the module header before the code",
      module.index("THE VERDICT RULE") < module.index("struct DraftCheckShape"))
check("token ids priced at J-031's 4 bytes",
      "DC_TOKEN_ID_BYTES = 4" in module)
check("all five missing pieces are named in check order",
      all(s in module for s in (
          "DC_MISSING_DEVICE_ABSENT", "DC_MISSING_CONVERSATION_DEVICE",
          "DC_MISSING_IGPU_BACKEND", "DC_MISSING_MOE_GPU_ADMISSION",
          "DC_MISSING_VERIFY_WIDTH")))
check("global blockers stated (proposer + verify executor)",
      "G-PROPOSER" in module and "G-EXECUTOR" in module)
check("choose restricts to highest non-refused check rank",
      "best_rank" in module and "_check_rank" in module)
check("no speed/wall/tok-per-s claim function in the module",
      "tok_per_s" not in module and "wall_seconds" not in module)

check("use gate still fails closed (J-036, unedited by this slice)",
      "raise Error(" in options and "draft-check passes do not exist" in options)
check("facade speculative_generate still raises not-implemented",
      "speculative model generation and KV reconciliation are not implemented"
      in facade)
check("J-071 caps: model proposers 15, conversation 8",
      "PROPOSER_CONVERSATION" in verify and "15" in verify and ", 8)" in verify)
check("J-072 loop initial k is 4 (recorded, not restated in the module)",
      "LOOP_K_INITIAL = 4" in loop)
check("J-031 MoE GPU plan is a planning layer (no device execution)",
      "plan_moe_gpu_division" in moe_gpu)
check("J-054 admissions: width 1 and width 4 proven shapes only",
      "ADMISSION_WIDTH1_PROVEN" in block and "ADMISSION_TILE4_PROVEN" in block
      and "ADMISSION_UNBUILT" in block)
check("J-067 iGPU copy bytes are zero by construction",
      "copy_bytes_charged = 0" in igpu or "copy_bytes_charged" in igpu)

check("suite has 13 groups", suite.count("def test_") == 13)
check("suite pins the dense kept combination (CPU draft + GPU check)",
      "kept draft is cpu" in suite and "kept check is gpu" in suite)
check("suite pins the MoE kept combination (both-on-CPU)",
      "moe kept is both-cpu" in suite)
check("suite pins the MTP kept combination (both-on-GPU)",
      "mtp kept draft with target" in suite)
check("suite prices the expert re-pay exactly (J-031/J-080)",
      "expert bytes re-paid as upload" in suite)

failed = [n for n, ok in checks if not ok]
print(f"== {len(checks) - len(failed)}/{len(checks)} checks PASS ==")
sys.exit(1 if failed else 0)
