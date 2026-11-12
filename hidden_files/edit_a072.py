import pathlib
p = pathlib.Path("aesir_engine/tests/test_vulkan_batch_a072.mojo")
s = p.read_text()
helper = '''

def _free_weights(weights: VulkanDecodeWeights):
    # The shim caps live buffers at 128 slots; cases must
    # hand their fixture weights back or later cases starve.
    for li in range(len(weights.layers)):
        var w = weights.layers[li]
        VulkanBuffers.free(w.g_attn)
        VulkanBuffers.free(w.g_ffn)
        VulkanBuffers.free(w.wq)
        VulkanBuffers.free(w.wk)
        VulkanBuffers.free(w.wv)
        VulkanBuffers.free(w.wo)
        VulkanBuffers.free(w.w_gate)
        VulkanBuffers.free(w.w_up)
        VulkanBuffers.free(w.w_down)
    VulkanBuffers.free(weights.embedding)
    VulkanBuffers.free(weights.g_final)
    VulkanBuffers.free(weights.w_head)
'''
anchor = "def _prompt0() -> List[Int]:"
assert s.count(anchor) == 1
s = s.replace(anchor, helper.strip() + "\n\n\n" + anchor, 1)
prints = [
    '    print("Vulkan continuous batch 4-seq match solo + oracle anchor: PASS")',
    '    print("Vulkan continuous batch heterogeneous lengths/gens: PASS")',
    '    print("Vulkan continuous batch dynamic admission (2-slot churn): PASS")',
    '    print("Vulkan continuous batch isolation (no KV cross-talk): PASS")',
    '    print("Vulkan continuous batch rejection (7 of 7 pre-dispatch): PASS")',
    '    print("Vulkan continuous batch single-slot serial equivalence: PASS")',
]
for line in prints:
    assert s.count(line) == 1, line
    s = s.replace(line, "    _free_weights(weights)\n" + line, 1)
p.write_text(s)
print("EDIT_OK")
