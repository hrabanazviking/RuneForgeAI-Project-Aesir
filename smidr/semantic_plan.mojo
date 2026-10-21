# Original source graph construction. No numerical kernels or device program.
from std.collections import Dict
from smidr.activation_policy import DecoderActivationPolicy, empty_activation_policy, validate_activation_policy
from smidr.bias_policy import DecoderBiasPolicy, empty_bias_policy, validate_bias_policy
from std.math import isfinite
from std.memory import bitcast
from smidr.source_scalars import ScalarWord, DecoderScalars, empty_decoder_scalars, validate_decoder_scalars, validate_scalar_word, same_decoder_scalars
from loader.packed_gguf import PackedGGUF
from smidr.source_inventory import SourceTensorInventory, inventory_from_source, validate_source_inventory, validate_source_weight


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


@fieldwise_init
struct SemanticOperation(Copyable, Movable):
    var kind: String
    var inputs: List[Int]
    var output: Int
    var weight: String


struct SemanticPlan(Movable):
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
    var explicit_activation: Bool
    var activation_policy: DecoderActivationPolicy
    var activation_work: Int
    var explicit_bias: Bool
    var bias_policy: DecoderBiasPolicy
    var bias_work: Int
    var explicit_scalars: Bool
    var source_scalars: DecoderScalars

    def __init__(out self, var source: SourceTensorInventory):
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
             var shape: List[Int], weight: String = "", alias_of: Int = -1) raises -> Int:
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
        self.operations.append(SemanticOperation(kind, inputs^, output, weight))
        return output


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
    if query_tokens <= 0 or past_tokens < 0 or context_capacity <= 0 or context_capacity > p.source_context or past_tokens > context_capacity or query_tokens > context_capacity - past_tokens:
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


def _build_decoder_semantic_plan(var source: SourceTensorInventory,
                               parameters: DenseDecoderParameters, scalars: DecoderScalars,
                               explicit: Bool, policy: DecoderGraphPolicy, query_tokens: Int,
                               past_tokens: Int, context_capacity: Int,
                               bias_policy: DecoderBiasPolicy = empty_bias_policy(),
                               explicit_bias: Bool = False,
                               activation_policy: DecoderActivationPolicy = empty_activation_policy(),
                               explicit_activation: Bool = False) raises -> SemanticPlan:
    """Build an explicitly selected mathematical recipe from tagged values."""
    validate_source_inventory(source)
    if explicit:
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
    var plan = SemanticPlan(source^)
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
    var positions = plan.tensor("positions", [query_tokens])
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
            q = plan.emit("rope_query", p + "q_rotary", [q, positions], [query_tokens, plan.heads, plan.key_dim])
            k = plan.emit("rope_key", p + "k_rotary", [k, positions], [query_tokens, plan.kv_heads, plan.key_dim])
        var cache_k = plan.tensor(p + "key_cache", [context_capacity, plan.kv_heads, plan.key_dim], -1, True)
        var cache_v = plan.tensor(p + "value_cache", [context_capacity, plan.kv_heads, plan.value_dim], -1, True)
        var keys_view = plan.emit("kv_append_keys", p + "keys_view", [cache_k, k], [total, plan.kv_heads, plan.key_dim], "", cache_k)
        var values_view = plan.emit("kv_append_values", p + "values_view", [cache_v, v], [total, plan.kv_heads, plan.value_dim], "", cache_v)
        var scores = plan.emit("gqa_scaled_dot", p + "scores", [q, keys_view], [plan.heads, query_tokens, total])
        scores = plan.emit("causal_mask", p + "masked_scores", [scores, positions], [plan.heads, query_tokens, total])
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
    for name in plan.source.bindings:
        if name not in plan.used_weights:
            raise Error("SemanticPlan: source tensor semantics unresolved: " + name)
    var end = len(plan.operations)
    plan.tensors[plan.logits].last_use = end
    for i in range(len(plan.tensors)):
        if plan.tensors[i].persistent:
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
