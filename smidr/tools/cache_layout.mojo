# Metadata/relative address diagnostic. No physical allocation or cache data.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan, checked_product
from smidr.cache_layout import CacheLayoutAssumptions, plan_cache_layout, cache_element_offset
from smidr.tools.source_inventory import _quote


def main() raises:
    var args = argv()
    if len(args) != 12 and len(args) != 13 and len(args) != 16:
        raise Error("usage: cache_layout <source> <query> <past> <capacity> <key_width> <value_width> <key_stride> <value_stride> <alignment> <pool> <provenance> [enumerate | region slot head component]")
    var plan = read_dense_semantic_plan(args[1], Int(args[2]), Int(args[3]), Int(args[4]))
    var policy = CacheLayoutAssumptions(Int(args[5]), Int(args[6]), Int(args[7]), Int(args[8]), Int(args[9]), Int(args[10]), args[11])
    var layout = plan_cache_layout(plan, policy)
    var text = String("{\"schema_version\":1,\"layout\":\"assumed_token_major\",\"hardware_layout_verified\":false,\"source_fingerprint_verified\":false,\"execution_tested\":false,\"device_access\":false")
    text += ",\"total_bytes\":" + String(layout.total_bytes) + ",\"provenance\":" + _quote(layout.policy.provenance) + ",\"regions\":["
    var probe_count = 0
    for i in range(len(layout.regions)):
        var r = layout.regions[i].copy()
        var dimension = layout.key_dim if i % 2 == 0 else layout.value_dim
        if i != 0:
            text += ","
        text += "{\"layer\":" + String(r.layer) + ",\"kind\":" + _quote(r.kind) + ",\"name\":" + _quote(r.name)
        text += ",\"source_tensor\":" + String(r.source_tensor) + ",\"source_view\":" + String(r.source_view)
        text += ",\"offset\":" + String(r.offset) + ",\"token_bytes\":" + String(r.token_bytes) + ",\"stride\":" + String(r.stride) + ",\"byte_count\":" + String(r.byte_count)
        text += ",\"first_element\":" + String(cache_element_offset(layout, i, 0, 0, 0))
        text += ",\"last_element\":" + String(cache_element_offset(layout, i, layout.capacity - 1, layout.heads - 1, dimension - 1)) + "}"
        if len(args) == 13:
            var elements = checked_product(checked_product(layout.capacity, layout.heads), dimension)
            if elements > 4096 - probe_count:
                raise Error("CacheLayout: diagnostic host enumeration bound exceeded")
            probe_count += elements
    text += "]"
    if len(args) == 16:
        text += ",\"element_offset\":" + String(cache_element_offset(layout, Int(args[12]), Int(args[13]), Int(args[14]), Int(args[15])))
    elif len(args) == 13:
        if args[12] != "enumerate":
            raise Error("CacheLayout: unknown diagnostic request")
        text += ",\"element_offsets\":["
        var first = True
        for i in range(len(layout.regions)):
            var dimension = layout.key_dim if i % 2 == 0 else layout.value_dim
            for slot in range(layout.capacity):
                for head in range(layout.heads):
                    for component in range(dimension):
                        if not first:
                            text += ","
                        first = False
                        text += String(cache_element_offset(layout, i, slot, head, component))
        text += "]"
    print(text + "}")
