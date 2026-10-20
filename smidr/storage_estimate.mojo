# Checked scenario arithmetic. No allocator, hardware budget or precision claim.
from smidr.semantic_plan import SemanticPlan, checked_product
from smidr.source_inventory import validate_source_inventory


def checked_sum(a: Int, b: Int) raises -> Int:
    if a < 0 or b < 0 or a > 9223372036854775807 - b:
        raise Error("StorageEstimate: invalid or overflowing byte sum")
    return a + b


def aligned_bytes(elements: Int, width: Int, alignment: Int) raises -> Int:
    if alignment <= 0 or (alignment & (alignment - 1)) != 0:
        raise Error("StorageEstimate: alignment assumption must be a positive power of two")
    var size = checked_product(elements, width)
    var padding = (alignment - size % alignment) % alignment
    return checked_sum(size, padding)


@fieldwise_init
struct StorageAssumptions(Copyable, Movable):
    var activation_width: Int
    var kv_width: Int
    var index_width: Int
    var alignment: Int
    var device_weight_bytes: Int
    var workspace_bytes: Int
    var budget_bytes: Int
    var provenance: String


@fieldwise_init
struct StorageEstimate(Copyable, Movable):
    var tensor_bytes: List[Int]
    var activation_live_bytes: List[Int]
    var persistent_kv_bytes: Int
    var input_bytes: Int
    var peak_activation_bytes: Int
    var peak_step: Int
    var total_bytes: Int
    var within_supplied_budget: Bool


def estimate_storage(plan: SemanticPlan, policy: StorageAssumptions) raises -> StorageEstimate:
    if policy.activation_width <= 0 or policy.kv_width <= 0 or policy.index_width <= 0 or policy.device_weight_bytes <= 0 or policy.workspace_bytes < 0 or policy.budget_bytes <= 0 or policy.provenance.byte_length() == 0:
        raise Error("StorageEstimate: explicit positive widths/weights/budget and provenance required")
    validate_source_inventory(plan.source)
    # Assumptions are caller supplied, not capabilities discovered from hardware.
    _ = aligned_bytes(1, 1, policy.alignment)
    var count = len(plan.operations)
    if count == 0 or len(plan.tensors) == 0 or plan.logits < 0 or plan.logits >= len(plan.tensors):
        raise Error("StorageEstimate: graph has no valid exported result")
    var sizes = List[Int]()
    var births = List[Int]()
    var deaths = List[Int]()
    for _ in range(count + 2):
        births.append(0)
        deaths.append(0)
    var kv_bytes = 0
    var inputs = 0
    for i in range(len(plan.tensors)):
        var tensor = plan.tensors[i].copy()
        if tensor.producer < -1 or tensor.producer >= count or tensor.last_use < tensor.producer or tensor.last_use > count:
            raise Error("StorageEstimate: invalid tensor lifetime")
        var elements = 1
        if len(tensor.shape) == 0:
            raise Error("StorageEstimate: empty shape")
        for dimension in tensor.shape:
            elements = checked_product(elements, dimension)
        if elements != tensor.elements:
            raise Error("StorageEstimate: shape/product mismatch")
        if tensor.persistent and (tensor.producer != -1 or tensor.last_use != count or tensor.alias_of != -1):
            raise Error("StorageEstimate: persistent storage must span the whole graph")
        if tensor.alias_of != -1:
            if tensor.alias_of < 0 or tensor.alias_of >= len(plan.tensors) or tensor.producer < 0 or tensor.persistent:
                raise Error("StorageEstimate: invalid alias base")
            var base = plan.tensors[tensor.alias_of].copy()
            if not base.persistent or base.alias_of != -1 or base.elements < tensor.elements or len(base.shape) != len(tensor.shape):
                raise Error("StorageEstimate: invalid persistent alias extent")
            for axis in range(1, len(tensor.shape)):
                if base.shape[axis] != tensor.shape[axis]:
                    raise Error("StorageEstimate: incompatible alias shape")
            sizes.append(0)
            continue
        var width = policy.activation_width
        if tensor.persistent:
            width = policy.kv_width
        elif tensor.producer == -1:
            width = policy.index_width
        var size = aligned_bytes(tensor.elements, width, policy.alignment)
        sizes.append(size)
        if tensor.persistent:
            kv_bytes = checked_sum(kv_bytes, size)
        elif tensor.producer == -1:
            # External token/position storage is conservatively retained.
            inputs = checked_sum(inputs, size)
        else:
            births[tensor.producer] = checked_sum(births[tensor.producer], size)
            deaths[tensor.last_use + 1] = checked_sum(deaths[tensor.last_use + 1], size)
    # Public typed graphs can be modified by a caller: reject stale lifetimes.
    for i in range(count):
        var operation = plan.operations[i].copy()
        if operation.output < 0 or operation.output >= len(plan.tensors) or plan.tensors[operation.output].producer != i:
            raise Error("StorageEstimate: invalid operation output producer")
        for input_id in operation.inputs:
            if input_id < 0 or input_id >= len(plan.tensors):
                raise Error("StorageEstimate: invalid operation input")
            if plan.tensors[input_id].producer >= i or plan.tensors[input_id].last_use < i:
                raise Error("StorageEstimate: input used outside its lifetime")
    if plan.tensors[plan.logits].last_use != count:
        raise Error("StorageEstimate: exported result is not retained")
    var live = 0
    var peak = 0
    var peak_step = 0
    var timeline = List[Int]()
    for i in range(count + 1):
        if deaths[i] > live:
            raise Error("StorageEstimate: inconsistent release accounting")
        live -= deaths[i]
        live = checked_sum(live, births[i])
        timeline.append(live)
        if live > peak:
            peak = live
            peak_step = i
    var total = checked_sum(checked_sum(kv_bytes, inputs), peak)
    total = checked_sum(total, policy.device_weight_bytes)
    total = checked_sum(total, policy.workspace_bytes)
    return StorageEstimate(sizes^, timeline^, kv_bytes, inputs, peak,
                           peak_step, total, total <= policy.budget_bytes)
