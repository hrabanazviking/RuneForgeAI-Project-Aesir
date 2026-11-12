import pathlib
# 1) SPIRV pipeline pins 22 -> 25
p = pathlib.Path('/home/volmarr/aesir-team-02/aesir_engine/tests/test_spirv_pipeline_a055.mojo')
s = p.read_text()
repls = [
 ('if "\\"kernel_count\\": 22" not in manifest:', 'if "\\"kernel_count\\": 25" not in manifest:'),
 ('raise Error("manifest kernel_count is not 22")', 'raise Error("manifest kernel_count is not 25")'),
]
for a,b in repls:
    assert a in s, a
    s = s.replace(a,b)
old_names = '''        "q8_0_gemm", "gemm_f32", "iq1_s_gemv", "iq2_xxs_gemv",
        "iq3_xxs_gemv", "iq4_nl_gemv",'''
new_names = '''        "q8_0_gemm", "gemm_f32", "iq1_s_gemv", "iq2_xxs_gemv",
        "iq3_xxs_gemv", "iq4_nl_gemv", "rope_batched",
        "kv_append_chunk", "attention_prefill",'''
assert old_names in s; s = s.replace(old_names, new_names)
old_print = 'print("SPIR-V manifest (22 kernels: 13 prior + embed_gather + kv_append + attention_decode_strided registered A-066 + q8_0_gemm + gemm_f32 + 4 IQ GEMV registered A-068, deterministic): PASS")'
new_print = 'print("SPIR-V manifest (25 kernels: 22 prior + rope_batched + kv_append_chunk + attention_prefill registered A-069, deterministic): PASS")'
assert old_print in s; s = s.replace(old_print, new_print)
old_consts = '''        "kQ80GemmSpv", "kGemmF32Spv", "kIq1SGemvSpv", "kIq2XxsGemvSpv",
        "kIq3XxsGemvSpv", "kIq4NlGemvSpv",'''
new_consts = '''        "kQ80GemmSpv", "kGemmF32Spv", "kIq1SGemvSpv", "kIq2XxsGemvSpv",
        "kIq3XxsGemvSpv", "kIq4NlGemvSpv", "kRopeBatchedSpv",
        "kKvAppendChunkSpv", "kAttentionPrefillSpv",'''
assert old_consts in s; s = s.replace(old_consts, new_consts)
old_hprint = 'print("SPIR-V embedded header (22 arrays + registry table): PASS")'
new_hprint = 'print("SPIR-V embedded header (25 arrays + registry table): PASS")'
assert old_hprint in s; s = s.replace(old_hprint, new_hprint)
p.write_text(s); print('SPIRV_TEST_OK')
# 2) run_all: import + cases + pin
p2 = pathlib.Path('/home/volmarr/aesir-team-02/aesir_engine/tests/run_all.mojo')
t = p2.read_text()
old_imp = '''from tests.test_vulkan_gemm_a068 import (
    test_vulkan_prefill_gemm_oracle_parity,'''
new_imp = '''from tests.test_vulkan_prefill_a069 import (
    test_vulkan_chunked_prefill_cpu_oracle_parity,
    test_vulkan_chunked_prefill_identical_to_unchunked,
    test_vulkan_chunked_prefill_causal_isolation,
    test_vulkan_chunked_prefill_rope_global_positions,
    test_vulkan_chunked_prefill_kv_append_chunk_slots,
    test_vulkan_chunked_prefill_rejection,
    test_vulkan_chunked_prefill_dispatch_and_bounds,
)
from tests.test_vulkan_gemm_a068 import (
    test_vulkan_prefill_gemm_oracle_parity,'''
assert old_imp in t; t = t.replace(old_imp, new_imp, 1)
old_case = '    run_case(ledger, "gpu.vulkan_prefill_gemm_oracle_parity", test_vulkan_prefill_gemm_oracle_parity)'
new_case = '''    run_case(ledger, "gpu.vulkan_chunked_prefill_cpu_oracle_parity", test_vulkan_chunked_prefill_cpu_oracle_parity)
    run_case(ledger, "gpu.vulkan_chunked_prefill_identical_to_unchunked", test_vulkan_chunked_prefill_identical_to_unchunked)
    run_case(ledger, "gpu.vulkan_chunked_prefill_causal_isolation", test_vulkan_chunked_prefill_causal_isolation)
    run_case(ledger, "gpu.vulkan_chunked_prefill_rope_global_positions", test_vulkan_chunked_prefill_rope_global_positions)
    run_case(ledger, "gpu.vulkan_chunked_prefill_kv_append_chunk_slots", test_vulkan_chunked_prefill_kv_append_chunk_slots)
    run_case(ledger, "gpu.vulkan_chunked_prefill_rejection", test_vulkan_chunked_prefill_rejection)
    run_case(ledger, "gpu.vulkan_chunked_prefill_dispatch_and_bounds", test_vulkan_chunked_prefill_dispatch_and_bounds)
''' + old_case
assert old_case in t; t = t.replace(old_case, new_case, 1)
old_pin = '    ledger.finish(518)'
new_pin = '''    # A-069 re-pin: 518 -> 525 -- seven chunked prefill cases
    # (gpu.vulkan_chunked_prefill_* in
    # tests/test_vulkan_prefill_a069.mojo) counted on top of
    # the A-068 seat pin.
    ledger.finish(525)'''
assert old_pin in t; t = t.replace(old_pin, new_pin, 1)
p2.write_text(t); print('RUN_ALL_OK')
