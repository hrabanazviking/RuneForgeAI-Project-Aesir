from tests.test_vulkan_async_a071 import (
    test_vulkan_async_token_identity,
    test_vulkan_async_no_wait_idle,
    test_vulkan_async_timeline_sane,
    test_vulkan_async_dispatch_queueing,
    test_vulkan_async_rejection,
    test_vulkan_async_dispatch_evidence,
    _free_weights,
    _ModelFixture,
    _upload_weights,
    _prompt,
)
from core.vulkan_decode import VulkanDecode
from core.vulkan_async import VulkanAsync


def main() raises:
    test_vulkan_async_token_identity()
    test_vulkan_async_no_wait_idle()
    test_vulkan_async_timeline_sane()
    test_vulkan_async_dispatch_queueing()
    test_vulkan_async_rejection()
    test_vulkan_async_dispatch_evidence()
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var trace = VulkanDecode.generate_async_traced(
        weights, _prompt(), 8, 256, 4, 2, 64, 512, 96, 16,
        Float32(1.0e-5), Float32(10000.0),
    )
    print("A071_TIMELINE_TRACE_BEGIN")
    for i in range(len(trace.tokens)):
        var busy = trace.busy_ns[i]
        var span = trace.span_ns[i]
        var frac = Float64(0.0)
        if span > 0:
            frac = Float64(busy) / Float64(span)
        print("token", i, "id", trace.tokens[i], "submits", trace.submits[i], "gpu_busy_ns", busy, "span_ns", span, "busy_fraction", frac, "host_wait_ns", trace.host_wait_ns[i])
    var st = VulkanAsync.stats()
    print("totals submits", st.submits, "completed", st.completed, "max_depth", st.max_depth, "wait_idle", st.wait_idle_calls, "fence_waits", st.fence_waits, "host_wait_ns", st.host_wait_ns, "gpu_busy_ns", st.gpu_busy_ns, "gpu_span_ns", st.gpu_span_ns, "busy_fraction", st.busy_fraction())
    print("A071_TIMELINE_TRACE_END")
    _free_weights(weights)
    print("A071_DRIVER_ALL_PASS")
