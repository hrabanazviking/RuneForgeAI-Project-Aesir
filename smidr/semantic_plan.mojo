from smidr.dynamic_decoder_policy import DynamicDecoderHistory, empty_dynamic_decoder_history, validate_dynamic_decoder_history, advance_dynamic_decoder_history, same_dynamic_decoder_history
from smidr.dynamic_rotary_context import DynamicRotaryContext
from smidr.scaling_policy import DecoderScalingPolicy, empty_scaling_policy, same_scaling_policy, validate_scaling_policy
from smidr.window_policy import DecoderWindowPolicy, empty_window_policy, same_window_policy, validate_window_policy
# Original source graph construction. No numerical kernels or device program.
from std.collections import Dict
from smidr.session_policy import DecoderSessionPolicy, empty_session_policy, validate_session_policy
from smidr.activation_policy import DecoderActivationPolicy, empty_activation_policy, validate_activation_policy
from smidr.bias_policy import DecoderBiasPolicy, empty_bias_policy, validate_bias_policy
from std.math import isfinite
from std.memory import bitcast
from smidr.source_scalars import ScalarWord, DecoderScalars, empty_decoder_scalars, validate_decoder_scalars, validate_scalar_word, same_decoder_scalars, same_scalar_word
from loader.packed_gguf import PackedGGUF
from smidr.source_inventory import SourceTensorInventory, inventory_from_source, validate_source_inventory, validate_source_weight
from smidr.source_weight_sharing import SourceWeightSharingPolicy, empty_source_weight_sharing, validate_source_weight_sharing, validate_shared_source_coverage


def checked_product(a: Int, b: Int) raises -> Int:
    if a <= 0 or b <= 0 or a > 9223372036854775807 // b:
        raise Error("SemanticPlan: invalid or overflowing positive shape product")
    return a * b


@fieldwise_init
struct DenseDecoderParameters(Copyable, Movable):
    """Owned mathematical configuration, independent of container reads."""
    var layers: Int
    var hidden: Int
    var feed_forward: Int
    var heads: Int
    var kv_heads: Int
    var key_dim: Int
    var value_dim: Int
    var rope_dim: Int
    var vocabulary: Int
    var source_context: Int
    var rope_base: Float32
    var rms_epsilon: Float32
    var source_layout: String


@fieldwise_init
struct DecoderGeometry(Copyable, Movable):
    var layers: Int
    var hidden: Int
    var feed_forward: Int
    var heads: Int
    var kv_heads: Int
    var key_dim: Int
    var value_dim: Int
    var rope_dim: Int
    var vocabulary: Int
    var source_context: Int
    var source_layout: String


def decoder_geometry(p: DenseDecoderParameters) -> DecoderGeometry:
    return DecoderGeometry(p.layers, p.hidden, p.feed_forward, p.heads, p.kv_heads,
        p.key_dim, p.value_dim, p.rope_dim, p.vocabulary, p.source_context, p.source_layout)


@fieldwise_init
struct DecoderGraphPolicy(Copyable, Movable):
    """Explicit mathematical choices, not a source architecture certification."""
    var rope_enabled: List[Int]
    var output_weight: String
    var provenance: String


def validate_decoder_graph_policy(policy: DecoderGraphPolicy,
                                  source: SourceTensorInventory, layers: Int,
                                  hidden: Int, vocabulary: Int) raises:
    # Check bounds before any caller-owned list/string is copied.
    if layers <= 0 or layers > len(source.bindings) // 9 or len(policy.rope_enabled) != layers or layers > source.policy.tensors:
        raise Error("SemanticPlan: explicit rotary policy length exceeds layer evidence")
    var limit = source.policy.work
    if limit <= 0 or layers > limit or policy.provenance.byte_length() == 0 or policy.provenance.byte_length() > limit - layers:
        raise Error("SemanticPlan: explicit bounded decoder provenance required")
    var remaining = limit - layers - policy.provenance.byte_length()
    if policy.output_weight.byte_length() == 0 or policy.output_weight.byte_length() > remaining:
        raise Error("SemanticPlan: explicit bounded output weight required")
    for flag in policy.rope_enabled:
        if flag != 0 and flag != 1:
            raise Error("SemanticPlan: rotary policy entries must be zero or one")
    validate_source_weight(source, policy.output_weight, hidden, vocabulary, False)


@fieldwise_init
struct SemanticTensor(Copyable, Movable):
    var name: String
    var shape: List[Int]
    var elements: Int
    var producer: Int
    var last_use: Int
    var persistent: Bool
    var alias_of: Int


struct SemanticOperation(Copyable, Movable):
    var kind: String
    var inputs: List[Int]
    var output: Int
    var weight: String
    var window_tokens: Int
    var scaling_kind: String
    var scaling_factor: ScalarWord
    var position_start: Int
    var dynamic_reference: Int
    var dynamic_selected: Int
    var dynamic_factor: ScalarWord

    def __init__(out self, kind: String, var inputs: List[Int], output: Int,
                 weight: String, window_tokens: Int = 0, scaling_kind: String = "",
                 scaling_factor: ScalarWord = ScalarWord(0, 0), position_start: Int = -1,
                 dynamic_reference: Int = 0, dynamic_selected: Int = 0,
                 dynamic_factor: ScalarWord = ScalarWord(0, 0)):
        self.kind = kind
        self.inputs = inputs^
        self.output = output
        self.weight = weight
        self.window_tokens = window_tokens
        self.scaling_kind = scaling_kind
        self.scaling_factor = scaling_factor.copy()
        self.position_start = position_start
        self.dynamic_reference = dynamic_reference
        self.dynamic_selected = dynamic_selected
        self.dynamic_factor = dynamic_factor.copy()


struct SemanticPlan(Movable):
    var source_sharing: SourceWeightSharingPolicy
    var sharing_work: Int
    var source: SourceTensorInventory
    var tensors: List[SemanticTensor]
    var operations: List[SemanticOperation]
    var used_weights: Dict[String, Bool]
    var layers: Int
    var hidden: Int
    var feed_forward: Int
    var heads: Int
    var kv_heads: Int
    var key_dim: Int
    var value_dim: Int
    var rope_dim: Int
    var vocabulary: Int
    var context_capacity: Int
    var query_tokens: Int
    var past_tokens: Int
    var rope_base: Float32
    var rms_epsilon: Float32
    var source_layout: String
    var logits: Int
    var decoder_policy: DecoderGraphPolicy
    var explicit_dynamic: Bool
    var dynamic_source_context: Int
    var dynamic_before: DynamicDecoderHistory
    var dynamic_after: DynamicDecoderHistory
    var dynamic_work: Int
    var explicit_scaling: Bool
    var scaling_policy: DecoderScalingPolicy
    var scaling_work: Int
    var explicit_window: Bool
    var window_policy: DecoderWindowPolicy
    var window_work: Int
    var explicit_session: Bool
    var session_policy: DecoderSessionPolicy
    var session_work: Int
    var cache_exports: List[Int]
    var explicit_activation: Bool
    var activation_policy: DecoderActivationPolicy
    var activation_work: Int
    var explicit_bias: Bool
    var bias_policy: DecoderBiasPolicy
    var bias_work: Int
    var explicit_scalars: Bool
    var source_scalars: DecoderScalars

    def __init__(out self, var source: SourceTensorInventory):
        self.source_sharing = empty_source_weight_sharing()
        self.sharing_work = 0
        self.source = source^
        self.tensors = List[SemanticTensor]()
        self.operations = List[SemanticOperation]()
        self.used_weights = Dict[String, Bool]()
        self.layers = 0
        self.hidden = 0
        self.feed_forward = 0
        self.heads = 0
        self.kv_heads = 0
        self.key_dim = 0
        self.value_dim = 0
        self.rope_dim = 0
        self.vocabulary = 0
        self.context_capacity = 0
        self.query_tokens = 0
        self.past_tokens = 0
        self.rope_base = 0
        self.rms_epsilon = 0
        self.source_layout = String("")
        self.logits = -1
        self.decoder_policy = DecoderGraphPolicy(List[Int](), "", "")
        self.explicit_dynamic = False
        self.dynamic_source_context = 0
        self.dynamic_before = empty_dynamic_decoder_history()
        self.dynamic_after = empty_dynamic_decoder_history()
        self.dynamic_work = 0
        self.explicit_scaling = False
        self.scaling_policy = empty_scaling_policy()
        self.scaling_work = 0
        self.explicit_window = False
        self.window_policy = empty_window_policy()
        self.window_work = 0
        self.explicit_session = False
        self.session_policy = empty_session_policy()
        self.session_work = 0
        self.cache_exports = List[Int]()
        self.explicit_activation = False
        self.activation_policy = empty_activation_policy()
        self.activation_work = 0
        self.explicit_bias = False
        self.bias_policy = empty_bias_policy()
        self.bias_work = 0
        self.explicit_scalars = False
        self.source_scalars = empty_decoder_scalars()

    def tensor(mut self, name: String, var shape: List[Int], producer: Int = -1,
               persistent: Bool = False, alias_of: Int = -1) raises -> Int:
        var elements = 1
        for dimension in shape:
            elements = checked_product(elements, dimension)
        var index = len(self.tensors)
        self.tensors.append(SemanticTensor(name, shape^, elements, producer,
                                          producer, persistent, alias_of))
        return index

    def weight(mut self, name: String, columns: Int, rows: Int = 1, vector: Bool = False) raises:
        validate_source_weight(self.source, name, columns, rows, vector)
        self.used_weights[name] = True

    def emit(mut self, kind: String, name: String, var inputs: List[Int],
             var shape: List[Int], weight: String = "", alias_of: Int = -1,
             window_tokens: Int = 0, scaling_kind: String = "",
             scaling_factor: ScalarWord = ScalarWord(0, 0), position_start: Int = -1,
             dynamic_reference: Int = 0, dynamic_selected: Int = 0,
             dynamic_factor: ScalarWord = ScalarWord(0, 0)) raises -> Int:
        var index = len(self.operations)
        for input_id in inputs:
            if input_id < 0 or input_id >= len(self.tensors):
                raise Error("SemanticPlan: invalid input tensor")
            self.tensors[input_id].last_use = index
        if alias_of >= 0 and (alias_of >= len(self.tensors) or not self.tensors[alias_of].persistent):
            raise Error("SemanticPlan: only persistent KV storage may be aliased")
        if weight.byte_length() != 0 and weight not in self.used_weights:
            raise Error("SemanticPlan: operation weight was not shape checked")
        var output = self.tensor(name, shape^, index, False, alias_of)
        self.operations.append(SemanticOperation(kind, inputs^, output, weight, window_tokens, scaling_kind, scaling_factor, position_start, dynamic_reference, dynamic_selected, dynamic_factor))
        return output


def is_plan_export(plan: SemanticPlan, tensor: Int) raises -> Bool:
    if tensor == plan.logits:
        return True
    if len(plan.cache_exports) > plan.source.policy.work:
        raise Error("DecoderSession: export list exceeds source work")
    if plan.explicit_session:
        for id in plan.cache_exports:
            if id == tensor:
                return True
    return False


def validate_plan_source_sharing(plan: SemanticPlan) raises:
    var charge = validate_source_weight_sharing(plan.source, plan.source_sharing)
    if charge != plan.sharing_work:
        raise Error("SourceWeightSharing: retained source sharing charge changed")
    if len(plan.source_sharing.aliases) != 0:
        if not plan.explicit_scalars or not plan.explicit_bias or not plan.explicit_activation or not plan.explicit_session or not plan.explicit_window or not plan.explicit_scaling or plan.explicit_dynamic or plan.decoder_policy.output_weight != "token_embd.weight":
            raise Error("SourceWeightSharing: complete ordinary source recipe required")
        validate_shared_source_coverage(plan.source, plan.used_weights, plan.source_sharing)


def validate_plan_scalar_state(plan: SemanticPlan) raises:
    if plan.explicit_scalars:
        _ = validate_decoder_scalars(plan.source_scalars)
        if plan.source_scalars.work_limit > plan.source.policy.work or bitcast[DType.uint32](plan.rms_epsilon) != 0 or bitcast[DType.uint32](plan.rope_base) != 0:
            raise Error("SourceScalar: explicit state bound/compatibility slot changed")
    elif not same_decoder_scalars(plan.source_scalars, empty_decoder_scalars()):
        raise Error("SourceScalar: stray explicit scalar state")


def rms_scalar(plan: SemanticPlan) raises -> ScalarWord:
    var value = plan.source_scalars.epsilon.copy() if plan.explicit_scalars else ScalarWord(32, UInt64(bitcast[DType.uint32](plan.rms_epsilon)))
    validate_scalar_word(value)
    return value^


def rotary_scalar(plan: SemanticPlan) raises -> ScalarWord:
    var value = plan.source_scalars.rope_base.copy() if plan.explicit_scalars else ScalarWord(32, UInt64(bitcast[DType.uint32](plan.rope_base)))
    validate_scalar_word(value)
    return value^


def gguf_dense_decoder_parameters(source: PackedGGUF) raises -> DenseDecoderParameters:
    """Decode only the existing GGUF recipe; storage/architecture breadth follows."""
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SemanticPlan: live GGUF metadata owner required")
    var architecture = source.text("general.architecture")
    if architecture != "llama":
        raise Error("SemanticPlan: architecture semantic importer unresolved: " + architecture)
    var prefix = String("llama.")
    # Never silently drop a new architecture-specific semantic modifier.
    var known = Dict[String, Bool]()
    var keys: List[String] = ["context_length", "embedding_length", "block_count",
        "feed_forward_length", "attention.head_count", "attention.head_count_kv",
        "attention.key_length", "attention.value_length", "rope.dimension_count",
        "rope.freq_base", "attention.layer_norm_rms_epsilon", "tensor_data_layout",
        "rope.scaling.type", "vocab_size"]
    for key in keys:
        known[prefix + key] = True
    var integer_keys: List[String] = ["context_length", "embedding_length", "block_count",
        "feed_forward_length", "attention.head_count", "attention.head_count_kv",
        "attention.key_length", "attention.value_length", "rope.dimension_count", "vocab_size"]
    for key in integer_keys:
        var full_key = prefix + key
        if full_key in source.fields and source.field_types[full_key] != 4 and source.field_types[full_key] != 10:
            raise Error("SemanticPlan: expected unsigned integer shape metadata: " + full_key)
    for key in source.fields:
        if String(key).startswith(prefix) and key not in known:
            raise Error("SemanticPlan: metadata semantics unresolved: " + key)
    if prefix + "rope.scaling.type" in source.fields and source.text(prefix + "rope.scaling.type") != "none":
        raise Error("SemanticPlan: scaled RoPE recipe unresolved")
    var layers = source.integer(prefix + "block_count")
    var hidden = source.integer(prefix + "embedding_length")
    var feed_forward = source.integer(prefix + "feed_forward_length")
    var heads = source.integer(prefix + "attention.head_count")
    var kv_heads = source.integer(prefix + "attention.head_count_kv", heads)
    if heads <= 0 or hidden <= 0 or kv_heads <= 0 or heads % kv_heads != 0:
        raise Error("SemanticPlan: invalid hidden/query/KV head dimensions")
    var default_dim = hidden // heads
    if hidden % heads != 0 and (prefix + "attention.key_length" not in source.fields or prefix + "attention.value_length" not in source.fields):
        raise Error("SemanticPlan: non-integral default head dimension")
    if "token_embd.weight" not in source.tensors:
        raise Error("SemanticPlan: missing embedding")
    var vocabulary = source.tensors["token_embd.weight"].rows
    if prefix + "vocab_size" in source.fields and source.integer(prefix + "vocab_size") != vocabulary:
        raise Error("SemanticPlan: vocabulary metadata and embedding disagree")
    return DenseDecoderParameters(layers, hidden, feed_forward, heads, kv_heads,
        source.integer(prefix + "attention.key_length", default_dim),
        source.integer(prefix + "attention.value_length", default_dim),
        source.integer(prefix + "rope.dimension_count"), vocabulary,
        source.integer(prefix + "context_length"), source.floating(prefix + "rope.freq_base"),
        source.floating(prefix + "attention.layer_norm_rms_epsilon"),
        source.text(prefix + "tensor_data_layout") if prefix + "tensor_data_layout" in source.fields else String("reference"))


def _sift_spans(mut starts: List[Int], mut ends: List[Int], size: Int, root: Int):
    var parent = root
    while parent < size // 2:
        var child = parent * 2 + 1
        if child + 1 < size and starts[child + 1] > starts[child]:
            child += 1
        if starts[parent] >= starts[child]:
            return
        var start = starts[parent]
        var end = ends[parent]
        starts[parent] = starts[child]
        ends[parent] = ends[child]
        starts[child] = start
        ends[child] = end
        parent = child


def _check_disjoint_spans(mut starts: List[Int], mut ends: List[Int]) raises:
    # Original paired heapsort: bounded metadata, O(n log n), no file access.
    var parent = len(starts) // 2
    while parent > 0:
        parent -= 1
        _sift_spans(starts, ends, len(starts), parent)
    var size = len(starts)
    while size > 1:
        size -= 1
        var start = starts[0]
        var end = ends[0]
        starts[0] = starts[size]
        ends[0] = ends[size]
        starts[size] = start
        ends[size] = end
        _sift_spans(starts, ends, size, 0)
    for i in range(1, len(starts)):
        if starts[i] < ends[i - 1]:
            raise Error("SemanticPlan: overlapping descriptive source bindings")


def validate_dense_gguf_inventory(source: SourceTensorInventory) raises:
    """Recheck mutable GGUF descriptors, not backing-file identity or device fit."""
    if source.architecture != "llama":
        raise Error("SemanticPlan: architecture semantic importer unresolved: " + source.architecture)
    validate_source_inventory(source)
    for name in source.storage:
        if source.storage[name].source_format != "gguf":
            raise Error("SemanticPlan: ordinary configuration adapter remains unresolved")


def validate_dense_decoder_parameters(parameters: DenseDecoderParameters,
                                      source: SourceTensorInventory,
                                      query_tokens: Int, past_tokens: Int,
                                      context_capacity: Int) raises:
    if not isfinite(parameters.rms_epsilon) or parameters.rms_epsilon <= 0 or not isfinite(parameters.rope_base) or parameters.rope_base <= 0:
        raise Error("SemanticPlan: non-finite or non-positive numerical parameter")
    validate_decoder_geometry(decoder_geometry(parameters), source, query_tokens, past_tokens, context_capacity)


def validate_decoder_geometry(p: DecoderGeometry, source: SourceTensorInventory,
                              query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises:
    _validate_decoder_geometry(p, source, query_tokens, past_tokens, context_capacity, 0)


def _validate_decoder_geometry(p: DecoderGeometry, source: SourceTensorInventory,
                               query_tokens: Int, past_tokens: Int,
                               context_capacity: Int, dynamic_limit: Int) raises:
    if p.layers <= 0 or p.layers > len(source.bindings) // 9 or p.layers > (9223372036854775807 - 5) // 23:
        raise Error("SemanticPlan: layer count exceeds source tensor evidence")
    if p.hidden <= 0 or p.feed_forward <= 0 or p.vocabulary <= 0 or p.source_context <= 0:
        raise Error("SemanticPlan: invalid decoder dimensions")
    if p.heads <= 0 or p.kv_heads <= 0 or p.heads % p.kv_heads != 0:
        raise Error("SemanticPlan: invalid hidden/query/KV head dimensions")
    _ = checked_product(p.heads, p.key_dim)
    _ = checked_product(p.kv_heads, p.key_dim)
    _ = checked_product(p.kv_heads, p.value_dim)
    _ = checked_product(p.heads, p.value_dim)
    if p.rope_dim <= 0 or p.rope_dim > p.key_dim or p.rope_dim % 2 != 0:
        raise Error("SemanticPlan: invalid rotary dimension")
    if query_tokens <= 0 or past_tokens < 0 or context_capacity <= 0 or context_capacity > (p.source_context if dynamic_limit == 0 else dynamic_limit) or past_tokens > context_capacity or query_tokens > context_capacity - past_tokens:
        raise Error("SemanticPlan: invalid session query/past/context extent")
    if "token_embd.weight" not in source.bindings:
        raise Error("SemanticPlan: missing embedding")
    if source.bindings["token_embd.weight"].rows != p.vocabulary:
        raise Error("SemanticPlan: vocabulary metadata and embedding disagree")


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              parameters: DenseDecoderParameters,
                              policy: DecoderGraphPolicy,
                              query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    return _build_decoder_semantic_plan(source^, parameters, empty_decoder_scalars(), False,
        policy, query_tokens, past_tokens, context_capacity)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              geometry: DecoderGeometry, scalars: DecoderScalars,
                              policy: DecoderGraphPolicy, query_tokens: Int,
                              past_tokens: Int, context_capacity: Int) raises -> SemanticPlan:
    _ = validate_decoder_scalars(scalars)
    if scalars.work_limit > source.policy.work:
        raise Error("SourceScalar: scalar work limit exceeds source policy")
    # Zero slots are explicitly unavailable compatibility fields, never rounded constants.
    var p = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim,
        geometry.rope_dim, geometry.vocabulary, geometry.source_context, 0, 0, geometry.source_layout)
    return _build_decoder_semantic_plan(source^, p, scalars, True, policy,
        query_tokens, past_tokens, context_capacity)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              parameters: DenseDecoderParameters, policy: DecoderGraphPolicy,
                              bias: DecoderBiasPolicy, query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    return _build_decoder_semantic_plan(source^, parameters, empty_decoder_scalars(), False,
        policy, query_tokens, past_tokens, context_capacity, bias, True)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              geometry: DecoderGeometry, scalars: DecoderScalars,
                              policy: DecoderGraphPolicy, bias: DecoderBiasPolicy,
                              query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    _ = validate_decoder_scalars(scalars)
    if scalars.work_limit > source.policy.work:
        raise Error("SourceScalar: scalar work limit exceeds source policy")
    var p = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim,
        geometry.rope_dim, geometry.vocabulary, geometry.source_context, 0, 0, geometry.source_layout)
    return _build_decoder_semantic_plan(source^, p, scalars, True, policy,
        query_tokens, past_tokens, context_capacity, bias, True)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              parameters: DenseDecoderParameters, policy: DecoderGraphPolicy,
                              bias: DecoderBiasPolicy, activation: DecoderActivationPolicy,
                              query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    return _build_decoder_semantic_plan(source^, parameters, empty_decoder_scalars(), False,
        policy, query_tokens, past_tokens, context_capacity, bias, True, activation, True)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              geometry: DecoderGeometry, scalars: DecoderScalars,
                              policy: DecoderGraphPolicy, bias: DecoderBiasPolicy,
                              activation: DecoderActivationPolicy, query_tokens: Int,
                              past_tokens: Int, context_capacity: Int) raises -> SemanticPlan:
    _ = validate_decoder_scalars(scalars)
    if scalars.work_limit > source.policy.work:
        raise Error("SourceScalar: scalar work limit exceeds source policy")
    var p = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim,
        geometry.rope_dim, geometry.vocabulary, geometry.source_context, 0, 0, geometry.source_layout)
    return _build_decoder_semantic_plan(source^, p, scalars, True, policy,
        query_tokens, past_tokens, context_capacity, bias, True, activation, True)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              parameters: DenseDecoderParameters, policy: DecoderGraphPolicy,
                              bias: DecoderBiasPolicy, activation: DecoderActivationPolicy,
                              session: DecoderSessionPolicy, query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    return _build_decoder_semantic_plan(source^, parameters, empty_decoder_scalars(), False,
        policy, query_tokens, past_tokens, context_capacity, bias, True, activation, True, session, True)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              geometry: DecoderGeometry, scalars: DecoderScalars,
                              policy: DecoderGraphPolicy, bias: DecoderBiasPolicy,
                              activation: DecoderActivationPolicy, session: DecoderSessionPolicy,
                              query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    _ = validate_decoder_scalars(scalars)
    if scalars.work_limit > source.policy.work:
        raise Error("SourceScalar: scalar work limit exceeds source policy")
    var p = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim,
        geometry.rope_dim, geometry.vocabulary, geometry.source_context, 0, 0, geometry.source_layout)
    return _build_decoder_semantic_plan(source^, p, scalars, True, policy,
        query_tokens, past_tokens, context_capacity, bias, True, activation, True, session, True)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              parameters: DenseDecoderParameters, policy: DecoderGraphPolicy,
                              bias: DecoderBiasPolicy, activation: DecoderActivationPolicy,
                              session: DecoderSessionPolicy, window: DecoderWindowPolicy, query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    return _build_decoder_semantic_plan(source^, parameters, empty_decoder_scalars(), False,
        policy, query_tokens, past_tokens, context_capacity, bias, True, activation, True, session, True, window, True)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              geometry: DecoderGeometry, scalars: DecoderScalars,
                              policy: DecoderGraphPolicy, bias: DecoderBiasPolicy,
                              activation: DecoderActivationPolicy, session: DecoderSessionPolicy, window: DecoderWindowPolicy,
                              query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    _ = validate_decoder_scalars(scalars)
    if scalars.work_limit > source.policy.work:
        raise Error("SourceScalar: scalar work limit exceeds source policy")
    var p = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim,
        geometry.rope_dim, geometry.vocabulary, geometry.source_context, 0, 0, geometry.source_layout)
    return _build_decoder_semantic_plan(source^, p, scalars, True, policy,
        query_tokens, past_tokens, context_capacity, bias, True, activation, True, session, True, window, True)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              parameters: DenseDecoderParameters, policy: DecoderGraphPolicy,
                              bias: DecoderBiasPolicy, activation: DecoderActivationPolicy,
                              session: DecoderSessionPolicy, window: DecoderWindowPolicy, scaling: DecoderScalingPolicy, query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    return _build_decoder_semantic_plan(source^, parameters, empty_decoder_scalars(), False,
        policy, query_tokens, past_tokens, context_capacity, bias, True, activation, True, session, True, window, True, scaling, True)


def build_decoder_semantic_plan(var source: SourceTensorInventory,
                              geometry: DecoderGeometry, scalars: DecoderScalars,
                              policy: DecoderGraphPolicy, bias: DecoderBiasPolicy,
                              activation: DecoderActivationPolicy, session: DecoderSessionPolicy, window: DecoderWindowPolicy, scaling: DecoderScalingPolicy,
                              query_tokens: Int, past_tokens: Int,
                              context_capacity: Int,
                              source_sharing: SourceWeightSharingPolicy = empty_source_weight_sharing()) raises -> SemanticPlan:
    _ = validate_decoder_scalars(scalars)
    if scalars.work_limit > source.policy.work:
        raise Error("SourceScalar: scalar work limit exceeds source policy")
    var p = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim,
        geometry.rope_dim, geometry.vocabulary, geometry.source_context, 0, 0, geometry.source_layout)
    return _build_decoder_semantic_plan(source^, p, scalars, True, policy,
        query_tokens, past_tokens, context_capacity, bias, True, activation, True, session, True, window, True, scaling, True, source_sharing=source_sharing)


def build_dynamic_decoder_semantic_plan(var source: SourceTensorInventory,
                              parameters: DenseDecoderParameters, policy: DecoderGraphPolicy,
                              bias: DecoderBiasPolicy, activation: DecoderActivationPolicy,
                              session: DecoderSessionPolicy, window: DecoderWindowPolicy,
                              before: DynamicDecoderHistory, query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    return _build_decoder_semantic_plan(source^, parameters, empty_decoder_scalars(), False,
        policy, query_tokens, past_tokens, context_capacity, bias, True, activation, True,
        session, True, window, True, empty_scaling_policy(), False, before, True)


def build_dynamic_decoder_semantic_plan(var source: SourceTensorInventory,
                              geometry: DecoderGeometry, scalars: DecoderScalars,
                              policy: DecoderGraphPolicy, bias: DecoderBiasPolicy,
                              activation: DecoderActivationPolicy, session: DecoderSessionPolicy,
                              window: DecoderWindowPolicy, before: DynamicDecoderHistory,
                              query_tokens: Int, past_tokens: Int, context_capacity: Int) raises -> SemanticPlan:
    _ = validate_decoder_scalars(scalars)
    if scalars.work_limit > source.policy.work:
        raise Error("SourceScalar: scalar work limit exceeds source policy")
    var p = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim,
        geometry.rope_dim, geometry.vocabulary, geometry.source_context, 0, 0, geometry.source_layout)
    return _build_decoder_semantic_plan(source^, p, scalars, True, policy,
        query_tokens, past_tokens, context_capacity, bias, True, activation, True,
        session, True, window, True, empty_scaling_policy(), False, before, True)


def dynamic_plan_work(before: DynamicDecoderHistory, after: DynamicDecoderHistory,
                      past: Int, query: Int, flags: List[Int], source_work: Int) raises -> Int:
    var a = validate_dynamic_decoder_history(before, past, source_work)
    var b = validate_dynamic_decoder_history(after, past + query, source_work)
    if source_work < 128 or a > source_work - 128 or b > source_work - 128 - a:
        raise Error("DynamicDecoder: graph history work exceeded")
    var remaining = source_work - 128 - a - b
    var count = 0
    if len(flags) > source_work:
        raise Error("DynamicDecoder: rotary selection scan exceeded")
    for flag in flags:
        if flag != 0 and flag != 1:
            raise Error("DynamicDecoder: invalid rotary selection")
        if flag == 1:
            if remaining < 128:
                raise Error("DynamicDecoder: rotary descriptor work exceeded")
            remaining -= 128
            count += 2
    return 128 + a + b + 64 * count


def _build_decoder_semantic_plan(var source: SourceTensorInventory,
                               parameters: DenseDecoderParameters, scalars: DecoderScalars,
                               explicit: Bool, policy: DecoderGraphPolicy, query_tokens: Int,
                               past_tokens: Int, context_capacity: Int,
                               bias_policy: DecoderBiasPolicy = empty_bias_policy(),
                               explicit_bias: Bool = False,
                               activation_policy: DecoderActivationPolicy = empty_activation_policy(),
                               explicit_activation: Bool = False,
                               session_policy: DecoderSessionPolicy = empty_session_policy(),
                               explicit_session: Bool = False,
                               window_policy: DecoderWindowPolicy = empty_window_policy(),
                               explicit_window: Bool = False,
                               scaling_policy: DecoderScalingPolicy = empty_scaling_policy(),
                               explicit_scaling: Bool = False,
                               dynamic_before: DynamicDecoderHistory = empty_dynamic_decoder_history(),
                               explicit_dynamic: Bool = False,
                               source_sharing: SourceWeightSharingPolicy = empty_source_weight_sharing()) raises -> SemanticPlan:
    """Build an explicitly selected mathematical recipe from tagged values."""
    validate_source_inventory(source)
    var dynamic_after = empty_dynamic_decoder_history()
    var dynamic_work = 0
    if explicit_dynamic:
        if explicit_scaling or not explicit_session or not explicit_window or dynamic_before.policy.reference != parameters.source_context:
            raise Error("DynamicDecoder: distinct session/window/source context ownership required")
        _ = validate_dynamic_decoder_history(dynamic_before, past_tokens, source.policy.work)
        _validate_decoder_geometry(decoder_geometry(parameters), source, query_tokens, past_tokens, context_capacity, dynamic_before.policy.limit)
        if not explicit and (not isfinite(parameters.rms_epsilon) or parameters.rms_epsilon <= 0 or not isfinite(parameters.rope_base) or parameters.rope_base <= 0):
            raise Error("SemanticPlan: non-finite or non-positive numerical parameter")
        var theta = scalars.rope_base.copy() if explicit else ScalarWord(32, UInt64(bitcast[DType.uint32](parameters.rope_base)))
        if not same_scalar_word(theta, dynamic_before.policy.theta):
            raise Error("DynamicDecoder: exact selected theta word differs from policy")
        dynamic_after = advance_dynamic_decoder_history(dynamic_before, query_tokens, past_tokens, context_capacity, source.policy.work)
        dynamic_work = dynamic_plan_work(dynamic_before, dynamic_after, past_tokens, query_tokens, policy.rope_enabled, source.policy.work)
    elif explicit:
        validate_decoder_geometry(decoder_geometry(parameters), source, query_tokens, past_tokens, context_capacity)
    else:
        validate_dense_decoder_parameters(parameters, source, query_tokens, past_tokens, context_capacity)
    validate_decoder_graph_policy(policy, source, parameters.layers, parameters.hidden, parameters.vocabulary)
    var bias_work = 0
    if explicit_bias:
        bias_work = validate_bias_policy(bias_policy, parameters.layers, len(source.bindings), source.policy.work)
    var activation_work = 0
    if explicit_activation:
        activation_work = validate_activation_policy(activation_policy, parameters.layers, source.policy.work)
    var session_work = 0
    if explicit_session:
        session_work = validate_session_policy(session_policy, parameters.layers, source.policy.work)
        if session_policy.mode == "full_prefix" and past_tokens != 0:
            raise Error("DecoderSession: full prefix cannot discard supplied past state")
    var window_work = 0
    if explicit_window:
        if not explicit_session:
            raise Error("DecoderWindow: explicit session required")
        window_work = validate_window_policy(window_policy, parameters.layers, source.policy.work)
    var scaling_work = 0
    if explicit_scaling:
        if not explicit_session or not explicit_window:
            raise Error("DecoderScaling: explicit session/window ownership required")
        scaling_work = validate_scaling_policy(scaling_policy, source.policy.work)
    var plan = SemanticPlan(source^)
    plan.sharing_work = validate_source_weight_sharing(plan.source, source_sharing)
    plan.source_sharing = source_sharing.copy()
    plan.explicit_dynamic = explicit_dynamic
    if explicit_dynamic:
        plan.dynamic_source_context = parameters.source_context
        plan.dynamic_before = dynamic_before.copy()
        plan.dynamic_after = dynamic_after.copy()
        plan.dynamic_work = dynamic_work
    plan.explicit_scaling = explicit_scaling
    plan.scaling_policy = scaling_policy.copy()
    plan.scaling_work = scaling_work
    plan.explicit_window = explicit_window
    plan.window_policy = window_policy.copy()
    plan.window_work = window_work
    plan.explicit_session = explicit_session
    plan.session_policy = session_policy.copy()
    plan.session_work = session_work
    plan.explicit_activation = explicit_activation
    plan.activation_policy = activation_policy.copy()
    plan.activation_work = activation_work
    plan.explicit_bias = explicit_bias
    plan.bias_policy = bias_policy.copy()
    plan.bias_work = bias_work
    plan.decoder_policy = policy.copy()
    plan.explicit_scalars = explicit
    plan.source_scalars = scalars.copy()
    plan.layers = parameters.layers
    plan.hidden = parameters.hidden
    plan.feed_forward = parameters.feed_forward
    plan.heads = parameters.heads
    plan.kv_heads = parameters.kv_heads
    plan.key_dim = parameters.key_dim
    plan.value_dim = parameters.value_dim
    plan.rope_dim = parameters.rope_dim
    plan.vocabulary = parameters.vocabulary
    plan.rope_base = parameters.rope_base
    plan.rms_epsilon = parameters.rms_epsilon
    plan.source_layout = parameters.source_layout
    plan.query_tokens = query_tokens
    plan.past_tokens = past_tokens
    plan.context_capacity = context_capacity
    var query_width = checked_product(plan.heads, plan.key_dim)
    var key_width = checked_product(plan.kv_heads, plan.key_dim)
    var value_width = checked_product(plan.kv_heads, plan.value_dim)
    var attended_width = checked_product(plan.heads, plan.value_dim)
    var total = past_tokens + query_tokens
    plan.weight("token_embd.weight", plan.hidden, plan.vocabulary)
    plan.weight("output_norm.weight", plan.hidden, 1, True)
    var output_weight = policy.output_weight
    plan.weight(output_weight, plan.hidden, plan.vocabulary)
    var tokens = plan.tensor("tokens", [query_tokens])
    var positions: Int
    if explicit_dynamic:
        positions = plan.emit("position_range", "positions", List[Int](), [query_tokens], "", -1, 0, "", ScalarWord(0, 0), past_tokens)
    else:
        positions = plan.tensor("positions", [query_tokens])
    var x = plan.emit("embedding_gather", "embedding", [tokens], [query_tokens, plan.hidden], "token_embd.weight")
    for layer in range(plan.layers):
        var p = String("blk.") + String(layer) + "."
        plan.weight(p + "attn_norm.weight", plan.hidden, 1, True)
        plan.weight(p + "ffn_norm.weight", plan.hidden, 1, True)
        plan.weight(p + "attn_q.weight", plan.hidden, query_width)
        plan.weight(p + "attn_k.weight", plan.hidden, key_width)
        plan.weight(p + "attn_v.weight", plan.hidden, value_width)
        plan.weight(p + "attn_output.weight", attended_width, plan.hidden)
        plan.weight(p + "ffn_gate.weight", plan.hidden, plan.feed_forward)
        plan.weight(p + "ffn_up.weight", plan.hidden, plan.feed_forward)
        plan.weight(p + "ffn_down.weight", plan.feed_forward, plan.hidden)
        var residual = x
        var norm = plan.emit("rms_norm", p + "attn_norm", [x], [query_tokens, plan.hidden], p + "attn_norm.weight")
        var q = plan.emit("linear", p + "q", [norm], [query_tokens, plan.heads, plan.key_dim], p + "attn_q.weight")
        var k = plan.emit("linear", p + "k", [norm], [query_tokens, plan.kv_heads, plan.key_dim], p + "attn_k.weight")
        var v = plan.emit("linear", p + "v", [norm], [query_tokens, plan.kv_heads, plan.value_dim], p + "attn_v.weight")
        if explicit_bias and bias_policy.attention[layer] == 1:
            plan.weight(p + "attn_q.bias", query_width, 1, True)
            plan.weight(p + "attn_k.bias", key_width, 1, True)
            plan.weight(p + "attn_v.bias", value_width, 1, True)
            q = plan.emit("add_projection_bias", p + "q_biased", [q], [query_tokens, plan.heads, plan.key_dim], p + "attn_q.bias")
            k = plan.emit("add_projection_bias", p + "k_biased", [k], [query_tokens, plan.kv_heads, plan.key_dim], p + "attn_k.bias")
            v = plan.emit("add_projection_bias", p + "v_biased", [v], [query_tokens, plan.kv_heads, plan.value_dim], p + "attn_v.bias")
        if policy.rope_enabled[layer] == 1:
            q = plan.emit("rope_query", p + "q_rotary", [q, positions], [query_tokens, plan.heads, plan.key_dim], "", -1, 0, scaling_policy.kind if explicit_scaling else String(""), scaling_policy.factor.copy() if explicit_scaling else ScalarWord(0, 0), -1, dynamic_before.policy.reference if explicit_dynamic else 0, dynamic_after.selected_contexts[len(dynamic_after.selected_contexts) - 1] if explicit_dynamic else 0, dynamic_before.policy.factor.copy() if explicit_dynamic else ScalarWord(0, 0))
            k = plan.emit("rope_key", p + "k_rotary", [k, positions], [query_tokens, plan.kv_heads, plan.key_dim], "", -1, 0, scaling_policy.kind if explicit_scaling else String(""), scaling_policy.factor.copy() if explicit_scaling else ScalarWord(0, 0), -1, dynamic_before.policy.reference if explicit_dynamic else 0, dynamic_after.selected_contexts[len(dynamic_after.selected_contexts) - 1] if explicit_dynamic else 0, dynamic_before.policy.factor.copy() if explicit_dynamic else ScalarWord(0, 0))
        var keys_view = k
        var values_view = v
        if not explicit_session or session_policy.mode == "cached_append":
            var cache_k = plan.tensor(p + "key_cache", [context_capacity, plan.kv_heads, plan.key_dim], -1, True)
            var cache_v = plan.tensor(p + "value_cache", [context_capacity, plan.kv_heads, plan.value_dim], -1, True)
            keys_view = plan.emit("kv_append_keys", p + "keys_view", [cache_k, k], [total, plan.kv_heads, plan.key_dim], "", cache_k)
            values_view = plan.emit("kv_append_values", p + "values_view", [cache_v, v], [total, plan.kv_heads, plan.value_dim], "", cache_v)
        if explicit_session and session_policy.return_cache == 1:
            plan.cache_exports.append(keys_view)
            plan.cache_exports.append(values_view)
        var scores = plan.emit("gqa_scaled_dot", p + "scores", [q, keys_view], [plan.heads, query_tokens, total])
        scores = plan.emit("causal_window_mask" if explicit_window and window_policy.windows[layer] > 0 else String("causal_mask"), p + "masked_scores", [scores, positions], [plan.heads, query_tokens, total], "", -1, window_policy.windows[layer] if explicit_window else 0)
        scores = plan.emit("softmax", p + "probabilities", [scores], [plan.heads, query_tokens, total])
        var attention = plan.emit("gqa_weighted_values", p + "attention", [scores, values_view], [query_tokens, attended_width])
        attention = plan.emit("linear", p + "attn_output", [attention], [query_tokens, plan.hidden], p + "attn_output.weight")
        if explicit_bias and bias_policy.attention[layer] == 1:
            plan.weight(p + "attn_output.bias", plan.hidden, 1, True)
            attention = plan.emit("add_projection_bias", p + "attn_output_biased", [attention], [query_tokens, plan.hidden], p + "attn_output.bias")
        x = plan.emit("add", p + "attn_residual", [residual, attention], [query_tokens, plan.hidden])
        residual = x
        norm = plan.emit("rms_norm", p + "ffn_norm", [x], [query_tokens, plan.hidden], p + "ffn_norm.weight")
        var gate = plan.emit("linear", p + "gate", [norm], [query_tokens, plan.feed_forward], p + "ffn_gate.weight")
        var up = plan.emit("linear", p + "up", [norm], [query_tokens, plan.feed_forward], p + "ffn_up.weight")
        if explicit_bias and bias_policy.mlp[layer] == 1:
            plan.weight(p + "ffn_gate.bias", plan.feed_forward, 1, True)
            plan.weight(p + "ffn_up.bias", plan.feed_forward, 1, True)
            gate = plan.emit("add_projection_bias", p + "gate_biased", [gate], [query_tokens, plan.feed_forward], p + "ffn_gate.bias")
            up = plan.emit("add_projection_bias", p + "up_biased", [up], [query_tokens, plan.feed_forward], p + "ffn_up.bias")
        var activation = activation_policy.kinds[layer] if explicit_activation else String("silu")
        gate = plan.emit(activation, p + "gate_" + activation, [gate], [query_tokens, plan.feed_forward])
        gate = plan.emit("multiply", p + "gated", [gate, up], [query_tokens, plan.feed_forward])
        var down = plan.emit("linear", p + "down", [gate], [query_tokens, plan.hidden], p + "ffn_down.weight")
        if explicit_bias and bias_policy.mlp[layer] == 1:
            plan.weight(p + "ffn_down.bias", plan.hidden, 1, True)
            down = plan.emit("add_projection_bias", p + "down_biased", [down], [query_tokens, plan.hidden], p + "ffn_down.bias")
        x = plan.emit("add", p + "ffn_residual", [residual, down], [query_tokens, plan.hidden])
    x = plan.emit("rms_norm", "output_norm", [x], [query_tokens, plan.hidden], "output_norm.weight")
    plan.logits = plan.emit("linear", "logits", [x], [query_tokens, plan.vocabulary], output_weight)
    # Exact consumed tensor set: do not silently omit biases, norms or factors.
    if len(plan.source_sharing.aliases) == 0:
        for name in plan.source.bindings:
            if name not in plan.used_weights:
                raise Error("SemanticPlan: source tensor semantics unresolved: " + name)
    validate_plan_source_sharing(plan)
    var end = len(plan.operations)
    plan.tensors[plan.logits].last_use = end
    for i in range(len(plan.tensors)):
        if plan.tensors[i].persistent or is_plan_export(plan, i):
            plan.tensors[i].last_use = end
    return plan^



def build_dense_semantic_plan(var source: SourceTensorInventory,
                              parameters: DenseDecoderParameters,
                              query_tokens: Int, past_tokens: Int,
                              context_capacity: Int) raises -> SemanticPlan:
    """Historical GGUF recipe and output selection, with unchanged graph fields."""
    validate_dense_gguf_inventory(source)
    validate_dense_decoder_parameters(parameters, source, query_tokens, past_tokens, context_capacity)
    if parameters.layers > source.policy.tensors or parameters.layers > source.policy.work:
        raise Error("SemanticPlan: rotary policy exceeds admitted source bounds")
    var flags = List[Int]()
    for _ in range(parameters.layers):
        flags.append(1)
    var output = String("output.weight") if "output.weight" in source.bindings else String("token_embd.weight")
    var policy = DecoderGraphPolicy(flags^, output, "historical GGUF dense recipe")
    return build_decoder_semantic_plan(source^, parameters, policy, query_tokens, past_tokens, context_capacity)


def read_dense_semantic_plan(path: String, query_tokens: Int,
                             past_tokens: Int, context_capacity: Int) raises -> SemanticPlan:
    var source = PackedGGUF(path)
    try:
        var parameters = gguf_dense_decoder_parameters(source)
        var inventory = inventory_from_source(source)
        source.source.close()
        return build_dense_semantic_plan(inventory^, parameters, query_tokens,
                                         past_tokens, context_capacity)
    except e:
        source.source.close()
        raise e


def validate_plan_window_state(plan: SemanticPlan) raises:
    validate_plan_scaling_state(plan)
    if not plan.explicit_window:
        if not same_window_policy(plan.window_policy, empty_window_policy()) or plan.window_work != 0:
            raise Error("DecoderWindow: stray explicit policy state")
        for op in plan.operations:
            if op.kind == "causal_window_mask" or op.window_tokens != 0:
                raise Error("DecoderWindow: mask lacks explicit policy")
        return
    if not plan.explicit_session or validate_window_policy(plan.window_policy, plan.layers, plan.source.policy.work) != plan.window_work:
        raise Error("DecoderWindow: session/policy/accounting changed")
    if len(plan.operations) > plan.source.policy.work or len(plan.tensors) > plan.source.policy.work or plan.query_tokens <= 0 or plan.past_tokens < 0 or plan.past_tokens > plan.context_capacity or plan.query_tokens > plan.context_capacity - plan.past_tokens:
        raise Error("DecoderWindow: graph/session work bounds changed")
    var names = Dict[String, Int]()
    for i in range(len(plan.tensors)):
        if plan.tensors[i].name in names:
            raise Error("DecoderWindow: duplicate source role")
        names[plan.tensors[i].name] = i
    if "positions" not in names:
        raise Error("DecoderWindow: positions missing")
    if plan.explicit_dynamic:
        validate_plan_position_role(plan, names["positions"])
    var masks = 0
    for op in plan.operations:
        if op.kind != "causal_window_mask" and op.window_tokens != 0:
            raise Error("DecoderWindow: stray source width metadata")
        masks += Int(op.kind == "causal_mask" or op.kind == "causal_window_mask")
    if masks != plan.layers:
        raise Error("DecoderWindow: incomplete/duplicate mask set")
    for layer in range(plan.layers):
        var p = String("blk.") + String(layer) + "."
        if p + "masked_scores" not in names or p + "scores" not in names:
            raise Error("DecoderWindow: source score/mask role missing")
        var id = names[p + "masked_scores"]
        var t = plan.tensors[id].copy()
        if t.producer < 0 or t.producer >= len(plan.operations) or t.persistent or t.alias_of != -1:
            raise Error("DecoderWindow: invalid mask producer/storage")
        var op = plan.operations[t.producer].copy()
        var kind = String("causal_window_mask") if plan.window_policy.windows[layer] > 0 else String("causal_mask")
        var shape = List[Int]([plan.heads, plan.query_tokens, plan.past_tokens + plan.query_tokens])
        var elements = checked_product(checked_product(plan.heads, plan.query_tokens), plan.past_tokens + plan.query_tokens)
        var scores = plan.tensors[names[p + "scores"]].copy()
        var positions = plan.tensors[names["positions"]].copy()
        if t.elements != elements or scores.shape != shape or scores.elements != elements or scores.producer < 0 or scores.producer >= t.producer or scores.persistent or scores.alias_of != -1 or positions.producer != (0 if plan.explicit_dynamic else -1) or positions.persistent or positions.alias_of != -1 or positions.shape != List[Int]([plan.query_tokens]) or positions.elements != plan.query_tokens:
            raise Error("DecoderWindow: changed mask input/product/storage/positions")
        if op.kind != kind or op.window_tokens != plan.window_policy.windows[layer] or op.output != id or op.inputs != List[Int]([names[p + "scores"], names["positions"]]) or op.weight.byte_length() != 0 or t.shape != shape:
            raise Error("DecoderWindow: changed selected mask/edge/shape")


def validate_plan_scaling_state(plan: SemanticPlan) raises:
    if len(plan.operations) > plan.source.policy.work or len(plan.tensors) > plan.source.policy.work:
        raise Error("DecoderScaling: graph work bound changed")
    validate_plan_dynamic_state(plan)
    if not plan.explicit_scaling:
        if not same_scaling_policy(plan.scaling_policy, empty_scaling_policy()) or plan.scaling_work != 0:
            raise Error("DecoderScaling: stray explicit policy state")
        for op in plan.operations:
            if op.scaling_kind.byte_length() != 0 or op.scaling_factor.width != 0 or op.scaling_factor.bits != 0:
                raise Error("DecoderScaling: source metadata lacks explicit policy")
        return
    if not plan.explicit_session or not plan.explicit_window or validate_scaling_policy(plan.scaling_policy, plan.source.policy.work) != plan.scaling_work:
        raise Error("DecoderScaling: policy ownership/accounting changed")
    validate_decoder_graph_policy(plan.decoder_policy, plan.source, plan.layers, plan.hidden, plan.vocabulary)
    if plan.query_tokens <= 0 or plan.key_dim <= 0 or plan.rope_dim <= 0 or plan.rope_dim > plan.key_dim or plan.rope_dim % 2 != 0:
        raise Error("DecoderScaling: rotary dimensions changed")
    var names = Dict[String, Int]()
    for i in range(len(plan.tensors)):
        if plan.tensors[i].name in names:
            raise Error("DecoderScaling: duplicate source role")
        names[plan.tensors[i].name] = i
    if "positions" not in names:
        raise Error("DecoderScaling: source positions missing")
    var pos_id = names["positions"]
    var pos = plan.tensors[pos_id].copy()
    if pos.shape != List[Int]([plan.query_tokens]) or pos.elements != plan.query_tokens or pos.producer != -1 or pos.persistent or pos.alias_of != -1:
        raise Error("DecoderScaling: changed source positions")
    var count = 0
    for op in plan.operations:
        if op.kind == "rope_query" or op.kind == "rope_key":
            count += 1
            if op.scaling_kind != plan.scaling_policy.kind or not same_scalar_word(op.scaling_factor, plan.scaling_policy.factor):
                raise Error("DecoderScaling: selected source operation factor changed")
        elif op.scaling_kind.byte_length() != 0 or op.scaling_factor.width != 0 or op.scaling_factor.bits != 0:
            raise Error("DecoderScaling: stray source operation factor")
    if plan.explicit_bias:
        _ = validate_bias_policy(plan.bias_policy, plan.layers, len(plan.source.bindings), plan.source.policy.work)
    var expected = 0
    for layer in range(plan.layers):
        var prefix = String("blk.") + String(layer) + "."
        for side in List[String](["q", "k"]):
            var name = prefix + side + "_rotary"
            if plan.decoder_policy.rope_enabled[layer] == 0:
                if name in names:
                    raise Error("DecoderScaling: rotary output bypasses NoPE selection")
                continue
            expected += 1
            if name not in names:
                raise Error("DecoderScaling: selected rotary source output missing")
            var t = plan.tensors[names[name]].copy()
            if t.producer < 0 or t.producer >= len(plan.operations):
                raise Error("DecoderScaling: invalid rotary producer")
            var op = plan.operations[t.producer].copy()
            var input_name = prefix + side + (String("_biased") if plan.explicit_bias and plan.bias_policy.attention[layer] == 1 else String(""))
            if input_name not in names:
                raise Error("DecoderScaling: source rotary activation missing")
            var input_id = names[input_name]
            var input = plan.tensors[input_id].copy()
            var heads = plan.heads if side == "q" else plan.kv_heads
            var shape = List[Int]([plan.query_tokens, heads, plan.key_dim])
            var elements = checked_product(checked_product(plan.query_tokens, heads), plan.key_dim)
            if op.kind != (String("rope_query") if side == "q" else String("rope_key")) or op.inputs != List[Int]([input_id, pos_id]) or op.output != names[name] or op.weight.byte_length() != 0 or op.window_tokens != 0:
                raise Error("DecoderScaling: changed source rotary kind/edges/weight")
            if t.shape != shape or input.shape != shape or t.elements != elements or input.elements != elements or t.persistent or t.alias_of != -1 or input.persistent or input.alias_of != -1 or input.producer < 0 or input.producer >= t.producer or input.last_use < t.producer or input.last_use > len(plan.operations) or t.last_use < t.producer or t.last_use > len(plan.operations):
                raise Error("DecoderScaling: changed rotary axes/products/storage/lifetimes")
    if count != expected:
        raise Error("DecoderScaling: missing/duplicate rotary source operations")


def validate_plan_position_role(plan: SemanticPlan, id: Int) raises:
    if id < 0 or id >= len(plan.tensors) or plan.query_tokens <= 0:
        raise Error("DynamicDecoder: missing position role")
    var t = plan.tensors[id].copy()
    if t.name != "positions" or t.shape != List[Int]([plan.query_tokens]) or t.elements != plan.query_tokens or t.persistent or t.alias_of != -1 or t.last_use < t.producer or t.last_use > len(plan.operations):
        raise Error("DynamicDecoder: changed position shape/product/storage/lifetime")
    var ranges = 0
    for op in plan.operations:
        if op.kind == "position_range":
            ranges += 1
        elif op.position_start != -1:
            raise Error("DynamicDecoder: stray position start")
    if not plan.explicit_dynamic:
        if t.producer != -1 or ranges != 0:
            raise Error("DynamicDecoder: legacy positions must be external")
        return
    if t.producer != 0 or ranges != 1 or len(plan.operations) == 0:
        raise Error("DynamicDecoder: unique first position range required")
    var op = plan.operations[0].copy()
    if op.kind != "position_range" or op.output != id or op.position_start != plan.past_tokens or len(op.inputs) != 0 or op.weight.byte_length() != 0 or op.window_tokens != 0 or op.scaling_kind.byte_length() != 0 or op.scaling_factor.width != 0 or op.scaling_factor.bits != 0:
        raise Error("DynamicDecoder: changed position range producer")
    if plan.past_tokens < 0 or plan.context_capacity <= 0 or plan.past_tokens > plan.context_capacity or plan.query_tokens > plan.context_capacity - plan.past_tokens or plan.context_capacity > plan.dynamic_before.policy.limit:
        raise Error("DynamicDecoder: position range exceeds invocation bounds")


def validate_plan_dynamic_state(plan: SemanticPlan) raises:
    var work = plan.source.policy.work
    if work < 0 or len(plan.tensors) > work or len(plan.operations) > work:
        raise Error("DynamicDecoder: source graph work exceeded")
    if not plan.explicit_dynamic:
        if plan.dynamic_source_context != 0 or plan.dynamic_work != 0 or not same_dynamic_decoder_history(plan.dynamic_before, empty_dynamic_decoder_history(), work) or not same_dynamic_decoder_history(plan.dynamic_after, empty_dynamic_decoder_history(), work):
            raise Error("DynamicDecoder: stray optional history state")
        for op in plan.operations:
            if op.kind == "position_range" or op.position_start != -1 or op.dynamic_reference != 0 or op.dynamic_selected != 0 or op.dynamic_factor.width != 0 or op.dynamic_factor.bits != 0:
                raise Error("DynamicDecoder: stray optional operation state")
        return
    if plan.explicit_scaling or not plan.explicit_session or not plan.explicit_window or not plan.explicit_bias or not plan.explicit_activation or plan.dynamic_source_context != plan.dynamic_before.policy.reference:
        raise Error("DynamicDecoder: source/session/window ownership changed")
    validate_source_inventory(plan.source)
    validate_plan_scalar_state(plan)
    if not same_scalar_word(rotary_scalar(plan), plan.dynamic_before.policy.theta):
        raise Error("DynamicDecoder: selected theta word changed")
    _ = validate_dynamic_decoder_history(plan.dynamic_before, plan.past_tokens, work)
    if plan.query_tokens <= 0 or plan.past_tokens < 0 or plan.context_capacity <= 0 or plan.past_tokens > plan.context_capacity or plan.query_tokens > plan.context_capacity - plan.past_tokens or plan.context_capacity > plan.dynamic_before.policy.limit:
        raise Error("DynamicDecoder: invalid dynamic invocation extent")
    # Recheck the declared after history before any copy from it.
    _ = validate_dynamic_decoder_history(plan.dynamic_after, plan.past_tokens + plan.query_tokens, work)
    var after = advance_dynamic_decoder_history(plan.dynamic_before, plan.query_tokens, plan.past_tokens, plan.context_capacity, work)
    if not same_dynamic_decoder_history(after, plan.dynamic_after, work) or dynamic_plan_work(plan.dynamic_before, after, plan.past_tokens, plan.query_tokens, plan.decoder_policy.rope_enabled, work) != plan.dynamic_work:
        raise Error("DynamicDecoder: changed after history or graph charge")
    var geometry = DecoderGeometry(plan.layers, plan.hidden, plan.feed_forward, plan.heads, plan.kv_heads, plan.key_dim, plan.value_dim, plan.rope_dim, plan.vocabulary, plan.dynamic_source_context, plan.source_layout)
    _validate_decoder_geometry(geometry, plan.source, plan.query_tokens, plan.past_tokens, plan.context_capacity, plan.dynamic_before.policy.limit)
    validate_decoder_graph_policy(plan.decoder_policy, plan.source, plan.layers, plan.hidden, plan.vocabulary)
    if validate_bias_policy(plan.bias_policy, plan.layers, len(plan.source.bindings), work) != plan.bias_work:
        raise Error("DynamicDecoder: changed bias accounting")
    if validate_session_policy(plan.session_policy, plan.layers, work) != plan.session_work or validate_window_policy(plan.window_policy, plan.layers, work) != plan.window_work or validate_activation_policy(plan.activation_policy, plan.layers, work) != plan.activation_work:
        raise Error("DynamicDecoder: changed policy accounting")
    if not same_scaling_policy(plan.scaling_policy, empty_scaling_policy()) or plan.scaling_work != 0:
        raise Error("DynamicDecoder: stray static scaling state")
    var full = plan.session_policy.mode == "full_prefix"
    if full and plan.past_tokens != 0:
        raise Error("DynamicDecoder: full prefix cannot discard supplied past")
    var names = Dict[String, Int]()
    var last = List[Int]()
    var end = len(plan.operations)
    for i in range(len(plan.tensors)):
        var t = plan.tensors[i].copy()
        if t.name in names or t.producer < -1 or t.producer >= end or (t.producer >= 0 and plan.operations[t.producer].output != i) or len(t.shape) == 0 or len(t.shape) > work:
            raise Error("DynamicDecoder: duplicate/orphaned tensor identity")
        var elements = 1
        for dim in t.shape:
            elements = checked_product(elements, dim)
        if elements != t.elements:
            raise Error("DynamicDecoder: tensor shape product changed")
        names[t.name] = i
        last.append(t.producer)
    if "positions" not in names or "tokens" not in names or "logits" not in names or plan.logits != names["logits"]:
        raise Error("DynamicDecoder: missing source input/export role")
    var pos_id = names["positions"]
    validate_plan_position_role(plan, pos_id)
    var tokens = plan.tensors[names["tokens"]].copy()
    if tokens.producer != -1 or tokens.persistent or tokens.alias_of != -1 or tokens.shape != List[Int]([plan.query_tokens]) or tokens.elements != plan.query_tokens:
        raise Error("DynamicDecoder: changed external tokens")
    var selected = after.selected_contexts[len(after.selected_contexts) - 1]
    var count = 0
    for i in range(end):
        var op = plan.operations[i].copy()
        if op.output < 0 or op.output >= len(plan.tensors) or plan.tensors[op.output].producer != i or len(op.inputs) > work:
            raise Error("DynamicDecoder: invalid source output/arity")
        for id in op.inputs:
            if id < 0 or id >= len(plan.tensors) or plan.tensors[id].producer >= i:
                raise Error("DynamicDecoder: unavailable source operand")
            last[id] = i
        if op.scaling_kind.byte_length() != 0 or op.scaling_factor.width != 0 or op.scaling_factor.bits != 0:
            raise Error("DynamicDecoder: stray source scaling metadata")
        if op.kind == "rope_query" or op.kind == "rope_key":
            count += 1
            if op.dynamic_reference != plan.dynamic_source_context or op.dynamic_selected != selected or not same_scalar_word(op.dynamic_factor, plan.dynamic_before.policy.factor) or op.scaling_kind.byte_length() != 0 or op.scaling_factor.width != 0 or op.scaling_factor.bits != 0:
                raise Error("DynamicDecoder: source rotary context/factor changed")
        elif op.dynamic_reference != 0 or op.dynamic_selected != 0 or op.dynamic_factor.width != 0 or op.dynamic_factor.bits != 0:
            raise Error("DynamicDecoder: stray nonrotary context metadata")
    var expected = 0
    var exports = List[Int]()
    var bases = Dict[Int, Bool]()
    var views = Dict[Int, Bool]()
    for layer in range(plan.layers):
        var prefix = String("blk.") + String(layer) + "."
        for side in List[String](["q", "k"]):
            var name = prefix + side + "_rotary"
            if plan.decoder_policy.rope_enabled[layer] == 0:
                if name in names:
                    raise Error("DynamicDecoder: NoPE output has rotary operation")
                continue
            expected += 1
            var input_name = prefix + side + (String("_biased") if plan.bias_policy.attention[layer] == 1 else String(""))
            if name not in names or input_name not in names or prefix + side not in names or prefix + "attn_norm" not in names:
                raise Error("DynamicDecoder: rotary source roles missing")
            var id = names[name]
            var t = plan.tensors[id].copy()
            var input_id = names[input_name]
            var input = plan.tensors[input_id].copy()
            var heads = plan.heads if side == "q" else plan.kv_heads
            var shape = List[Int]([plan.query_tokens, heads, plan.key_dim])
            if t.producer < 0 or input.producer < 0 or input.producer >= t.producer or t.persistent or t.alias_of != -1 or input.persistent or input.alias_of != -1 or t.shape != shape or input.shape != shape:
                raise Error("DynamicDecoder: changed rotary axes/storage/order")
            var op = plan.operations[t.producer].copy()
            if op.kind != (String("rope_query") if side == "q" else String("rope_key")) or op.inputs != List[Int]([input_id, pos_id]) or op.output != id or op.weight.byte_length() != 0 or op.window_tokens != 0:
                raise Error("DynamicDecoder: changed rotary edges/kind/weight")
            var raw_id = names[prefix + side]
            var raw = plan.tensors[raw_id].copy()
            if raw.producer < 0 or raw.shape != shape or raw.persistent or raw.alias_of != -1:
                raise Error("DynamicDecoder: changed rotary projection")
            var projection = plan.operations[raw.producer].copy()
            var weight = prefix + "attn_" + side + ".weight"
            if projection.kind != "linear" or projection.output != raw_id or projection.inputs != List[Int]([names[prefix + "attn_norm"]]) or projection.weight != weight:
                raise Error("DynamicDecoder: changed rotary projection source")
            validate_source_weight(plan.source, weight, plan.hidden, checked_product(heads, plan.key_dim), False)
            if plan.bias_policy.attention[layer] == 1:
                var bias = plan.operations[input.producer].copy()
                var bias_weight = prefix + "attn_" + side + ".bias"
                if bias.kind != "add_projection_bias" or bias.output != input_id or bias.inputs != List[Int]([raw_id]) or bias.weight != bias_weight:
                    raise Error("DynamicDecoder: changed biased rotary input")
                validate_source_weight(plan.source, bias_weight, checked_product(heads, plan.key_dim), 1, True)
        for side in List[String](["key", "value"]):
            var base_name = prefix + side + "_cache"
            var view_name = prefix + (String("keys_view") if side == "key" else String("values_view"))
            var letter = String("k") if side == "key" else String("v")
            var writer_name = prefix + letter
            if plan.bias_policy.attention[layer] == 1:
                writer_name += "_biased"
            if side == "key" and plan.decoder_policy.rope_enabled[layer] == 1:
                writer_name = prefix + "k_rotary"
            if writer_name not in names:
                raise Error("DynamicDecoder: cache writer missing")
            var writer_id = names[writer_name]
            if full:
                if base_name in names or view_name in names:
                    raise Error("DynamicDecoder: full prefix has persistent cache")
                if plan.session_policy.return_cache == 1:
                    exports.append(writer_id)
            else:
                if base_name not in names or view_name not in names:
                    raise Error("DynamicDecoder: cache base/view missing")
                var base_id = names[base_name]
                var view_id = names[view_name]
                var base = plan.tensors[base_id].copy()
                var view = plan.tensors[view_id].copy()
                var dim = plan.key_dim if side == "key" else plan.value_dim
                if not base.persistent or base.producer != -1 or base.alias_of != -1 or base.shape != List[Int]([plan.context_capacity, plan.kv_heads, dim]) or view.persistent or view.alias_of != base_id or view.producer < 0 or view.shape != List[Int]([plan.past_tokens + plan.query_tokens, plan.kv_heads, dim]):
                    raise Error("DynamicDecoder: cache extent/storage changed")
                var append = plan.operations[view.producer].copy()
                if append.kind != (String("kv_append_keys") if side == "key" else String("kv_append_values")) or append.output != view_id or append.inputs != List[Int]([base_id, writer_id]) or append.weight.byte_length() != 0:
                    raise Error("DynamicDecoder: cache insertion edge changed")
                bases[base_id] = True
                views[view_id] = True
                if plan.session_policy.return_cache == 1:
                    exports.append(view_id)
    if count != expected or plan.cache_exports != exports:
        raise Error("DynamicDecoder: duplicate/missing rotary operation or cache export")
    for i in range(len(plan.tensors)):
        var t = plan.tensors[i].copy()
        if t.persistent != (i in bases) or (t.alias_of != -1) != (i in views):
            raise Error("DynamicDecoder: stray persistent/alias storage")
        if t.producer == -1 and i != names["tokens"] and i not in bases:
            raise Error("DynamicDecoder: stray external tensor")
        if t.persistent or i == plan.logits or i in exports:
            last[i] = end
        if t.last_use != last[i]:
            raise Error("DynamicDecoder: source tensor lifetime changed")


def dynamic_position_at(plan: SemanticPlan, index: Int) raises -> Int:
    validate_plan_dynamic_state(plan)
    if not plan.explicit_dynamic or index < 0 or index >= plan.query_tokens:
        raise Error("DynamicDecoder: position index out of range")
    return plan.past_tokens + index


def dynamic_context_output(plan: SemanticPlan) raises -> DynamicRotaryContext:
    validate_plan_dynamic_state(plan)
    if not plan.explicit_dynamic:
        raise Error("DynamicDecoder: explicit context output required")
    var h = plan.dynamic_after.copy()
    return DynamicRotaryContext(h.policy.reference, h.selected_contexts[len(h.selected_contexts) - 1], h.policy.limit)


def dynamic_cache_history_output(plan: SemanticPlan) raises -> DynamicDecoderHistory:
    validate_plan_dynamic_state(plan)
    if not plan.explicit_dynamic:
        raise Error("DynamicDecoder: explicit cache history output required")
    if plan.session_policy.return_cache == 1:
        return plan.dynamic_after.copy()
    return empty_dynamic_decoder_history()
