from tests.test_vulkan_layer_a065 import (
    test_vulkan_layer_oracle_parity,
    test_vulkan_layer_known_value,
    test_vulkan_layer_standalone_index,
    test_vulkan_layer_rejection,
    test_vulkan_layer_dispatch_evidence,
)


def main() raises:
    test_vulkan_layer_oracle_parity()
    test_vulkan_layer_known_value()
    test_vulkan_layer_standalone_index()
    test_vulkan_layer_rejection()
    test_vulkan_layer_dispatch_evidence()
    print("A065_DRIVER_ALL_PASS")
