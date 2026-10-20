# Original explicit cache address scenario. No allocation, cache data or math.
from std.collections import Dict
from smidr.source_inventory import validate_source_inventory, validate_source_weight
from smidr.semantic_plan import SemanticPlan, checked_product, validate_decoder_graph_policy
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


def _lifetime(plan: SemanticPlan, index: Int) raises:
    var tensor = plan.tensors[index].copy()
    var last = tensor.producer
    for step in range(len(plan.operations)):
        for input_id in plan.operations[step].inputs:
            if input_id == index:
                if step <= tensor.producer:
                    raise Error("CacheLayout: writer/input used before production")
                last = step
    if tensor.last_use != last:
        raise Error("CacheLayout: writer/input lifetime mismatch")


def _projection(plan: SemanticPlan, name: String, rows: Int) raises:
    if name not in plan.source.bindings or name not in plan.used_weights:
        raise Error("CacheLayout: missing consumed source projection binding")
    if not plan.used_weights[name]:
        raise Error("CacheLayout: projection is not marked consumed")
    validate_source_weight(plan.source, name, plan.hidden, rows, False)


def plan_cache_layout(plan: SemanticPlan, policy: CacheLayoutAssumptions) raises -> CacheLayout:
    _policy(policy)
    validate_source_inventory(plan.source)
    if plan.hidden <= 0:
        raise Error("CacheLayout: invalid source hidden dimension")
    if plan.layers <= 0 or plan.layers > len(plan.tensors) // 2 or len(plan.operations) == 0 or plan.context_capacity <= 0 or plan.query_tokens <= 0 or plan.past_tokens < 0 or plan.past_tokens > plan.context_capacity or plan.query_tokens > plan.context_capacity - plan.past_tokens or plan.heads <= 0 or plan.kv_heads <= 0 or plan.heads % plan.kv_heads != 0:
        raise Error("CacheLayout: invalid source cache/session dimensions")
    validate_decoder_graph_policy(plan.decoder_policy, plan.source, plan.layers, plan.hidden, plan.vocabulary)
    if plan.logits < 0 or plan.logits >= len(plan.tensors):
        raise Error("CacheLayout: missing decoder output")
    var logits = plan.tensors[plan.logits].copy()
    if logits.producer < 0 or logits.producer >= len(plan.operations) or plan.operations[logits.producer].output != plan.logits or plan.operations[logits.producer].weight != plan.decoder_policy.output_weight:
        raise Error("CacheLayout: explicit output policy disagrees with graph")
    if plan.operations[logits.producer].kind != "linear" or plan.decoder_policy.output_weight not in plan.used_weights or not plan.used_weights[plan.decoder_policy.output_weight] or len(logits.shape) != 2 or logits.shape[0] != plan.query_tokens or logits.shape[1] != plan.vocabulary or logits.elements != checked_product(plan.query_tokens, plan.vocabulary):
        raise Error("CacheLayout: invalid explicit decoder output binding/shape")
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
        if plan.decoder_policy.rope_enabled[layer] == 0 and (p + "k_rotary" in names or p + "q_rotary" in names):
            raise Error("CacheLayout: NoPE policy disagrees with rotary tensors")
        _projection(plan, p + "attn_k.weight", key_elements)
        _projection(plan, p + "attn_v.weight", value_elements)
        for side in range(2):
            var is_key = side == 0
            var kind = String("key") if is_key else String("value")
            var base_name = p + kind + "_cache"
            var view_name = p + (String("keys_view") if is_key else String("values_view"))
            var rotary_key = is_key and plan.decoder_policy.rope_enabled[layer] == 1
            var writer_name = p + ((String("k_rotary") if rotary_key else String("k")) if is_key else String("v"))
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
            if writer_op.output != writer_id or writer_op.kind != (String("rope_key") if rotary_key else String("linear")):
                raise Error("CacheLayout: invalid cache writer identity")
            if not is_key and writer_op.weight != p + "attn_v.weight":
                raise Error("CacheLayout: value projection source mismatch")
            var projection_id = writer_id
            if rotary_key:
                if p + "k" not in names or "positions" not in names or len(writer_op.inputs) != 2 or writer_op.weight != "":
                    raise Error("CacheLayout: missing key projection/position inputs")
                projection_id = names[p + "k"]
                var position_id = names["positions"]
                if writer_op.inputs[0] != projection_id or writer_op.inputs[1] != position_id:
                    raise Error("CacheLayout: rotary key input identity mismatch")
                var positions = plan.tensors[position_id].copy()
                if len(positions.shape) != 1 or positions.shape[0] != plan.query_tokens or positions.elements != plan.query_tokens or positions.producer != -1 or positions.persistent or positions.alias_of != -1:
                    raise Error("CacheLayout: invalid rotary positions")
                _lifetime(plan, position_id)
            _shape(plan, projection_id, plan.query_tokens, dimension)
            var projection = plan.tensors[projection_id].copy()
            if projection.producer < 0 or projection.producer >= view.producer or projection.persistent or projection.alias_of != -1 or (rotary_key and projection.producer >= writer.producer):
                raise Error("CacheLayout: invalid projection producer")
            var projection_op = plan.operations[projection.producer].copy()
            var projection_weight = p + (String("attn_k.weight") if is_key else String("attn_v.weight"))
            if projection_op.output != projection_id or projection_op.kind != "linear" or projection_op.weight != projection_weight or len(projection_op.inputs) != 1 or p + "attn_norm" not in names:
                raise Error("CacheLayout: projection source mismatch")
            var norm_id = names[p + "attn_norm"]
            if projection_op.inputs[0] != norm_id:
                raise Error("CacheLayout: projection dependency mismatch")
            var norm = plan.tensors[norm_id].copy()
            if len(norm.shape) != 2 or norm.shape[0] != plan.query_tokens or norm.shape[1] != plan.hidden or norm.elements != checked_product(plan.query_tokens, plan.hidden) or norm.producer < 0 or norm.producer >= projection.producer or norm.persistent or norm.alias_of != -1:
                raise Error("CacheLayout: invalid projection input shape/dependency")
            var norm_op = plan.operations[norm.producer].copy()
            if norm_op.output != norm_id or norm_op.kind != "rms_norm" or norm_op.weight != p + "attn_norm.weight":
                raise Error("CacheLayout: invalid projection normalization identity")
            _lifetime(plan, writer_id)
            _lifetime(plan, projection_id)
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
