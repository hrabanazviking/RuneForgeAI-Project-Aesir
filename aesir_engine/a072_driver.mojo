from tests.test_vulkan_batch_a072 import (
    test_vulkan_continuous_batch_four_match_single,
    test_vulkan_continuous_batch_heterogeneous,
    test_vulkan_continuous_batch_dynamic_admission,
    test_vulkan_continuous_batch_isolation,
    test_vulkan_continuous_batch_rejection,
    test_vulkan_continuous_batch_single_slot_serial,
)


def main() raises:
    test_vulkan_continuous_batch_four_match_single()
    test_vulkan_continuous_batch_heterogeneous()
    test_vulkan_continuous_batch_dynamic_admission()
    test_vulkan_continuous_batch_isolation()
    test_vulkan_continuous_batch_rejection()
    test_vulkan_continuous_batch_single_slot_serial()
    print("A072_DRIVER_ALL_PASS")
