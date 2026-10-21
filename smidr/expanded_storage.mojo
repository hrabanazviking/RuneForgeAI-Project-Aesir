from smidr.expanded_graph import is_expanded_export
# Checked storage volume for expanded mathematical IR, never device admission.
from smidr.expanded_graph import ExpandedGraph, validate_rotary_expansion
from smidr.semantic_plan import checked_product
from smidr.storage_estimate import aligned_bytes, checked_sum
from smidr.source_inventory import validate_source_inventory, validate_source_weight


@fieldwise_init
struct ExpandedStorageAssumptions(Copyable, Movable):
    var activation_width: Int
    var predicate_width: Int
    var kv_width: Int
    var index_width: Int
    var alignment: Int
    var device_weight_bytes: Int
    var workspace_bytes: Int
    var budget_bytes: Int
    var provenance: String


struct ExpandedStorageEstimate(Copyable, Movable):
    var value_bytes: List[Int]
    var real_live_bytes: List[Int]
    var predicate_live_bytes: List[Int]
    var activation_live_bytes: List[Int]
    var persistent_kv_bytes: Int
    var input_bytes: Int
    var peak_activation_bytes: Int
    var peak_step: Int
    var total_bytes: Int
    var within_supplied_budget: Bool

    var index_live_bytes: List[Int]

    def __init__(out self, var value_bytes: List[Int],
                 var real_live_bytes: List[Int],
                 var predicate_live_bytes: List[Int],
                 var activation_live_bytes: List[Int],
                 persistent_kv_bytes: Int,
                 input_bytes: Int,
                 peak_activation_bytes: Int,
                 peak_step: Int,
                 total_bytes: Int,
                 within_supplied_budget: Bool,
                 var index_live_bytes: List[Int] = List[Int]()):
        self.value_bytes = value_bytes^
        self.real_live_bytes = real_live_bytes^
        self.predicate_live_bytes = predicate_live_bytes^
        self.activation_live_bytes = activation_live_bytes^
        self.persistent_kv_bytes = persistent_kv_bytes
        self.input_bytes = input_bytes
        self.peak_activation_bytes = peak_activation_bytes
        self.peak_step = peak_step
        self.total_bytes = total_bytes
        self.within_supplied_budget = within_supplied_budget
        self.index_live_bytes = index_live_bytes^


def validate_expanded_storage_graph(graph: ExpandedGraph) raises:
    validate_rotary_expansion(graph)
    var count = len(graph.operations)
    var value_count = len(graph.values)
    if count == 0 or value_count == 0 or graph.result < 0 or graph.result >= value_count:
        raise Error("ExpandedStorage: missing graph/export")
    if len(graph.source_values) != len(graph.source.tensors) or len(graph.weight_values) != len(graph.source.source.bindings):
        raise Error("ExpandedStorage: incomplete source/constant mapping")
    validate_source_inventory(graph.source.source)
    var last = List[Int]()
    var produced = List[Bool]()
    var constant_count = 0
    var packed_bytes = 0
    for i in range(value_count):
        var value = graph.values[i].copy()
        if len(value.shape) == 0:
            raise Error("ExpandedStorage: empty shape")
        var elements = 1
        for dimension in value.shape:
            elements = checked_product(elements, dimension)
        if elements != value.elements or value.producer < -1 or value.producer >= count or value.last_use < value.producer or value.last_use > count:
            raise Error("ExpandedStorage: invalid shape/product/lifetime")
        last.append(value.producer)
        produced.append(False)
        if value.storage == "source_weight":
            if value.domain != "real" or value.producer != -1 or value.alias_of != -1 or value.source_tensor != -1 or value.source_weight not in graph.weight_values or graph.weight_values[value.source_weight] != i or value.source_weight not in graph.source.source.bindings:
                raise Error("ExpandedStorage: invalid source constant role/mapping")
            var binding = graph.source.source.bindings[value.source_weight]
            validate_source_weight(graph.source.source, value.source_weight,
                binding.columns, binding.rows, len(value.shape) == 1)
            var shape_ok = False
            if len(value.shape) == 1:
                shape_ok = binding.rows == 1 and value.shape[0] == binding.columns
            elif len(value.shape) == 2:
                shape_ok = value.shape[0] == binding.rows and value.shape[1] == binding.columns
            if not shape_ok or value.name != value.source_weight:
                raise Error("ExpandedStorage: source constant logical shape mismatch")
            constant_count += 1
            packed_bytes = checked_sum(packed_bytes, binding.byte_count)
        elif value.storage == "index":
            if value.domain != "index" or value.producer != -1 or value.alias_of != -1 or len(value.shape) != 1 or value.shape[0] != graph.source.query_tokens or (value.name != "tokens" and value.name != "positions"):
                raise Error("ExpandedStorage: invalid external index role")
        elif value.storage == "persistent_kv":
            if value.domain != "real" or value.producer != -1 or value.alias_of != -1:
                raise Error("ExpandedStorage: invalid persistent KV role")
        elif value.storage == "activation":
            if (value.domain != "real" and value.domain != "predicate" and value.domain != "index") or value.producer < 0 or value.alias_of != -1:
                raise Error("ExpandedStorage: invalid activation domain/role")
        elif value.storage == "kv_view":
            if value.domain != "real" or value.producer < 0 or value.alias_of < 0 or value.alias_of >= value_count or value.source_tensor < 0:
                raise Error("ExpandedStorage: invalid KV view role")
            var base = graph.values[value.alias_of].copy()
            if base.storage != "persistent_kv" or base.domain != "real" or base.alias_of != -1 or base.elements < value.elements or len(base.shape) != len(value.shape):
                raise Error("ExpandedStorage: invalid KV view base/extent")
            for axis in range(1, len(value.shape)):
                if base.shape[axis] != value.shape[axis]:
                    raise Error("ExpandedStorage: incompatible KV view axes")
        else:
            raise Error("ExpandedStorage: unresolved value storage role")
        if value.storage != "source_weight" and value.source_weight.byte_length() != 0:
            raise Error("ExpandedStorage: nonconstant has a source constant identity")
        if value.source_tensor < -1 or (value.source_tensor >= 0 and (value.source_tensor not in graph.source_values or graph.source_values[value.source_tensor] != i)):
            raise Error("ExpandedStorage: value source identity is not mapped")
        if (value.storage == "index" or value.storage == "persistent_kv") and value.source_tensor == -1:
            raise Error("ExpandedStorage: external storage has no source identity")
    if constant_count != len(graph.weight_values):
        raise Error("ExpandedStorage: duplicate or missing source constants")
    if packed_bytes != graph.source.source.weight_bytes:
        raise Error("ExpandedStorage: source packed byte total mismatch")
    for i in range(len(graph.source.tensors)):
        if i not in graph.source_values:
            raise Error("ExpandedStorage: missing source tensor mapping")
        var mapped = graph.source_values[i]
        if mapped < 0 or mapped >= value_count:
            raise Error("ExpandedStorage: source tensor map is out of range")
        var value = graph.values[mapped].copy()
        var source = graph.source.tensors[i].copy()
        if value.source_tensor != i or value.name != source.name or value.elements != source.elements or len(value.shape) != len(source.shape):
            raise Error("ExpandedStorage: source value identity/shape mismatch")
        for axis in range(len(source.shape)):
            if value.shape[axis] != source.shape[axis]:
                raise Error("ExpandedStorage: source value axes mismatch")
        if source.producer == -1:
            if source.persistent:
                if value.storage != "persistent_kv":
                    raise Error("ExpandedStorage: source persistent role changed")
            elif value.storage != "index":
                raise Error("ExpandedStorage: source index role changed")
        elif source.alias_of != -1:
            if source.alias_of not in graph.source_values or value.alias_of != graph.source_values[source.alias_of] or value.storage != "kv_view":
                raise Error("ExpandedStorage: source alias identity changed")
        elif value.storage != "activation":
            raise Error("ExpandedStorage: source activation role changed")
    for i in range(count):
        var op = graph.operations[i].copy()
        if op.output < 0 or op.output >= value_count or produced[op.output] or graph.values[op.output].producer != i:
            raise Error("ExpandedStorage: invalid/duplicate operation producer")
        var output = graph.values[op.output].copy()
        if output.storage != "activation" and output.storage != "kv_view":
            raise Error("ExpandedStorage: operation cannot produce retained external storage")
        produced[op.output] = True
        if op.kind.byte_length() == 0 or op.source_operation < 0 or op.source_operation >= len(graph.source.operations):
            raise Error("ExpandedStorage: missing source operation identity")
        if op.kind == "prefix_key_indices":
            if len(op.inputs) != 0 or output.domain != "index":
                raise Error("ExpandedStorage: key indices must be index-domain")
        elif op.kind == "causal_window_predicate":
            if len(op.inputs) != 2 or output.domain != "predicate":
                raise Error("ExpandedStorage: window mask must be predicate-domain")
        elif op.kind == "compare_nonnegative":
            if len(op.inputs) != 1 or output.domain != "predicate":
                raise Error("ExpandedStorage: comparison result must be a predicate")
        elif output.domain != "real":
            raise Error("ExpandedStorage: unexpected predicate result")
        if op.kind == "select_negative_infinity" and len(op.inputs) != 2:
            raise Error("ExpandedStorage: window select arity mismatch")
        if op.kind == "select" and len(op.inputs) != 3:
            raise Error("ExpandedStorage: select arity mismatch")
        var found_weight = False
        for j in range(len(op.inputs)):
            var input_id = op.inputs[j]
            if input_id < 0 or input_id >= value_count or graph.values[input_id].producer >= i:
                raise Error("ExpandedStorage: unavailable operation input")
            var input = graph.values[input_id].copy()
            var expected_domain = String("real")
            if op.kind == "causal_window_predicate":
                expected_domain = String("index")
            elif op.kind == "select_negative_infinity" and j == 1:
                expected_domain = String("predicate")
            elif op.kind == "select" and j == 0:
                expected_domain = String("predicate")
            elif op.kind == "rotary_angles" and j == 0:
                expected_domain = String("index")
            elif (op.kind == "embedding_gather" and j == 0) or ((op.kind == "rope_query" or op.kind == "rope_key" or op.kind == "causal_mask") and j == 1):
                expected_domain = String("index")
            if input.domain != expected_domain:
                raise Error("ExpandedStorage: operand domain mismatch")
            last[input_id] = i
            if input.storage == "source_weight" and input.source_weight == op.source_weight:
                found_weight = True
        if op.source_weight.byte_length() != 0 and not found_weight:
            raise Error("ExpandedStorage: operation source constant is missing")
        if output.storage == "kv_view":
            if (op.kind != "kv_append_keys" and op.kind != "kv_append_values") or len(op.inputs) != 2 or op.inputs[0] != output.alias_of:
                raise Error("ExpandedStorage: alias output is not a KV append")
    if graph.source.logits not in graph.source_values or graph.source_values[graph.source.logits] != graph.result or graph.values[graph.result].storage != "activation" or graph.values[graph.result].domain != "real":
        raise Error("ExpandedStorage: invalid exported source result")
    for i in range(value_count):
        var value = graph.values[i].copy()
        if (value.producer >= 0) != produced[i]:
            raise Error("ExpandedStorage: orphan/misclassified producer")
        if value.storage == "source_weight" or value.storage == "persistent_kv" or is_expanded_export(graph, i):
            last[i] = count
        if value.last_use != last[i]:
            raise Error("ExpandedStorage: stale global lifetime")


def estimate_expanded_storage(graph: ExpandedGraph, policy: ExpandedStorageAssumptions) raises -> ExpandedStorageEstimate:
    if policy.activation_width <= 0 or policy.predicate_width <= 0 or policy.kv_width <= 0 or policy.index_width <= 0 or policy.device_weight_bytes <= 0 or policy.workspace_bytes < 0 or policy.budget_bytes <= 0 or policy.provenance.byte_length() == 0:
        raise Error("ExpandedStorage: explicit widths/weights/budget and provenance required")
    _ = aligned_bytes(1, 1, policy.alignment)
    validate_expanded_storage_graph(graph)
    var count = len(graph.operations)
    var real_births = List[Int]()
    var real_deaths = List[Int]()
    var index_births = List[Int]()
    var index_deaths = List[Int]()
    var predicate_births = List[Int]()
    var predicate_deaths = List[Int]()
    for _ in range(count + 2):
        index_births.append(0)
        index_deaths.append(0)
        real_births.append(0)
        real_deaths.append(0)
        predicate_births.append(0)
        predicate_deaths.append(0)
    var sizes = List[Int]()
    var kv_bytes = 0
    var inputs = 0
    for value in graph.values:
        if value.storage == "source_weight" or value.storage == "kv_view":
            sizes.append(0)
            continue
        var width = policy.activation_width
        if value.storage == "persistent_kv":
            width = policy.kv_width
        elif value.domain == "index":
            width = policy.index_width
        elif value.domain == "predicate":
            width = policy.predicate_width
        var size = aligned_bytes(value.elements, width, policy.alignment)
        sizes.append(size)
        if value.storage == "persistent_kv":
            kv_bytes = checked_sum(kv_bytes, size)
        elif value.storage == "index":
            inputs = checked_sum(inputs, size)
        elif value.domain == "index":
            index_births[value.producer] = checked_sum(index_births[value.producer], size)
            index_deaths[value.last_use + 1] = checked_sum(index_deaths[value.last_use + 1], size)
        elif value.domain == "predicate":
            predicate_births[value.producer] = checked_sum(predicate_births[value.producer], size)
            predicate_deaths[value.last_use + 1] = checked_sum(predicate_deaths[value.last_use + 1], size)
        else:
            real_births[value.producer] = checked_sum(real_births[value.producer], size)
            real_deaths[value.last_use + 1] = checked_sum(real_deaths[value.last_use + 1], size)
    var index_live = 0
    var index_timeline = List[Int]()
    var real_live = 0
    var predicate_live = 0
    var peak = 0
    var peak_step = 0
    var real_timeline = List[Int]()
    var predicate_timeline = List[Int]()
    var timeline = List[Int]()
    for i in range(count + 1):
        if real_deaths[i] > real_live or predicate_deaths[i] > predicate_live or index_deaths[i] > index_live:
            raise Error("ExpandedStorage: inconsistent release accounting")
        real_live = checked_sum(real_live - real_deaths[i], real_births[i])
        predicate_live = checked_sum(predicate_live - predicate_deaths[i], predicate_births[i])
        index_live = checked_sum(index_live - index_deaths[i], index_births[i])
        var live = checked_sum(checked_sum(real_live, predicate_live), index_live)
        index_timeline.append(index_live)
        real_timeline.append(real_live)
        predicate_timeline.append(predicate_live)
        timeline.append(live)
        if live > peak:
            peak = live
            peak_step = i
    var total = checked_sum(checked_sum(kv_bytes, inputs), peak)
    total = checked_sum(total, policy.device_weight_bytes)
    total = checked_sum(total, policy.workspace_bytes)
    return ExpandedStorageEstimate(sizes^, real_timeline^, predicate_timeline^,
        timeline^, kv_bytes, inputs, peak, peak_step, total, total <= policy.budget_bytes, index_timeline^)
