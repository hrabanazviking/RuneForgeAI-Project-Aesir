"""Validated dimensions and hybrid-state ownership for Qwen 3.5 (qwen35).

Qwen 3.5 is a hybrid architecture: every `full_attention_interval`-th
layer (1-based) is a full grouped-query attention layer, and the rest
are Gated DeltaNet (SSM) recurrent layers. Per SSM layer, q and k each
span ssm_group_count x ssm_state_size and v spans ssm_inner_size, so
the fused attn_qkv width is 2*groups*state + inner and the recurrence
runs over ssm_time_step_rank (v) heads with inner == dt_rank * state.

The profile is formula-driven from the model's own GGUF metadata
(mirroring gemma4_profile / dense_gqa_profile): `qwen35_profile_for`
reads the geometry out of the file, `validate_qwen35` checks the
hybrid relations and the exact tensor contract the Q35-1 loader
validator proved against the real 27B file (851 tensors: 498 Q8_0 +
353 F32). Tensor *shapes* are enforced here through PackedGGUF;
tensor *types* stay recorded-not-enforced, per the Q35-1 U2 verdict.
"""
from loader.packed_gguf import PackedGGUF


struct Qwen35Profile(Copyable):
    var name: String
    var layer_count: Int
    var hidden_size: Int
    var feed_forward_size: Int
    var attention_heads: Int
    var kv_heads: Int
    var head_dim: Int
    var vocabulary_size: Int
    var context_cap: Int
    var full_attention_interval: Int
    var ssm_group_count: Int
    var ssm_state_size: Int
    var ssm_time_step_rank: Int
    var ssm_inner_size: Int
    var ssm_conv_kernel: Int
    var rope_dimension_count: Int
    var rope_frequency_base: Float32
    var normalization_epsilon: Float32

    def __init__(out self, name: String, layer_count: Int, hidden_size: Int,
                 feed_forward_size: Int, attention_heads: Int, kv_heads: Int,
                 head_dim: Int, vocabulary_size: Int, context_cap: Int,
                 full_attention_interval: Int, ssm_group_count: Int,
                 ssm_state_size: Int, ssm_time_step_rank: Int,
                 ssm_inner_size: Int, ssm_conv_kernel: Int,
                 rope_dimension_count: Int, rope_frequency_base: Float32,
                 normalization_epsilon: Float32):
        self.name = name
        self.layer_count = layer_count
        self.hidden_size = hidden_size
        self.feed_forward_size = feed_forward_size
        self.attention_heads = attention_heads
        self.kv_heads = kv_heads
        self.head_dim = head_dim
        self.vocabulary_size = vocabulary_size
        self.context_cap = context_cap
        self.full_attention_interval = full_attention_interval
        self.ssm_group_count = ssm_group_count
        self.ssm_state_size = ssm_state_size
        self.ssm_time_step_rank = ssm_time_step_rank
        self.ssm_inner_size = ssm_inner_size
        self.ssm_conv_kernel = ssm_conv_kernel
        self.rope_dimension_count = rope_dimension_count
        self.rope_frequency_base = rope_frequency_base
        self.normalization_epsilon = normalization_epsilon

    def label(self) -> String:
        return "Qwen 3.5 " + self.name

    def is_full_attention(self, layer: Int) -> Bool:
        return (layer + 1) % self.full_attention_interval == 0

    def full_attention_layers(self) -> Int:
        return self.layer_count // self.full_attention_interval

    def ssm_layers(self) -> Int:
        return self.layer_count - self.full_attention_layers()

    def query_width(self) -> Int:
        return self.attention_heads * self.head_dim

    def kv_width(self) -> Int:
        return self.kv_heads * self.head_dim

    def qkv_width(self) -> Int:
        return 2 * self.ssm_group_count * self.ssm_state_size + self.ssm_inner_size

    def kv_elements(self, context_length: Int) -> Int:
        """K+V elements for ONLY the full-attention layers."""
        return self.full_attention_layers() * 2 * context_length * self.kv_width()

    def ssm_state_elements(self) -> Int:
        """Recurrence matrices: SSM layers x v-heads x state x state."""
        return self.ssm_layers() * self.ssm_time_step_rank * self.ssm_state_size * self.ssm_state_size

    def conv_ring_elements(self) -> Int:
        """Conv1d rings: SSM layers x qkv width x conv kernel."""
        return self.ssm_layers() * self.qkv_width() * self.ssm_conv_kernel

    def activation_elements(self, context_length: Int) -> Int:
        """Per-token scratch in the dense profiles' accounting style,
        plus the fused qkv projection and the inner-width SSM output."""
        return (
            3 * self.hidden_size + 2 * self.query_width() + 2 * self.kv_width()
            + 2 * self.feed_forward_size + self.vocabulary_size
            + self.attention_heads * context_length
            + self.qkv_width() + 2 * self.ssm_inner_size
        )

    def expected_tensor_count(self) -> Int:
        """3 globals + 11 per full-attention layer + 14 per SSM layer."""
        return 3 + 11 * self.full_attention_layers() + 14 * self.ssm_layers()

    def validate_relations(self) raises:
        """Hybrid geometry self-consistency; every refusal is named."""
        if self.layer_count <= 0 or self.hidden_size <= 0 or self.feed_forward_size <= 0:
            raise Error("Qwen35 profile has non-positive dense geometry")
        if self.full_attention_interval < 2:
            raise Error("Qwen35 full_attention_interval must be at least 2 for a hybrid profile")
        if self.layer_count % self.full_attention_interval != 0:
            raise Error(
                "Qwen35 full_attention_interval " + String(self.full_attention_interval)
                + " does not divide block_count " + String(self.layer_count)
            )
        if self.ssm_group_count <= 0 or self.ssm_state_size <= 0 or self.ssm_time_step_rank <= 0:
            raise Error("GGUF qwen35 SSM metadata is incomplete")
        if self.ssm_inner_size != self.ssm_time_step_rank * self.ssm_state_size:
            raise Error(
                "Qwen35 ssm_inner_size " + String(self.ssm_inner_size)
                + " != ssm_time_step_rank * ssm_state_size ("
                + String(self.ssm_time_step_rank) + " * " + String(self.ssm_state_size) + ")"
            )
        if self.qkv_width() <= self.ssm_inner_size:
            raise Error("Qwen35 qkv width does not exceed ssm_inner_size")
        if self.attention_heads <= 0 or self.kv_heads <= 0 or self.head_dim <= 0:
            raise Error("Qwen35 attention head geometry is incomplete")
        if self.query_width() <= 0 or self.kv_width() <= 0 or self.query_width() % self.kv_width() != 0:
            raise Error("Qwen35 query/kv head geometry is inconsistent")
        if self.head_dim % 2 != 0 or self.rope_dimension_count <= 0 or self.rope_dimension_count > self.head_dim:
            raise Error(
                "Qwen35 rope_dimension_count " + String(self.rope_dimension_count)
                + " is inconsistent with head_dim " + String(self.head_dim)
            )
        if self.ssm_conv_kernel <= 0:
            raise Error("Qwen35 ssm_conv_kernel must be positive")
        if self.vocabulary_size <= 0 or self.context_cap < 2:
            raise Error("Qwen35 vocabulary/context geometry is incomplete")


def qwen35_27b_profile() -> Qwen35Profile:
    """The census-proven 27B geometry (Q35-1 header census of the real file)."""
    return Qwen35Profile(
        "27B", 64, 5120, 17408, 24, 4, 256, 248320, 262144,
        4, 16, 128, 48, 6144, 4, 64, Float32(10000000), Float32(1e-6),
    )


def qwen35_profile_for(model: PackedGGUF) raises -> Qwen35Profile:
    if model.text("general.architecture") != "qwen35":
        raise Error("Qwen35 profile requires qwen35 architecture")
    var prefix = String("qwen35.")
    var head_dim = model.integer(prefix + "attention.key_length")
    var vocab = 0
    if "token_embd.weight" in model.tensors:
        vocab = model.tensors["token_embd.weight"].rows
    var profile = Qwen35Profile(
        "metadata",
        model.integer(prefix + "block_count"),
        model.integer(prefix + "embedding_length"),
        model.integer(prefix + "feed_forward_length"),
        model.integer(prefix + "attention.head_count"),
        model.integer(prefix + "attention.head_count_kv"),
        head_dim,
        vocab,
        model.integer(prefix + "context_length"),
        model.integer(prefix + "full_attention_interval"),
        model.integer(prefix + "ssm.group_count"),
        model.integer(prefix + "ssm.state_size"),
        model.integer(prefix + "ssm.time_step_rank"),
        model.integer(prefix + "ssm.inner_size"),
        model.integer(prefix + "ssm.conv_kernel"),
        model.integer(prefix + "rope.dimension_count"),
        model.floating(prefix + "rope.freq_base"),
        model.floating(prefix + "attention.layer_norm_rms_epsilon"),
    )
    if model.integer(prefix + "attention.value_length", head_dim) != head_dim:
        raise Error("Qwen35 attention key/value lengths differ")
    profile.validate_relations()
    return profile^


def validate_qwen35(model: PackedGGUF, profile: Qwen35Profile,
                    context_length: Int) raises:
    if model.text("general.architecture") != "qwen35":
        raise Error("Native " + profile.label() + " requires qwen35 architecture")
    profile.validate_relations()
    var prefix = String("qwen35.")
    var keys: List[String] = [
        "block_count", "embedding_length", "feed_forward_length",
        "attention.head_count", "attention.head_count_kv",
        "attention.key_length", "full_attention_interval",
        "ssm.group_count", "ssm.state_size", "ssm.time_step_rank",
        "ssm.inner_size", "ssm.conv_kernel", "rope.dimension_count",
    ]
    var values: List[Int] = [
        profile.layer_count, profile.hidden_size, profile.feed_forward_size,
        profile.attention_heads, profile.kv_heads, profile.head_dim,
        profile.full_attention_interval, profile.ssm_group_count,
        profile.ssm_state_size, profile.ssm_time_step_rank,
        profile.ssm_inner_size, profile.ssm_conv_kernel,
        profile.rope_dimension_count,
    ]
    for i in range(len(keys)):
        if model.integer(prefix + keys[i]) != values[i]:
            raise Error("Unsupported " + profile.label() + " metadata: " + keys[i])
    if model.integer(prefix + "attention.value_length", profile.head_dim) != profile.head_dim:
        raise Error("Unsupported " + profile.label() + " metadata: attention.value_length")
    if (model.floating(prefix + "rope.freq_base") != profile.rope_frequency_base
            or model.floating(prefix + "attention.layer_norm_rms_epsilon")
                != profile.normalization_epsilon):
        raise Error("Unsupported " + profile.label() + " RoPE or normalization")
    if context_length < 2 or context_length > min(
        profile.context_cap, model.integer(prefix + "context_length")
    ):
        raise Error(
            profile.label() + " context must be within 2.."
            + String(profile.context_cap) + " tokens"
        )
    _ = model.require_tensor("token_embd.weight", profile.hidden_size, profile.vocabulary_size)
    _ = model.require_tensor("output_norm.weight", profile.hidden_size)
    _ = model.require_tensor("output.weight", profile.hidden_size, profile.vocabulary_size)
    for layer in range(profile.layer_count):
        var lp = "blk." + String(layer) + "."
        _ = model.require_tensor(lp + "attn_norm.weight", profile.hidden_size)
        _ = model.require_tensor(lp + "post_attention_norm.weight", profile.hidden_size)
        _ = model.require_tensor(lp + "ffn_gate.weight", profile.hidden_size, profile.feed_forward_size)
        _ = model.require_tensor(lp + "ffn_up.weight", profile.hidden_size, profile.feed_forward_size)
        _ = model.require_tensor(lp + "ffn_down.weight", profile.feed_forward_size, profile.hidden_size)
        if profile.is_full_attention(layer):
            _ = model.require_tensor(lp + "attn_q.weight", profile.hidden_size, 2 * profile.query_width())
            _ = model.require_tensor(lp + "attn_k.weight", profile.hidden_size, profile.kv_width())
            _ = model.require_tensor(lp + "attn_v.weight", profile.hidden_size, profile.kv_width())
            _ = model.require_tensor(lp + "attn_output.weight", profile.query_width(), profile.hidden_size)
            _ = model.require_tensor(lp + "attn_q_norm.weight", profile.head_dim)
            _ = model.require_tensor(lp + "attn_k_norm.weight", profile.head_dim)
        else:
            _ = model.require_tensor(lp + "attn_qkv.weight", profile.hidden_size, profile.qkv_width())
            _ = model.require_tensor(lp + "attn_gate.weight", profile.hidden_size, profile.ssm_inner_size)
            _ = model.require_tensor(lp + "ssm_alpha.weight", profile.hidden_size, profile.ssm_time_step_rank)
            _ = model.require_tensor(lp + "ssm_beta.weight", profile.hidden_size, profile.ssm_time_step_rank)
            _ = model.require_tensor(lp + "ssm_a", profile.ssm_time_step_rank)
            _ = model.require_tensor(lp + "ssm_conv1d.weight", profile.ssm_conv_kernel, profile.qkv_width())
            _ = model.require_tensor(lp + "ssm_dt.bias", profile.ssm_time_step_rank)
            _ = model.require_tensor(lp + "ssm_norm.weight", profile.ssm_state_size)
            _ = model.require_tensor(lp + "ssm_out.weight", profile.ssm_inner_size, profile.hidden_size)
    if len(model.tensors) != profile.expected_tensor_count():
        raise Error("Unsupported " + profile.label() + " tensor set")
    for name in model.tensors.keys():
        var tensor = model.tensors[name]
        if tensor.rows == 1 and tensor.kind != 0:
            raise Error(profile.label() + " norm/scale tensors must be F32: " + name)
