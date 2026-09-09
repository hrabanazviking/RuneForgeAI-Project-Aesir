"""Validated dimensions and KV ownership for supported dense Gemma 4 profiles."""
from loader.packed_gguf import PackedGGUF


struct Gemma4Profile(Copyable):
    var name: String
    var layer_count: Int
    var hidden_size: Int
    var feed_forward_size: Int
    var shared_feed_forward_size: Int
    var attention_heads: Int
    var kv_heads: Int
    var global_head_dim: Int
    var local_head_dim: Int
    var shared_kv_layers: Int
    var full_attention_period: Int
    var vocabulary_size: Int
    var per_layer_input_size: Int
    var context_cap: Int
    var shared_local_layer: Int
    var shared_global_layer: Int

    def __init__(out self, name: String, layer_count: Int, hidden_size: Int,
                 feed_forward_size: Int, shared_feed_forward_size: Int,
                 attention_heads: Int, kv_heads: Int,
                 global_head_dim: Int, local_head_dim: Int,
                 shared_kv_layers: Int, full_attention_period: Int,
                 vocabulary_size: Int, per_layer_input_size: Int,
                 context_cap: Int, shared_local_layer: Int,
                 shared_global_layer: Int):
        self.name = name
        self.layer_count = layer_count
        self.hidden_size = hidden_size
        self.feed_forward_size = feed_forward_size
        self.shared_feed_forward_size = shared_feed_forward_size
        self.attention_heads = attention_heads
        self.kv_heads = kv_heads
        self.global_head_dim = global_head_dim
        self.local_head_dim = local_head_dim
        self.shared_kv_layers = shared_kv_layers
        self.full_attention_period = full_attention_period
        self.vocabulary_size = vocabulary_size
        self.per_layer_input_size = per_layer_input_size
        self.context_cap = context_cap
        self.shared_local_layer = shared_local_layer
        self.shared_global_layer = shared_global_layer

    def owns_kv(self, layer: Int) -> Bool:
        return layer < self.layer_count - self.shared_kv_layers

    def is_local(self, layer: Int) -> Bool:
        return layer % self.full_attention_period != self.full_attention_period - 1

    def head_dim(self, layer: Int) -> Int:
        return self.local_head_dim if self.is_local(layer) else self.global_head_dim

    def kv_layer(self, layer: Int) -> Int:
        if self.owns_kv(layer):
            return layer
        return self.shared_local_layer if self.is_local(layer) else self.shared_global_layer

    def ffn_size(self, layer: Int) -> Int:
        return self.feed_forward_size if self.owns_kv(layer) else self.shared_feed_forward_size

    def label(self) -> String:
        return "Gemma 4 " + self.name


def gemma4_e4b_profile() -> Gemma4Profile:
    return Gemma4Profile("E4B", 42, 2560, 10240, 10240, 8, 2, 512, 256,
                         18, 6, 262144, 256, 32768, 22, 23)


def gemma4_e2b_profile() -> Gemma4Profile:
    return Gemma4Profile("E2B", 35, 1536, 6144, 12288, 8, 1, 512, 256,
                         20, 5, 262144, 256, 16384, 13, 14)


def gemma4_profile_for(model: PackedGGUF) raises -> Gemma4Profile:
    if model.text("general.architecture") != "gemma4":
        raise Error("Native CUDA session requires dense Gemma 4")
    var layers = model.integer("gemma4.block_count")
    if layers == 42:
        return gemma4_e4b_profile()
    if layers == 35:
        return gemma4_e2b_profile()
    raise Error("Unsupported dense Gemma 4 layer count: " + String(layers))


def validate_gemma4(model: PackedGGUF, profile: Gemma4Profile,
                    context_length: Int) raises:
    var keys: List[String] = [
        "block_count", "embedding_length",
        "attention.head_count", "attention.head_count_kv",
        "attention.key_length", "attention.value_length",
        "attention.key_length_swa", "attention.value_length_swa",
        "attention.sliding_window", "attention.shared_kv_layers",
        "embedding_length_per_layer_input", "rope.dimension_count",
        "rope.dimension_count_swa",
    ]
    var values: List[Int] = [
        profile.layer_count, profile.hidden_size,
        profile.attention_heads, profile.kv_heads, profile.global_head_dim,
        profile.global_head_dim, profile.local_head_dim, profile.local_head_dim,
        512, profile.shared_kv_layers, profile.per_layer_input_size,
        profile.global_head_dim, profile.local_head_dim,
    ]
    for i in range(len(keys)):
        var key = "gemma4." + keys[i]
        if model.integer(key) != values[i]:
            raise Error("Unsupported " + profile.label() + " metadata: " + keys[i])
    var ffn_key = String("gemma4.feed_forward_length")
    if model.field_types.get(ffn_key, -1) == 9:
        var widths = model.integer_array(ffn_key, profile.layer_count)
        for layer in range(profile.layer_count):
            if widths[layer] != profile.ffn_size(layer):
                raise Error("Unsupported " + profile.label() + " per-layer feed-forward width")
    else:
        var width = model.integer(ffn_key)
        if width != profile.feed_forward_size or width != profile.shared_feed_forward_size:
            raise Error("Unsupported " + profile.label() + " feed-forward width")
    if context_length < 2 or context_length > min(profile.context_cap, model.integer("gemma4.context_length")):
        raise Error(profile.label() + " CUDA context must be within 2.." + String(profile.context_cap) + " tokens")
    if model.floating("gemma4.rope.freq_base") != 1000000 or model.floating("gemma4.rope.freq_base_swa") != 10000 or model.floating("gemma4.final_logit_softcapping") != 30:
        raise Error("Unsupported Gemma 4 RoPE or logit scale")
    if model.floating("gemma4.attention.layer_norm_rms_epsilon") != Float32(1e-6):
        raise Error("Unsupported Gemma 4 normalization epsilon")
    var pattern = model.array_offset("gemma4.attention.sliding_window_pattern", 7)
    if Int(model.source._read_u64(pattern + 4)) != profile.layer_count:
        raise Error("Gemma 4 sliding-window pattern length mismatch")
    for layer in range(profile.layer_count):
        if Bool(model.source.mmap_ptr.unsafe_load(pattern + 12 + layer)) != profile.is_local(layer):
            raise Error("Unsupported Gemma 4 sliding-window pattern")
    var per_layer_width = profile.layer_count * profile.per_layer_input_size
    _ = model.require_tensor("token_embd.weight", profile.hidden_size, profile.vocabulary_size)
    _ = model.require_tensor("per_layer_token_embd.weight", per_layer_width, profile.vocabulary_size)
    _ = model.require_tensor("per_layer_model_proj.weight", profile.hidden_size, per_layer_width)
    _ = model.require_tensor("per_layer_proj_norm.weight", profile.per_layer_input_size)
    _ = model.require_tensor("output_norm.weight", profile.hidden_size)
    _ = model.require_tensor("rope_freqs.weight", profile.global_head_dim // 2)
    for layer in range(profile.layer_count):
        var prefix = "blk." + String(layer) + "."
        var width = profile.head_dim(layer)
        var ffn_width = profile.ffn_size(layer)
        _ = model.require_tensor(prefix + "attn_q.weight", profile.hidden_size, width * profile.attention_heads)
        _ = model.require_tensor(prefix + "attn_output.weight", width * profile.attention_heads, profile.hidden_size)
        _ = model.require_tensor(prefix + "attn_q_norm.weight", width)
        if profile.owns_kv(layer):
            _ = model.require_tensor(prefix + "attn_k.weight", profile.hidden_size, width * profile.kv_heads)
            _ = model.require_tensor(prefix + "attn_v.weight", profile.hidden_size, width * profile.kv_heads)
            _ = model.require_tensor(prefix + "attn_k_norm.weight", width)
        var norms: List[String] = ["attn_norm", "post_attention_norm", "ffn_norm", "post_ffw_norm", "post_norm"]
        for norm in norms:
            _ = model.require_tensor(prefix + norm + ".weight", profile.hidden_size)
        _ = model.require_tensor(prefix + "ffn_up.weight", profile.hidden_size, ffn_width)
        _ = model.require_tensor(prefix + "ffn_gate.weight", profile.hidden_size, ffn_width)
        _ = model.require_tensor(prefix + "ffn_down.weight", ffn_width, profile.hidden_size)
        _ = model.require_tensor(prefix + "inp_gate.weight", profile.hidden_size, profile.per_layer_input_size)
        _ = model.require_tensor(prefix + "proj.weight", profile.per_layer_input_size, profile.hidden_size)
        _ = model.require_tensor(prefix + "layer_output_scale.weight", 1)
        if prefix + "ffn_gate_inp.weight" in model.tensors:
            raise Error("Gemma 4 MoE is not supported by the dense CUDA path")
    for name in model.tensors.keys():
        var tensor = model.tensors[name]
        if tensor.rows == 1 and tensor.kind != 0:
            raise Error("Gemma 4 norm/scale tensors must be F32: " + name)
    if "output.weight" in model.tensors:
        raise Error("This Gemma 4 CUDA profile requires tied output embeddings")
