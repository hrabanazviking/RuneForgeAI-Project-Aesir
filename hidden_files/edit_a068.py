#!/usr/bin/env python3
"""A-068 device-side edits: IQ SPIR-V dedup into the generated
header, run_all registration + re-pin, A-055 pipeline test pins.
Every replacement is anchor-asserted; any miss aborts."""
import pathlib, re, sys

ROOT = pathlib.Path("/home/volmarr/aesir-team-01")

# ---- 1. Shim IQ dedup (A-062 precedent; generated words verified
# byte-identical to the hand-embedded arrays before this run) ----
shim_path = ROOT / "aesir_engine/vulkan_buffer_shim.c"
header = (ROOT / "aesir_engine/shaders/generated/aesir_shaders_spv.h").read_text()
for name in ["kIq2XxsGemvSpv", "kIq3XxsGemvSpv", "kIq4NlGemvSpv", "kIq1SGemvSpv",
             "kQ80GemmSpv", "kGemmF32Spv"]:
    assert name in header, f"generated header lacks {name}"
lines = shim_path.read_text().splitlines(keepends=True)
for arr in ["kIq2XxsGemvSpv", "kIq1sGemvSpv", "kIq3XxsGemvSpv", "kIq4NlGemvSpv"]:
    start = None
    for i, ln in enumerate(lines):
        if ln.startswith(f"static const uint32_t {arr}[] = {{"):
            start = i
            break
    assert start is not None, f"hand array {arr} not found"
    end = None
    for j in range(start, len(lines)):
        if lines[j].rstrip() == "};":
            end = j
            break
    assert end is not None, f"hand array {arr} unterminated"
    # The Bytes line follows (possibly after blank lines within 3).
    bend = None
    for j in range(end + 1, min(end + 4, len(lines))):
        if lines[j].startswith(f"static const size_t {arr}Bytes"):
            bend = j
            break
    assert bend is not None, f"Bytes line for {arr} not found"
    del lines[start:bend + 1]
    print(f"dedup: removed {arr} hand array ({bend - start + 1} lines)")
text = "".join(lines)
# iq1_s: the generator names it kIq1SGemvSpv (capital S); repoint
# the remaining call-site references from the hand name.
n_ren = text.count("kIq1sGemvSpv")
text = text.replace("kIq1sGemvSpv", "kIq1SGemvSpv")
print(f"dedup: renamed {n_ren} kIq1sGemvSpv references to kIq1SGemvSpv")
assert "static const uint32_t kIq" not in text
shim_path.write_text(text)

# ---- 2. run_all.mojo registration + re-pin 501 -> 507 ----
ra_path = ROOT / "aesir_engine/tests/run_all.mojo"
ra = ra_path.read_text()
anchor = """from tests.test_vulkan_layer_a065 import (
    test_vulkan_layer_oracle_parity,
    test_vulkan_layer_known_value,
    test_vulkan_layer_standalone_index,
    test_vulkan_layer_rejection,
    test_vulkan_layer_dispatch_evidence,
)
"""
assert ra.count(anchor) == 1
ra = ra.replace(anchor, anchor + """from tests.test_vulkan_gemm_a068 import (
    test_vulkan_prefill_gemm_oracle_parity,
    test_vulkan_prefill_gemm_known_value,
    test_vulkan_prefill_gemm_f32_parity,
    test_vulkan_prefill_gemm_batch_independence,
    test_vulkan_prefill_gemm_rejection,
    test_vulkan_prefill_gemm_dispatch_evidence,
)
""")
anchor2 = '    run_case(ledger, "gpu.vulkan_layer_dispatch_evidence", test_vulkan_layer_dispatch_evidence)\n'
assert ra.count(anchor2) == 1
ra = ra.replace(anchor2, anchor2 + """    run_case(ledger, "gpu.vulkan_prefill_gemm_oracle_parity", test_vulkan_prefill_gemm_oracle_parity)
    run_case(ledger, "gpu.vulkan_prefill_gemm_known_value", test_vulkan_prefill_gemm_known_value)
    run_case(ledger, "gpu.vulkan_prefill_gemm_f32_parity", test_vulkan_prefill_gemm_f32_parity)
    run_case(ledger, "gpu.vulkan_prefill_gemm_batch_independence", test_vulkan_prefill_gemm_batch_independence)
    run_case(ledger, "gpu.vulkan_prefill_gemm_rejection", test_vulkan_prefill_gemm_rejection)
    run_case(ledger, "gpu.vulkan_prefill_gemm_dispatch_evidence", test_vulkan_prefill_gemm_dispatch_evidence)
""")
anchor3 = "    ledger.finish(501)\n"
assert ra.count(anchor3) == 1
ra = ra.replace(anchor3, """    # A-068 re-pin: 501 -> 507 -- six Vulkan prefill GEMM
    # cases (gpu.vulkan_prefill_gemm_* in
    # tests/test_vulkan_gemm_a068.mojo) counted on top of the
    # A-065 seat pin on this branch base; A-066/A-067 are built
    # in parallel and the union total reconciles at banking.
    ledger.finish(507)
""")
ra_path.write_text(ra)
print("run_all: registered 6 cases, pin 501 -> 507")

# ---- 3. A-055 pipeline test pins 13 -> 19 kernels ----
t_path = ROOT / "aesir_engine/tests/test_spirv_pipeline_a055.mojo"
t = t_path.read_text()
subs = [
    ('"\\"kernel_count\\": 13"', '"\\"kernel_count\\": 19"'),
    ("SPIR-V manifest (13 kernels:", "SPIR-V manifest (19 kernels:"),
    ("SPIR-V embedded header (13 arrays", "SPIR-V embedded header (19 arrays"),
    ('"q4k_gemv", "q5_k_gemv", "q6_k_gemv", "q8_0_gemv",',
     '"q4k_gemv", "q5_k_gemv", "q6_k_gemv", "q8_0_gemv",\n        "q8_0_gemm", "gemm_f32", "iq1_s_gemv", "iq2_xxs_gemv",\n        "iq3_xxs_gemv", "iq4_nl_gemv",'),
    ('"kQ4kGemvSpv", "kQ5KGemvSpv", "kQ6KGemvSpv", "kQ80GemvSpv",',
     '"kQ4kGemvSpv", "kQ5KGemvSpv", "kQ6KGemvSpv", "kQ80GemvSpv",\n        "kQ80GemmSpv", "kGemmF32Spv", "kIq1SGemvSpv", "kIq2XxsGemvSpv",\n        "kIq3XxsGemvSpv", "kIq4NlGemvSpv",'),
]
for old, new in subs:
    assert t.count(old) == 1, f"A-055 test anchor not unique: {old[:50]}"
    t = t.replace(old, new)
t_path.write_text(t)
print("a055 test: kernel_count pin 13 -> 19, names/consts extended")
print("EDIT_A068_ALL_OK")
