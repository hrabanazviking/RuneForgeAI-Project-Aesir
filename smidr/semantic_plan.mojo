# Original source graph construction. No numerical kernels or device program.
from std.collections import Dict
from std.math import isfinite
from loader.packed_gguf import PackedGGUF
from smidr.source_inventory import SourceTensorInventory, inventory_from_source


def checked_product(a: Int, b: Int) raises -> Int:
    if a <= 0 or b <= 0 or a > 9223372036854775807 // b:
        raise Error("SemanticPlan: invalid or overflowing positive shape product")
    return a * b


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

    def tensor(mut self, name: String, var shape: List[Int], producer: Int = -1,
               persistent: Bool = False, alias_of: Int = -1) raises -> Int:
        var elements = 1
        for dimension in shape:
            elements = checked_product(elements, dimension)
        var index = len(self.tensors)
        self.tensors.append(SemanticTensor(name, shape^, elements, producer,
                                          producer, persistent, alias_of))
        return index

    def weight(mut self, name: String, columns: Int, rows: Int = 1) raises:
        if name not in self.source.bindings:
            raise Error("SemanticPlan: missing source weight " + name)
        var binding = self.source.bindings[name]
        if binding.columns != columns or binding.rows != rows:
            raise Error("SemanticPlan: source weight shape mismatch " + name)
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


def read_dense_semantic_plan(path: String, query_tokens: Int,
                             past_tokens: Int, context_capacity: Int) raises -> SemanticPlan:
    var source = PackedGGUF(path)
    var plan = SemanticPlan(inventory_from_source(source))
    # Incremental importer coverage, never hardware eligibility or a target cap.
    if plan.source.architecture != "llama":
        raise Error("SemanticPlan: architecture semantic importer unresolved: " + plan.source.architecture)
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
    plan.layers = source.integer(prefix + "block_count")
    plan.hidden = source.integer(prefix + "embedding_length")
    plan.feed_forward = source.integer(prefix + "feed_forward_length")
    plan.heads = source.integer(prefix + "attention.head_count")
    plan.kv_heads = source.integer(prefix + "attention.head_count_kv", plan.heads)
    if plan.heads <= 0 or plan.hidden <= 0 or plan.kv_heads <= 0 or plan.heads % plan.kv_heads != 0:
        raise Error("SemanticPlan: invalid hidden/query/KV head dimensions")
    var default_dim = plan.hidden // plan.heads
    if plan.hidden % plan.heads != 0 and (prefix + "attention.key_length" not in source.fields or prefix + "attention.value_length" not in source.fields):
        raise Error("SemanticPlan: non-integral default head dimension")
    plan.key_dim = source.integer(prefix + "attention.key_length", default_dim)
    plan.value_dim = source.integer(prefix + "attention.value_length", default_dim)
    var query_width = checked_product(plan.heads, plan.key_dim)
    var key_width = checked_product(plan.kv_heads, plan.key_dim)
    var value_width = checked_product(plan.kv_heads, plan.value_dim)
    var attended_width = checked_product(plan.heads, plan.value_dim)
    plan.rope_dim = source.integer(prefix + "rope.dimension_count")
    if plan.rope_dim <= 0 or plan.rope_dim > plan.key_dim or plan.rope_dim % 2 != 0:
        raise Error("SemanticPlan: invalid rotary dimension")
    plan.rms_epsilon = source.floating(prefix + "attention.layer_norm_rms_epsilon")
    plan.rope_base = source.floating(prefix + "rope.freq_base")
    if not isfinite(plan.rms_epsilon) or plan.rms_epsilon <= 0 or not isfinite(plan.rope_base) or plan.rope_base <= 0:
        raise Error("SemanticPlan: non-finite or non-positive numerical parameter")
    plan.source_layout = source.text(prefix + "tensor_data_layout") if prefix + "tensor_data_layout" in source.fields else String("reference")
    # No default machine resource capacity. This is an explicit session shape.
    var source_context = source.integer(prefix + "context_length")
    if query_tokens <= 0 or past_tokens < 0 or context_capacity <= 0 or context_capacity > source_context or past_tokens > context_capacity or query_tokens > context_capacity - past_tokens:
        raise Error("SemanticPlan: invalid session query/past/context extent")
    plan.query_tokens = query_tokens
    plan.past_tokens = past_tokens
    plan.context_capacity = context_capacity
    var total = past_tokens + query_tokens
    if plan.layers <= 0 or plan.layers > len(source.tensors) // 9:
        raise Error("SemanticPlan: layer count exceeds source tensor evidence")
    if plan.feed_forward <= 0 or "token_embd.weight" not in source.tensors:
        raise Error("SemanticPlan: missing embedding or invalid FFN dimension")
    plan.vocabulary = source.tensors["token_embd.weight"].rows
    if prefix + "vocab_size" in source.fields and source.integer(prefix + "vocab_size") != plan.vocabulary:
        raise Error("SemanticPlan: vocabulary metadata and embedding disagree")
    plan.weight("token_embd.weight", plan.hidden, plan.vocabulary)
    plan.weight("output_norm.weight", plan.hidden)
    var output_weight = String("output.weight") if "output.weight" in source.tensors else String("token_embd.weight")
    plan.weight(output_weight, plan.hidden, plan.vocabulary)
    var tokens = plan.tensor("tokens", [query_tokens])
    var positions = plan.tensor("positions", [query_tokens])
    var x = plan.emit("embedding_gather", "embedding", [tokens], [query_tokens, plan.hidden], "token_embd.weight")
    for layer in range(plan.layers):
        var p = String("blk.") + String(layer) + "."
        plan.weight(p + "attn_norm.weight", plan.hidden)
        plan.weight(p + "ffn_norm.weight", plan.hidden)
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
        x = plan.emit("add", p + "attn_residual", [residual, attention], [query_tokens, plan.hidden])
        residual = x
        norm = plan.emit("rms_norm", p + "ffn_norm", [x], [query_tokens, plan.hidden], p + "ffn_norm.weight")
        var gate = plan.emit("linear", p + "gate", [norm], [query_tokens, plan.feed_forward], p + "ffn_gate.weight")
        var up = plan.emit("linear", p + "up", [norm], [query_tokens, plan.feed_forward], p + "ffn_up.weight")
        gate = plan.emit("silu", p + "gate_silu", [gate], [query_tokens, plan.feed_forward])
        gate = plan.emit("multiply", p + "gated", [gate, up], [query_tokens, plan.feed_forward])
        var down = plan.emit("linear", p + "down", [gate], [query_tokens, plan.hidden], p + "ffn_down.weight")
        x = plan.emit("add", p + "ffn_residual", [residual, down], [query_tokens, plan.hidden])
    x = plan.emit("rms_norm", "output_norm", [x], [query_tokens, plan.hidden], "output_norm.weight")
    plan.logits = plan.emit("linear", "logits", [x], [query_tokens, plan.vocabulary], output_weight)
    # Exact consumed tensor set: do not silently omit biases, norms or factors.
    for name in source.tensors:
        if name not in plan.used_weights:
            raise Error("SemanticPlan: source tensor semantics unresolved: " + name)
    var end = len(plan.operations)
    plan.tensors[plan.logits].last_use = end
    for i in range(len(plan.tensors)):
        if plan.tensors[i].persistent:
            plan.tensors[i].last_use = end
    return plan^
