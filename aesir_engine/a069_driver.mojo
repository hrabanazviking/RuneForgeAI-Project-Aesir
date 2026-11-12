from tests.test_vulkan_prefill_a069 import (
    test_vulkan_chunked_prefill_cpu_oracle_parity,
    test_vulkan_chunked_prefill_identical_to_unchunked,
    test_vulkan_chunked_prefill_causal_isolation,
    test_vulkan_chunked_prefill_rope_global_positions,
    test_vulkan_chunked_prefill_kv_append_chunk_slots,
    test_vulkan_chunked_prefill_rejection,
    test_vulkan_chunked_prefill_dispatch_and_bounds,
)


def main() raises:
    test_vulkan_chunked_prefill_cpu_oracle_parity()
    test_vulkan_chunked_prefill_identical_to_unchunked()
    test_vulkan_chunked_prefill_causal_isolation()
    test_vulkan_chunked_prefill_rope_global_positions()
    test_vulkan_chunked_prefill_kv_append_chunk_slots()
    test_vulkan_chunked_prefill_rejection()
    test_vulkan_chunked_prefill_dispatch_and_bounds()
    print("A069_DRIVER_ALL_PASS")
