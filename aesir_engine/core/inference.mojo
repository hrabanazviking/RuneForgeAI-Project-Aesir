from std.math import sqrt, tanh, exp, log, cos, sin
# core/inference.mojo
# The Loom of Fate: The Forward Pass
#
# Strings together the kernels from the Forge (compute) and the Memory (MimirWell)
# to weave the destiny of the tokens.

from std.math import max, min
from std.memory.alloc import alloc, Layout
from .mimir_well import RuneTensor, MimirWell, KVCache, DeviceTopology, NPUBackendType, GPURealmType, CompressedFormatType, shard_split_cols, shard_split_rows, f16, f32
from .compute import gemm_f16, gemm_q4_k_m, gemm_q5_0, gemm_q8_0, gemm_f16_arm_neon, rmsnorm_arm_neon, gemm_f16_npu, gemm_f16_gpu, rmsnorm_gpu, gemm_f16_sharded, all_reduce_sum, flash_attention_2, flash_attention_gqa, silu, gelu_tanh, geglu, rmsnorm, apply_rope, apply_rope_partial_neox, dequantize_q4_0, BlockQ4_0, iq_grid_alloc, dequantize_q4_1, BlockQ4_1, dequantize_q5_0, BlockQ5_0, dequantize_q5_1, BlockQ5_1
from .extreme_quantization import dequantize_iq_block, iq_block_bytes
from loader.gguf import GGUFSeer
from loader.quantization import dequantize_q4_0_block, dequantize_q8_0_block
from .packed_quantization import packed_value, ggml_kind_of_format
from core.sampler import sample_token_from_logits, RuneRNG


def _required_block_weight(seer: GGUFSeer, key: String) raises -> RuneTensor[f16]:
    """Returns one usable layer weight or rejects the incomplete model."""
    if key not in seer.tensors:
        raise Error("TransformerBlock: missing required tensor '" + key + "'")

    var weight = seer.tensors[key].copy()
    if weight.rows <= 0 or weight.cols <= 0 or weight.size <= 0:
        raise Error("TransformerBlock: required tensor '" + key + "' is empty")
    var address = Int(weight.data)
    if address == 0 or address == 1:
        raise Error("TransformerBlock: required tensor '" + key + "' has an invalid pointer")
    return weight^


def _optional_block_weight(seer: GGUFSeer, key: String) raises -> RuneTensor[f16]:
    """Returns optional layer weight tensor if present."""
    if key in seer.tensors:
        return seer.tensors[key].copy()
    return RuneTensor[f16](0, 0, Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1), False)


struct _ValidatedBlockCopyToken(Copyable, ImplicitlyCopyable):
    """Module-private token restricting complete-state construction to copy()."""
    var approved: Bool

    def __init__(out self):
        self.approved = True




struct TransformerBlock(Copyable):
    """
    A single layer of the Transformer.
    Weaves attention and feed-forward networks together.
    """
    var layer_idx: Int
    var head_dim: Int
    var num_heads: Int
    var num_kv_heads: Int
    var rms_epsilon: Scalar[f32]
    var rope_theta: Scalar[f32]
    var rope_neox: Bool

    var attn_norm_weight: RuneTensor[f16]
    var attn_q_norm_weight: RuneTensor[f16]
    var attn_k_norm_weight: RuneTensor[f16]
    var post_attn_norm_weight: RuneTensor[f16]
    var post_ffw_norm_weight: RuneTensor[f16]
    var attn_q_weight: RuneTensor[f16]
    var attn_k_weight: RuneTensor[f16]
    var attn_v_weight: RuneTensor[f16]
    var attn_output_weight: RuneTensor[f16]
    var ffn_norm_weight: RuneTensor[f16]
    var ffn_up_weight: RuneTensor[f16]
    var ffn_gate_weight: RuneTensor[f16]
    var ffn_down_weight: RuneTensor[f16]
    var attn_q_bias: RuneTensor[f16]
    var attn_k_bias: RuneTensor[f16]
    var attn_v_bias: RuneTensor[f16]
    var has_bias: Bool
    # Architecture modifiers resolved from GGUFModelConfig at build time.
    var attn_scale: Scalar[f32]
    var attn_softcap: Scalar[f32]
    var residual_scale: Scalar[f32]
    var layer_sliding_window: Int
    var ffn_gelu: Bool

    def __init__(out self, layer_idx: Int, head_dim: Int, num_heads: Int, seer: GGUFSeer) raises:
        if layer_idx < 0:
            raise Error("TransformerBlock: layer_idx must be non-negative")
        if head_dim <= 0:
            raise Error("TransformerBlock: head_dim must be positive")
        if num_heads <= 0:
            raise Error("TransformerBlock: num_heads must be positive")

        self.layer_idx = layer_idx
        self.head_dim = head_dim
        self.num_heads = num_heads
        self.num_kv_heads = num_heads
        self.rms_epsilon = 1e-5
        if seer.config.head_count_kv > 0:
            self.num_kv_heads = seer.config.head_count_kv
        self.rms_epsilon = seer.config.rms_epsilon
        self.rope_theta = seer.config.rope_freq_base
        self.rope_neox = (
            seer.config.architecture == "qwen2"
            or seer.config.architecture == "qwen3"
            or seer.config.architecture == "qwen35"
            or seer.config.architecture.startswith("gemma2")
        )
        self.attn_scale = seer.config.attention_scale
        self.attn_softcap = seer.config.attn_logit_softcapping
        self.residual_scale = seer.config.residual_scale
        # Gemma2 alternates local (sliding-window) and global attention,
        # local on even layers; other archs get no window from this rule.
        self.layer_sliding_window = 0
        if seer.config.architecture.startswith("gemma2") and layer_idx % 2 == 0:
            self.layer_sliding_window = seer.config.sliding_window
        self.ffn_gelu = seer.config.architecture.startswith("gemma2")

        var prefix = "blk." + String(self.layer_idx) + "."
        self.attn_norm_weight = _required_block_weight(seer, prefix + "attn_norm.weight")
        self.attn_q_norm_weight = _optional_block_weight(seer, prefix + "attn_q_norm.weight")
        self.attn_k_norm_weight = _optional_block_weight(seer, prefix + "attn_k_norm.weight")
        self.post_attn_norm_weight = _optional_block_weight(seer, prefix + "post_attention_norm.weight")
        self.post_ffw_norm_weight = _optional_block_weight(seer, prefix + "post_ffw_norm.weight")
        self.attn_q_weight = _required_block_weight(seer, prefix + "attn_q.weight")
        self.attn_k_weight = _required_block_weight(seer, prefix + "attn_k.weight")
        self.attn_v_weight = _required_block_weight(seer, prefix + "attn_v.weight")
        self.attn_output_weight = _required_block_weight(seer, prefix + "attn_output.weight")
        self.ffn_norm_weight = _required_block_weight(seer, prefix + "ffn_norm.weight")
        self.ffn_up_weight = _required_block_weight(seer, prefix + "ffn_up.weight")
        self.ffn_gate_weight = _required_block_weight(seer, prefix + "ffn_gate.weight")
        self.ffn_down_weight = _required_block_weight(seer, prefix + "ffn_down.weight")

        self.has_bias = (prefix + "attn_q.bias") in seer.tensors
        if self.has_bias:
            self.attn_q_bias = _optional_block_weight(seer, prefix + "attn_q.bias")
            self.attn_k_bias = _optional_block_weight(seer, prefix + "attn_k.bias")
            self.attn_v_bias = _optional_block_weight(seer, prefix + "attn_v.bias")
        else:
            self.attn_q_bias = _optional_block_weight(seer, prefix + "attn_q.bias")
            self.attn_k_bias = _optional_block_weight(seer, prefix + "attn_k.bias")
            self.attn_v_bias = _optional_block_weight(seer, prefix + "attn_v.bias")

    def __init__(out self, layer_idx: Int, head_dim: Int, num_heads: Int) raises:
        raise Error(
            "TransformerBlock: the legacy constructor is non-runnable; "
            "construct from a GGUFSeer with complete layer weights"
        )

    def __init__(
        out self,
        token: _ValidatedBlockCopyToken,
        layer_idx: Int,
        head_dim: Int,
        num_heads: Int,
        num_kv_heads: Int,
        rms_epsilon: Scalar[f32],
        rope_theta: Scalar[f32],
        rope_neox: Bool,
        attn_norm_weight: RuneTensor[f16],
        attn_q_weight: RuneTensor[f16],
        attn_k_weight: RuneTensor[f16],
        attn_v_weight: RuneTensor[f16],
        attn_output_weight: RuneTensor[f16],
        ffn_norm_weight: RuneTensor[f16],
        ffn_up_weight: RuneTensor[f16],
        ffn_gate_weight: RuneTensor[f16],
        ffn_down_weight: RuneTensor[f16],
        attn_q_bias: RuneTensor[f16],
        attn_k_bias: RuneTensor[f16],
        attn_v_bias: RuneTensor[f16],
        has_bias: Bool,
        attn_q_norm_weight: RuneTensor[f16] = RuneTensor[f16](0, 0, Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1), False),
        attn_k_norm_weight: RuneTensor[f16] = RuneTensor[f16](0, 0, Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1), False),
        post_attn_norm_weight: RuneTensor[f16] = RuneTensor[f16](0, 0, Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1), False),
        post_ffw_norm_weight: RuneTensor[f16] = RuneTensor[f16](0, 0, Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1), False),
        attn_scale: Scalar[f32] = Scalar[f32](0.0),
        attn_softcap: Scalar[f32] = Scalar[f32](0.0),
        residual_scale: Scalar[f32] = Scalar[f32](0.0),
        layer_sliding_window: Int = 0,
        ffn_gelu: Bool = False,
    ):
        """Builds a complete copy; the token is module-private by design."""
        self.layer_idx = layer_idx
        self.head_dim = head_dim
        self.num_heads = num_heads
        self.num_kv_heads = num_kv_heads
        self.rms_epsilon = rms_epsilon
        self.rope_theta = rope_theta
        self.rope_neox = rope_neox
        self.attn_scale = attn_scale
        self.attn_softcap = attn_softcap
        self.residual_scale = residual_scale
        self.layer_sliding_window = layer_sliding_window
        self.ffn_gelu = ffn_gelu
        self.attn_norm_weight = attn_norm_weight.copy()
        self.attn_q_norm_weight = attn_q_norm_weight.copy()
        self.attn_k_norm_weight = attn_k_norm_weight.copy()
        self.post_attn_norm_weight = post_attn_norm_weight.copy()
        self.post_ffw_norm_weight = post_ffw_norm_weight.copy()
        self.attn_q_weight = attn_q_weight.copy()
        self.attn_k_weight = attn_k_weight.copy()
        self.attn_v_weight = attn_v_weight.copy()
        self.attn_output_weight = attn_output_weight.copy()
        self.ffn_norm_weight = ffn_norm_weight.copy()
        self.ffn_up_weight = ffn_up_weight.copy()
        self.ffn_gate_weight = ffn_gate_weight.copy()
        self.ffn_down_weight = ffn_down_weight.copy()
        self.attn_q_bias = attn_q_bias.copy()
        self.attn_k_bias = attn_k_bias.copy()
        self.attn_v_bias = attn_v_bias.copy()
        self.has_bias = has_bias

    def __copyinit__(out self, existing: Self):
        self.layer_idx = existing.layer_idx
        self.head_dim = existing.head_dim
        self.num_heads = existing.num_heads
        self.num_kv_heads = existing.num_kv_heads
        self.rms_epsilon = existing.rms_epsilon
        self.rope_theta = existing.rope_theta
        self.rope_neox = existing.rope_neox
        self.attn_norm_weight = existing.attn_norm_weight
        self.attn_q_norm_weight = existing.attn_q_norm_weight
        self.attn_k_norm_weight = existing.attn_k_norm_weight
        self.post_attn_norm_weight = existing.post_attn_norm_weight
        self.post_ffw_norm_weight = existing.post_ffw_norm_weight
        self.attn_q_weight = existing.attn_q_weight
        self.attn_k_weight = existing.attn_k_weight
        self.attn_v_weight = existing.attn_v_weight
        self.attn_output_weight = existing.attn_output_weight
        self.ffn_norm_weight = existing.ffn_norm_weight
        self.ffn_up_weight = existing.ffn_up_weight
        self.ffn_gate_weight = existing.ffn_gate_weight
        self.ffn_down_weight = existing.ffn_down_weight
        self.attn_q_bias = existing.attn_q_bias
        self.attn_k_bias = existing.attn_k_bias
        self.attn_v_bias = existing.attn_v_bias
        self.has_bias = existing.has_bias
        self.attn_scale = existing.attn_scale
        self.attn_softcap = existing.attn_softcap
        self.residual_scale = existing.residual_scale
        self.layer_sliding_window = existing.layer_sliding_window
        self.ffn_gelu = existing.ffn_gelu

    @always_inline
    def copy(self) -> Self:
        return Self(
            _ValidatedBlockCopyToken(),
            self.layer_idx,
            self.head_dim,
            self.num_heads,
            self.num_kv_heads,
            self.rms_epsilon,
            self.rope_theta,
            self.rope_neox,
            self.attn_norm_weight.copy(),
            self.attn_q_weight.copy(),
            self.attn_k_weight.copy(),
            self.attn_v_weight.copy(),
            self.attn_output_weight.copy(),
            self.ffn_norm_weight.copy(),
            self.ffn_up_weight.copy(),
            self.ffn_gate_weight.copy(),
            self.ffn_down_weight.copy(),
            self.attn_q_bias.copy(),
            self.attn_k_bias.copy(),
            self.attn_v_bias.copy(),
            self.has_bias,
            self.attn_q_norm_weight.copy(),
            self.attn_k_norm_weight.copy(),
            self.post_attn_norm_weight.copy(),
            self.post_ffw_norm_weight.copy(),
            self.attn_scale,
            self.attn_softcap,
            self.residual_scale,
            self.layer_sliding_window,
            self.ffn_gelu,
        )

    def forward(
        self,
        mut x: RuneTensor[f16],
        mut seer: GGUFSeer,
        mut well: MimirWell,
        seq_len: Int,
        start_pos: Int,
        mut kv_cache: KVCache,
        topology: DeviceTopology = DeviceTopology(1),
        use_npu: Bool = False,
        npu_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
        use_gpu_realm: Bool = False,
        gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)
    ) raises:

        """
        Executes one layer on the host path. Logical sharding remains sequential
        host computation; physical accelerator options fail closed.
        """
        var num_devices = topology.num_devices
        if num_devices <= 1:
            var start_offset = well.offset
            try:
                # 1. Attention Norm
                var residual = well.allocate(x.size)
                var residual_tensor = RuneTensor[f16](x.rows, x.cols, residual, False)
                for i in range(x.size):
                    residual_tensor.data.unsafe_store(i, x.data.unsafe_load(i))
                    
                if use_gpu_realm:
                    rmsnorm_gpu(x, self.attn_norm_weight, gpu_realm, self.rms_epsilon)
                else:
                    rmsnorm(x, self.attn_norm_weight, self.rms_epsilon)

                # 2. QKV Projections
                var q_cols = self.attn_q_weight.rows if self.attn_q_weight.cols == x.cols else self.attn_q_weight.cols
                var k_cols = self.attn_k_weight.rows if self.attn_k_weight.cols == x.cols else self.attn_k_weight.cols
                var v_cols = self.attn_v_weight.rows if self.attn_v_weight.cols == x.cols else self.attn_v_weight.cols
                var q_ptr = well.allocate(x.rows * q_cols)
                var k_ptr = well.allocate(x.rows * k_cols)
                var v_ptr = well.allocate(x.rows * v_cols)

                var q = RuneTensor[f16](x.rows, q_cols, q_ptr, False)
                var k = RuneTensor[f16](x.rows, k_cols, k_ptr, False)
                var v = RuneTensor[f16](x.rows, v_cols, v_ptr, False)
                
                if use_gpu_realm:
                    gemm_f16_gpu(x, self.attn_q_weight, q, gpu_realm)
                    gemm_f16_gpu(x, self.attn_k_weight, k, gpu_realm)
                    gemm_f16_gpu(x, self.attn_v_weight, v, gpu_realm)
                elif use_npu:
                    gemm_f16_npu(x, self.attn_q_weight, q, npu_backend)
                    gemm_f16_npu(x, self.attn_k_weight, k, npu_backend)
                    gemm_f16_npu(x, self.attn_v_weight, v, npu_backend)
                else:
                    gemm_f16(x, self.attn_q_weight, q)
                    gemm_f16(x, self.attn_k_weight, k)
                    gemm_f16(x, self.attn_v_weight, v)

                if self.has_bias:
                    var q_bias_size = self.attn_q_bias.cols
                    var k_bias_size = self.attn_k_bias.cols
                    var v_bias_size = self.attn_v_bias.cols
                    for i in range(q.size):
                        q.data.unsafe_store(i, q.data.unsafe_load(i) + self.attn_q_bias.data.unsafe_load(i % q_bias_size))
                    for i in range(k.size):
                        k.data.unsafe_store(i, k.data.unsafe_load(i) + self.attn_k_bias.data.unsafe_load(i % k_bias_size))
                    for i in range(v.size):
                        v.data.unsafe_store(i, v.data.unsafe_load(i) + self.attn_v_bias.data.unsafe_load(i % v_bias_size))


                # 2.5 Per-Head Q/K RMSNorm (Gemma 3)
                if Int(self.attn_q_norm_weight.data) > 1 and self.attn_q_norm_weight.size > 0:
                    var num_q_heads = self.num_heads
                    var h_dim = self.head_dim
                    for h in range(num_q_heads):
                        var head_ptr = q.data.unsafe_offset(h * h_dim)
                        var head_tensor = RuneTensor[f16](1, h_dim, head_ptr, False)
                        rmsnorm(head_tensor, self.attn_q_norm_weight, self.rms_epsilon)
                if Int(self.attn_k_norm_weight.data) > 1 and self.attn_k_norm_weight.size > 0:
                    var num_k_heads = self.num_kv_heads
                    var h_dim = self.head_dim
                    for h in range(num_k_heads):
                        var head_ptr = k.data.unsafe_offset(h * h_dim)
                        var head_tensor = RuneTensor[f16](1, h_dim, head_ptr, False)
                        rmsnorm(head_tensor, self.attn_k_norm_weight, self.rms_epsilon)

                # 3. RoPE
                var effective_head_dim = self.head_dim
                if q.cols % effective_head_dim != 0:
                    effective_head_dim = q.cols // self.num_heads
                apply_rope(q, k, start_pos, effective_head_dim, self.rope_theta, self.rope_neox)

                # 4. Ring-Buffer KV Cache Append & Flash Attention 2
                kv_cache.append(self.layer_idx, start_pos, k, v)
                var active_seq_len = min(start_pos + 1, kv_cache.max_seq_len)
                var k_slice = kv_cache.get_k_slice(self.layer_idx, active_seq_len)
                var v_slice = kv_cache.get_v_slice(self.layer_idx, active_seq_len)

                var attn_out_ptr = well.allocate(x.rows * q.cols)
                var attn_out = RuneTensor[f16](x.rows, q.cols, attn_out_ptr, False)
                _ = self.layer_idx
                # Note: flash_attention_gqa internally applies scale = 1.0 / sqrt(head_dim)

                flash_attention_gqa(
                    q,
                    k_slice,
                    v_slice,
                    attn_out,
                    active_seq_len,
                    effective_head_dim,
                    self.num_heads,
                    self.num_kv_heads,
                    self.attn_scale,
                    self.attn_softcap,
                    self.layer_sliding_window,
                    start_pos,
                )

                # 5. Output Projection
                if use_gpu_realm:
                    gemm_f16_gpu(attn_out, self.attn_output_weight, x, gpu_realm)
                elif use_npu:
                    gemm_f16_npu(attn_out, self.attn_output_weight, x, npu_backend)
                else:
                    gemm_f16(attn_out, self.attn_output_weight, x)
                    _ = self.layer_idx


                # 5.5 Post-Attention Norm (Gemma 3)
                if Int(self.post_attn_norm_weight.data) > 1 and self.post_attn_norm_weight.size > 0:
                    rmsnorm(x, self.post_attn_norm_weight, self.rms_epsilon)

                # 5.6 Residual scale (Granite): the branch output is
                # scaled before the residual add, never the stream after.
                if self.residual_scale != Scalar[f32](0.0):
                    for i in range(x.size):
                        x.data.unsafe_store(i, Scalar[f16](x.data.unsafe_load(i).cast[DType.float32]() * self.residual_scale))

                # 6. Residual Add
                for i in range(x.size):
                    x.data.unsafe_store(i, x.data.unsafe_load(i) + residual_tensor.data.unsafe_load(i))

                # 7. FFN Norm
                for i in range(x.size):
                    residual_tensor.data.unsafe_store(i, x.data.unsafe_load(i))
                    
                if use_gpu_realm:
                    rmsnorm_gpu(x, self.ffn_norm_weight, gpu_realm, self.rms_epsilon)
                else:
                    rmsnorm(x, self.ffn_norm_weight, self.rms_epsilon)

                # 8. Feed Forward Network
                var up_cols = self.ffn_up_weight.rows if self.ffn_up_weight.cols == x.cols else self.ffn_up_weight.cols
                var gate_cols = self.ffn_gate_weight.rows if self.ffn_gate_weight.cols == x.cols else self.ffn_gate_weight.cols
                var up_ptr = well.allocate(up_cols * x.rows)
                var up = RuneTensor[f16](x.rows, up_cols, up_ptr, False)
                
                var gate_ptr = well.allocate(gate_cols * x.rows)
                var gate = RuneTensor[f16](x.rows, gate_cols, gate_ptr, False)
                
                if use_gpu_realm:
                    gemm_f16_gpu(x, self.ffn_up_weight, up, gpu_realm)
                    gemm_f16_gpu(x, self.ffn_gate_weight, gate, gpu_realm)
                elif use_npu:
                    gemm_f16_npu(x, self.ffn_up_weight, up, npu_backend)
                    gemm_f16_npu(x, self.ffn_gate_weight, gate, npu_backend)
                else:
                    gemm_f16(x, self.ffn_up_weight, up)
                    gemm_f16(x, self.ffn_gate_weight, gate)
                    
                # Apply the gate activation and multiply by up
                # (elementwise): SwiGLU by default, GeGLU for Gemma2.
                if self.ffn_gelu:
                    gelu_tanh(gate)
                else:
                    silu(gate)
                for i in range(up.size):
                    up.data.unsafe_store(i, up.data.unsafe_load(i) * gate.data.unsafe_load(i))
                    
                # GEMM down
                var ffn_out_cols = self.ffn_down_weight.rows if self.ffn_down_weight.cols == up.cols else self.ffn_down_weight.cols
                var ffn_out_ptr = well.allocate(x.rows * ffn_out_cols)
                var ffn_out = RuneTensor[f16](x.rows, ffn_out_cols, ffn_out_ptr, False)
                if use_gpu_realm:
                    gemm_f16_gpu(up, self.ffn_down_weight, ffn_out, gpu_realm)
                elif use_npu:
                    gemm_f16_npu(up, self.ffn_down_weight, ffn_out, npu_backend)
                else:
                    gemm_f16(up, self.ffn_down_weight, ffn_out)
                for i in range(x.size):
                    x.data.unsafe_store(i, ffn_out.data.unsafe_load(i))

                # 8.5 Post-FFN Norm (Gemma2): applied to the FFN branch
                # output before the residual add, mirroring llama.cpp.
                if Int(self.post_ffw_norm_weight.data) > 1 and self.post_ffw_norm_weight.size > 0:
                    rmsnorm(x, self.post_ffw_norm_weight, self.rms_epsilon)

                # 8.6 Residual scale (Granite), FFN branch.
                if self.residual_scale != Scalar[f32](0.0):
                    for i in range(x.size):
                        x.data.unsafe_store(i, Scalar[f16](x.data.unsafe_load(i).cast[DType.float32]() * self.residual_scale))

                # 9. Residual Add
                for i in range(x.size):
                    x.data.unsafe_store(i, x.data.unsafe_load(i) + residual_tensor.data.unsafe_load(i))

                well.reset_kv_cache(start_offset)
            except e:
                well.reset_kv_cache(start_offset)
                raise e
        else:
            # Multi-Device Sharded Path (The Bifrost Shard Matrix)
            var start_offset = well.offset

            # 1. Attention Norm
            var residual = well.allocate(x.size)
            var residual_tensor = RuneTensor[f16](x.rows, x.cols, residual, False)
            for i in range(x.size):
                residual_tensor.data.unsafe_store(i, x.data.unsafe_load(i))
                
            rmsnorm(x, self.attn_norm_weight, self.rms_epsilon)

            # 2. Sharded Column-Parallel QKV Projections
            var q_weight_shards = shard_split_rows(self.attn_q_weight, num_devices)
            var k_weight_shards = shard_split_rows(self.attn_k_weight, num_devices)
            var v_weight_shards = shard_split_rows(self.attn_v_weight, num_devices)

            var x_shards = List[RuneTensor[f16]]()
            var q_shards = List[RuneTensor[f16]]()
            var k_shards = List[RuneTensor[f16]]()
            var v_shards = List[RuneTensor[f16]]()

            var shard_dim = x.cols // num_devices

            for _ in range(num_devices):
                var x_d_ptr = well.allocate(x.size)
                var x_d = RuneTensor[f16](x.rows, x.cols, x_d_ptr, False)
                for i in range(x.size):
                    x_d.data.unsafe_store(i, x.data.unsafe_load(i))
                x_shards.append(x_d.copy())

                var q_d_ptr = well.allocate(x.rows * shard_dim)
                q_shards.append(RuneTensor[f16](x.rows, shard_dim, q_d_ptr, False))

                var k_d_ptr = well.allocate(x.rows * shard_dim)
                k_shards.append(RuneTensor[f16](x.rows, shard_dim, k_d_ptr, False))

                var v_d_ptr = well.allocate(x.rows * shard_dim)
                v_shards.append(RuneTensor[f16](x.rows, shard_dim, v_d_ptr, False))

            gemm_f16_sharded(x_shards, q_weight_shards, q_shards)
            gemm_f16_sharded(x_shards, k_weight_shards, k_shards)
            gemm_f16_sharded(x_shards, v_weight_shards, v_shards)

            # Reconstruct full q, k, v for RoPE, KV cache append & Flash Attention 2
            var full_q_ptr = well.allocate(x.size)
            var full_k_ptr = well.allocate(x.size)
            var full_v_ptr = well.allocate(x.size)

            var full_q = RuneTensor[f16](x.rows, x.cols, full_q_ptr, False)
            var full_k = RuneTensor[f16](x.rows, x.cols, full_k_ptr, False)
            var full_v = RuneTensor[f16](x.rows, x.cols, full_v_ptr, False)

            for d in range(num_devices):
                for i in range(shard_dim):
                    full_q.data.unsafe_store(d * shard_dim + i, q_shards[d].data.unsafe_load(i))
                    full_k.data.unsafe_store(d * shard_dim + i, k_shards[d].data.unsafe_load(i))
                    full_v.data.unsafe_store(d * shard_dim + i, v_shards[d].data.unsafe_load(i))

            # 3. RoPE
            apply_rope(full_q, full_k, start_pos, self.head_dim, self.rope_theta, self.rope_neox)

            # 4. Fixed-capacity KV Cache Append & Flash Attention 2
            kv_cache.append(self.layer_idx, start_pos, full_k, full_v)
            var active_seq_len = min(start_pos + 1, kv_cache.max_seq_len)
            var k_slice = kv_cache.get_k_slice(self.layer_idx, active_seq_len)
            var v_slice = kv_cache.get_v_slice(self.layer_idx, active_seq_len)

            var attn_out_shards = List[RuneTensor[f16]]()
            var k_slice_shards = shard_split_cols(k_slice, num_devices, well)
            var v_slice_shards = shard_split_cols(v_slice, num_devices, well)
            var q_shards_roped = shard_split_cols(full_q, num_devices, well)

            for d in range(num_devices):
                var attn_out_d_ptr = well.allocate(x.rows * shard_dim)
                var attn_out_d = RuneTensor[f16](x.rows, shard_dim, attn_out_d_ptr, False)
                flash_attention_2(q_shards_roped[d], k_slice_shards[d], v_slice_shards[d], attn_out_d, active_seq_len, self.head_dim)
                attn_out_shards.append(attn_out_d.copy())

            # 5. Row-Parallel Output Projection & All-Reduce
            var attn_out_weight_shards = shard_split_cols(self.attn_output_weight, num_devices, well)
            var out_shards = List[RuneTensor[f16]]()
            for _ in range(num_devices):
                var out_d_ptr = well.allocate(x.size)
                out_shards.append(RuneTensor[f16](x.rows, x.cols, out_d_ptr, False))

            gemm_f16_sharded(attn_out_shards, attn_out_weight_shards, out_shards)
            all_reduce_sum(out_shards, x)

            # 6. Residual Add
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual_tensor.data.unsafe_load(i))

            # 7. FFN Norm
            for i in range(x.size):
                residual_tensor.data.unsafe_store(i, x.data.unsafe_load(i))
                
            rmsnorm(x, self.ffn_norm_weight, self.rms_epsilon)

            # 8. Sharded Column-Parallel SwiGLU FFN Projections
            var up_weight_shards = shard_split_rows(self.ffn_up_weight, num_devices)
            var gate_weight_shards = shard_split_rows(self.ffn_gate_weight, num_devices)

            var inter_dim = self.ffn_up_weight.rows
            var inter_shard_dim = inter_dim // num_devices

            var x_ffn_shards = List[RuneTensor[f16]]()
            var up_shards = List[RuneTensor[f16]]()
            var gate_shards = List[RuneTensor[f16]]()

            for _ in range(num_devices):
                var x_d_ptr = well.allocate(x.size)
                var x_d = RuneTensor[f16](x.rows, x.cols, x_d_ptr, False)
                for i in range(x.size):
                    x_d.data.unsafe_store(i, x.data.unsafe_load(i))
                x_ffn_shards.append(x_d.copy())

                var up_d_ptr = well.allocate(x.rows * inter_shard_dim)
                up_shards.append(RuneTensor[f16](x.rows, inter_shard_dim, up_d_ptr, False))

                var gate_d_ptr = well.allocate(x.rows * inter_shard_dim)
                gate_shards.append(RuneTensor[f16](x.rows, inter_shard_dim, gate_d_ptr, False))

            gemm_f16_sharded(x_ffn_shards, up_weight_shards, up_shards)
            gemm_f16_sharded(x_ffn_shards, gate_weight_shards, gate_shards)

            for d in range(num_devices):
                silu(gate_shards[d])
                for i in range(up_shards[d].size):
                    up_shards[d].data.unsafe_store(i, up_shards[d].data.unsafe_load(i) * gate_shards[d].data.unsafe_load(i))

            # Row-Parallel FFN Down Projection & All-Reduce
            var down_weight_shards = shard_split_cols(self.ffn_down_weight, num_devices, well)
            var ffn_out_shards = List[RuneTensor[f16]]()
            for _ in range(num_devices):
                var ffn_d_ptr = well.allocate(x.size)
                ffn_out_shards.append(RuneTensor[f16](x.rows, x.cols, ffn_d_ptr, False))

            gemm_f16_sharded(up_shards, down_weight_shards, ffn_out_shards)
            all_reduce_sum(ffn_out_shards, x)

            # 9. Residual Add
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual_tensor.data.unsafe_load(i))

            well.offset = start_offset

    def forward_batched(
        self,
        mut x: RuneTensor[f16],
        mut seer: GGUFSeer,
        mut well: MimirWell,
        start_pos: Int,
        mut kv_cache: KVCache,
        topology: DeviceTopology = DeviceTopology(1),
        use_npu: Bool = False,
        npu_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
        use_gpu_realm: Bool = False,
        gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)
    ) raises:
        """Batched twin of forward()'s single-device body, for a block
        of x.rows consecutive positions starting at start_pos (prefill).

        Almost every stage of the original body was already row-generic
        (norms, GEMMs, bias add, RoPE, FFN, residual adds all operate on
        x.rows / x.size), so this is the same code with exactly three
        deltas: (1) the per-head Q/K RMSNorm loops over rows as well as
        heads — forward()'s version silently normalises only row 0 for
        multi-row input; (2) the KV append is KVCache.append_block;
        (3) attention runs the existing flash_attention_gqa once per
        row with that row's own causal bound and query_pos, so per-row
        numerics are bit-identical to the per-token path. The sharded
        multi-device body has no batched form and raises here.
        """
        if topology.num_devices > 1:
            raise Error("TransformerBlock.forward_batched: sharded multi-device path is single-row only")
        if x.rows <= 0:
            raise Error("TransformerBlock.forward_batched: batch must have at least one row")
        if start_pos < 0 or start_pos + x.rows > kv_cache.max_seq_len:
            raise Error("TransformerBlock.forward_batched: batch exceeds KV cache capacity")
        var start_offset = well.offset
        try:
            # 1. Attention Norm
            var residual = well.allocate(x.size)
            var residual_tensor = RuneTensor[f16](x.rows, x.cols, residual, False)
            for i in range(x.size):
                residual_tensor.data.unsafe_store(i, x.data.unsafe_load(i))

            if use_gpu_realm:
                rmsnorm_gpu(x, self.attn_norm_weight, gpu_realm, self.rms_epsilon)
            else:
                rmsnorm(x, self.attn_norm_weight, self.rms_epsilon)

            # 2. QKV Projections
            var q_cols = self.attn_q_weight.rows if self.attn_q_weight.cols == x.cols else self.attn_q_weight.cols
            var k_cols = self.attn_k_weight.rows if self.attn_k_weight.cols == x.cols else self.attn_k_weight.cols
            var v_cols = self.attn_v_weight.rows if self.attn_v_weight.cols == x.cols else self.attn_v_weight.cols
            var q_ptr = well.allocate(x.rows * q_cols)
            var k_ptr = well.allocate(x.rows * k_cols)
            var v_ptr = well.allocate(x.rows * v_cols)

            var q = RuneTensor[f16](x.rows, q_cols, q_ptr, False)
            var k = RuneTensor[f16](x.rows, k_cols, k_ptr, False)
            var v = RuneTensor[f16](x.rows, v_cols, v_ptr, False)

            if use_gpu_realm:
                gemm_f16_gpu(x, self.attn_q_weight, q, gpu_realm)
                gemm_f16_gpu(x, self.attn_k_weight, k, gpu_realm)
                gemm_f16_gpu(x, self.attn_v_weight, v, gpu_realm)
            elif use_npu:
                gemm_f16_npu(x, self.attn_q_weight, q, npu_backend)
                gemm_f16_npu(x, self.attn_k_weight, k, npu_backend)
                gemm_f16_npu(x, self.attn_v_weight, v, npu_backend)
            else:
                gemm_f16(x, self.attn_q_weight, q)
                gemm_f16(x, self.attn_k_weight, k)
                gemm_f16(x, self.attn_v_weight, v)

            if self.has_bias:
                var q_bias_size = self.attn_q_bias.cols
                var k_bias_size = self.attn_k_bias.cols
                var v_bias_size = self.attn_v_bias.cols
                for i in range(q.size):
                    q.data.unsafe_store(i, q.data.unsafe_load(i) + self.attn_q_bias.data.unsafe_load(i % q_bias_size))
                for i in range(k.size):
                    k.data.unsafe_store(i, k.data.unsafe_load(i) + self.attn_k_bias.data.unsafe_load(i % k_bias_size))
                for i in range(v.size):
                    v.data.unsafe_store(i, v.data.unsafe_load(i) + self.attn_v_bias.data.unsafe_load(i % v_bias_size))

            # 2.5 Per-Head Q/K RMSNorm (Gemma 3) — row-major form: every
            # row's heads are normalised (delta 1 vs forward()).
            if Int(self.attn_q_norm_weight.data) > 1 and self.attn_q_norm_weight.size > 0:
                var num_q_heads = self.num_heads
                var h_dim = self.head_dim
                for r in range(q.rows):
                    for h in range(num_q_heads):
                        var head_ptr = q.data.unsafe_offset(r * q.cols + h * h_dim)
                        var head_tensor = RuneTensor[f16](1, h_dim, head_ptr, False)
                        rmsnorm(head_tensor, self.attn_q_norm_weight, self.rms_epsilon)
            if Int(self.attn_k_norm_weight.data) > 1 and self.attn_k_norm_weight.size > 0:
                var num_k_heads = self.num_kv_heads
                var h_dim = self.head_dim
                for r in range(k.rows):
                    for h in range(num_k_heads):
                        var head_ptr = k.data.unsafe_offset(r * k.cols + h * h_dim)
                        var head_tensor = RuneTensor[f16](1, h_dim, head_ptr, False)
                        rmsnorm(head_tensor, self.attn_k_norm_weight, self.rms_epsilon)

            # 3. RoPE (already row-generic: pos = start_pos + r per row)
            var effective_head_dim = self.head_dim
            if q.cols % effective_head_dim != 0:
                effective_head_dim = q.cols // self.num_heads
            apply_rope(q, k, start_pos, effective_head_dim, self.rope_theta, self.rope_neox)

            # 4. Block KV Cache Append & per-row Flash Attention (deltas
            # 2 and 3): one slice for the whole span, then the existing
            # decode-shaped kernel per row with that row's causal bound.
            kv_cache.append_block(self.layer_idx, start_pos, k, v, x.rows)
            var total_seq_len = min(start_pos + x.rows, kv_cache.max_seq_len)
            var k_slice = kv_cache.get_k_slice(self.layer_idx, total_seq_len)
            var v_slice = kv_cache.get_v_slice(self.layer_idx, total_seq_len)

            var attn_out_ptr = well.allocate(x.rows * q.cols)
            var attn_out = RuneTensor[f16](x.rows, q.cols, attn_out_ptr, False)
            for r in range(x.rows):
                var q_row = RuneTensor[f16](1, q.cols, q.data.unsafe_offset(r * q.cols), False)
                var o_row = RuneTensor[f16](1, q.cols, attn_out_ptr.unsafe_offset(r * q.cols), False)
                flash_attention_gqa(
                    q_row,
                    k_slice,
                    v_slice,
                    o_row,
                    min(start_pos + r + 1, kv_cache.max_seq_len),
                    effective_head_dim,
                    self.num_heads,
                    self.num_kv_heads,
                    self.attn_scale,
                    self.attn_softcap,
                    self.layer_sliding_window,
                    start_pos + r,
                )

            # 5. Output Projection
            if use_gpu_realm:
                gemm_f16_gpu(attn_out, self.attn_output_weight, x, gpu_realm)
            elif use_npu:
                gemm_f16_npu(attn_out, self.attn_output_weight, x, npu_backend)
            else:
                gemm_f16(attn_out, self.attn_output_weight, x)

            # 5.5 Post-Attention Norm (Gemma 3)
            if Int(self.post_attn_norm_weight.data) > 1 and self.post_attn_norm_weight.size > 0:
                rmsnorm(x, self.post_attn_norm_weight, self.rms_epsilon)

            # 5.6 Residual scale (Granite)
            if self.residual_scale != Scalar[f32](0.0):
                for i in range(x.size):
                    x.data.unsafe_store(i, Scalar[f16](x.data.unsafe_load(i).cast[DType.float32]() * self.residual_scale))

            # 6. Residual Add
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual_tensor.data.unsafe_load(i))

            # 7. FFN Norm
            for i in range(x.size):
                residual_tensor.data.unsafe_store(i, x.data.unsafe_load(i))

            if use_gpu_realm:
                rmsnorm_gpu(x, self.ffn_norm_weight, gpu_realm, self.rms_epsilon)
            else:
                rmsnorm(x, self.ffn_norm_weight, self.rms_epsilon)

            # 8. Feed Forward Network
            var up_cols = self.ffn_up_weight.rows if self.ffn_up_weight.cols == x.cols else self.ffn_up_weight.cols
            var gate_cols = self.ffn_gate_weight.rows if self.ffn_gate_weight.cols == x.cols else self.ffn_gate_weight.cols
            var up_ptr = well.allocate(up_cols * x.rows)
            var up = RuneTensor[f16](x.rows, up_cols, up_ptr, False)

            var gate_ptr = well.allocate(gate_cols * x.rows)
            var gate = RuneTensor[f16](x.rows, gate_cols, gate_ptr, False)

            if use_gpu_realm:
                gemm_f16_gpu(x, self.ffn_up_weight, up, gpu_realm)
                gemm_f16_gpu(x, self.ffn_gate_weight, gate, gpu_realm)
            elif use_npu:
                gemm_f16_npu(x, self.ffn_up_weight, up, npu_backend)
                gemm_f16_npu(x, self.ffn_gate_weight, up, npu_backend)
            else:
                gemm_f16(x, self.ffn_up_weight, up)
                gemm_f16(x, self.ffn_gate_weight, gate)

            if self.ffn_gelu:
                gelu_tanh(gate)
            else:
                silu(gate)
            for i in range(up.size):
                up.data.unsafe_store(i, up.data.unsafe_load(i) * gate.data.unsafe_load(i))

            var ffn_out_cols = self.ffn_down_weight.rows if self.ffn_down_weight.cols == up.cols else self.ffn_down_weight.cols
            var ffn_out_ptr = well.allocate(x.rows * ffn_out_cols)
            var ffn_out = RuneTensor[f16](x.rows, ffn_out_cols, ffn_out_ptr, False)
            if use_gpu_realm:
                gemm_f16_gpu(up, self.ffn_down_weight, ffn_out, gpu_realm)
            elif use_npu:
                gemm_f16_npu(up, self.ffn_down_weight, ffn_out, npu_backend)
            else:
                gemm_f16(up, self.ffn_down_weight, ffn_out)
            for i in range(x.size):
                x.data.unsafe_store(i, ffn_out.data.unsafe_load(i))

            # 8.5 Post-FFN Norm (Gemma2)
            if Int(self.post_ffw_norm_weight.data) > 1 and self.post_ffw_norm_weight.size > 0:
                rmsnorm(x, self.post_ffw_norm_weight, self.rms_epsilon)

            # 8.6 Residual scale (Granite), FFN branch.
            if self.residual_scale != Scalar[f32](0.0):
                for i in range(x.size):
                    x.data.unsafe_store(i, Scalar[f16](x.data.unsafe_load(i).cast[DType.float32]() * self.residual_scale))

            # 9. Residual Add
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual_tensor.data.unsafe_load(i))

            well.reset_kv_cache(start_offset)
        except e:
            well.reset_kv_cache(start_offset)
            raise e


def _embed_token_into(
    mut seer: GGUFSeer,
    token_id: Int,
    dst: Pointer[Scalar[f16], MutUntrackedOrigin],
    tensor_name: String = "token_embd.weight",
    apply_arch_scale: Bool = True,
) raises:
    """Writes one token's embedding row into dst (hidden_dim elements):
    quantized rows (Q8_0 / K-quant via the packed oracle / IQ via the
    codebook block decoder / Q4_0 / Q4_1 / Q5_0 / Q5_1) or plain rows, then the arch
    embedding scale (explicit metadata scale wins; the Gemma family
    falls back to sqrt(hidden_dim)). This is the body of _embed_token
    with the destination unrolled, so a batch of rows can be embedded
    into one tensor (see _embed_tokens). Any quantized format without
    a branch here raises instead of falling through to a wrong-format
    decode: before the IQ branch existed, an IQ3_S embedding row was
    silently decoded as Q4_0 (wrong layout AND wrong row stride),
    which collapsed IQ-embedding models (e.g. Oprius-3.1-1.1B i1
    IQ2_M, token_embd IQ3_S) to <unk> on every generated token."""
    if tensor_name not in seer.tensors:
        raise Error("Inference requires " + tensor_name)
    ref token_embd = seer.tensors[tensor_name]
    var hidden_dim = token_embd.cols
    var vocab_dim = token_embd.rows
    if token_id < 0 or token_id >= vocab_dim:
        raise Error("Inference token ID is outside the embedding vocabulary")
    if token_embd.is_quantized:
        var num_blocks = hidden_dim // 32
        if token_embd.quant_format.value == CompressedFormatType.Q8_0:
            var block_bytes = 34
            var src_byte_offset = (token_id * num_blocks) * block_bytes
            var src_ptr = token_embd.data.unsafe_bitcast[Byte]().unsafe_offset(src_byte_offset)
            dequantize_q8_0_block(src_ptr, dst, num_blocks)
        elif 10 <= ggml_kind_of_format(Int(token_embd.quant_format.value)) and ggml_kind_of_format(Int(token_embd.quant_format.value)) <= 14:
            var emb_kind = ggml_kind_of_format(Int(token_embd.quant_format.value))
            var k_block_bytes = 210
            if emb_kind == 10:
                k_block_bytes = 84
            elif emb_kind == 11:
                k_block_bytes = 110
            elif emb_kind == 12:
                k_block_bytes = 144
            elif emb_kind == 13:
                k_block_bytes = 176
            var row_bytes = (hidden_dim // 256) * k_block_bytes
            var row_base = token_id * row_bytes
            var emb_bytes = token_embd.data.unsafe_bitcast[Byte]()
            for i in range(hidden_dim):
                dst.unsafe_store(i, Scalar[f16](packed_value(emb_bytes, row_base, emb_kind, i)))
        elif (
            token_embd.quant_format.value == CompressedFormatType.IQ1_S
            or token_embd.quant_format.value == CompressedFormatType.IQ2_XXS
            or token_embd.quant_format.value == CompressedFormatType.IQ2_S
            or token_embd.quant_format.value == CompressedFormatType.IQ3_S
            or token_embd.quant_format.value == CompressedFormatType.IQ2_XS
            or token_embd.quant_format.value == CompressedFormatType.IQ3_XXS
        ):
            # IQ embedding row: (hidden_dim // 256) super-blocks of
            # iq_block_bytes(kind) each, decoded block-by-block with
            # the codebook grid. The grid lives in a heap allocation
            # from iq_grid_alloc (the phase-3 discipline: a stack
            # grid in a GEMM frame is layout-clobbered by this
            # toolchain; see iq-worker REPORT.md phase 3).
            if hidden_dim % 256 != 0:
                raise Error("Inference IQ token embedding requires complete 256-value blocks")
            var fmt = token_embd.quant_format.value
            var iq_kind = 22
            if fmt == CompressedFormatType.IQ1_S:
                iq_kind = 19
            elif fmt == CompressedFormatType.IQ2_XXS:
                iq_kind = 16
            elif fmt == CompressedFormatType.IQ3_S:
                iq_kind = 21
            elif fmt == CompressedFormatType.IQ2_XS:
                iq_kind = 17
            elif fmt == CompressedFormatType.IQ3_XXS:
                iq_kind = 18
            var iq_block = iq_block_bytes(iq_kind)
            var row_base = token_id * (hidden_dim // 256) * iq_block
            var emb_bytes = token_embd.data.unsafe_bitcast[Byte]()
            var grid_ptr = iq_grid_alloc(iq_kind)
            var scratch = alloc[Float32](256)
            for b in range(hidden_dim // 256):
                dequantize_iq_block(
                    emb_bytes,
                    row_base + b * iq_block,
                    iq_kind,
                    grid_ptr,
                    scratch,
                )
                for i in range(256):
                    dst.unsafe_store(
                        b * 256 + i, Scalar[f16](scratch.unsafe_load(i))
                    )
            scratch.unsafe_free()
            grid_ptr.unsafe_free()
        elif token_embd.quant_format.value == CompressedFormatType.Q4_0:
            var block_bytes = 18
            var src_byte_offset = (token_id * num_blocks) * block_bytes
            var src_ptr = token_embd.data.unsafe_bitcast[Byte]().unsafe_offset(src_byte_offset)
            dequantize_q4_0_block(src_ptr, dst, num_blocks)
        elif token_embd.quant_format.value == CompressedFormatType.Q4_1:
            var block_bytes = 20
            var src_byte_offset = (token_id * num_blocks) * block_bytes
            var src_ptr = token_embd.data.unsafe_bitcast[Byte]().unsafe_offset(src_byte_offset)
            dequantize_q4_1(src_ptr.unsafe_bitcast[BlockQ4_1](), dst, num_blocks)
        elif token_embd.quant_format.value == CompressedFormatType.Q5_0:
            var block_bytes = 22
            var src_byte_offset = (token_id * num_blocks) * block_bytes
            var src_ptr = token_embd.data.unsafe_bitcast[Byte]().unsafe_offset(src_byte_offset)
            dequantize_q5_0(src_ptr.unsafe_bitcast[BlockQ5_0](), dst, num_blocks)
        elif token_embd.quant_format.value == CompressedFormatType.Q5_1:
            var block_bytes = 24
            var src_byte_offset = (token_id * num_blocks) * block_bytes
            var src_ptr = token_embd.data.unsafe_bitcast[Byte]().unsafe_offset(src_byte_offset)
            dequantize_q5_1(src_ptr.unsafe_bitcast[BlockQ5_1](), dst, num_blocks)
        else:
            raise Error(
                "Inference token embedding has an unsupported quantized format: "
                + token_embd.quant_format.name()
            )
    else:
        var src_offset = token_id * hidden_dim
        for i in range(hidden_dim):
            dst.unsafe_store(i, token_embd.data.unsafe_load(src_offset + i))
    if apply_arch_scale and seer.config.embedding_scale != Float32(0.0):
        var cfg_emb_scale = seer.config.embedding_scale
        for i in range(hidden_dim):
            dst.unsafe_store(i, Scalar[f16](dst.unsafe_load(i).cast[DType.float32]() * cfg_emb_scale))
    elif apply_arch_scale and seer.config.architecture.startswith("gemma"):
        var emb_scale = Float32(sqrt(Float64(hidden_dim)))
        for i in range(hidden_dim):
            dst.unsafe_store(i, Scalar[f16](dst.unsafe_load(i).cast[DType.float32]() * emb_scale))
    

def _embed_token(
    mut seer: GGUFSeer, mut well: MimirWell, token_id: Int
) raises -> RuneTensor[f16]:
    """Token embedding lookup shared by every arch forward path."""
    if "token_embd.weight" not in seer.tensors:
        raise Error("Inference requires token_embd.weight")
    ref token_embd = seer.tensors["token_embd.weight"]
    var hidden_dim = token_embd.cols
    var x_ptr = well.allocate(hidden_dim)
    _embed_token_into(seer, token_id, x_ptr)
    return RuneTensor[f16](1, hidden_dim, x_ptr, False)


def _embed_tokens(
    mut seer: GGUFSeer,
    mut well: MimirWell,
    tokens: List[Int],
    start_pos: Int,
    batch_len: Int,
) raises -> RuneTensor[f16]:
    """Batched embedding lookup: a [batch_len, hidden] tensor whose row
    r is exactly _embed_token(tokens[start_pos + r]) — the per-row
    computation is a pure function of the token id, so the block is
    identical to batch_len single lookups."""
    if "token_embd.weight" not in seer.tensors:
        raise Error("Inference requires token_embd.weight")
    ref token_embd = seer.tensors["token_embd.weight"]
    var hidden_dim = token_embd.cols
    var base = well.allocate(batch_len * hidden_dim)
    for r in range(batch_len):
        _embed_token_into(
            seer, tokens[start_pos + r], base.unsafe_offset(r * hidden_dim)
        )
    return RuneTensor[f16](batch_len, hidden_dim, base, False)

def forward_pass(
    tokens: List[Int],
    mut seer: GGUFSeer, 
    mut well: MimirWell, 
    mut kv_cache: KVCache,
    start_pos: Int = 0,
    num_layers: Int = 32, 
    head_dim: Int = 128, 
    num_heads: Int = 32,
    topology: DeviceTopology = DeviceTopology(1),
    blocks: List[TransformerBlock] = List[TransformerBlock](),
    use_npu: Bool = False,
    npu_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
    use_gpu_realm: Bool = False,
    gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
    temperature: Scalar[f32] = 0.0,
    top_k: Int = 40,
    top_p: Scalar[f32] = 0.9,
    repetition_penalty: Scalar[f32] = 1.1,
    is_prefill: Bool = False,
    span_start: Int = -1,
    span_rows: List[Float32] = List[Float32](),
) raises -> Int:

    """
    The Weaving of Fate.
    Executes the full LLM forward pass across transformer layers with bounds safety.
    """
    if len(tokens) == 0:
        raise Error("forward_pass: tokens list cannot be empty")
    if num_layers <= 0 or head_dim <= 0 or num_heads <= 0:
        raise Error("forward_pass: model architecture dimensions must be positive")

    var initial_offset = well.offset
    var token_idx = min(max(0, start_pos), len(tokens) - 1)
    var last_token = tokens[token_idx]

    # 1. Token Embedding Lookup (shared helper; see _embed_token)
    var x = _embed_token(seer, well, last_token)
    if span_start >= 0:
        apply_embedding_span(x, span_rows, span_start, start_pos)

    # 2. Layer-by-Layer Forward Pass
    var actual_layers = min(num_layers, seer.config.block_count)
    if len(blocks) >= actual_layers:
        for l in range(actual_layers):
            blocks[l].forward(

                x, seer, well, 1, start_pos, kv_cache, topology, use_npu, npu_backend, use_gpu_realm, gpu_realm
            )
    else:
        for l in range(actual_layers):
            var temp_block = TransformerBlock(l, head_dim, num_heads, seer)
            temp_block.forward(
                x, seer, well, 1, start_pos, kv_cache, topology, use_npu, npu_backend, use_gpu_realm, gpu_realm
            )

    if is_prefill:
        well.offset = initial_offset
        return 0
        
    # 3. Final RMSNorm
    if "output_norm.weight" in seer.tensors:
        ref output_norm_weight = seer.tensors["output_norm.weight"]
        var epsilon: Scalar[f32] = 1e-5
        if seer.config.rms_epsilon > 0.0:
            epsilon = seer.config.rms_epsilon
        try:
            if use_gpu_realm:
                rmsnorm_gpu(x, output_norm_weight, gpu_realm, epsilon)
            else:
                rmsnorm(x, output_norm_weight, epsilon)
        except e:
            well.offset = initial_offset
            raise e
    
    # 4. Final projection to logits
    if "output.weight" not in seer.tensors:
        well.offset = initial_offset
        raise Error("Inference requires output.weight")

    ref output_weight = seer.tensors["output.weight"]
    var vocab_size = output_weight.rows
    var logits_ptr = well.allocate(vocab_size)
    var logits = RuneTensor[f16](1, vocab_size, logits_ptr, False)
    
    var output_weight_eff = output_weight.copy()
    
    if use_gpu_realm:
        gemm_f16_gpu(x, output_weight_eff, logits, gpu_realm)
    elif use_npu:
        gemm_f16_npu(x, output_weight_eff, logits, npu_backend)
    else:
        gemm_f16(x, output_weight_eff, logits)

    # Logit scaling (Granite divides by logit_scale) and final logit
    # softcapping (Gemma2: c * tanh(logits / c)), per llama.cpp graphs.
    if seer.config.logit_scale != Float32(0.0):
        var inv_logit_scale = Float32(1.0) / seer.config.logit_scale
        for i in range(vocab_size):
            logits.data.unsafe_store(i, Scalar[f16](logits.data.unsafe_load(i).cast[DType.float32]() * inv_logit_scale))
    if seer.config.final_logit_softcapping != Float32(0.0):
        var cap = seer.config.final_logit_softcapping
        for i in range(vocab_size):
            var v = logits.data.unsafe_load(i).cast[DType.float32]()
            logits.data.unsafe_store(i, Scalar[f16](cap * tanh(v / cap)))


    # 6. Temperature & Top-K / Top-P sampling with repetition penalty
    var rng = RuneRNG(42)
    var suppress_list = List[Int]()
    var best_token = sample_token_from_logits(
        logits.data,
        vocab_size,
        temperature=temperature,
        top_k=top_k,
        top_p=top_p,
        repetition_penalty=repetition_penalty,
        context_tokens=tokens,
        rng=rng,
        suppress_tokens=suppress_list,
    )
    well.offset = initial_offset
    return best_token



def apply_embedding_span(
    mut x: RuneTensor[f16],
    span_rows: List[Float32],
    span_start: Int,
    chunk_start_pos: Int,
) raises:
    """Replaces the embedding rows of x that fall inside an image span
    with precomputed encoder rows (design doc section 4, slice 4).

    x holds the embedding stream for the chunk of positions
    [chunk_start_pos, chunk_start_pos + x.rows). span_rows is a flat
    [n_span, x.cols] Float32 buffer whose row k belongs at absolute
    position span_start + k. Positions outside the span keep their
    token_embd rows exactly. Fail-closed: an empty buffer, a negative
    span start, or a buffer whose length is not a whole number of
    x.cols rows raises instead of truncating or padding."""
    if span_start < 0:
        raise Error("apply_embedding_span: span start must be non-negative")
    if len(span_rows) == 0:
        raise Error("apply_embedding_span: span row buffer is empty")
    if x.cols <= 0 or len(span_rows) % x.cols != 0:
        raise Error(
            "apply_embedding_span: span row width does not match the embedding width"
        )
    var n_span = len(span_rows) // x.cols
    var lo = max(span_start, chunk_start_pos)
    var hi = min(span_start + n_span, chunk_start_pos + x.rows)
    for pos in range(lo, hi):
        var dst_row = pos - chunk_start_pos
        var src_row = pos - span_start
        for j in range(x.cols):
            x.data.unsafe_store(
                dst_row * x.cols + j,
                Scalar[f16](span_rows[src_row * x.cols + j]),
            )


def forward_pass_batched(
    tokens: List[Int],
    mut seer: GGUFSeer,
    mut well: MimirWell,
    mut kv_cache: KVCache,
    start_pos: Int,
    batch_len: Int,
    num_layers: Int = 32,
    head_dim: Int = 128,
    num_heads: Int = 32,
    topology: DeviceTopology = DeviceTopology(1),
    blocks: List[TransformerBlock] = List[TransformerBlock](),
    use_npu: Bool = False,
    npu_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
    use_gpu_realm: Bool = False,
    gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
    temperature: Scalar[f32] = 0.0,
    top_k: Int = 40,
    top_p: Scalar[f32] = 0.9,
    repetition_penalty: Scalar[f32] = 1.1,
    is_prefill: Bool = False,
    span_start: Int = -1,
    span_rows: List[Float32] = List[Float32](),
) raises -> Int:
    """Batched twin of forward_pass for one prefill chunk: processes
    batch_len consecutive prompt tokens starting at start_pos in a
    single pass through the layers (see TransformerBlock
    .forward_batched for why the numerics are bit-identical to
    batch_len per-token passes). With is_prefill=True the chunk only
    fills the KV cache and returns 0, exactly like forward_pass;
    otherwise the output stage runs on the LAST row only, through the
    unchanged norm + LM head + sampling code.
    """
    if len(tokens) == 0:
        raise Error("forward_pass_batched: tokens list cannot be empty")
    if num_layers <= 0 or head_dim <= 0 or num_heads <= 0:
        raise Error("forward_pass_batched: model architecture dimensions must be positive")
    if batch_len <= 0 or start_pos < 0 or start_pos + batch_len > len(tokens):
        raise Error("forward_pass_batched: chunk range outside the token list")
    if start_pos + batch_len > kv_cache.max_seq_len:
        raise Error("forward_pass_batched: chunk exceeds KV cache capacity")

    var initial_offset = well.offset

    # 1. Batched token embedding (rows are _embed_token per position)
    var x = _embed_tokens(seer, well, tokens, start_pos, batch_len)
    if span_start >= 0:
        apply_embedding_span(x, span_rows, span_start, start_pos)

    # 2. Layer-by-layer batched forward
    var actual_layers = min(num_layers, seer.config.block_count)
    if len(blocks) >= actual_layers:
        for l in range(actual_layers):
            blocks[l].forward_batched(
                x, seer, well, start_pos, kv_cache, topology, use_npu, npu_backend, use_gpu_realm, gpu_realm
            )
    else:
        for l in range(actual_layers):
            var temp_block = TransformerBlock(l, head_dim, num_heads, seer)
            temp_block.forward_batched(
                x, seer, well, start_pos, kv_cache, topology, use_npu, npu_backend, use_gpu_realm, gpu_realm
            )

    if is_prefill:
        well.offset = initial_offset
        return 0

    # 3-6. Output stage on the last row only — identical code to
    # forward_pass operating on a 1-row view of the final hidden row.
    var x_last = RuneTensor[f16](
        1, x.cols, x.data.unsafe_offset((batch_len - 1) * x.cols), False
    )

    if "output_norm.weight" in seer.tensors:
        ref output_norm_weight = seer.tensors["output_norm.weight"]
        var epsilon: Scalar[f32] = 1e-5
        if seer.config.rms_epsilon > 0.0:
            epsilon = seer.config.rms_epsilon
        try:
            if use_gpu_realm:
                rmsnorm_gpu(x_last, output_norm_weight, gpu_realm, epsilon)
            else:
                rmsnorm(x_last, output_norm_weight, epsilon)
        except e:
            well.offset = initial_offset
            raise e

    if "output.weight" not in seer.tensors:
        well.offset = initial_offset
        raise Error("Inference requires output.weight")

    ref output_weight = seer.tensors["output.weight"]
    var vocab_size = output_weight.rows
    var logits_ptr = well.allocate(vocab_size)
    var logits = RuneTensor[f16](1, vocab_size, logits_ptr, False)

    var output_weight_eff = output_weight.copy()

    if use_gpu_realm:
        gemm_f16_gpu(x_last, output_weight_eff, logits, gpu_realm)
    elif use_npu:
        gemm_f16_npu(x_last, output_weight_eff, logits, npu_backend)
    else:
        gemm_f16(x_last, output_weight_eff, logits)

    if seer.config.logit_scale != Float32(0.0):
        var inv_logit_scale = Float32(1.0) / seer.config.logit_scale
        for i in range(vocab_size):
            logits.data.unsafe_store(i, Scalar[f16](logits.data.unsafe_load(i).cast[DType.float32]() * inv_logit_scale))
    if seer.config.final_logit_softcapping != Float32(0.0):
        var cap = seer.config.final_logit_softcapping
        for i in range(vocab_size):
            var v = logits.data.unsafe_load(i).cast[DType.float32]()
            logits.data.unsafe_store(i, Scalar[f16](cap * tanh(v / cap)))

    var rng = RuneRNG(42)
    var suppress_list = List[Int]()
    var best_token = sample_token_from_logits(
        logits.data,
        vocab_size,
        temperature=temperature,
        top_k=top_k,
        top_p=top_p,
        repetition_penalty=repetition_penalty,
        context_tokens=tokens,
        rng=rng,
        suppress_tokens=suppress_list,
    )
    well.offset = initial_offset
    return best_token

def forward_pass(
    tokens: List[Int], 
    mut seer: GGUFSeer, 
    mut well: MimirWell, 
    num_layers: Int = 32, 
    head_dim: Int = 128, 
    num_heads: Int = 32,
    topology: DeviceTopology = DeviceTopology(1),
    blocks: List[TransformerBlock] = List[TransformerBlock](),
    use_npu: Bool = False,
    npu_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
    use_gpu_realm: Bool = False,
    gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
    temperature: Scalar[f32] = 0.0,
    top_k: Int = 40,
    top_p: Scalar[f32] = 0.9,
    repetition_penalty: Scalar[f32] = 1.1,
) raises -> Int:
    """
    Overload for forward_pass without an explicit KVCache.
    """
    ref token_embd = seer.tensors["token_embd.weight"]
    var kv_dim = token_embd.cols
    var context_length = 2048
    if seer.config.head_count_kv > 0:
        kv_dim = seer.config.kv_dim()
    if seer.config.context_length > 0:
        context_length = seer.config.context_length
    # Match the engine-wide runtime ceiling (aesir.mojo MAX_RUNTIME_CONTEXT):
    # never size a KV cache from a model's full trained context, which is
    # what made 128K-context models demand multi-GB pools on small hosts.
    if context_length > 16000:
        context_length = 16000

    var initial_offset = well.offset
    try:
        var kv_cache = KVCache(context_length, kv_dim, well, num_layers)
        return forward_pass(
            tokens,
            seer,
            well,
            kv_cache,
            0,
            num_layers,
            head_dim,
            num_heads,
            topology,
            blocks,
            use_npu,
            npu_backend,
            use_gpu_realm,
            gpu_realm,
            temperature,
            top_k,
            top_p,
            repetition_penalty,
        )
    except e:
        well.offset = initial_offset
        raise e



# ---------------------------------------------------------------------------
# Gemma 4 (S-039): dedicated CPU path mirroring the CUDA session's
# semantics (core/gemma4_cuda.mojo) on the generic primitives. The
# generic TransformerBlock cannot express this arch: shared-KV layers,
# dual head dims (512 global / 256 sliding-window), per-layer FFN
# widths, per-layer input embeddings (PLE), a weightless V RMSNorm,
# attention score scale 1.0, and global RoPE that rotates only the
# first 64 NeoX pairs (rope_freqs factors are 1.0 there, ~1e30 after).
# ---------------------------------------------------------------------------

def _gemma4_rope(mut t: RuneTensor[f16], start_pos: Int, head_dim: Int, theta: Scalar[f32], rot_pairs: Int):
    """NeoX half-split RoPE over the first rot_pairs pairs of each head:
    pair (j, j + head_dim//2), frequency ladder over head_dim. Local
    layers pass rot_pairs == head_dim//2 (full rope, theta 1e4);
    global layers pass the count of unit rope_freqs factors (64,
    theta 1e6) and the remaining pairs pass through unrotated,
    exactly as the CUDA rope_kernel's factor division behaves."""
    var half = head_dim // 2
    var heads = t.cols // head_dim
    for h in range(heads):
        for j in range(rot_pairs):
            var freq = 1.0 / (theta ** (Float32(2 * j) / Float32(head_dim)))
            var ang = Float32(start_pos) * freq
            var c = cos(ang)
            var sn = sin(ang)
            var i0 = h * head_dim + j
            var i1 = i0 + half
            var a = t.data.unsafe_load(i0).cast[DType.float32]()
            var b = t.data.unsafe_load(i1).cast[DType.float32]()
            t.data.unsafe_store(i0, Scalar[f16](a * c - b * sn))
            t.data.unsafe_store(i1, Scalar[f16](a * sn + b * c))


def _gemma4_ple(mut seer: GGUFSeer, mut well: MimirWell, token_id: Int, x: RuneTensor[f16]) raises -> RuneTensor[f16]:
    """Per-layer input embedding vector for one token (all layers'
    slices in one [1, layers*ple_dim] tensor), CUDA semantics:
    PLE = (emb[token]*sqrt(ple_dim) + RMSNorm(proj(x))) / sqrt(2),
    the norm grouped per layer slice with per_layer_proj_norm weights.
    (The CUDA norm_kernel's extra 1/sqrt(hidden) input scale cancels
    in the RMS ratio, epsilon aside, so a plain grouped rmsnorm is
    the same function.)"""
    var ple_dim = seer.config.per_layer_input_length
    var layers = seer.config.block_count
    var width = ple_dim * layers
    var emb_ptr = well.allocate(width)
    _embed_token_into(seer, token_id, emb_ptr, "per_layer_token_embd.weight", False)
    var emb = RuneTensor[f16](1, width, emb_ptr, False)
    var emb_scale = Float32(sqrt(Float64(ple_dim)))
    for i in range(width):
        emb.data.unsafe_store(i, Scalar[f16](emb.data.unsafe_load(i).cast[DType.float32]() * emb_scale))
    var tmp_ptr = well.allocate(width)
    var tmp = RuneTensor[f16](1, width, tmp_ptr, False)
    var proj_weight = seer.tensors["per_layer_model_proj.weight"].copy()
    gemm_f16(x, proj_weight, tmp)
    var grouped = RuneTensor[f16](layers, ple_dim, tmp_ptr, False)
    var norm_weight = seer.tensors["per_layer_proj_norm.weight"].copy()
    rmsnorm(grouped, norm_weight, Scalar[f32](seer.config.rms_epsilon))
    var inv_sqrt2 = Float32(1.0) / Float32(sqrt(Float64(2)))
    for i in range(width):
        var v = emb.data.unsafe_load(i).cast[DType.float32]() + tmp.data.unsafe_load(i).cast[DType.float32]()
        emb.data.unsafe_store(i, Scalar[f16](v * inv_sqrt2))
    return emb^


def _gemma4_ple_batched(mut seer: GGUFSeer, mut well: MimirWell, tokens: List[Int], start_pos: Int, batch_len: Int, x: RuneTensor[f16]) raises -> RuneTensor[f16]:
    """Batched twin of _gemma4_ple (S-041): a [batch_len,
    layers*ple_dim] tensor whose row r is exactly
    _gemma4_ple(tokens[start_pos + r], x row r). The per-layer
    embedding lookup and scale are per row; the model projection is
    one multi-row GEMM; the grouped proj-norm views the block as
    [batch_len * layers, ple_dim] rows — the same row-major layout
    the single-token path norms — so each (row, layer) group is
    normed by the identical operation."""
    var ple_dim = seer.config.per_layer_input_length
    var layers = seer.config.block_count
    var width = ple_dim * layers
    var emb_ptr = well.allocate(batch_len * width)
    var emb_scale = Float32(sqrt(Float64(ple_dim)))
    for r in range(batch_len):
        var row_ptr = emb_ptr.unsafe_offset(r * width)
        _embed_token_into(seer, tokens[start_pos + r], row_ptr, "per_layer_token_embd.weight", False)
        for i in range(width):
            row_ptr.unsafe_store(i, Scalar[f16](row_ptr.unsafe_load(i).cast[DType.float32]() * emb_scale))
    var emb = RuneTensor[f16](batch_len, width, emb_ptr, False)
    var tmp_ptr = well.allocate(batch_len * width)
    var tmp = RuneTensor[f16](batch_len, width, tmp_ptr, False)
    var proj_weight = seer.tensors["per_layer_model_proj.weight"].copy()
    gemm_f16(x, proj_weight, tmp)
    var grouped = RuneTensor[f16](batch_len * layers, ple_dim, tmp_ptr, False)
    var norm_weight = seer.tensors["per_layer_proj_norm.weight"].copy()
    rmsnorm(grouped, norm_weight, Scalar[f32](seer.config.rms_epsilon))
    var inv_sqrt2 = Float32(1.0) / Float32(sqrt(Float64(2)))
    for i in range(batch_len * width):
        var v = emb.data.unsafe_load(i).cast[DType.float32]() + tmp.data.unsafe_load(i).cast[DType.float32]()
        emb.data.unsafe_store(i, Scalar[f16](v * inv_sqrt2))
    return emb^


struct Gemma4Block(Copyable):
    """One Gemma 4 layer on the CPU path (see banner above)."""

    var layer_idx: Int
    var is_local: Bool
    var owns_kv: Bool
    var kv_layer: Int
    var head_dim: Int
    var num_heads: Int
    var num_kv_heads: Int
    var rms_epsilon: Scalar[f32]
    var rope_theta: Scalar[f32]
    var rope_rot_pairs: Int
    var sliding_window: Int
    var per_layer_input: Int
    var attn_norm_weight: RuneTensor[f16]
    var attn_q_norm_weight: RuneTensor[f16]
    var attn_k_norm_weight: RuneTensor[f16]
    var post_attn_norm_weight: RuneTensor[f16]
    var post_ffw_norm_weight: RuneTensor[f16]
    var post_norm_weight: RuneTensor[f16]
    var attn_q_weight: RuneTensor[f16]
    var attn_k_weight: RuneTensor[f16]
    var attn_v_weight: RuneTensor[f16]
    var attn_output_weight: RuneTensor[f16]
    var ffn_norm_weight: RuneTensor[f16]
    var ffn_up_weight: RuneTensor[f16]
    var ffn_gate_weight: RuneTensor[f16]
    var ffn_down_weight: RuneTensor[f16]
    var inp_gate_weight: RuneTensor[f16]
    var proj_weight: RuneTensor[f16]
    var layer_output_scale_weight: RuneTensor[f16]

    def __init__(out self, layer_idx: Int, mut seer: GGUFSeer) raises:
        self.layer_idx = layer_idx
        self.is_local = seer.config.gemma4_is_local(layer_idx)
        self.owns_kv = seer.config.gemma4_owns_kv(layer_idx)
        self.kv_layer = seer.config.gemma4_kv_layer(layer_idx)
        self.head_dim = seer.config.gemma4_head_dim(layer_idx)
        self.num_heads = seer.config.head_count
        self.num_kv_heads = seer.config.head_count_kv
        self.rms_epsilon = Scalar[f32](seer.config.rms_epsilon)
        self.per_layer_input = seer.config.per_layer_input_length
        if self.is_local:
            self.rope_theta = Scalar[f32](seer.config.rope_freq_base_swa)
            self.rope_rot_pairs = self.head_dim // 2
            self.sliding_window = seer.config.sliding_window
        else:
            self.rope_theta = Scalar[f32](seer.config.rope_freq_base)
            self.sliding_window = 0
            # Global RoPE rotates only the pairs whose rope_freqs
            # factor is exactly 1 (the rest are ~1e30: no rotation).
            var pairs = 0
            if "rope_freqs.weight" in seer.tensors:
                ref freqs = seer.tensors["rope_freqs.weight"]
                while pairs < freqs.size and freqs.data.unsafe_load(pairs).cast[DType.float32]() == Float32(1.0):
                    pairs += 1
            self.rope_rot_pairs = pairs
        var prefix = String("blk.") + String(layer_idx) + String(".")
        self.attn_norm_weight = _required_block_weight(seer, prefix + "attn_norm.weight")
        self.attn_q_norm_weight = _required_block_weight(seer, prefix + "attn_q_norm.weight")
        self.attn_k_norm_weight = _optional_block_weight(seer, prefix + "attn_k_norm.weight")
        self.post_attn_norm_weight = _required_block_weight(seer, prefix + "post_attention_norm.weight")
        self.post_ffw_norm_weight = _required_block_weight(seer, prefix + "post_ffw_norm.weight")
        self.post_norm_weight = _required_block_weight(seer, prefix + "post_norm.weight")
        self.attn_q_weight = _required_block_weight(seer, prefix + "attn_q.weight")
        self.attn_k_weight = _optional_block_weight(seer, prefix + "attn_k.weight")
        self.attn_v_weight = _optional_block_weight(seer, prefix + "attn_v.weight")
        self.attn_output_weight = _required_block_weight(seer, prefix + "attn_output.weight")
        self.ffn_norm_weight = _required_block_weight(seer, prefix + "ffn_norm.weight")
        self.ffn_up_weight = _required_block_weight(seer, prefix + "ffn_up.weight")
        self.ffn_gate_weight = _required_block_weight(seer, prefix + "ffn_gate.weight")
        self.ffn_down_weight = _required_block_weight(seer, prefix + "ffn_down.weight")
        self.inp_gate_weight = _required_block_weight(seer, prefix + "inp_gate.weight")
        self.proj_weight = _required_block_weight(seer, prefix + "proj.weight")
        self.layer_output_scale_weight = _required_block_weight(seer, prefix + "layer_output_scale.weight")

    def __copyinit__(out self, existing: Self):
        self.layer_idx = existing.layer_idx
        self.is_local = existing.is_local
        self.owns_kv = existing.owns_kv
        self.kv_layer = existing.kv_layer
        self.head_dim = existing.head_dim
        self.num_heads = existing.num_heads
        self.num_kv_heads = existing.num_kv_heads
        self.rms_epsilon = existing.rms_epsilon
        self.rope_theta = existing.rope_theta
        self.rope_rot_pairs = existing.rope_rot_pairs
        self.sliding_window = existing.sliding_window
        self.per_layer_input = existing.per_layer_input
        self.attn_norm_weight = existing.attn_norm_weight
        self.attn_q_norm_weight = existing.attn_q_norm_weight
        self.attn_k_norm_weight = existing.attn_k_norm_weight
        self.post_attn_norm_weight = existing.post_attn_norm_weight
        self.post_ffw_norm_weight = existing.post_ffw_norm_weight
        self.post_norm_weight = existing.post_norm_weight
        self.attn_q_weight = existing.attn_q_weight
        self.attn_k_weight = existing.attn_k_weight
        self.attn_v_weight = existing.attn_v_weight
        self.attn_output_weight = existing.attn_output_weight
        self.ffn_norm_weight = existing.ffn_norm_weight
        self.ffn_up_weight = existing.ffn_up_weight
        self.ffn_gate_weight = existing.ffn_gate_weight
        self.ffn_down_weight = existing.ffn_down_weight
        self.inp_gate_weight = existing.inp_gate_weight
        self.proj_weight = existing.proj_weight
        self.layer_output_scale_weight = existing.layer_output_scale_weight

    def _head_norm(self, mut t: RuneTensor[f16], weight: RuneTensor[f16]) raises:
        """Per-head RMSNorm with a learned weight (Q/K norms)."""
        var heads = t.cols // self.head_dim
        for h in range(heads):
            var head = RuneTensor[f16](1, self.head_dim, t.data.unsafe_offset(h * self.head_dim), False)
            rmsnorm(head, weight, self.rms_epsilon)

    def _head_norm_plain(self, mut t: RuneTensor[f16]):
        """Per-head RMSNorm with NO weight (the V norm, CUDA norm(""))."""
        var heads = t.cols // self.head_dim
        for h in range(heads):
            var base = h * self.head_dim
            var ss: Float32 = 0.0
            for d in range(self.head_dim):
                var v = t.data.unsafe_load(base + d).cast[DType.float32]()
                ss += v * v
            var inv = Float32(1.0) / Float32(sqrt(Float64(ss / Float32(self.head_dim)) + self.rms_epsilon.cast[DType.float64]()))
            for d in range(self.head_dim):
                var v = t.data.unsafe_load(base + d).cast[DType.float32]()
                t.data.unsafe_store(base + d, Scalar[f16](v * inv))

    def forward(
        self,
        mut x: RuneTensor[f16],
        mut seer: GGUFSeer,
        mut well: MimirWell,
        start_pos: Int,
        mut kv_cache: KVCache,
        ple: RuneTensor[f16],
    ) raises:
        """One Gemma 4 layer, single token row, CUDA-session order:
        attn_norm -> Q(+q_norm, rope) -> own K/V(+k_norm, plain v_norm,
        rope, cache under the OWNING layer) or shared KV read ->
        attention (scale 1.0, sliding window on local layers) ->
        output proj -> post_attention_norm -> residual -> ffn_norm ->
        GeGLU FFN -> post_ffw_norm -> residual -> PLE gate
        (inp_gate, gelu, x PLE slice, proj, post_norm) -> residual ->
        layer_output_scale. Local K/V rows are zero-padded to the
        cache width (global head dim); flash attention reads only
        head_dim lanes per row, so the padding is inert."""
        if x.rows != 1:
            raise Error("Gemma4Block.forward: single-row path only")
        var start_offset = well.offset
        var hidden = x.cols
        try:
            var residual_ptr = well.allocate(x.size)
            var residual = RuneTensor[f16](1, hidden, residual_ptr, False)
            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            rmsnorm(x, self.attn_norm_weight, self.rms_epsilon)
            var q_cols = self.attn_q_weight.rows
            var q_ptr = well.allocate(q_cols)
            var q = RuneTensor[f16](1, q_cols, q_ptr, False)
            gemm_f16(x, self.attn_q_weight, q)
            self._head_norm(q, self.attn_q_norm_weight)
            if self.owns_kv:
                var kv_cols = self.attn_k_weight.rows
                var k_ptr = well.allocate(kv_cols)
                var k = RuneTensor[f16](1, kv_cols, k_ptr, False)
                gemm_f16(x, self.attn_k_weight, k)
                var v_ptr = well.allocate(kv_cols)
                var v = RuneTensor[f16](1, kv_cols, v_ptr, False)
                gemm_f16(x, self.attn_v_weight, v)
                self._head_norm(k, self.attn_k_norm_weight)
                self._head_norm_plain(v)
                _gemma4_rope(k, start_pos, self.head_dim, self.rope_theta, self.rope_rot_pairs)
                _gemma4_rope(q, start_pos, self.head_dim, self.rope_theta, self.rope_rot_pairs)
                var cache_width = kv_cache.hidden_dim
                var kpad_ptr = well.allocate(cache_width)
                var kpad = RuneTensor[f16](1, cache_width, kpad_ptr, False)
                var vpad_ptr = well.allocate(cache_width)
                var vpad = RuneTensor[f16](1, cache_width, vpad_ptr, False)
                for i in range(cache_width):
                    kpad.data.unsafe_store(i, Scalar[f16](0.0))
                    vpad.data.unsafe_store(i, Scalar[f16](0.0))
                for i in range(kv_cols):
                    kpad.data.unsafe_store(i, k.data.unsafe_load(i))
                    vpad.data.unsafe_store(i, v.data.unsafe_load(i))
                kv_cache.append(self.kv_layer, start_pos, kpad, vpad)
            else:
                _gemma4_rope(q, start_pos, self.head_dim, self.rope_theta, self.rope_rot_pairs)
            var active = min(start_pos + 1, kv_cache.max_seq_len)
            var k_slice = kv_cache.get_k_slice(self.kv_layer, active)
            var v_slice = kv_cache.get_v_slice(self.kv_layer, active)
            var attn_ptr = well.allocate(q_cols)
            var attn_out = RuneTensor[f16](1, q_cols, attn_ptr, False)
            flash_attention_gqa(
                q, k_slice, v_slice, attn_out, active, self.head_dim,
                self.num_heads, self.num_kv_heads,
                Scalar[f32](1.0), Scalar[f32](0.0), self.sliding_window, start_pos,
            )
            gemm_f16(attn_out, self.attn_output_weight, x)
            rmsnorm(x, self.post_attn_norm_weight, self.rms_epsilon)
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))
            # FFN (GeGLU) with post-norm, CUDA order.
            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            rmsnorm(x, self.ffn_norm_weight, self.rms_epsilon)
            var up_cols = self.ffn_up_weight.rows
            var up_ptr = well.allocate(up_cols)
            var up = RuneTensor[f16](1, up_cols, up_ptr, False)
            gemm_f16(x, self.ffn_up_weight, up)
            var gate_ptr = well.allocate(up_cols)
            var gate = RuneTensor[f16](1, up_cols, gate_ptr, False)
            gemm_f16(x, self.ffn_gate_weight, gate)
            gelu_tanh(gate)
            for i in range(up.size):
                up.data.unsafe_store(i, up.data.unsafe_load(i) * gate.data.unsafe_load(i))
            gemm_f16(up, self.ffn_down_weight, x)
            rmsnorm(x, self.post_ffw_norm_weight, self.rms_epsilon)
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))
            # Per-layer input branch: gelu(inp_gate . x) * PLE slice,
            # projected back, post-normed, added, then output scale.
            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            var ple_dim = self.per_layer_input
            var g_ptr = well.allocate(ple_dim)
            var g = RuneTensor[f16](1, ple_dim, g_ptr, False)
            gemm_f16(x, self.inp_gate_weight, g)
            gelu_tanh(g)
            var ple_base = self.layer_idx * ple_dim
            for i in range(ple_dim):
                var gv = g.data.unsafe_load(i).cast[DType.float32]() * ple.data.unsafe_load(ple_base + i).cast[DType.float32]()
                g.data.unsafe_store(i, Scalar[f16](gv))
            gemm_f16(g, self.proj_weight, x)
            rmsnorm(x, self.post_norm_weight, self.rms_epsilon)
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))
            var out_scale = self.layer_output_scale_weight.data.unsafe_load(0).cast[DType.float32]()
            for i in range(x.size):
                x.data.unsafe_store(i, Scalar[f16](x.data.unsafe_load(i).cast[DType.float32]() * out_scale))
            well.reset_kv_cache(start_offset)
        except e:
            well.reset_kv_cache(start_offset)
            raise e

    def forward_batched(
        self,
        mut x: RuneTensor[f16],
        mut seer: GGUFSeer,
        mut well: MimirWell,
        start_pos: Int,
        mut kv_cache: KVCache,
        ple: RuneTensor[f16],
    ) raises:
        """Batched twin of forward() for a block of x.rows consecutive
        positions starting at start_pos (prefill), S-041.

        Mirrors TransformerBlock.forward_batched's discipline: the
        stage bodies are row-generic (norms, GEMMs, residual adds run
        over x.rows / x.size, so each weight block is decoded once per
        chunk instead of once per token), with exactly these deltas
        vs forward(): (1) the per-head Q/K norms and the plain V norm
        run per row through the same single-row helpers on row views;
        (2) RoPE runs per row with that row's own position; (3) the KV
        append is KVCache.append_block of the zero-padded rows under
        the OWNING layer; (4) attention runs the existing
        flash_attention_gqa once per row with that row's own causal
        bound and query_pos, over one slice for the whole span — so
        per-row numerics match the per-token path operation for
        operation. The PLE branch reads each row's own PLE slice from
        the batched ple tensor ([x.rows, layers * ple_dim])."""
        if x.rows <= 0:
            raise Error("Gemma4Block.forward_batched: batch must have at least one row")
        if start_pos < 0 or start_pos + x.rows > kv_cache.max_seq_len:
            raise Error("Gemma4Block.forward_batched: batch exceeds KV cache capacity")
        var start_offset = well.offset
        var hidden = x.cols
        var batch = x.rows
        try:
            var residual_ptr = well.allocate(x.size)
            var residual = RuneTensor[f16](batch, hidden, residual_ptr, False)
            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            rmsnorm(x, self.attn_norm_weight, self.rms_epsilon)
            var q_cols = self.attn_q_weight.rows
            var q_ptr = well.allocate(batch * q_cols)
            var q = RuneTensor[f16](batch, q_cols, q_ptr, False)
            gemm_f16(x, self.attn_q_weight, q)
            for r in range(batch):
                var q_row = RuneTensor[f16](1, q_cols, q_ptr.unsafe_offset(r * q_cols), False)
                self._head_norm(q_row, self.attn_q_norm_weight)
            if self.owns_kv:
                var kv_cols = self.attn_k_weight.rows
                var k_ptr = well.allocate(batch * kv_cols)
                var k = RuneTensor[f16](batch, kv_cols, k_ptr, False)
                gemm_f16(x, self.attn_k_weight, k)
                var v_ptr = well.allocate(batch * kv_cols)
                var v = RuneTensor[f16](batch, kv_cols, v_ptr, False)
                gemm_f16(x, self.attn_v_weight, v)
                for r in range(batch):
                    var k_row = RuneTensor[f16](1, kv_cols, k_ptr.unsafe_offset(r * kv_cols), False)
                    self._head_norm(k_row, self.attn_k_norm_weight)
                    var v_row = RuneTensor[f16](1, kv_cols, v_ptr.unsafe_offset(r * kv_cols), False)
                    self._head_norm_plain(v_row)
                    _gemma4_rope(k_row, start_pos + r, self.head_dim, self.rope_theta, self.rope_rot_pairs)
                    var q_row2 = RuneTensor[f16](1, q_cols, q_ptr.unsafe_offset(r * q_cols), False)
                    _gemma4_rope(q_row2, start_pos + r, self.head_dim, self.rope_theta, self.rope_rot_pairs)
                var cache_width = kv_cache.hidden_dim
                var kpad_ptr = well.allocate(batch * cache_width)
                var kpad = RuneTensor[f16](batch, cache_width, kpad_ptr, False)
                var vpad_ptr = well.allocate(batch * cache_width)
                var vpad = RuneTensor[f16](batch, cache_width, vpad_ptr, False)
                for i in range(batch * cache_width):
                    kpad.data.unsafe_store(i, Scalar[f16](0.0))
                    vpad.data.unsafe_store(i, Scalar[f16](0.0))
                for r in range(batch):
                    for i in range(kv_cols):
                        kpad.data.unsafe_store(r * cache_width + i, k.data.unsafe_load(r * kv_cols + i))
                        vpad.data.unsafe_store(r * cache_width + i, v.data.unsafe_load(r * kv_cols + i))
                kv_cache.append_block(self.kv_layer, start_pos, kpad, vpad, batch)
            else:
                for r in range(batch):
                    var q_row = RuneTensor[f16](1, q_cols, q_ptr.unsafe_offset(r * q_cols), False)
                    _gemma4_rope(q_row, start_pos + r, self.head_dim, self.rope_theta, self.rope_rot_pairs)
            var total = min(start_pos + batch, kv_cache.max_seq_len)
            var k_slice = kv_cache.get_k_slice(self.kv_layer, total)
            var v_slice = kv_cache.get_v_slice(self.kv_layer, total)
            var attn_ptr = well.allocate(batch * q_cols)
            var attn_out = RuneTensor[f16](batch, q_cols, attn_ptr, False)
            for r in range(batch):
                var q_row = RuneTensor[f16](1, q_cols, q_ptr.unsafe_offset(r * q_cols), False)
                var o_row = RuneTensor[f16](1, q_cols, attn_ptr.unsafe_offset(r * q_cols), False)
                flash_attention_gqa(
                    q_row, k_slice, v_slice, o_row,
                    min(start_pos + r + 1, kv_cache.max_seq_len),
                    self.head_dim,
                    self.num_heads, self.num_kv_heads,
                    Scalar[f32](1.0), Scalar[f32](0.0), self.sliding_window, start_pos + r,
                )
            gemm_f16(attn_out, self.attn_output_weight, x)
            rmsnorm(x, self.post_attn_norm_weight, self.rms_epsilon)
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))
            # FFN (GeGLU) with post-norm, CUDA order.
            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            rmsnorm(x, self.ffn_norm_weight, self.rms_epsilon)
            var up_cols = self.ffn_up_weight.rows
            var up_ptr = well.allocate(batch * up_cols)
            var up = RuneTensor[f16](batch, up_cols, up_ptr, False)
            gemm_f16(x, self.ffn_up_weight, up)
            var gate_ptr = well.allocate(batch * up_cols)
            var gate = RuneTensor[f16](batch, up_cols, gate_ptr, False)
            gemm_f16(x, self.ffn_gate_weight, gate)
            gelu_tanh(gate)
            for i in range(up.size):
                up.data.unsafe_store(i, up.data.unsafe_load(i) * gate.data.unsafe_load(i))
            gemm_f16(up, self.ffn_down_weight, x)
            rmsnorm(x, self.post_ffw_norm_weight, self.rms_epsilon)
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))
            # Per-layer input branch per row: gelu(inp_gate . x) * the
            # row's own PLE slice, projected back, post-normed, added,
            # then output scale.
            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            var ple_dim = self.per_layer_input
            var g_ptr = well.allocate(batch * ple_dim)
            var g = RuneTensor[f16](batch, ple_dim, g_ptr, False)
            gemm_f16(x, self.inp_gate_weight, g)
            gelu_tanh(g)
            var ple_base = self.layer_idx * ple_dim
            var ple_width = ple.cols
            for r in range(batch):
                for i in range(ple_dim):
                    var gv = g.data.unsafe_load(r * ple_dim + i).cast[DType.float32]() * ple.data.unsafe_load(r * ple_width + ple_base + i).cast[DType.float32]()
                    g.data.unsafe_store(r * ple_dim + i, Scalar[f16](gv))
            gemm_f16(g, self.proj_weight, x)
            rmsnorm(x, self.post_norm_weight, self.rms_epsilon)
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))
            var out_scale = self.layer_output_scale_weight.data.unsafe_load(0).cast[DType.float32]()
            for i in range(x.size):
                x.data.unsafe_store(i, Scalar[f16](x.data.unsafe_load(i).cast[DType.float32]() * out_scale))
            well.reset_kv_cache(start_offset)
        except e:
            well.reset_kv_cache(start_offset)
            raise e




def forward_pass_gemma4(
    tokens: List[Int],
    mut seer: GGUFSeer,
    mut well: MimirWell,
    mut kv_cache: KVCache,
    mut blocks: List[Gemma4Block],
    start_pos: Int = 0,
    temperature: Scalar[f32] = 0.0,
    top_k: Int = 40,
    top_p: Scalar[f32] = 0.9,
    repetition_penalty: Scalar[f32] = 1.1,
    is_prefill: Bool = False,
) raises -> Int:
    """Full Gemma 4 forward for one position: token embedding (with
    the Gemma sqrt(hidden) scale via _embed_token), the PLE vector,
    every Gemma4Block, then forward_pass's output stage (final norm,
    tied LM head, logit scale, final-logit softcapping, sampling)."""
    if len(tokens) == 0:
        raise Error("forward_pass_gemma4: tokens list cannot be empty")
    if len(blocks) < seer.config.block_count:
        raise Error("forward_pass_gemma4: Gemma4Block list is incomplete")
    var initial_offset = well.offset
    var token_idx = min(max(0, start_pos), len(tokens) - 1)
    var last_token = tokens[token_idx]
    var x = _embed_token(seer, well, last_token)
    var vocab_dim = seer.tensors["token_embd.weight"].rows
    try:
        var ple = _gemma4_ple(seer, well, last_token, x)
        for l in range(seer.config.block_count):
            blocks[l].forward(x, seer, well, start_pos, kv_cache, ple)
        if is_prefill:
            well.offset = initial_offset
            return 0
        if "output_norm.weight" not in seer.tensors:
            raise Error("Inference requires output_norm.weight")
        ref output_norm = seer.tensors["output_norm.weight"]
        rmsnorm(x, output_norm, Scalar[f32](seer.config.rms_epsilon))
        if "output.weight" not in seer.tensors:
            raise Error("Inference requires output.weight")
        ref output_weight = seer.tensors["output.weight"]
        var logits_ptr = well.allocate(vocab_dim)
        var logits = RuneTensor[f16](1, vocab_dim, logits_ptr, False)
        gemm_f16(x, output_weight, logits)
        if seer.config.logit_scale != Float32(0.0):
            var inv_logit_scale = Float32(1.0) / seer.config.logit_scale
            for i in range(vocab_dim):
                logits.data.unsafe_store(i, Scalar[f16](logits.data.unsafe_load(i).cast[DType.float32]() * inv_logit_scale))
        if seer.config.final_logit_softcapping != Float32(0.0):
            var cap = seer.config.final_logit_softcapping
            for i in range(vocab_dim):
                var v = logits.data.unsafe_load(i).cast[DType.float32]()
                logits.data.unsafe_store(i, Scalar[f16](cap * tanh(v / cap)))
        var rng = RuneRNG(42)
        var suppress_list = List[Int]()
        var next_token = sample_token_from_logits(
            logits.data, vocab_dim,
            temperature=temperature, top_k=top_k, top_p=top_p,
            repetition_penalty=repetition_penalty,
            context_tokens=tokens, rng=rng, suppress_tokens=suppress_list,
        )
        well.offset = initial_offset
        return next_token
    except e:
        well.offset = initial_offset
        raise e^


def forward_pass_gemma4_batched(
    tokens: List[Int],
    mut seer: GGUFSeer,
    mut well: MimirWell,
    mut kv_cache: KVCache,
    mut blocks: List[Gemma4Block],
    start_pos: Int,
    batch_len: Int,
    is_prefill: Bool = True,
    temperature: Scalar[f32] = 0.0,
    top_k: Int = 40,
    top_p: Scalar[f32] = 0.9,
    repetition_penalty: Scalar[f32] = 1.1,
) raises -> Int:
    """Batched twin of forward_pass_gemma4 for one prefill chunk of
    batch_len tokens at start_pos (S-041), mirroring
    forward_pass_qwen35_batched's contract: a pure-prefill chunk
    (is_prefill) fills the KV cache and returns 0 without paying the
    LM head; a non-prefill chunk runs forward_pass_gemma4's output
    stage (final norm, tied head, logit scale, final-logit
    softcapping, sampling) on the last row only."""
    if len(tokens) == 0:
        raise Error("forward_pass_gemma4_batched: tokens list cannot be empty")
    if len(blocks) < seer.config.block_count:
        raise Error("forward_pass_gemma4_batched: Gemma4Block list is incomplete")
    if batch_len <= 0 or start_pos < 0 or start_pos + batch_len > len(tokens):
        raise Error("forward_pass_gemma4_batched: chunk range outside the token list")
    if start_pos + batch_len > kv_cache.max_seq_len:
        raise Error("forward_pass_gemma4_batched: chunk exceeds KV cache capacity")
    var initial_offset = well.offset
    var x = _embed_tokens(seer, well, tokens, start_pos, batch_len)
    var vocab_dim = seer.tensors["token_embd.weight"].rows
    try:
        var ple = _gemma4_ple_batched(seer, well, tokens, start_pos, batch_len, x)
        for l in range(seer.config.block_count):
            blocks[l].forward_batched(x, seer, well, start_pos, kv_cache, ple)
        if is_prefill:
            well.offset = initial_offset
            return 0
        var x_last = RuneTensor[f16](
            1, x.cols, x.data.unsafe_offset((batch_len - 1) * x.cols), False
        )
        if "output_norm.weight" not in seer.tensors:
            raise Error("Inference requires output_norm.weight")
        ref output_norm = seer.tensors["output_norm.weight"]
        rmsnorm(x_last, output_norm, Scalar[f32](seer.config.rms_epsilon))
        if "output.weight" not in seer.tensors:
            raise Error("Inference requires output.weight")
        ref output_weight = seer.tensors["output.weight"]
        var logits_ptr = well.allocate(vocab_dim)
        var logits = RuneTensor[f16](1, vocab_dim, logits_ptr, False)
        gemm_f16(x_last, output_weight, logits)
        if seer.config.logit_scale != Float32(0.0):
            var inv_logit_scale = Float32(1.0) / seer.config.logit_scale
            for i in range(vocab_dim):
                logits.data.unsafe_store(i, Scalar[f16](logits.data.unsafe_load(i).cast[DType.float32]() * inv_logit_scale))
        if seer.config.final_logit_softcapping != Float32(0.0):
            var cap = seer.config.final_logit_softcapping
            for i in range(vocab_dim):
                var v = logits.data.unsafe_load(i).cast[DType.float32]()
                logits.data.unsafe_store(i, Scalar[f16](cap * tanh(v / cap)))
        var rng = RuneRNG(42)
        var suppress_list = List[Int]()
        var next_token = sample_token_from_logits(
            logits.data, vocab_dim,
            temperature=temperature, top_k=top_k, top_p=top_p,
            repetition_penalty=repetition_penalty,
            context_tokens=tokens, rng=rng, suppress_tokens=suppress_list,
        )
        well.offset = initial_offset
        return next_token
    except e:
        well.offset = initial_offset
        raise e^

# ---------------------------------------------------------------------------
# Qwen3.5 hybrid architecture: Gated DeltaNet SSM layers interleaved with
# gated full-attention layers. Implemented from llama.cpp's qwen35 graph
# (see docs): every full_attention_interval-th layer (1-based) attends;
# the rest run the delta-rule recurrence. Both layer types use
# post_attention_norm.weight as the pre-FFN norm and a SwiGLU FFN.
# ---------------------------------------------------------------------------

def _sigmoid_f32(x: Float32) -> Float32:
    return Float32(1.0) / (Float32(1.0) + exp(-x))


def _softplus_f32(x: Float32) -> Float32:
    if x > Float32(20.0):
        return x
    return log(Float32(1.0) + exp(x))


struct Qwen35State(Movable):
    """Persistent per-generation SSM state, heap-held in f32: the
    [d_state x d_state] recurrence matrix per SSM layer/head and the
    causal-conv input ring (kernel-1 previous qkv vectors per layer)."""

    var ssm_layer_count: Int
    var head_count: Int
    var d_state: Int
    var conv_dim: Int
    var conv_kernel: Int
    var s_data: Pointer[Scalar[f32], MutUntrackedOrigin]
    var conv_data: Pointer[Scalar[f32], MutUntrackedOrigin]
    var scratch: Pointer[Scalar[f32], MutUntrackedOrigin]

    def __init__(
        out self,
        ssm_layer_count: Int,
        head_count: Int,
        d_state: Int,
        conv_dim: Int,
        conv_kernel: Int,
    ):
        self.ssm_layer_count = ssm_layer_count
        self.head_count = head_count
        self.d_state = d_state
        self.conv_dim = conv_dim
        self.conv_kernel = conv_kernel
        var s_count = ssm_layer_count * head_count * d_state * d_state
        var c_count = ssm_layer_count * max(0, conv_kernel - 1) * conv_dim
        if s_count <= 0:
            s_count = 1
        if c_count <= 0:
            c_count = 1
        self.s_data = alloc(Layout[Scalar[f32]](count=s_count)).unsafe_leak()
        self.conv_data = alloc(Layout[Scalar[f32]](count=c_count)).unsafe_leak()
        self.scratch = alloc(Layout[Scalar[f32]](count=max(1, 2 * d_state))).unsafe_leak()
        self.reset()

    def reset(mut self):
        var s_count = self.ssm_layer_count * self.head_count * self.d_state * self.d_state
        for i in range(max(0, s_count)):
            self.s_data.unsafe_store(i, Scalar[f32](0.0))
        var c_count = self.ssm_layer_count * max(0, self.conv_kernel - 1) * self.conv_dim
        for i in range(max(0, c_count)):
            self.conv_data.unsafe_store(i, Scalar[f32](0.0))

    def __del__(deinit self):
        self.s_data.free()
        self.conv_data.free()
        self.scratch.free()


struct Qwen35Block(Copyable):
    """One Qwen3.5 layer: either gated full attention or Gated DeltaNet."""

    var layer_idx: Int
    var is_full_attn: Bool
    var ssm_slot: Int
    var head_dim: Int
    var num_heads: Int
    var num_kv_heads: Int
    var rms_epsilon: Scalar[f32]
    var rope_theta: Scalar[f32]
    var rope_dims: Int
    var attn_norm_weight: RuneTensor[f16]
    var post_attn_norm_weight: RuneTensor[f16]
    var ffn_gate_weight: RuneTensor[f16]
    var ffn_up_weight: RuneTensor[f16]
    var ffn_down_weight: RuneTensor[f16]
    var q_weight: RuneTensor[f16]
    var k_weight: RuneTensor[f16]
    var v_weight: RuneTensor[f16]
    var o_weight: RuneTensor[f16]
    var q_norm_weight: RuneTensor[f16]
    var k_norm_weight: RuneTensor[f16]
    var qkv_weight: RuneTensor[f16]
    var gate_weight: RuneTensor[f16]
    var alpha_weight: RuneTensor[f16]
    var beta_weight: RuneTensor[f16]
    var ssm_a: RuneTensor[f16]
    var dt_bias: RuneTensor[f16]
    var conv1d_weight: RuneTensor[f16]
    var ssm_norm_weight: RuneTensor[f16]
    var ssm_out_weight: RuneTensor[f16]

    def __init__(
        out self,
        layer_idx: Int,
        head_dim: Int,
        num_heads: Int,
        mut seer: GGUFSeer,
    ) raises:
        self.layer_idx = layer_idx
        self.head_dim = head_dim
        self.num_heads = num_heads
        self.num_kv_heads = seer.config.head_count_kv
        self.rope_dims = seer.config.rope_dimension_count
        if self.rope_dims <= 0:
            self.rope_dims = head_dim
        var cfg_theta = seer.config.rope_freq_base
        self.rope_theta = Scalar[f32](cfg_theta) if cfg_theta != Float32(0.0) else Scalar[f32](10000.0)
        self.rms_epsilon = Scalar[f32](seer.config.rms_epsilon)
        var interval = seer.config.full_attention_interval
        if interval <= 0:
            interval = 4
        self.is_full_attn = (layer_idx + 1) % interval == 0
        self.ssm_slot = layer_idx - (layer_idx + 1) // interval
        var prefix = String("blk.") + String(layer_idx) + String(".")
        self.attn_norm_weight = _required_block_weight(seer, prefix + "attn_norm.weight")
        self.post_attn_norm_weight = _required_block_weight(seer, prefix + "post_attention_norm.weight")
        self.ffn_gate_weight = _required_block_weight(seer, prefix + "ffn_gate.weight")
        self.ffn_up_weight = _required_block_weight(seer, prefix + "ffn_up.weight")
        self.ffn_down_weight = _required_block_weight(seer, prefix + "ffn_down.weight")
        if self.is_full_attn:
            self.q_weight = _required_block_weight(seer, prefix + "attn_q.weight")
            self.k_weight = _required_block_weight(seer, prefix + "attn_k.weight")
            self.v_weight = _required_block_weight(seer, prefix + "attn_v.weight")
            self.o_weight = _required_block_weight(seer, prefix + "attn_output.weight")
            self.q_norm_weight = _required_block_weight(seer, prefix + "attn_q_norm.weight")
            self.k_norm_weight = _required_block_weight(seer, prefix + "attn_k_norm.weight")
            self.qkv_weight = _optional_block_weight(seer, prefix + "attn_qkv.weight")
            self.gate_weight = _optional_block_weight(seer, prefix + "attn_gate.weight")
            self.alpha_weight = _optional_block_weight(seer, prefix + "ssm_alpha.weight")
            self.beta_weight = _optional_block_weight(seer, prefix + "ssm_beta.weight")
            self.ssm_a = _optional_block_weight(seer, prefix + "ssm_a")
            self.dt_bias = _optional_block_weight(seer, prefix + "ssm_dt.bias")
            self.conv1d_weight = _optional_block_weight(seer, prefix + "ssm_conv1d.weight")
            self.ssm_norm_weight = _optional_block_weight(seer, prefix + "ssm_norm.weight")
            self.ssm_out_weight = _optional_block_weight(seer, prefix + "ssm_out.weight")
        else:
            self.q_weight = _optional_block_weight(seer, prefix + "attn_q.weight")
            self.k_weight = _optional_block_weight(seer, prefix + "attn_k.weight")
            self.v_weight = _optional_block_weight(seer, prefix + "attn_v.weight")
            self.o_weight = _optional_block_weight(seer, prefix + "attn_output.weight")
            self.q_norm_weight = _optional_block_weight(seer, prefix + "attn_q_norm.weight")
            self.k_norm_weight = _optional_block_weight(seer, prefix + "attn_k_norm.weight")
            self.qkv_weight = _required_block_weight(seer, prefix + "attn_qkv.weight")
            self.gate_weight = _required_block_weight(seer, prefix + "attn_gate.weight")
            self.alpha_weight = _required_block_weight(seer, prefix + "ssm_alpha.weight")
            self.beta_weight = _required_block_weight(seer, prefix + "ssm_beta.weight")
            self.ssm_a = _required_block_weight(seer, prefix + "ssm_a")
            self.dt_bias = _required_block_weight(seer, prefix + "ssm_dt.bias")
            self.conv1d_weight = _required_block_weight(seer, prefix + "ssm_conv1d.weight")
            self.ssm_norm_weight = _required_block_weight(seer, prefix + "ssm_norm.weight")
            self.ssm_out_weight = _required_block_weight(seer, prefix + "ssm_out.weight")

    def __copyinit__(out self, existing: Self):
        self.layer_idx = existing.layer_idx
        self.is_full_attn = existing.is_full_attn
        self.ssm_slot = existing.ssm_slot
        self.head_dim = existing.head_dim
        self.num_heads = existing.num_heads
        self.num_kv_heads = existing.num_kv_heads
        self.rms_epsilon = existing.rms_epsilon
        self.rope_theta = existing.rope_theta
        self.rope_dims = existing.rope_dims
        self.attn_norm_weight = existing.attn_norm_weight
        self.post_attn_norm_weight = existing.post_attn_norm_weight
        self.ffn_gate_weight = existing.ffn_gate_weight
        self.ffn_up_weight = existing.ffn_up_weight
        self.ffn_down_weight = existing.ffn_down_weight
        self.q_weight = existing.q_weight
        self.k_weight = existing.k_weight
        self.v_weight = existing.v_weight
        self.o_weight = existing.o_weight
        self.q_norm_weight = existing.q_norm_weight
        self.k_norm_weight = existing.k_norm_weight
        self.qkv_weight = existing.qkv_weight
        self.gate_weight = existing.gate_weight
        self.alpha_weight = existing.alpha_weight
        self.beta_weight = existing.beta_weight
        self.ssm_a = existing.ssm_a
        self.dt_bias = existing.dt_bias
        self.conv1d_weight = existing.conv1d_weight
        self.ssm_norm_weight = existing.ssm_norm_weight
        self.ssm_out_weight = existing.ssm_out_weight

    def _head_rmsnorm(
        self,
        mut vec: RuneTensor[f16],
        head_start: Int,
        weight: RuneTensor[f16],
    ):
        var mean: Float32 = 0.0
        for d in range(self.head_dim):
            var val = vec.data.unsafe_load(head_start + d).cast[DType.float32]()
            mean += val * val
        var scale = Float32(1.0) / sqrt(mean / Float32(self.head_dim) + self.rms_epsilon.cast[DType.float32]())
        for d in range(self.head_dim):
            var val = vec.data.unsafe_load(head_start + d).cast[DType.float32]()
            var w = weight.data.unsafe_load(d).cast[DType.float32]()
            vec.data.unsafe_store(head_start + d, Scalar[f16](val * scale * w))

    def forward(
        self,
        mut x: RuneTensor[f16],
        mut seer: GGUFSeer,
        mut well: MimirWell,
        start_pos: Int,
        mut kv_cache: KVCache,
        mut state: Qwen35State,
    ) raises:
        var start_offset = well.offset
        var hidden = x.cols
        try:
            var residual_ptr = well.allocate(x.size)
            var residual = RuneTensor[f16](1, hidden, residual_ptr, False)
            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            rmsnorm(x, self.attn_norm_weight)

            if self.is_full_attn:
                var q_width = self.num_heads * self.head_dim
                var kv_width = self.num_kv_heads * self.head_dim
                var q_full_ptr = well.allocate(2 * q_width)
                var q_full = RuneTensor[f16](1, 2 * q_width, q_full_ptr, False)
                gemm_f16(x, self.q_weight, q_full)
                var q_ptr = well.allocate(q_width)
                var q = RuneTensor[f16](1, q_width, q_ptr, False)
                var gate_ptr = well.allocate(q_width)
                var gate = RuneTensor[f16](1, q_width, gate_ptr, False)
                for h in range(self.num_heads):
                    var src = h * 2 * self.head_dim
                    var dst = h * self.head_dim
                    for d in range(self.head_dim):
                        q.data.unsafe_store(dst + d, q_full.data.unsafe_load(src + d))
                        gate.data.unsafe_store(dst + d, q_full.data.unsafe_load(src + self.head_dim + d))
                var k_ptr = well.allocate(kv_width)
                var k = RuneTensor[f16](1, kv_width, k_ptr, False)
                gemm_f16(x, self.k_weight, k)
                var v_ptr = well.allocate(kv_width)
                var v = RuneTensor[f16](1, kv_width, v_ptr, False)
                gemm_f16(x, self.v_weight, v)
                for h in range(self.num_heads):
                    self._head_rmsnorm(q, h * self.head_dim, self.q_norm_weight)
                for h in range(self.num_kv_heads):
                    self._head_rmsnorm(k, h * self.head_dim, self.k_norm_weight)
                apply_rope_partial_neox(q, k, start_pos, self.head_dim, self.rope_dims, self.rope_theta)
                kv_cache.append(self.layer_idx, start_pos, k, v)
                var active_seq_len = min(start_pos + 1, kv_cache.max_seq_len)
                var k_slice = kv_cache.get_k_slice(self.layer_idx, active_seq_len)
                var v_slice = kv_cache.get_v_slice(self.layer_idx, active_seq_len)
                var attn_ptr = well.allocate(q_width)
                var attn_out = RuneTensor[f16](1, q_width, attn_ptr, False)
                flash_attention_gqa(
                    q,
                    k_slice,
                    v_slice,
                    attn_out,
                    active_seq_len,
                    self.head_dim,
                    self.num_heads,
                    self.num_kv_heads,
                )
                for i in range(q_width):
                    var a = attn_out.data.unsafe_load(i).cast[DType.float32]()
                    var g = gate.data.unsafe_load(i).cast[DType.float32]()
                    attn_out.data.unsafe_store(i, Scalar[f16](a * _sigmoid_f32(g)))
                gemm_f16(attn_out, self.o_weight, x)
            else:
                var inner = self.gate_weight.rows
                var conv_dim = 3 * inner
                var n_heads = state.head_count
                var d_state = state.d_state
                var qkv_ptr = well.allocate(conv_dim)
                var qkv = RuneTensor[f16](1, conv_dim, qkv_ptr, False)
                gemm_f16(x, self.qkv_weight, qkv)
                var z_ptr = well.allocate(inner)
                var z = RuneTensor[f16](1, inner, z_ptr, False)
                gemm_f16(x, self.gate_weight, z)
                var dt_rank = self.alpha_weight.rows
                var alpha_ptr = well.allocate(dt_rank)
                var alpha = RuneTensor[f16](1, dt_rank, alpha_ptr, False)
                gemm_f16(x, self.alpha_weight, alpha)
                var beta_ptr = well.allocate(dt_rank)
                var beta_raw = RuneTensor[f16](1, dt_rank, beta_ptr, False)
                gemm_f16(x, self.beta_weight, beta_raw)

                # Causal depthwise conv1d (kernel from weights, ring state
                # holds the previous kernel-1 raw qkv vectors).
                var kernel = state.conv_kernel
                var ring = state.conv_data.unsafe_offset(
                    self.ssm_slot * max(0, kernel - 1) * conv_dim
                )
                var conv_ptr = well.allocate(conv_dim)
                var conv_out = RuneTensor[f16](1, conv_dim, conv_ptr, False)
                for c in range(conv_dim):
                    var acc: Float32 = 0.0
                    for tap in range(kernel):
                        var kval = self.conv1d_weight.data.unsafe_load(c * kernel + tap).cast[DType.float32]()
                        var sample: Float32
                        if tap < kernel - 1:
                            sample = ring.unsafe_load(tap * conv_dim + c).cast[DType.float32]()
                        else:
                            sample = qkv.data.unsafe_load(c).cast[DType.float32]()
                        acc += kval * sample
                    conv_out.data.unsafe_store(c, Scalar[f16](acc))
                if kernel > 1:
                    for tap in range(kernel - 2):
                        for c in range(conv_dim):
                            ring.unsafe_store(
                                tap * conv_dim + c,
                                ring.unsafe_load((tap + 1) * conv_dim + c),
                            )
                    for c in range(conv_dim):
                        ring.unsafe_store(
                            (kernel - 2) * conv_dim + c,
                            Scalar[f32](qkv.data.unsafe_load(c).cast[DType.float32]()),
                        )
                silu(conv_out)

                # Delta-rule recurrence per head over the f32 state matrix.
                var y_ptr = well.allocate(inner)
                var y = RuneTensor[f16](1, inner, y_ptr, False)
                var s_base = state.s_data.unsafe_offset(
                    self.ssm_slot * n_heads * d_state * d_state
                )
                for h in range(n_heads):
                    var q_off = h * d_state
                    var k_off = inner + h * d_state
                    var v_off = 2 * inner + h * d_state
                    # L2-normalize q and k in place (llama.cpp gated delta
                    # net normalizes with eps inside the square root).
                    var q_norm: Float32 = 0.0
                    var k_norm: Float32 = 0.0
                    for d in range(d_state):
                        var qv = conv_out.data.unsafe_load(q_off + d).cast[DType.float32]()
                        var kv = conv_out.data.unsafe_load(k_off + d).cast[DType.float32]()
                        q_norm += qv * qv
                        k_norm += kv * kv
                    var q_scale = Float32(1.0) / sqrt(q_norm + Float32(1e-6))
                    var k_scale = Float32(1.0) / sqrt(k_norm + Float32(1e-6))
                    for d in range(d_state):
                        conv_out.data.unsafe_store(q_off + d, Scalar[f16](conv_out.data.unsafe_load(q_off + d).cast[DType.float32]() * q_scale))
                        conv_out.data.unsafe_store(k_off + d, Scalar[f16](conv_out.data.unsafe_load(k_off + d).cast[DType.float32]() * k_scale))
                    var a_val = self.ssm_a.data.unsafe_load(h).cast[DType.float32]()
                    var dt = _softplus_f32(
                        alpha.data.unsafe_load(h).cast[DType.float32]()
                        + self.dt_bias.data.unsafe_load(h).cast[DType.float32]()
                    )
                    var decay = exp(a_val * dt)
                    var beta = _sigmoid_f32(beta_raw.data.unsafe_load(h).cast[DType.float32]())
                    var s_head = s_base.unsafe_offset(h * d_state * d_state)
                    for i in range(d_state):
                        for j in range(d_state):
                            var idx = i * d_state + j
                            s_head.unsafe_store(idx, s_head.unsafe_load(idx) * decay)
                    for j in range(d_state):
                        var mem: Float32 = 0.0
                        for i in range(d_state):
                            mem += s_head.unsafe_load(i * d_state + j).cast[DType.float32]() * conv_out.data.unsafe_load(k_off + i).cast[DType.float32]()
                        var delta = (conv_out.data.unsafe_load(v_off + j).cast[DType.float32]() - mem) * beta
                        state.scratch.unsafe_store(j, Scalar[f32](delta))
                    for i in range(d_state):
                        var k_i = conv_out.data.unsafe_load(k_off + i).cast[DType.float32]()
                        for j in range(d_state):
                            var idx = i * d_state + j
                            s_head.unsafe_store(idx, s_head.unsafe_load(idx) + Scalar[f32](k_i) * state.scratch.unsafe_load(j))
                    var head_scale = Float32(1.0) / sqrt(Float32(d_state))
                    for j in range(d_state):
                        var acc: Float32 = 0.0
                        for i in range(d_state):
                            acc += s_head.unsafe_load(i * d_state + j).cast[DType.float32]() * conv_out.data.unsafe_load(q_off + i).cast[DType.float32]()
                        state.scratch.unsafe_store(d_state + j, Scalar[f32](acc * head_scale))
                    # Per-head RMSNorm with the shared ssm_norm weight,
                    # gated by silu(z) for this head.
                    var mean: Float32 = 0.0
                    for d in range(d_state):
                        var val = state.scratch.unsafe_load(d_state + d).cast[DType.float32]()
                        mean += val * val
                    var nscale = Float32(1.0) / sqrt(mean / Float32(d_state) + self.rms_epsilon.cast[DType.float32]())
                    for d in range(d_state):
                        var val = state.scratch.unsafe_load(d_state + d).cast[DType.float32]() * nscale
                        var w = self.ssm_norm_weight.data.unsafe_load(d).cast[DType.float32]()
                        var zg = z.data.unsafe_load(q_off + d).cast[DType.float32]()
                        var silu_z = zg / (Float32(1.0) + exp(-zg))
                        y.data.unsafe_store(q_off + d, Scalar[f16](val * w * silu_z))
                gemm_f16(y, self.ssm_out_weight, x)

            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))

            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            rmsnorm(x, self.post_attn_norm_weight)
            var ffn_dim = self.ffn_gate_weight.rows
            var gate_ptr = well.allocate(ffn_dim)
            var gate_t = RuneTensor[f16](1, ffn_dim, gate_ptr, False)
            gemm_f16(x, self.ffn_gate_weight, gate_t)
            var up_ptr = well.allocate(ffn_dim)
            var up_t = RuneTensor[f16](1, ffn_dim, up_ptr, False)
            gemm_f16(x, self.ffn_up_weight, up_t)
            silu(gate_t)
            for i in range(ffn_dim):
                up_t.data.unsafe_store(i, up_t.data.unsafe_load(i) * gate_t.data.unsafe_load(i))
            gemm_f16(up_t, self.ffn_down_weight, x)
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))
            well.reset_kv_cache(start_offset)
        except e:
            well.reset_kv_cache(start_offset)
            raise e^



    def forward_batched(
        self,
        mut x: RuneTensor[f16],
        mut seer: GGUFSeer,
        mut well: MimirWell,
        start_pos: Int,
        mut kv_cache: KVCache,
        mut state: Qwen35State,
    ) raises:
        """Batched twin of forward() for x.rows consecutive positions
        (prefill). Full-attention layers batch every GEMM, run the
        existing attention kernel per row with that row's causal bound,
        and use append_block — bit-identical to per-token. DeltaNet
        layers batch the four input projections and the output GEMM,
        but the conv1d and the delta-rule recurrence stay strictly
        sequential per row (the recurrence is inherently sequential):
        the batched conv reads taps from the extended history
        [ring_old (kernel-1 rows) ‖ this block's qkv rows], which is
        exactly the sample sequence the per-token path sees, in the
        same tap order; the ring is advanced once, by the whole block,
        after all rows are convolved.
        """
        var start_offset = well.offset
        var hidden = x.cols
        var batch = x.rows
        try:
            var residual_ptr = well.allocate(x.size)
            var residual = RuneTensor[f16](batch, hidden, residual_ptr, False)
            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            rmsnorm(x, self.attn_norm_weight)

            if self.is_full_attn:
                var q_width = self.num_heads * self.head_dim
                var kv_width = self.num_kv_heads * self.head_dim
                var q_full_ptr = well.allocate(batch * 2 * q_width)
                var q_full = RuneTensor[f16](batch, 2 * q_width, q_full_ptr, False)
                gemm_f16(x, self.q_weight, q_full)
                var q_ptr = well.allocate(batch * q_width)
                var q = RuneTensor[f16](batch, q_width, q_ptr, False)
                var gate_ptr = well.allocate(batch * q_width)
                var gate = RuneTensor[f16](batch, q_width, gate_ptr, False)
                for r in range(batch):
                    for h in range(self.num_heads):
                        var src = r * 2 * q_width + h * 2 * self.head_dim
                        var dst = r * q_width + h * self.head_dim
                        for d in range(self.head_dim):
                            q.data.unsafe_store(dst + d, q_full.data.unsafe_load(src + d))
                            gate.data.unsafe_store(dst + d, q_full.data.unsafe_load(src + self.head_dim + d))
                var k_ptr = well.allocate(batch * kv_width)
                var k = RuneTensor[f16](batch, kv_width, k_ptr, False)
                gemm_f16(x, self.k_weight, k)
                var v_ptr = well.allocate(batch * kv_width)
                var v = RuneTensor[f16](batch, kv_width, v_ptr, False)
                gemm_f16(x, self.v_weight, v)
                for r in range(batch):
                    for h in range(self.num_heads):
                        self._head_rmsnorm(q, r * q_width + h * self.head_dim, self.q_norm_weight)
                    for h in range(self.num_kv_heads):
                        self._head_rmsnorm(k, r * kv_width + h * self.head_dim, self.k_norm_weight)
                apply_rope_partial_neox(q, k, start_pos, self.head_dim, self.rope_dims, self.rope_theta)
                kv_cache.append_block(self.layer_idx, start_pos, k, v, batch)
                var total_seq_len = min(start_pos + batch, kv_cache.max_seq_len)
                var k_slice = kv_cache.get_k_slice(self.layer_idx, total_seq_len)
                var v_slice = kv_cache.get_v_slice(self.layer_idx, total_seq_len)
                var attn_ptr = well.allocate(batch * q_width)
                var attn_out = RuneTensor[f16](batch, q_width, attn_ptr, False)
                for r in range(batch):
                    var q_row = RuneTensor[f16](1, q_width, q.data.unsafe_offset(r * q_width), False)
                    var o_row = RuneTensor[f16](1, q_width, attn_ptr.unsafe_offset(r * q_width), False)
                    flash_attention_gqa(
                        q_row,
                        k_slice,
                        v_slice,
                        o_row,
                        min(start_pos + r + 1, kv_cache.max_seq_len),
                        self.head_dim,
                        self.num_heads,
                        self.num_kv_heads,
                    )
                for i in range(attn_out.size):
                    var a = attn_out.data.unsafe_load(i).cast[DType.float32]()
                    var g = gate.data.unsafe_load(i).cast[DType.float32]()
                    attn_out.data.unsafe_store(i, Scalar[f16](a * _sigmoid_f32(g)))
                gemm_f16(attn_out, self.o_weight, x)
            else:
                var inner = self.gate_weight.rows
                var conv_dim = 3 * inner
                var n_heads = state.head_count
                var d_state = state.d_state
                var qkv_ptr = well.allocate(batch * conv_dim)
                var qkv = RuneTensor[f16](batch, conv_dim, qkv_ptr, False)
                gemm_f16(x, self.qkv_weight, qkv)
                var z_ptr = well.allocate(batch * inner)
                var z = RuneTensor[f16](batch, inner, z_ptr, False)
                gemm_f16(x, self.gate_weight, z)
                var dt_rank = self.alpha_weight.rows
                var alpha_ptr = well.allocate(batch * dt_rank)
                var alpha = RuneTensor[f16](batch, dt_rank, alpha_ptr, False)
                gemm_f16(x, self.alpha_weight, alpha)
                var beta_ptr = well.allocate(batch * dt_rank)
                var beta_raw = RuneTensor[f16](batch, dt_rank, beta_ptr, False)
                gemm_f16(x, self.beta_weight, beta_raw)

                # Causal depthwise conv1d over the extended history
                # [ring_old ‖ qkv rows]: row r, tap t reads history
                # index r + t — the same samples, same tap order, as
                # kernel-1 successive per-token calls. The ring itself
                # is not touched until every row is convolved.
                var kernel = state.conv_kernel
                var ring = state.conv_data.unsafe_offset(
                    self.ssm_slot * max(0, kernel - 1) * conv_dim
                )
                var conv_ptr = well.allocate(batch * conv_dim)
                var conv_out = RuneTensor[f16](batch, conv_dim, conv_ptr, False)
                for r in range(batch):
                    var out_base = r * conv_dim
                    for c in range(conv_dim):
                        var acc: Float32 = 0.0
                        for tap in range(kernel):
                            var kval = self.conv1d_weight.data.unsafe_load(c * kernel + tap).cast[DType.float32]()
                            var hist_idx = r + tap
                            var sample: Float32
                            if hist_idx < kernel - 1:
                                sample = ring.unsafe_load(hist_idx * conv_dim + c).cast[DType.float32]()
                            else:
                                sample = qkv.data.unsafe_load((hist_idx - (kernel - 1)) * conv_dim + c).cast[DType.float32]()
                            acc += kval * sample
                        conv_out.data.unsafe_store(out_base + c, Scalar[f16](acc))
                # Advance the ring once by the whole block: new slot j
                # holds history index batch + j. Sources sit at higher
                # indices than destinations (or inside qkv), so the
                # in-place copy cannot clobber unread history.
                if kernel > 1:
                    for j in range(kernel - 1):
                        var hist_idx = batch + j
                        for c in range(conv_dim):
                            if hist_idx < kernel - 1:
                                ring.unsafe_store(
                                    j * conv_dim + c,
                                    ring.unsafe_load(hist_idx * conv_dim + c),
                                )
                            else:
                                ring.unsafe_store(
                                    j * conv_dim + c,
                                    Scalar[f32](qkv.data.unsafe_load((hist_idx - (kernel - 1)) * conv_dim + c).cast[DType.float32]()),
                                )
                silu(conv_out)

                # Delta-rule recurrence: strictly sequential per row,
                # body identical to forward() with row offsets applied.
                var y_ptr = well.allocate(batch * inner)
                var y = RuneTensor[f16](batch, inner, y_ptr, False)
                var s_base = state.s_data.unsafe_offset(
                    self.ssm_slot * n_heads * d_state * d_state
                )
                for r in range(batch):
                    var conv_base = r * conv_dim
                    var row_base = r * inner
                    var ab_base = r * dt_rank
                    for h in range(n_heads):
                        var q_off = conv_base + h * d_state
                        var k_off = conv_base + inner + h * d_state
                        var v_off = conv_base + 2 * inner + h * d_state
                        var q_norm: Float32 = 0.0
                        var k_norm: Float32 = 0.0
                        for d in range(d_state):
                            var qv = conv_out.data.unsafe_load(q_off + d).cast[DType.float32]()
                            var kv = conv_out.data.unsafe_load(k_off + d).cast[DType.float32]()
                            q_norm += qv * qv
                            k_norm += kv * kv
                        var q_scale = Float32(1.0) / sqrt(q_norm + Float32(1e-6))
                        var k_scale = Float32(1.0) / sqrt(k_norm + Float32(1e-6))
                        for d in range(d_state):
                            conv_out.data.unsafe_store(q_off + d, Scalar[f16](conv_out.data.unsafe_load(q_off + d).cast[DType.float32]() * q_scale))
                            conv_out.data.unsafe_store(k_off + d, Scalar[f16](conv_out.data.unsafe_load(k_off + d).cast[DType.float32]() * k_scale))
                        var a_val = self.ssm_a.data.unsafe_load(h).cast[DType.float32]()
                        var dt = _softplus_f32(
                            alpha.data.unsafe_load(ab_base + h).cast[DType.float32]()
                            + self.dt_bias.data.unsafe_load(h).cast[DType.float32]()
                        )
                        var decay = exp(a_val * dt)
                        var beta = _sigmoid_f32(beta_raw.data.unsafe_load(ab_base + h).cast[DType.float32]())
                        var s_head = s_base.unsafe_offset(h * d_state * d_state)
                        for i in range(d_state):
                            for j in range(d_state):
                                var idx = i * d_state + j
                                s_head.unsafe_store(idx, s_head.unsafe_load(idx) * decay)
                        for j in range(d_state):
                            var mem: Float32 = 0.0
                            for i in range(d_state):
                                mem += s_head.unsafe_load(i * d_state + j).cast[DType.float32]() * conv_out.data.unsafe_load(k_off + i).cast[DType.float32]()
                            var delta = (conv_out.data.unsafe_load(v_off + j).cast[DType.float32]() - mem) * beta
                            state.scratch.unsafe_store(j, Scalar[f32](delta))
                        for i in range(d_state):
                            var k_i = conv_out.data.unsafe_load(k_off + i).cast[DType.float32]()
                            for j in range(d_state):
                                var idx = i * d_state + j
                                s_head.unsafe_store(idx, s_head.unsafe_load(idx) + Scalar[f32](k_i) * state.scratch.unsafe_load(j))
                        var head_scale = Float32(1.0) / sqrt(Float32(d_state))
                        for j in range(d_state):
                            var acc: Float32 = 0.0
                            for i in range(d_state):
                                acc += s_head.unsafe_load(i * d_state + j).cast[DType.float32]() * conv_out.data.unsafe_load(q_off + i).cast[DType.float32]()
                            state.scratch.unsafe_store(d_state + j, Scalar[f32](acc * head_scale))
                        var mean: Float32 = 0.0
                        for d in range(d_state):
                            var val = state.scratch.unsafe_load(d_state + d).cast[DType.float32]()
                            mean += val * val
                        var nscale = Float32(1.0) / sqrt(mean / Float32(d_state) + self.rms_epsilon.cast[DType.float32]())
                        for d in range(d_state):
                            var val = state.scratch.unsafe_load(d_state + d).cast[DType.float32]() * nscale
                            var w = self.ssm_norm_weight.data.unsafe_load(d).cast[DType.float32]()
                            var zg = z.data.unsafe_load(row_base + h * d_state + d).cast[DType.float32]()
                            var silu_z = zg / (Float32(1.0) + exp(-zg))
                            y.data.unsafe_store(row_base + h * d_state + d, Scalar[f16](val * w * silu_z))
                gemm_f16(y, self.ssm_out_weight, x)

            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))

            for i in range(x.size):
                residual.data.unsafe_store(i, x.data.unsafe_load(i))
            rmsnorm(x, self.post_attn_norm_weight)
            var ffn_dim = self.ffn_gate_weight.rows
            var gate_ptr = well.allocate(batch * ffn_dim)
            var gate_t = RuneTensor[f16](batch, ffn_dim, gate_ptr, False)
            gemm_f16(x, self.ffn_gate_weight, gate_t)
            var up_ptr = well.allocate(batch * ffn_dim)
            var up_t = RuneTensor[f16](batch, ffn_dim, up_ptr, False)
            gemm_f16(x, self.ffn_up_weight, up_t)
            silu(gate_t)
            for i in range(gate_t.size):
                up_t.data.unsafe_store(i, up_t.data.unsafe_load(i) * gate_t.data.unsafe_load(i))
            gemm_f16(up_t, self.ffn_down_weight, x)
            for i in range(x.size):
                x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))
            well.reset_kv_cache(start_offset)
        except e:
            well.reset_kv_cache(start_offset)
            raise e^


def forward_pass_qwen35_batched(
    tokens: List[Int],
    mut seer: GGUFSeer,
    mut well: MimirWell,
    mut kv_cache: KVCache,
    mut blocks: List[Qwen35Block],
    mut state: Qwen35State,
    start_pos: Int,
    batch_len: Int,
    is_prefill: Bool = True,
    temperature: Scalar[f32] = 0.0,
    top_k: Int = 40,
    top_p: Scalar[f32] = 0.9,
    repetition_penalty: Scalar[f32] = 1.1,
) raises -> Int:
    """Batched twin of forward_pass_qwen35 for one prefill chunk of
    batch_len tokens at start_pos. Unlike forward_pass_qwen35 this
    honors is_prefill: a pure-prefill chunk fills the KV cache and SSM
    state and returns 0 without paying the LM head. The SSM state
    resets exactly once, when the chunk starts at position 0 (the
    first chunk of a fresh sequence) — matching forward_pass_qwen35's
    reset-on-position-0 rule. A non-prefill chunk runs the output
    stage on the last row through the same norm + LM head + sampling.
    """
    if len(tokens) == 0:
        raise Error("forward_pass_qwen35_batched: tokens list cannot be empty")
    if batch_len <= 0 or start_pos < 0 or start_pos + batch_len > len(tokens):
        raise Error("forward_pass_qwen35_batched: chunk range outside the token list")
    if start_pos + batch_len > kv_cache.max_seq_len:
        raise Error("forward_pass_qwen35_batched: chunk exceeds KV cache capacity")
    if start_pos == 0:
        state.reset()
    var initial_offset = well.offset
    var x = _embed_tokens(seer, well, tokens, start_pos, batch_len)
    var vocab_dim = seer.tensors["token_embd.weight"].rows
    try:
        for l in range(seer.config.block_count):
            blocks[l].forward_batched(x, seer, well, start_pos, kv_cache, state)

        if is_prefill:
            well.offset = initial_offset
            return 0

        var x_last = RuneTensor[f16](
            1, x.cols, x.data.unsafe_offset((batch_len - 1) * x.cols), False
        )
        if "output_norm.weight" not in seer.tensors:
            raise Error("Inference requires output_norm.weight")
        ref output_norm = seer.tensors["output_norm.weight"]
        rmsnorm(x_last, output_norm)

        if "output.weight" not in seer.tensors:
            raise Error("Inference requires output.weight")
        ref output_weight = seer.tensors["output.weight"]
        var logits_ptr = well.allocate(vocab_dim)
        var logits = RuneTensor[f16](1, vocab_dim, logits_ptr, False)
        gemm_f16(x_last, output_weight, logits)

        var rng = RuneRNG(42)
        var suppress_list = List[Int]()
        var next_token = sample_token_from_logits(
            logits.data,
            vocab_dim,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            context_tokens=tokens,
            rng=rng,
            suppress_tokens=suppress_list,
        )
        well.offset = initial_offset
        return next_token
    except e:
        well.offset = initial_offset
        raise e^

def forward_pass_qwen35(
    tokens: List[Int],
    mut seer: GGUFSeer,
    mut well: MimirWell,
    mut kv_cache: KVCache,
    mut blocks: List[Qwen35Block],
    mut state: Qwen35State,
    start_pos: Int = 0,
    temperature: Scalar[f32] = 0.0,
    top_k: Int = 40,
    top_p: Scalar[f32] = 0.9,
    repetition_penalty: Scalar[f32] = 1.1,
) raises -> Int:
    """Full forward pass for the Qwen3.5 hybrid arch. Mirrors
    forward_pass's output stage (final norm, LM head, sampling) but runs
    Qwen35Blocks and carries the SSM state across token positions; the
    state resets whenever a fresh sequence starts at position 0."""
    if len(tokens) == 0:
        raise Error("forward_pass_qwen35: tokens list cannot be empty")
    if start_pos == 0:
        state.reset()
    var initial_offset = well.offset
    var token_idx = min(max(0, start_pos), len(tokens) - 1)
    var last_token = tokens[token_idx]
    var x = _embed_token(seer, well, last_token)
    var vocab_dim = seer.tensors["token_embd.weight"].rows
    try:
        for l in range(seer.config.block_count):
            blocks[l].forward(x, seer, well, start_pos, kv_cache, state)

        if "output_norm.weight" not in seer.tensors:
            raise Error("Inference requires output_norm.weight")
        ref output_norm = seer.tensors["output_norm.weight"]
        rmsnorm(x, output_norm)

        if "output.weight" not in seer.tensors:
            raise Error("Inference requires output.weight")
        ref output_weight = seer.tensors["output.weight"]
        var logits_ptr = well.allocate(vocab_dim)
        var logits = RuneTensor[f16](1, vocab_dim, logits_ptr, False)
        gemm_f16(x, output_weight, logits)

        var rng = RuneRNG(42)
        var suppress_list = List[Int]()
        var next_token = sample_token_from_logits(
            logits.data,
            vocab_dim,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            context_tokens=tokens,
            rng=rng,
            suppress_tokens=suppress_list,
        )
        well.offset = initial_offset
        return next_token
    except e:
        well.offset = initial_offset
        raise e^
