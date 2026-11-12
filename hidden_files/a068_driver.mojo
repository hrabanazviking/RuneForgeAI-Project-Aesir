from tests.test_vulkan_gemm_a068 import (
    test_vulkan_prefill_gemm_oracle_parity,
    test_vulkan_prefill_gemm_known_value,
    test_vulkan_prefill_gemm_f32_parity,
    test_vulkan_prefill_gemm_batch_independence,
    test_vulkan_prefill_gemm_rejection,
    test_vulkan_prefill_gemm_dispatch_evidence,
)


def main() raises:
    test_vulkan_prefill_gemm_oracle_parity()
    test_vulkan_prefill_gemm_known_value()
    test_vulkan_prefill_gemm_f32_parity()
    test_vulkan_prefill_gemm_batch_independence()
    test_vulkan_prefill_gemm_rejection()
    test_vulkan_prefill_gemm_dispatch_evidence()
    print("A068_DRIVER_ALL_PASS")
