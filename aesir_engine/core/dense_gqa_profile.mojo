"""Profiles and strict tensor contracts for dense GQA transformer adapters."""
from loader.packed_gguf import PackedGGUF


comptime LLAMA3_8B_LAYER_COUNT = 32
comptime LLAMA3_8B_HIDDEN_SIZE = 4096
comptime LLAMA3_8B_FEED_FORWARD_SIZE = 14336
comptime LLAMA3_8B_ATTENTION_HEADS = 32
comptime LLAMA3_8B_KV_HEADS = 8
comptime LLAMA3_8B_HEAD_DIM = 128
comptime LLAMA3_8B_VOCABULARY_SIZE = 128256
comptime LLAMA3_8B_CONTEXT_CAP = 8192


struct DenseGQAProfile(Copyable):
    var family: String
    var architecture: String
    var name: String
    var layer_count: Int
    var hidden_size: Int
    var feed_forward_size: Int
    var attention_heads: Int
    var kv_heads: Int
    var head_dim: Int
    var vocabulary_size: Int
    var context_cap: Int
    var ordinary_token_limit: Int
    var eos_token_id: Int
    var end_of_turn_token_id: Int
    var rope_frequency_base: Float32
    var normalization_epsilon: Float32
    var expected_tensor_count: Int
    var qk_norm: Bool
    var neox_rope: Bool
    var tied_embeddings: Bool
    var add_bos: Bool

    def __init__(out self, family: String, architecture: String, name: String,
                 layer_count: Int, hidden_size: Int, feed_forward_size: Int,
                 attention_heads: Int, kv_heads: Int, head_dim: Int,
                 vocabulary_size: Int, context_cap: Int,
                 ordinary_token_limit: Int, eos_token_id: Int,
                 end_of_turn_token_id: Int, rope_frequency_base: Float32,
                 normalization_epsilon: Float32, expected_tensor_count: Int,
                 qk_norm: Bool, neox_rope: Bool, tied_embeddings: Bool,
                 add_bos: Bool):
        self.family = family
        self.architecture = architecture
        self.name = name
        self.layer_count = layer_count
        self.hidden_size = hidden_size
        self.feed_forward_size = feed_forward_size
        self.attention_heads = attention_heads
        self.kv_heads = kv_heads
        self.head_dim = head_dim
        self.vocabulary_size = vocabulary_size
        self.context_cap = context_cap
        self.ordinary_token_limit = ordinary_token_limit
        self.eos_token_id = eos_token_id
        self.end_of_turn_token_id = end_of_turn_token_id
        self.rope_frequency_base = rope_frequency_base
        self.normalization_epsilon = normalization_epsilon
        self.expected_tensor_count = expected_tensor_count
        self.qk_norm = qk_norm
        self.neox_rope = neox_rope
        self.tied_embeddings = tied_embeddings
        self.add_bos = add_bos

    def query_width(self) -> Int:
        return self.attention_heads * self.head_dim

    def kv_width(self) -> Int:
        return self.kv_heads * self.head_dim

    def activation_elements(self, context_length: Int) -> Int:
        return (
            3 * self.hidden_size + 2 * self.query_width() + 2 * self.kv_width()
            + 2 * self.feed_forward_size + self.vocabulary_size
            + self.attention_heads * context_length
        )

    def kv_elements(self, context_length: Int) -> Int:
        return self.layer_count * 2 * context_length * self.kv_width()

    def label(self) -> String:
        return self.family + " " + self.name


def llama3_8b_profile() -> DenseGQAProfile:
    return DenseGQAProfile(
        "Llama 3", "llama", "8B", LLAMA3_8B_LAYER_COUNT,
        LLAMA3_8B_HIDDEN_SIZE, LLAMA3_8B_FEED_FORWARD_SIZE,
        LLAMA3_8B_ATTENTION_HEADS, LLAMA3_8B_KV_HEADS,
        LLAMA3_8B_HEAD_DIM, LLAMA3_8B_VOCABULARY_SIZE,
        LLAMA3_8B_CONTEXT_CAP, 128000, 128001, 128009,
        500000, Float32(1e-5), 291, False, False, False, True,
    )


def qwen3_0_6b_profile() -> DenseGQAProfile:
    return DenseGQAProfile(
        "Qwen 3", "qwen3", "0.6B", 28, 1024, 3072, 16, 8, 128,
        151936, 32768, 151669, 151645, 151645,
        1000000, Float32(1e-6), 310, True, True, True, False,
    )


def dense_gqa_profile_for(model: PackedGGUF) raises -> DenseGQAProfile:
    var architecture = model.text("general.architecture")
    var layers = model.integer(architecture + ".block_count")
    var hidden = model.integer(architecture + ".embedding_length")
    if architecture == "llama" and layers == 32 and hidden == 4096:
        return llama3_8b_profile()
    if architecture == "qwen3" and layers == 28 and hidden == 1024:
        return qwen3_0_6b_profile()
    raise Error(
        "No native dense GQA variant profile for " + architecture + ": "
        + String(layers) + " layers / " + String(hidden) + " hidden"
    )


def _require_profile_metadata(model: PackedGGUF,
                              profile: DenseGQAProfile) raises:
    var prefix = profile.architecture + "."
    var keys: List[String] = [
        "block_count", "embedding_length", "feed_forward_length",
        "attention.head_count", "attention.head_count_kv",
    ]
    var values: List[Int] = [
        profile.layer_count, profile.hidden_size, profile.feed_forward_size,
        profile.attention_heads, profile.kv_heads,
    ]
    for i in range(len(keys)):
        if model.integer(prefix + keys[i]) != values[i]:
            raise Error("Unsupported " + profile.label() + " metadata: " + keys[i])
    if profile.architecture == "llama":
        if model.integer(prefix + "rope.dimension_count") != profile.head_dim:
            raise Error("Unsupported " + profile.label() + " RoPE dimension")
    else:
        if (model.integer(prefix + "attention.key_length") != profile.head_dim
                or model.integer(prefix + "attention.value_length")
                    != profile.head_dim):
            raise Error("Unsupported " + profile.label() + " attention dimensions")
    if (model.floating(prefix + "rope.freq_base")
            != profile.rope_frequency_base
            or model.floating(prefix + "attention.layer_norm_rms_epsilon")
                != profile.normalization_epsilon):
        raise Error("Unsupported " + profile.label() + " RoPE or normalization")
    var scaling_key = prefix + "rope.scaling.type"
    if scaling_key in model.fields and model.text(scaling_key) != "none":
        raise Error("Scaled " + profile.label() + " RoPE is not supported")


def validate_dense_gqa(model: PackedGGUF, profile: DenseGQAProfile,
                       context_length: Int) raises:
    if model.text("general.architecture") != profile.architecture:
        raise Error(
            "Native " + profile.label() + " requires "
            + profile.architecture + " architecture"
        )
    _require_profile_metadata(model, profile)
    if context_length < 2 or context_length > min(
        profile.context_cap,
        model.integer(profile.architecture + ".context_length"),
    ):
        raise Error(
            profile.label() + " CUDA context must be within 2.."
            + String(profile.context_cap) + " tokens"
        )
    _ = model.require_tensor(
        "token_embd.weight", profile.hidden_size, profile.vocabulary_size
    )
    _ = model.require_tensor("output_norm.weight", profile.hidden_size)
    if profile.tied_embeddings:
        if "output.weight" in model.tensors:
            raise Error(profile.label() + " requires tied output embeddings")
    else:
        _ = model.require_tensor(
            "output.weight", profile.hidden_size, profile.vocabulary_size
        )
    for layer in range(profile.layer_count):
        var prefix = "blk." + String(layer) + "."
        _ = model.require_tensor(prefix + "attn_norm.weight", profile.hidden_size)
        _ = model.require_tensor(prefix + "ffn_norm.weight", profile.hidden_size)
        _ = model.require_tensor(
            prefix + "attn_q.weight", profile.hidden_size, profile.query_width()
        )
        _ = model.require_tensor(
            prefix + "attn_k.weight", profile.hidden_size, profile.kv_width()
        )
        _ = model.require_tensor(
            prefix + "attn_v.weight", profile.hidden_size, profile.kv_width()
        )
        _ = model.require_tensor(
            prefix + "attn_output.weight", profile.query_width(),
            profile.hidden_size,
        )
        _ = model.require_tensor(
            prefix + "ffn_gate.weight", profile.hidden_size,
            profile.feed_forward_size,
        )
        _ = model.require_tensor(
            prefix + "ffn_up.weight", profile.hidden_size,
            profile.feed_forward_size,
        )
        _ = model.require_tensor(
            prefix + "ffn_down.weight", profile.feed_forward_size,
            profile.hidden_size,
        )
        if profile.qk_norm:
            _ = model.require_tensor(prefix + "attn_q_norm.weight", profile.head_dim)
            _ = model.require_tensor(prefix + "attn_k_norm.weight", profile.head_dim)
        elif (prefix + "attn_q_norm.weight" in model.tensors
                or prefix + "attn_k_norm.weight" in model.tensors):
            raise Error("Unexpected " + profile.label() + " Q/K normalization")
        if (prefix + "attn_q.bias" in model.tensors
                or prefix + "attn_k.bias" in model.tensors
                or prefix + "attn_v.bias" in model.tensors):
            raise Error(profile.label() + " attention bias is not supported")
    if len(model.tensors) != profile.expected_tensor_count:
        raise Error("Unsupported " + profile.label() + " tensor set")
    for name in model.tensors.keys():
        var tensor = model.tensors[name]
        if tensor.rows == 1 and tensor.kind != 0:
            raise Error(profile.label() + " norm/scale tensors must be F32")
