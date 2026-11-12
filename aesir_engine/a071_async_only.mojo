from tests.test_vulkan_async_a071 import _ModelFixture, _upload_weights, _prompt
from core.vulkan_decode import VulkanDecode

def main() raises:
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var toks = VulkanDecode.generate_async(weights, _prompt(), 8, 256, 4, 2, 64, 512, 96, 16, Float32(1.0e-5), Float32(10000.0))
    for i in range(len(toks)):
        print("async token", i, toks[i])
    print("ASYNC_ONLY_PASS")
