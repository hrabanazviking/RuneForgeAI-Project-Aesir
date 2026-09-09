"""Validated dimensions and tensor contract for supported dense Llama 3 profiles."""
from loader.packed_gguf import PackedGGUF


comptime LLAMA3_8B_LAYER_COUNT = 32
comptime LLAMA3_8B_HIDDEN_SIZE = 4096
comptime LLAMA3_8B_FEED_FORWARD_SIZE = 14336
comptime LLAMA3_8B_ATTENTION_HEADS = 32
comptime LLAMA3_8B_KV_HEADS = 8
comptime LLAMA3_8B_HEAD_DIM = 128
comptime LLAMA3_8B_VOCABULARY_SIZE = 128256
comptime LLAMA3_8B_CONTEXT_CAP = 8192


struct Llama3Profile(Copyable):
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

    def __init__(out self, name: String, layer_count: Int, hidden_size: Int,
                 feed_forward_size: Int, attention_heads: Int, kv_heads: Int,
                 head_dim: Int, vocabulary_size: Int, context_cap: Int,
                 ordinary_token_limit: Int, eos_token_id: Int,
                 end_of_turn_token_id: Int,
                 rope_frequency_base: Float32, normalization_epsilon: Float32,
                 expected_tensor_count: Int):
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

    def kv_width(self) -> Int:
        return self.kv_heads * self.head_dim

    def activation_elements(self, context_length: Int) -> Int:
        return (
            5 * self.hidden_size + 2 * self.kv_width()
            + 2 * self.feed_forward_size + self.vocabulary_size
            + self.attention_heads * context_length
        )

    def kv_elements(self, context_length: Int) -> Int:
        return self.layer_count * 2 * context_length * self.kv_width()

    def label(self) -> String:
        return "Llama 3 " + self.name


def llama3_8b_profile() -> Llama3Profile:
    return Llama3Profile(
        "8B", LLAMA3_8B_LAYER_COUNT, LLAMA3_8B_HIDDEN_SIZE,
        LLAMA3_8B_FEED_FORWARD_SIZE, LLAMA3_8B_ATTENTION_HEADS,
        LLAMA3_8B_KV_HEADS, LLAMA3_8B_HEAD_DIM,
        LLAMA3_8B_VOCABULARY_SIZE, LLAMA3_8B_CONTEXT_CAP,
        128000, 128001, 128009,
        500000, Float32(1e-5), 291,
    )


def llama3_profile_for(model: PackedGGUF) raises -> Llama3Profile:
    if model.text("general.architecture") != "llama":
        raise Error("Native CUDA session requires dense Llama 3")
    var profile = llama3_8b_profile()
    if (model.integer("llama.block_count") == profile.layer_count
            and model.integer("llama.embedding_length") == profile.hidden_size):
        return profile^
    raise Error(
        "Unsupported dense Llama 3 dimensions: "
        + String(model.integer("llama.block_count")) + " layers / "
        + String(model.integer("llama.embedding_length")) + " hidden"
    )


def validate_llama3(model: PackedGGUF, profile: Llama3Profile,
                    context_length: Int) raises:
    if model.text("general.architecture") != "llama":
        raise Error("Native " + profile.label() + " CUDA requires llama architecture")
    var keys: List[String] = [
        "block_count", "embedding_length", "feed_forward_length",
        "attention.head_count", "attention.head_count_kv", "rope.dimension_count",
    ]
    var values: List[Int] = [
        profile.layer_count, profile.hidden_size, profile.feed_forward_size,
        profile.attention_heads, profile.kv_heads, profile.head_dim,
    ]
    for i in range(len(keys)):
        if model.integer("llama." + keys[i]) != values[i]:
            raise Error("Unsupported " + profile.label() + " metadata: " + keys[i])
    if context_length < 2 or context_length > min(
        profile.context_cap, model.integer("llama.context_length")
    ):
        raise Error(
            profile.label() + " CUDA context must be within 2.."
            + String(profile.context_cap) + " tokens"
        )
    if (model.floating("llama.rope.freq_base") != profile.rope_frequency_base
            or model.floating("llama.attention.layer_norm_rms_epsilon")
                != profile.normalization_epsilon):
        raise Error("Unsupported " + profile.label() + " RoPE or normalization")
    if ("llama.rope.scaling.type" in model.fields
            and model.text("llama.rope.scaling.type") != "none"):
        raise Error("Scaled Llama RoPE is not supported")
    _ = model.require_tensor(
        "token_embd.weight", profile.hidden_size, profile.vocabulary_size
    )
    _ = model.require_tensor(
        "output.weight", profile.hidden_size, profile.vocabulary_size
    )
    _ = model.require_tensor("output_norm.weight", profile.hidden_size)
    for layer in range(profile.layer_count):
        var prefix = "blk." + String(layer) + "."
        _ = model.require_tensor(prefix + "attn_norm.weight", profile.hidden_size)
        _ = model.require_tensor(prefix + "ffn_norm.weight", profile.hidden_size)
        _ = model.require_tensor(
            prefix + "attn_q.weight", profile.hidden_size,
            profile.attention_heads * profile.head_dim,
        )
        _ = model.require_tensor(
            prefix + "attn_k.weight", profile.hidden_size, profile.kv_width()
        )
        _ = model.require_tensor(
            prefix + "attn_v.weight", profile.hidden_size, profile.kv_width()
        )
        _ = model.require_tensor(
            prefix + "attn_output.weight",
            profile.attention_heads * profile.head_dim, profile.hidden_size,
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
    if len(model.tensors) != profile.expected_tensor_count:
        raise Error("Unsupported " + profile.label() + " tensor set")
    for name in model.tensors.keys():
        var tensor = model.tensors[name]
        if tensor.rows == 1 and tensor.kind != 0:
            raise Error("Llama normalization tensors must be F32")
