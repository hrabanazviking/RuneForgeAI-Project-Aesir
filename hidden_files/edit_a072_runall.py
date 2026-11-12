import pathlib
p = pathlib.Path("aesir_engine/tests/run_all.mojo")
s = p.read_text()
imp_anchor = """from tests.test_vulkan_prefill_a069 import (
    test_vulkan_chunked_prefill_cpu_oracle_parity,
    test_vulkan_chunked_prefill_identical_to_unchunked,
    test_vulkan_chunked_prefill_causal_isolation,
    test_vulkan_chunked_prefill_rope_global_positions,
    test_vulkan_chunked_prefill_kv_append_chunk_slots,
    test_vulkan_chunked_prefill_rejection,
    test_vulkan_chunked_prefill_dispatch_and_bounds,
)
"""
assert s.count(imp_anchor) == 1
new_import = imp_anchor + """from tests.test_vulkan_batch_a072 import (
    test_vulkan_continuous_batch_four_match_single,
    test_vulkan_continuous_batch_heterogeneous,
    test_vulkan_continuous_batch_dynamic_admission,
    test_vulkan_continuous_batch_isolation,
    test_vulkan_continuous_batch_rejection,
    test_vulkan_continuous_batch_single_slot_serial,
)
"""
s = s.replace(imp_anchor, new_import, 1)
case_anchor = '    run_case(ledger, "gpu.vulkan_chunked_prefill_dispatch_and_bounds", test_vulkan_chunked_prefill_dispatch_and_bounds)\n'
assert s.count(case_anchor) == 1
new_cases = case_anchor + """    run_case(ledger, "gpu.vulkan_continuous_batch_four_match_single", test_vulkan_continuous_batch_four_match_single)
    run_case(ledger, "gpu.vulkan_continuous_batch_heterogeneous", test_vulkan_continuous_batch_heterogeneous)
    run_case(ledger, "gpu.vulkan_continuous_batch_dynamic_admission", test_vulkan_continuous_batch_dynamic_admission)
    run_case(ledger, "gpu.vulkan_continuous_batch_isolation", test_vulkan_continuous_batch_isolation)
    run_case(ledger, "gpu.vulkan_continuous_batch_rejection", test_vulkan_continuous_batch_rejection)
    run_case(ledger, "gpu.vulkan_continuous_batch_single_slot_serial", test_vulkan_continuous_batch_single_slot_serial)
"""
s = s.replace(case_anchor, new_cases, 1)
pin_anchor = "    ledger.finish(531)\n"
assert s.count(pin_anchor) == 1
new_pin = """    # A-072 re-pin: 531 -> 537 -- six continuous batching
    # cases (gpu.vulkan_continuous_batch_* in
    # tests/test_vulkan_batch_a072.mojo) counted on top of
    # the A-070 seat pin on this branch base; A-071 is built
    # in parallel and the union total reconciles at banking.
    ledger.finish(537)
"""
s = s.replace(pin_anchor, new_pin, 1)
p.write_text(s)
print("RUNALL_EDIT_OK")
