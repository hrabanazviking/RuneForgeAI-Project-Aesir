# core/inference.mojo
# The Loom of Fate: The Forward Pass
#
# Strings together the kernels from the Forge (compute) and the Memory (MimirWell)
# to weave the destiny of the tokens.

from std.math import max, min
from .mimir_well import RuneTensor, MimirWell, KVCache, DeviceTopology, NPUBackendType, GPURealmType, shard_split_cols, shard_split_rows, f16, f32
from .compute import gemm_f16, gemm_f16_arm_neon, rmsnorm_arm_neon, gemm_f16_npu, gemm_f16_gpu, rmsnorm_gpu, gemm_f16_sharded, all_reduce_sum, flash_attention_2, flash_attention_gqa, silu, geglu, rmsnorm, apply_rope
from loader.gguf import GGUFSeer
from loader.quantization import dequantize_q4_0_block
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

    var attn_norm_weight: RuneTensor[f16]
    var attn_q_weight: RuneTensor[f16]
    var attn_k_weight: RuneTensor[f16]
    var attn_v_weight: RuneTensor[f16]
    var attn_output_weight: RuneTensor[f16]
    var ffn_norm_weight: RuneTensor[f16]
    var ffn_up_weight: RuneTensor[f16]
    var ffn_gate_weight: RuneTensor[f16]
    var ffn_down_weight: RuneTensor[f16]

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

        var prefix = "blk." + String(self.layer_idx) + "."
        self.attn_norm_weight = _required_block_weight(seer, prefix + "attn_norm.weight")
        self.attn_q_weight = _required_block_weight(seer, prefix + "attn_q.weight")
        self.attn_k_weight = _required_block_weight(seer, prefix + "attn_k.weight")
        self.attn_v_weight = _required_block_weight(seer, prefix + "attn_v.weight")
        self.attn_output_weight = _required_block_weight(seer, prefix + "attn_output.weight")
        self.ffn_norm_weight = _required_block_weight(seer, prefix + "ffn_norm.weight")
        self.ffn_up_weight = _required_block_weight(seer, prefix + "ffn_up.weight")
        self.ffn_gate_weight = _required_block_weight(seer, prefix + "ffn_gate.weight")
        self.ffn_down_weight = _required_block_weight(seer, prefix + "ffn_down.weight")

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
        attn_norm_weight: RuneTensor[f16],
        attn_q_weight: RuneTensor[f16],
        attn_k_weight: RuneTensor[f16],
        attn_v_weight: RuneTensor[f16],
        attn_output_weight: RuneTensor[f16],
        ffn_norm_weight: RuneTensor[f16],
        ffn_up_weight: RuneTensor[f16],
        ffn_gate_weight: RuneTensor[f16],
        ffn_down_weight: RuneTensor[f16],
    ):
        """Builds a complete copy; the token is module-private by design."""
        self.layer_idx = layer_idx
        self.head_dim = head_dim
        self.num_heads = num_heads
        self.num_kv_heads = num_kv_heads
        self.rms_epsilon = rms_epsilon
        self.attn_norm_weight = attn_norm_weight.copy()
        self.attn_q_weight = attn_q_weight.copy()
        self.attn_k_weight = attn_k_weight.copy()
        self.attn_v_weight = attn_v_weight.copy()
        self.attn_output_weight = attn_output_weight.copy()
        self.ffn_norm_weight = ffn_norm_weight.copy()
        self.ffn_up_weight = ffn_up_weight.copy()
        self.ffn_gate_weight = ffn_gate_weight.copy()
        self.ffn_down_weight = ffn_down_weight.copy()

    def __copyinit__(out self, existing: Self):
        self.layer_idx = existing.layer_idx
        self.head_dim = existing.head_dim
        self.num_heads = existing.num_heads
        self.num_kv_heads = existing.num_kv_heads
        self.rms_epsilon = existing.rms_epsilon
        self.attn_norm_weight = existing.attn_norm_weight
        self.attn_q_weight = existing.attn_q_weight
        self.attn_k_weight = existing.attn_k_weight
        self.attn_v_weight = existing.attn_v_weight
        self.attn_output_weight = existing.attn_output_weight
        self.ffn_norm_weight = existing.ffn_norm_weight
        self.ffn_up_weight = existing.ffn_up_weight
        self.ffn_gate_weight = existing.ffn_gate_weight
        self.ffn_down_weight = existing.ffn_down_weight

    @always_inline
    def copy(self) -> Self:
        return Self(
            _ValidatedBlockCopyToken(),
            self.layer_idx,
            self.head_dim,
            self.num_heads,
            self.num_kv_heads,
            self.rms_epsilon,
            self.attn_norm_weight.copy(),
            self.attn_q_weight.copy(),
            self.attn_k_weight.copy(),
            self.attn_v_weight.copy(),
            self.attn_output_weight.copy(),
            self.ffn_norm_weight.copy(),
            self.ffn_up_weight.copy(),
            self.ffn_gate_weight.copy(),
            self.ffn_down_weight.copy(),
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
                var q_cols = self.attn_q_weight.rows
                var k_cols = self.attn_k_weight.rows
                var v_cols = self.attn_v_weight.rows
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


                # 3. RoPE
                apply_rope(q, k, start_pos, self.head_dim)

                # 4. Ring-Buffer KV Cache Append & Flash Attention 2
                kv_cache.append(self.layer_idx, start_pos, k, v)
                var active_seq_len = min(start_pos + 1, kv_cache.max_seq_len)
                var k_slice = kv_cache.get_k_slice(self.layer_idx, active_seq_len)
                var v_slice = kv_cache.get_v_slice(self.layer_idx, active_seq_len)

                var attn_out_ptr = well.allocate(x.size)
                var attn_out = RuneTensor[f16](x.rows, x.cols, attn_out_ptr, False)
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

                # 5. Output Projection
                if use_gpu_realm:
                    gemm_f16_gpu(attn_out, self.attn_output_weight, x, gpu_realm)
                elif use_npu:
                    gemm_f16_npu(attn_out, self.attn_output_weight, x, npu_backend)
                else:
                    gemm_f16(attn_out, self.attn_output_weight, x)


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
                var up_ptr = well.allocate(self.ffn_up_weight.rows * x.rows)
                var up = RuneTensor[f16](x.rows, self.ffn_up_weight.rows, up_ptr, False)
                
                var gate_ptr = well.allocate(self.ffn_gate_weight.rows * x.rows)
                var gate = RuneTensor[f16](x.rows, self.ffn_gate_weight.rows, gate_ptr, False)
                
                if use_gpu_realm:
                    gemm_f16_gpu(x, self.ffn_up_weight, up, gpu_realm)
                    gemm_f16_gpu(x, self.ffn_gate_weight, gate, gpu_realm)
                elif use_npu:
                    gemm_f16_npu(x, self.ffn_up_weight, up, npu_backend)
                    gemm_f16_npu(x, self.ffn_gate_weight, gate, npu_backend)
                else:
                    gemm_f16(x, self.ffn_up_weight, up)
                    gemm_f16(x, self.ffn_gate_weight, gate)
                
                # Apply SiLU to gate and multiply by up (elementwise)
                silu(gate)
                for i in range(up.size):
                    up.data.unsafe_store(i, up.data.unsafe_load(i) * gate.data.unsafe_load(i))
                    
                # GEMM down
                if use_gpu_realm:
                    gemm_f16_gpu(up, self.ffn_down_weight, x, gpu_realm)
                elif use_npu:
                    gemm_f16_npu(up, self.ffn_down_weight, x, npu_backend)
                else:
                    gemm_f16(up, self.ffn_down_weight, x)


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
            apply_rope(full_q, full_k, start_pos, self.head_dim)

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
    gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)
) raises -> Int:

    """
    The Weaving of Fate.
    Executes the full forward pass for a sequence of tokens and returns the next token.
    """
    var seq_len = len(tokens)
    if seq_len == 0:
        return 0
        
    var token_idx = min(max(0, start_pos), seq_len - 1)
    var last_token = tokens[token_idx]
    
    if "token_embd.weight" not in seer.tensors:
        raise Error("Inference requires token_embd.weight")
    ref token_embd = seer.tensors["token_embd.weight"]
    var hidden_dim = token_embd.cols
    if last_token < 0 or last_token >= token_embd.rows:
        raise Error("Prompt token ID is outside the embedding vocabulary")
    
    var initial_offset = well.offset
    
    # 1. Retrieve token embedding
    var x_ptr = well.allocate(hidden_dim)
    var x = RuneTensor[f16](1, hidden_dim, x_ptr, False)
    
    # Copy or dequantize embedding for the last token
    if token_embd.is_quantized:
        var num_blocks = hidden_dim // 32
        var block_bytes = 18
        var src_byte_offset = (last_token * num_blocks) * block_bytes
        var src_ptr = token_embd.data.unsafe_bitcast[Byte]().unsafe_offset(src_byte_offset)
        dequantize_q4_0_block(src_ptr, x.data, num_blocks)
    else:
        for i in range(hidden_dim):
            x.data.unsafe_store(i, token_embd.data.unsafe_load(last_token * hidden_dim + i))
        
    # 2. Loop over layers
    if len(blocks) == num_layers:
        for layer_idx in range(num_layers):
            blocks[layer_idx].forward(x, seer, well, seq_len, start_pos, kv_cache, topology, use_npu, npu_backend, use_gpu_realm, gpu_realm)
    else:
        for layer_idx in range(num_layers):
            var temp_block = TransformerBlock(layer_idx, head_dim, num_heads, seer)
            temp_block.forward(x, seer, well, seq_len, start_pos, kv_cache, topology, use_npu, npu_backend, use_gpu_realm, gpu_realm)
        
    # 3. Final RMSNorm
    if "output_norm.weight" in seer.tensors:
        var epsilon: Scalar[f32] = 1e-5
        if seer.config.rms_epsilon > 0.0:
            epsilon = seer.config.rms_epsilon
        if use_gpu_realm:
            rmsnorm_gpu(x, seer.tensors["output_norm.weight"], gpu_realm, epsilon)
        else:
            rmsnorm(x, seer.tensors["output_norm.weight"], epsilon)
    
    # 4. Final projection to logits
    if "output.weight" not in seer.tensors:
        well.offset = initial_offset
        raise Error("Inference requires output.weight")

    ref output_weight = seer.tensors["output.weight"]
    var vocab_size = output_weight.rows
    var logits_ptr = well.allocate(vocab_size)
    var logits = RuneTensor[f16](1, vocab_size, logits_ptr, False)
    
    if use_gpu_realm:
        gemm_f16_gpu(x, output_weight, logits, gpu_realm)
    elif use_npu:
        gemm_f16_npu(x, output_weight, logits, npu_backend)
    else:
        gemm_f16(x, output_weight, logits)

    
    # 6. Temperature & Top-K / Top-P sampling with repetition penalty
    var rng = RuneRNG(42)
    var best_token = sample_token_from_logits(
        logits.data,
        vocab_size,
        temperature=0.7,
        top_k=40,
        top_p=0.9,
        repetition_penalty=1.1,
        context_tokens=tokens,
        rng=rng,
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
    gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)
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
    var kv_cache = KVCache(context_length, kv_dim, well, num_layers)
    var start_pos = max(0, len(tokens) - 1)
    return forward_pass(tokens, seer, well, kv_cache, start_pos, num_layers, head_dim, num_heads, topology, blocks, use_npu, npu_backend, use_gpu_realm, gpu_realm)
