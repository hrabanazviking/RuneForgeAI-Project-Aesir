# Original explicit cache address scenario. No allocation, cache data or math.
from std.collections import Dict
from loader.packed_gguf import packed_row_bytes
from smidr.semantic_plan import SemanticPlan, checked_product
from smidr.storage_estimate import checked_sum


@fieldwise_init
struct CacheLayoutAssumptions(Copyable, Movable):
    var key_width: Int
    var value_width: Int
    var key_stride: Int
    var value_stride: Int
    var alignment: Int
    var pool_bytes: Int
    var provenance: String


@fieldwise_init
struct CacheRegion(Copyable, Movable):
    var layer: Int
    var kind: String
    var name: String
    var source_tensor: Int
    var source_view: Int
    var offset: Int
    var token_bytes: Int
    var stride: Int
    var byte_count: Int


@fieldwise_init
struct CacheLayout(Movable):
    var policy: CacheLayoutAssumptions
    var layers: Int
    var capacity: Int
    var heads: Int
    var key_dim: Int
    var value_dim: Int
    var source_tensor_count: Int
    var regions: List[CacheRegion]
    var total_bytes: Int


def _policy(policy: CacheLayoutAssumptions) raises:
    if policy.key_width <= 0 or policy.value_width <= 0 or policy.key_stride <= 0 or policy.value_stride <= 0 or policy.pool_bytes <= 0 or policy.provenance.byte_length() == 0:
        raise Error("CacheLayout: explicit positive widths/strides/pool and provenance required")
    if policy.alignment <= 0 or (policy.alignment & (policy.alignment - 1)) != 0:
        raise Error("CacheLayout: alignment must be a positive power of two")
    if policy.key_stride % policy.alignment != 0 or policy.value_stride % policy.alignment != 0:
        raise Error("CacheLayout: token strides must satisfy assumed alignment")


def _shape(plan: SemanticPlan, index: Int, slots: Int, dimension: Int) raises:
    if index < 0 or index >= len(plan.tensors):
        raise Error("CacheLayout: cache-related tensor ID outside source graph")
    var tensor = plan.tensors[index].copy()
    if len(tensor.shape) != 3 or tensor.shape[0] != slots or tensor.shape[1] != plan.kv_heads or tensor.shape[2] != dimension or tensor.elements != checked_product(checked_product(slots, plan.kv_heads), dimension):
        raise Error("CacheLayout: cache-related logical [slot, head, component] shape mismatch")


def _projection(plan: SemanticPlan, name: String, rows: Int) raises:
    if name not in plan.source.bindings or name not in plan.used_weights:
        raise Error("CacheLayout: missing consumed source projection binding")
    if not plan.used_weights[name]:
        raise Error("CacheLayout: projection is not marked consumed")
    var b = plan.source.bindings[name]
    var bytes = checked_product(packed_row_bytes(b.source_kind, b.columns), b.rows)
    if b.columns != plan.hidden or b.rows != rows or b.byte_count != bytes or b.file_offset < plan.source.data_offset or b.file_offset > plan.source.source_bytes or b.byte_count > plan.source.source_bytes - b.file_offset:
        raise Error("CacheLayout: source projection binding shape/extent mismatch")


def plan_cache_layout(plan: SemanticPlan, policy: CacheLayoutAssumptions) raises -> CacheLayout:
    _policy(policy)
    if plan.hidden <= 0 or plan.source.source_bytes <= 0 or plan.source.data_offset < 0 or plan.source.data_offset > plan.source.source_bytes:
        raise Error("CacheLayout: invalid source inventory extent/dimension")
    if plan.layers <= 0 or plan.layers > len(plan.tensors) // 2 or len(plan.operations) == 0 or plan.context_capacity <= 0 or plan.query_tokens <= 0 or plan.past_tokens < 0 or plan.past_tokens > plan.context_capacity or plan.query_tokens > plan.context_capacity - plan.past_tokens or plan.heads <= 0 or plan.kv_heads <= 0 or plan.heads % plan.kv_heads != 0:
        raise Error("CacheLayout: invalid source cache/session dimensions")
    var key_elements = checked_product(plan.kv_heads, plan.key_dim)
    var value_elements = checked_product(plan.kv_heads, plan.value_dim)
    var key_bytes = checked_product(key_elements, policy.key_width)
    var value_bytes = checked_product(value_elements, policy.value_width)
    if key_bytes > policy.key_stride or value_bytes > policy.value_stride:
        raise Error("CacheLayout: assumed stride cannot hold a complete token entry")
    var key_size = checked_product(plan.context_capacity, policy.key_stride)
    var value_size = checked_product(plan.context_capacity, policy.value_stride)
    var total = checked_product(plan.layers, checked_sum(key_size, value_size))
    if total > policy.pool_bytes:
        raise Error("CacheLayout: scenario exceeds explicit cache pool bound")
    var names = Dict[String, Int]()
    for i in range(len(plan.tensors)):
        var name = plan.tensors[i].name
        if name in names:
            raise Error("CacheLayout: duplicate source tensor identity")
        names[name] = i
    var bases = Dict[Int, Bool]()
    var views = Dict[Int, Bool]()
    var regions = List[CacheRegion]()
    var cursor = 0
    for layer in range(plan.layers):
        var p = String("blk.") + String(layer) + "."
        _projection(plan, p + "attn_k.weight", key_elements)
        _projection(plan, p + "attn_v.weight", value_elements)
        for side in range(2):
            var is_key = side == 0
            var kind = String("key") if is_key else String("value")
            var base_name = p + kind + "_cache"
            var view_name = p + (String("keys_view") if is_key else String("values_view"))
            var writer_name = p + (String("k_rotary") if is_key else String("v"))
            if base_name not in names or view_name not in names or writer_name not in names:
                raise Error("CacheLayout: missing named source cache/view/writer")
            var base_id = names[base_name]
            var view_id = names[view_name]
            var writer_id = names[writer_name]
            var dimension = plan.key_dim if is_key else plan.value_dim
            _shape(plan, base_id, plan.context_capacity, dimension)
            _shape(plan, view_id, plan.past_tokens + plan.query_tokens, dimension)
            _shape(plan, writer_id, plan.query_tokens, dimension)
            var base = plan.tensors[base_id].copy()
            var view = plan.tensors[view_id].copy()
            var writer = plan.tensors[writer_id].copy()
            if not base.persistent or base.producer != -1 or base.alias_of != -1 or base.last_use != len(plan.operations) or view.persistent or view.alias_of != base_id or view.producer < 0 or view.producer >= len(plan.operations) or writer.persistent or writer.alias_of != -1 or writer.producer < 0 or writer.producer >= view.producer:
                raise Error("CacheLayout: invalid cache ownership/alias/producer/lifetime")
            var append = plan.operations[view.producer].copy()
            if append.kind != (String("kv_append_keys") if is_key else String("kv_append_values")) or append.output != view_id or len(append.inputs) != 2:
                raise Error("CacheLayout: invalid cache append operation")
            if append.inputs[0] != base_id or append.inputs[1] != writer_id:
                raise Error("CacheLayout: cache append input identity mismatch")
            var writer_op = plan.operations[writer.producer].copy()
            if writer_op.output != writer_id or writer_op.kind != (String("rope_key") if is_key else String("linear")):
                raise Error("CacheLayout: invalid cache writer identity")
            if not is_key and writer_op.weight != p + "attn_v.weight":
                raise Error("CacheLayout: value projection source mismatch")
            if is_key:
                if p + "k" not in names or "positions" not in names or len(writer_op.inputs) != 2:
                    raise Error("CacheLayout: missing key projection/position inputs")
                var key_id = names[p + "k"]
                if writer_op.inputs[0] != key_id or writer_op.inputs[1] != names["positions"]:
                    raise Error("CacheLayout: rotary key input identity mismatch")
                _shape(plan, key_id, plan.query_tokens, dimension)
                var key = plan.tensors[key_id].copy()
                if key.producer < 0 or key.producer >= writer.producer or key.persistent or key.alias_of != -1:
                    raise Error("CacheLayout: invalid key projection producer")
                var key_op = plan.operations[key.producer].copy()
                if key_op.output != key_id or key_op.kind != "linear" or key_op.weight != p + "attn_k.weight":
                    raise Error("CacheLayout: key projection source mismatch")
            var last = view.producer
            for step in range(len(plan.operations)):
                for input_id in plan.operations[step].inputs:
                    if input_id == view_id:
                        if step <= view.producer:
                            raise Error("CacheLayout: view used before production")
                        last = step
            if view.last_use != last:
                raise Error("CacheLayout: cache view lifetime mismatch")
            bases[base_id] = True
            views[view_id] = True
            var stride = policy.key_stride if is_key else policy.value_stride
            var token_bytes = key_bytes if is_key else value_bytes
            var size = key_size if is_key else value_size
            regions.append(CacheRegion(layer, kind, base_name, base_id, view_id,
                                       cursor, token_bytes, stride, size))
            cursor = checked_sum(cursor, size)
    for i in range(len(plan.tensors)):
        if plan.tensors[i].persistent and i not in bases:
            raise Error("CacheLayout: unbound persistent source tensor")
        if plan.tensors[i].alias_of != -1 and i not in views:
            raise Error("CacheLayout: unbound source cache alias")
    return CacheLayout(policy.copy(), plan.layers, plan.context_capacity, plan.kv_heads,
                       plan.key_dim, plan.value_dim, len(plan.tensors), regions^, total)


def validate_cache_layout(layout: CacheLayout) raises:
    _policy(layout.policy)
    if layout.layers <= 0 or len(layout.regions) != checked_product(layout.layers, 2) or layout.source_tensor_count <= 0:
        raise Error("CacheLayout: invalid returned region count/graph extent")
    var cursor = 0
    var ids = Dict[Int, Bool]()
    for i in range(len(layout.regions)):
        var r = layout.regions[i].copy()
        var is_key = i % 2 == 0
        var dimension = layout.key_dim if is_key else layout.value_dim
        var width = layout.policy.key_width if is_key else layout.policy.value_width
        var stride = layout.policy.key_stride if is_key else layout.policy.value_stride
        var token_bytes = checked_product(checked_product(layout.heads, dimension), width)
        var size = checked_product(layout.capacity, stride)
        var kind = String("key") if is_key else String("value")
        var name = String("blk.") + String(i // 2) + "." + kind + "_cache"
        if r.layer != i // 2 or r.kind != kind or r.name != name or r.offset != cursor or r.stride != stride or r.token_bytes != token_bytes or token_bytes > stride or r.byte_count != size:
            raise Error("CacheLayout: returned region shape/stride/identity/overlap mismatch")
        if r.source_tensor < 0 or r.source_tensor >= layout.source_tensor_count or r.source_view < 0 or r.source_view >= layout.source_tensor_count or r.source_tensor == r.source_view or r.source_tensor in ids or r.source_view in ids:
            raise Error("CacheLayout: invalid or repeated returned source IDs")
        ids[r.source_tensor] = True
        ids[r.source_view] = True
        cursor = checked_sum(cursor, size)
    if cursor != layout.total_bytes or cursor > layout.policy.pool_bytes:
        raise Error("CacheLayout: returned total exceeds/mismatches assumed pool")


def cache_element_offset(layout: CacheLayout, region: Int, slot: Int,
                          head: Int, component: Int) raises -> Int:
    validate_cache_layout(layout)
    if region < 0 or region >= len(layout.regions) or slot < 0 or slot >= layout.capacity or head < 0 or head >= layout.heads:
        raise Error("CacheLayout: region/slot/head index outside scenario")
    var is_key = region % 2 == 0
    var dimension = layout.key_dim if is_key else layout.value_dim
    var width = layout.policy.key_width if is_key else layout.policy.value_width
    if component < 0 or component >= dimension:
        raise Error("CacheLayout: component index outside scenario")
    # Validation proves every product/sum here fits inside a checked region.
    var r = layout.regions[region].copy()
    return r.offset + slot * r.stride + (head * dimension + component) * width
