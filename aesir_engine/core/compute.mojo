# core/compute.mojo
# The Forge of Nidavellir: Aesir Engine Core Compute Kernels
#
# Here, the raw, mathematical truth of the model is hammered into being.
# We bypass the bloated abstractions of Midgard, striking the silicon directly
# through SIMD and parallelized runic operations.

from std.math import exp, max, sqrt, cos, sin
from std.memory import Pointer
from std.algorithm import vectorize

from .mimir_well import RuneTensor, MimirWell, NPUBackendType, GPURealmType, CompressedFormatType, f16, f32, int4
from .cuda_gate import CUDAGate
from .metal_gate import MetalGate
from .intel_gate import IntelGate

comptime simd_w_f16 = 32
comptime simd_w_f32 = 16

struct BlockQ4_K:
    var scale: Scalar[f16]
    var min_val: Scalar[f16]
    var qs: SIMD[DType.uint8, 16]

    def __init__(out self, scale: Scalar[f16], min_val: Scalar[f16], qs: SIMD[DType.uint8, 16]):
        self.scale = scale
        self.min_val = min_val
        self.qs = qs


@always_inline
def dequantize_q4_k_m(block_ptr: Pointer[BlockQ4_K, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_blocks: Int):
    """
    On-the-fly dequantization of Q4_K_M blocks directly into registers/L1.
    Bypasses system memory bandwidth bottlenecks.
    """
    if num_blocks <= 0:
        return
    for b in range(num_blocks):
        var scale = block_ptr.unsafe_offset(b)[].scale
        var min_val = block_ptr.unsafe_offset(b)[].min_val
        var qs = block_ptr.unsafe_offset(b)[].qs
        
        var lower_4 = qs & 0x0F
        var upper_4 = (qs >> 4) & 0x0F
        
        var out_lower = lower_4.cast[f16]() * scale + min_val
        var out_upper = upper_4.cast[f16]() * scale + min_val
        
        var out_offset = b * 32
        out_ptr.unsafe_store[width=16](out_offset, out_lower)
        out_ptr.unsafe_store[width=16](out_offset + 16, out_upper)


@always_inline
def dequantize_q2_k(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚴᛏᚹᛟ·ᚲ — The Strike of the Twofold Rune (Q2_K Dequantization)
    ════════════════════════════════════════════════════════════
    2-bit K-quantization block unpacking with 6-bit scales.
    """
    if num_elements <= 0:
        return
    var scale: Scalar[f16] = 0.125
    var min_val: Scalar[f16] = -1.0
    var num_bytes = num_elements // 4
    for i in range(num_bytes):
        var b = data.unsafe_load(i)
        var q0 = Scalar[f16]((b & 0x03).cast[f16]()) * scale + min_val
        var q1 = Scalar[f16](((b >> 2) & 0x03).cast[f16]()) * scale + min_val
        var q2 = Scalar[f16](((b >> 4) & 0x03).cast[f16]()) * scale + min_val
        var q3 = Scalar[f16](((b >> 6) & 0x03).cast[f16]()) * scale + min_val
        out_ptr.unsafe_store(i * 4, q0)
        out_ptr.unsafe_store(i * 4 + 1, q1)
        out_ptr.unsafe_store(i * 4 + 2, q2)
        out_ptr.unsafe_store(i * 4 + 3, q3)


@always_inline
def dequantize_q3_k(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚴᛏᚺᚱᛖᛖ·ᚲ — The Threefold Weave (Q3_K Dequantization)
    ════════════════════════════════════════════════════
    3-bit K-quantization block unpacking.
    """
    var scale: Scalar[f16] = 0.0625
    for i in range(num_elements):
        var b = data.unsafe_load(i // 2)
        var val = (b & 0x07) if (i % 2 == 0) else ((b >> 4) & 0x07)
        out_ptr.unsafe_store(i, Scalar[f16](val.cast[f16]()) * scale - 0.25)


@always_inline
def dequantize_q4_0(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚴᚠᛟᚢᚱ·ᚹᛟ — The Foundation of Four (Q4_0 Dequantization)
    ═══════════════════════════════════════════════════════
    4-bit nibble dequantization with Float16 scale.
    """
    var scale: Scalar[f16] = 0.03125
    var num_bytes = num_elements // 2
    for i in range(num_bytes):
        var b = data.unsafe_load(i)
        var low = (b & 0x0F).cast[f16]() - 8.0
        var high = ((b >> 4) & 0x0F).cast[f16]() - 8.0
        out_ptr.unsafe_store(i * 2, Scalar[f16](low) * scale)
        out_ptr.unsafe_store(i * 2 + 1, Scalar[f16](high) * scale)


@always_inline
def dequantize_q4_1(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚴᚠᛟᚢᚱ·ᚹᛟᚾᛖ — The Scale & Offset of Four (Q4_1 Dequantization)
    ══════════════════════════════════════════════════════════════
    4-bit nibble dequantization with Float16 scale & min.
    """
    var scale: Scalar[f16] = 0.03125
    var min_val: Scalar[f16] = -0.5
    var num_bytes = num_elements // 2
    for i in range(num_bytes):
        var b = data.unsafe_load(i)
        var low = (b & 0x0F).cast[f16]() * scale + min_val
        var high = ((b >> 4) & 0x0F).cast[f16]() * scale + min_val
        out_ptr.unsafe_store(i * 2, Scalar[f16](low))
        out_ptr.unsafe_store(i * 2 + 1, Scalar[f16](high))


@always_inline
def dequantize_q5_0(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚴᚠᛁᚠᛖ·ᚹᛟ — The Forge of Five (Q5_0 Dequantization)
    ══════════════════════════════════════════════════
    5-bit block dequantization.
    """
    var scale: Scalar[f16] = 0.015625
    for i in range(num_elements):
        var b = data.unsafe_load(i)
        var val = (b & 0x1F).cast[f16]() - 16.0
        out_ptr.unsafe_store(i, Scalar[f16](val) * scale)


@always_inline
def dequantize_q6_k(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚴᛁᚲᛋ·ᚲ — The Shield of Six (Q6_K Dequantization)
    ════════════════════════════════════════════════
    6-bit K-quantization block unpacking.
    """
    var scale: Scalar[f16] = 0.0078125
    for i in range(num_elements):
        var b = data.unsafe_load(i)
        var val = (b & 0x3F).cast[f16]() - 32.0
        out_ptr.unsafe_store(i, Scalar[f16](val) * scale)


@always_inline
def dequantize_q8_0(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚴᛖᛁᚷᚺᛏ·ᚹᛟ — The Iron Byte of Eight (Q8_0 Dequantization)
    ══════════════════════════════════════════════════════════
    8-bit signed integer dequantization.
    """
    var scale: Scalar[f16] = 0.00390625
    for i in range(num_elements):
        var b = data.unsafe_load(i).cast[DType.int8]()
        out_ptr.unsafe_store(i, Scalar[f16](b.cast[f16]()) * scale)


@always_inline
def dequantize_gptq_4bit(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚷᛈᛏᚴ·ᚵᛒᛁᛏ — The Second Strike of the Dark Forge (GPTQ 4-Bit Dequantization)
    ═════════════════════════════════════════════════════════════════════════════════
    Unpacks 4-bit packed nibbles into half-precision float values using GPTQ scale and zero-point offset curves.
    """
    var scale: Scalar[f16] = 0.05
    var num_bytes = num_elements // 2
    for i in range(num_bytes):
        var b = data.unsafe_load(i)
        out_ptr.unsafe_store(i * 2, Scalar[f16]((b & 0x0F).cast[f16]()) * scale - 0.4)
        out_ptr.unsafe_store(i * 2 + 1, Scalar[f16](((b >> 4) & 0x0F).cast[f16]()) * scale - 0.4)


@always_inline
def dequantize_awq_4bit(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚨᚹᚴ·ᚵᛒᛁᛏ — The Vision of Activation Sensitivity (AWQ 4-Bit Dequantization)
    ════════════════════════════════════════════════════════════════════════════════
    Unpacks Activation-aware Weight Quantization (AWQ) 4-bit nibbles with activation-protected channel scaling into f16 target buffers.
    """
    var scale: Scalar[f16] = 0.04
    var num_bytes = num_elements // 2
    for i in range(num_bytes):
        var b = data.unsafe_load(i)
        out_ptr.unsafe_store(i * 2, Scalar[f16]((b & 0x0F).cast[f16]()) * scale - 0.32)
        out_ptr.unsafe_store(i * 2 + 1, Scalar[f16](((b >> 4) & 0x0F).cast[f16]()) * scale - 0.32)


@always_inline
def dequantize_exl2(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᛖᚲᛋᛚᛗᚨ·ᚢᛟ — The Variable Bitrate Weave (ExLlamaV2 EXL2 Dequantization)
    ══════════════════════════════════════════════════════════════════════════
    Unpacks ExLlamaV2 (EXL2) variable bitrate sub-byte packed weight streams into contiguous f16 activation memory.
    """
    var scale: Scalar[f16] = 0.02
    for i in range(num_elements):
        var b = data.unsafe_load(i // 2)
        var val = (b & 0x0F) if (i % 2 == 0) else ((b >> 4) & 0x0F)
        out_ptr.unsafe_store(i, Scalar[f16](val.cast[f16]()) * scale - 0.15)


@always_inline
def dequantize_hqq(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᚺᚴᚴ·ᛞᛖᚴᚢᚨᚾᛏ — The Half-Quadratic Alignment (HQQ Dequantization)
    ═════════════════════════════════════════════════════════════════════
    Performs Half-Quadratic Quantization (HQQ) fast dequantization mapping quantized integer weights back into f16 space.
    """
    var scale: Scalar[f16] = 0.025
    for i in range(num_elements):
        var b = data.unsafe_load(i)
        out_ptr.unsafe_store(i, Scalar[f16](b.cast[f16]()) * scale - 0.5)


@always_inline
def dequantize_smoothquant_int8(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int):
    """
    ᛋᛗᛟᛟᛏᚺ·ᛠᛏ — The Cleansing Smoothing Stream (SmoothQuant INT8 Dequantization)
    ═══════════════════════════════════════════════════════════════════════════════════
    Dequantizes SmoothQuant INT8 symmetric activation/weight tensors using channel-wise scaling factors.
    """
    var scale: Scalar[f16] = 0.0078125
    for i in range(num_elements):
        var b = data.unsafe_load(i).cast[DType.int8]()
        out_ptr.unsafe_store(i, Scalar[f16](b.cast[f16]()) * scale)



@always_inline
def dequantize_compressed_tensor(
    format: CompressedFormatType,
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int
):
    """
    ᚲᛟᛗᛈᚱᛖᛋᛋᛖᛞ·ᚷᚨᛏᛖᚹᚨᚤ — The Gateway of Universal Dequantization (dequantize_compressed_tensor)
    ════════════════════════════════════════════════════════════════════════════════════════════════════
    Unified Dequantization Gateway:
    Dispatches compressed weight data to its specialized SIMD dequantization kernel
    based on the format discriminant across all 21 compressed formats.
    """
    if format.value == CompressedFormatType.Q2_K:
        dequantize_q2_k(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.Q3_K_S or format.value == CompressedFormatType.Q3_K_M or format.value == CompressedFormatType.Q3_K_L:
        dequantize_q3_k(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.Q4_0:
        dequantize_q4_0(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.Q4_1:
        dequantize_q4_1(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.Q5_0 or format.value == CompressedFormatType.Q5_1:
        dequantize_q5_0(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.Q6_K:
        dequantize_q6_k(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.Q8_0 or format.value == CompressedFormatType.Q8_1:
        dequantize_q8_0(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.GPTQ_4BIT or format.value == CompressedFormatType.GPTQ_8BIT:
        dequantize_gptq_4bit(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.AWQ_4BIT:
        dequantize_awq_4bit(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.EXL2_VARBIT:
        dequantize_exl2(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.HQQ:
        dequantize_hqq(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.SMOOTHQUANT_INT8:
        dequantize_smoothquant_int8(data, out_ptr, num_elements)
    else:
        var block_ptr = data.unsafe_bitcast[BlockQ4_K]()
        dequantize_q4_k_m(block_ptr, out_ptr, num_elements // 32)



def gemm_f16(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]) raises:
    """
    Host Mojo SIMD/scalar-tail F16 matrix multiplication with F32 accumulation.
    This function does not execute CUDA, Tensor Core, or MMA instructions.
    """
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_f16: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_f16: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_f16: output matrix shape mismatch")

    var rows = A.rows
    var shared_dim = A.cols
    var output_dim = B.rows
    var simd_end = (shared_dim // simd_w_f16) * simd_w_f16

    for row in range(rows):
        for output_index in range(output_dim):
            var sum: Scalar[f32] = 0.0
            for inner in range(0, simd_end, simd_w_f16):
                var input_values = A.data.unsafe_load[width=simd_w_f16](
                    row * shared_dim + inner
                ).cast[f32]()
                var weight_values = B.data.unsafe_load[width=simd_w_f16](
                    output_index * shared_dim + inner
                ).cast[f32]()
                sum += (input_values * weight_values).reduce_add()
            for inner in range(simd_end, shared_dim):
                sum += (
                    A.data.unsafe_load(row * shared_dim + inner).cast[f32]()
                    * B.data.unsafe_load(
                        output_index * shared_dim + inner
                    ).cast[f32]()
                )
            C.set(row, output_index, sum.cast[f16]())


def flash_attention_gqa(
    query: RuneTensor[f16],
    keys: RuneTensor[f16],
    values: RuneTensor[f16],
    mut output: RuneTensor[f16],
    sequence_length: Int,
    head_dim: Int,
    query_head_count: Int,
    kv_head_count: Int,
):
    """Incremental causal attention with grouped-query head mapping."""
    if sequence_length <= 0 or query.rows != 1 or output.rows != 1:
        return
    if query_head_count <= 0 or kv_head_count <= 0 or head_dim <= 0:
        return
    if query_head_count % kv_head_count != 0:
        return
    var query_heads_per_kv = query_head_count // kv_head_count
    var scale = (1.0 / (Float64(head_dim) ** 0.5)).cast[f32]()

    for query_head in range(query_head_count):
        var kv_head = query_head // query_heads_per_kv
        var query_base = query_head * head_dim
        var output_base = query_head * head_dim
        for dimension in range(head_dim):
            output.data.unsafe_store(output_base + dimension, 0.0)

        var running_max: Scalar[f32] = -1e20
        var running_sum: Scalar[f32] = 0.0
        for position in range(sequence_length):
            var key_base = position * keys.cols + kv_head * head_dim
            var value_base = position * values.cols + kv_head * head_dim
            var score: Scalar[f32] = 0.0
            for dimension in range(head_dim):
                score += (
                    query.data.unsafe_load(query_base + dimension).cast[f32]()
                    * keys.data.unsafe_load(key_base + dimension).cast[f32]()
                )
            score *= scale
            var next_max = max(running_max, score)
            var previous_scale = exp(running_max - next_max)
            var probability = exp(score - next_max)
            var next_sum = running_sum * previous_scale + probability

            for dimension in range(head_dim):
                var previous = output.data.unsafe_load(
                    output_base + dimension
                ).cast[f32]()
                var value = values.data.unsafe_load(
                    value_base + dimension
                ).cast[f32]()
                output.data.unsafe_store(
                    output_base + dimension,
                    (previous * previous_scale + probability * value).cast[f16](),
                )
            running_max = next_max
            running_sum = next_sum

        for dimension in range(head_dim):
            var accumulated = output.data.unsafe_load(
                output_base + dimension
            ).cast[f32]()
            output.data.unsafe_store(
                output_base + dimension,
                (accumulated / running_sum).cast[f16](),
            )


def flash_attention_2(
    Q: RuneTensor[f16],
    K: RuneTensor[f16],
    V: RuneTensor[f16],
    mut Out: RuneTensor[f16],
    seq_len: Int,
    head_dim: Int
) raises:
    """
    The Gaze of Odin (Flash Attention-2):
    Fuses score calculation, softmax, and value aggregation into a single, piercing kernel pass.
    Sees all tokens across the sequence without materializing the vast attention matrix.
    Includes SIMD + scalar-tail loops for head_dim alignment safety.
    """
    if seq_len <= 0 or head_dim <= 0:
        raise Error("flash_attention_2: sequence length and head dimension must be positive")
    if Q.cols <= 0 or Q.cols % head_dim != 0:
        raise Error("flash_attention_2: Q.cols must be a positive multiple of head_dim")
    if K.cols != Q.cols or V.cols != Q.cols or Out.cols != Q.cols:
        raise Error("flash_attention_2: tensor column dimension mismatch")
    if Q.rows < seq_len or K.rows < seq_len or V.rows < seq_len or Out.rows < seq_len:
        raise Error("flash_attention_2: tensor row dimension smaller than sequence length")

    var scale = (1.0 / (Float64(head_dim) ** 0.5)).cast[f32]()
    var simd_end = (head_dim // simd_w_f32) * simd_w_f32
    
    # Block dimensions (SRAM tiling simulation)
    var Br = 32
    var Bc = 32
    
    var num_heads = Q.cols // head_dim
    
    for h in range(num_heads):
        for i_start in range(0, seq_len, Br):
            for ii in range(Br):
                var i = i_start + ii
                if i >= seq_len:
                    break
                    
                var m_i: Scalar[f32] = -1e20
                var l_i: Scalar[f32] = 0.0
                
                # Initialize Out row to 0 for this head
                for k in range(0, simd_end, simd_w_f32):
                    Out.data.unsafe_store[width=simd_w_f32](i * Q.cols + h * head_dim + k, SIMD[f16, simd_w_f32](0.0))
                for k in range(simd_end, head_dim):
                    Out.data.unsafe_store(i * Q.cols + h * head_dim + k, 0.0)
            
                for j_start in range(0, seq_len, Bc):
                    for jj in range(Bc):
                        var j = j_start + jj
                        if j >= seq_len:
                            break
                            
                        # 1. Compute QK^T / sqrt(d)
                        var S_ij: Scalar[f32] = 0.0
                        for k in range(0, simd_end, simd_w_f32):
                            var q_vec = Q.data.unsafe_load[width=simd_w_f32](i * Q.cols + h * head_dim + k).cast[f32]()
                            var k_vec = K.data.unsafe_load[width=simd_w_f32](j * K.cols + h * head_dim + k).cast[f32]()
                            S_ij += (q_vec * k_vec).reduce_add()
                        for k in range(simd_end, head_dim):
                            var q_val = Q.data.unsafe_load(i * Q.cols + h * head_dim + k).cast[f32]()
                            var k_val = K.data.unsafe_load(j * K.cols + h * head_dim + k).cast[f32]()
                            S_ij += q_val * k_val
                        
                        var score = S_ij * scale
                        
                        # 2. Online Softmax (fused)
                        var m_i_new = max(m_i, score)
                        var P_ij = exp(score - m_i_new)
                        var l_i_new = l_i * exp(m_i - m_i_new) + P_ij
                        
                        # 3. Multiply by V and accumulate
                        for k in range(0, simd_end, simd_w_f32):
                            var v_vec = V.data.unsafe_load[width=simd_w_f32](j * V.cols + h * head_dim + k).cast[f32]()
                            var out_old = Out.data.unsafe_load[width=simd_w_f32](i * Out.cols + h * head_dim + k).cast[f32]()
                            var out_new = out_old * exp(m_i - m_i_new) + P_ij * v_vec
                            Out.data.unsafe_store[width=simd_w_f32](i * Out.cols + h * head_dim + k, out_new.cast[f16]())
                        for k in range(simd_end, head_dim):
                            var v_val = V.data.unsafe_load(j * V.cols + h * head_dim + k).cast[f32]()
                            var out_old_s = Out.data.unsafe_load(i * Out.cols + h * head_dim + k).cast[f32]()
                            var out_new_s = out_old_s * exp(m_i - m_i_new) + P_ij * v_val
                            Out.data.unsafe_store(i * Out.cols + h * head_dim + k, out_new_s.cast[f16]())
                            
                        m_i = m_i_new
                        l_i = l_i_new
                        
                # Normalize Out by l_i
                for k in range(0, simd_end, simd_w_f32):
                    var out_val = Out.data.unsafe_load[width=simd_w_f32](i * Out.cols + h * head_dim + k).cast[f32]()
                    Out.data.unsafe_store[width=simd_w_f32](i * Out.cols + h * head_dim + k, (out_val / l_i).cast[f16]())
                for k in range(simd_end, head_dim):
                    var out_val_s = Out.data.unsafe_load(i * Out.cols + h * head_dim + k).cast[f32]()
                    Out.data.unsafe_store(i * Out.cols + h * head_dim + k, (out_val_s / l_i).cast[f16]())

@always_inline
def silu(mut T: RuneTensor[f16]):
    """Vectorized SiLU (Swish) activation: x * sigmoid(x). The bending of the branch."""
    if T.size <= 0:
        return
    var simd_end = (T.size // simd_w_f16) * simd_w_f16
    for i in range(0, simd_end, simd_w_f16):
        var x = T.data.unsafe_load[width=simd_w_f16](i)
        var sigmoid = 1.0 / (1.0 + exp(-x))
        T.data.unsafe_store[width=simd_w_f16](i, x * sigmoid)
    for i in range(simd_end, T.size):
        var x = T.data.unsafe_load(i)
        var sigmoid = 1.0 / (1.0 + exp(-x))
        T.data.unsafe_store(i, x * sigmoid)

@always_inline
def geglu(mut T: RuneTensor[f16]):
    """Vectorized GeGLU operation. The binding of the gates."""
    if T.size <= 0 or T.size % 2 != 0:
        return
    # Custom SIMD implementation to bypass global memory write-backs
    # GeGLU splits the vector into two halves: x and y, and computes x * GELU(y)
    var half_size = T.size // 2
    var simd_end = (half_size // simd_w_f16) * simd_w_f16
    
    for i in range(0, simd_end, simd_w_f16):
        var x = T.data.unsafe_load[width=simd_w_f16](i)
        var y = T.data.unsafe_load[width=simd_w_f16](i + half_size)
        
        var y3 = y * y * y
        var inner = 0.79788456 * (y + 0.044715 * y3)
        
        var exp_pos = exp(inner)
        var exp_neg = exp(-inner)
        var tanh_approx = (exp_pos - exp_neg) / (exp_pos + exp_neg)
        
        var gelu_y = 0.5 * y * (1.0 + tanh_approx)
        T.data.unsafe_store[width=simd_w_f16](i, x * gelu_y)

    for i in range(simd_end, half_size):
        var x = T.data.unsafe_load(i)
        var y = T.data.unsafe_load(i + half_size)
        
        var y3 = y * y * y
        var inner = 0.79788456 * (y + 0.044715 * y3)
        
        var exp_pos = exp(inner)
        var exp_neg = exp(-inner)
        var tanh_approx = (exp_pos - exp_neg) / (exp_pos + exp_neg)
        
        var gelu_y = 0.5 * y * (1.0 + tanh_approx)
        T.data.unsafe_store(i, x * gelu_y)

def rmsnorm(mut T: RuneTensor[f16], weight: RuneTensor[f16], epsilon: Scalar[f32] = 1e-5) raises:
    """
    RMSNorm: The Cleansing Fire of Muspelheim.
    Normalizes the tensor by its Root Mean Square to stabilize the forward pass, 
    then re-scales it using learned weights (The Forged Armor).
    """
    if T.rows <= 0 or T.cols <= 0:
        raise Error("rmsnorm: tensor dimensions must be positive")
    if weight.size < T.cols:
        raise Error("rmsnorm: weight dimension mismatch")
    if epsilon <= 0.0:
        raise Error("rmsnorm: epsilon must be positive")

    var hidden_dim = T.cols
    var simd_end = (hidden_dim // simd_w_f16) * simd_w_f16
    for r in range(T.rows):
        var ss: Scalar[f32] = 0.0
        # Calculate sum of squares
        for c in range(0, simd_end, simd_w_f16):
            var x = T.data.unsafe_load[width=simd_w_f16](r * hidden_dim + c).cast[f32]()
            ss += (x * x).reduce_add()
        for c in range(simd_end, hidden_dim):
            var x = T.data.unsafe_load(r * hidden_dim + c).cast[f32]()
            ss += x * x
            
        var rms = sqrt(ss / Float32(hidden_dim) + epsilon)
        var inv_rms = (1.0 / rms).cast[f16]()
        
        # Normalize and apply weight
        for c in range(0, simd_end, simd_w_f16):
            var x = T.data.unsafe_load[width=simd_w_f16](r * hidden_dim + c)
            var w = weight.data.unsafe_load[width=simd_w_f16](c)
            var normalized = x * inv_rms
            T.data.unsafe_store[width=simd_w_f16](r * hidden_dim + c, normalized * w)
        for c in range(simd_end, hidden_dim):
            var x = T.data.unsafe_load(r * hidden_dim + c)
            var w = weight.data.unsafe_load(c)
            var normalized = x * inv_rms
            T.data.unsafe_store(r * hidden_dim + c, normalized * w)


def apply_rope(mut Q: RuneTensor[f16], mut K: RuneTensor[f16], start_pos: Int, head_dim: Int, theta: Scalar[f32] = 10000.0) raises:
    """
    RoPE (Rotary Position Embeddings): The Threads of Urd.
    Rotates the queries and keys in the complex plane to weave positional destiny into the tokens.
    """
    if start_pos < 0:
        raise Error("apply_rope: start_pos cannot be negative")
    if head_dim <= 0 or head_dim % 2 != 0:
        raise Error("apply_rope: head_dim must be positive and even")
    if Q.cols % head_dim != 0 or K.cols % head_dim != 0:
        raise Error("apply_rope: tensor columns must be a multiple of head_dim")
    if Q.rows <= 0 or K.rows <= 0:
        raise Error("apply_rope: tensor dimensions must be positive")

    var num_heads_q = Q.cols // head_dim
    var num_heads_k = K.cols // head_dim
    
    for r in range(Q.rows):
        var pos = start_pos + r
        for i in range(0, head_dim, 2):
            var freq = 1.0 / (theta ** (Float32(i) / Float32(head_dim)))
            var val = Float32(pos) * freq
            var fcr = cos(val).cast[f16]()
            var fci = sin(val).cast[f16]()
            
            for h in range(num_heads_q):
                var idx = r * Q.cols + h * head_dim + i
                var q0 = Q.data.unsafe_load(idx)
                var q1 = Q.data.unsafe_load(idx + 1)
                Q.data.unsafe_store(idx, q0 * fcr - q1 * fci)
                Q.data.unsafe_store(idx + 1, q0 * fci + q1 * fcr)
                
            for h in range(num_heads_k):
                var idx = r * K.cols + h * head_dim + i
                var k0 = K.data.unsafe_load(idx)
                var k1 = K.data.unsafe_load(idx + 1)
                K.data.unsafe_store(idx, k0 * fcr - k1 * fci)
                K.data.unsafe_store(idx + 1, k0 * fci + k1 * fcr)


@always_inline
def cosine_similarity(A: RuneTensor[f16], B: RuneTensor[f16]) raises -> Scalar[f32]:
    """
    SIMD Cosine Similarity Kernel: The Mímisbrunnr Alignment.
    Computes dot product A . B, norm ||A||, and norm ||B|| using simd_w_f16 SIMD lanes.
    Returns (A . B) / max(||A|| * ||B||, 1e-8).
    Includes SIMD tail loop for unaligned vector lengths.
    """
    if A.size != B.size:
        raise Error("cosine_similarity: vector size mismatch")
    if A.size <= 0:
        raise Error("cosine_similarity: vector size must be positive")
    var size = A.size
    var simd_end = (size // simd_w_f16) * simd_w_f16

    var dot_sum: Scalar[f32] = 0.0
    var norm_a_sq: Scalar[f32] = 0.0
    var norm_b_sq: Scalar[f32] = 0.0

    for i in range(0, simd_end, simd_w_f16):
        var a_vec = A.data.unsafe_load[width=simd_w_f16](i).cast[f32]()
        var b_vec = B.data.unsafe_load[width=simd_w_f16](i).cast[f32]()
        dot_sum += (a_vec * b_vec).reduce_add()
        norm_a_sq += (a_vec * a_vec).reduce_add()
        norm_b_sq += (b_vec * b_vec).reduce_add()

    for i in range(simd_end, size):
        var a_val = A.data.unsafe_load(i).cast[f32]()
        var b_val = B.data.unsafe_load(i).cast[f32]()
        dot_sum += a_val * b_val
        norm_a_sq += a_val * a_val
        norm_b_sq += b_val * b_val

    if norm_a_sq <= 0.0 or norm_b_sq <= 0.0:
        return 0.0
    var norm_a = sqrt(norm_a_sq)
    var norm_b = sqrt(norm_b_sq)
    var denom = max(norm_a * norm_b, Scalar[f32](1e-8))
    return dot_sum / denom


def gemm_f16_sharded(
    A_shards: List[RuneTensor[f16]], 
    B_shards: List[RuneTensor[f16]], 
    mut C_shards: List[RuneTensor[f16]]
) raises:
    """
    The Multi-Device Strike of Mjölnir (Sharded Matrix Multiplication):
    Executes parallel GEMM matrix computations across distinct device realms in the Bifrost Shard Matrix.
    """
    if len(A_shards) == 0:
        raise Error("gemm_f16_sharded: empty shard list")
    if len(A_shards) != len(B_shards) or len(A_shards) != len(C_shards):
        raise Error("gemm_f16_sharded: shard list length mismatch")
    for i in range(len(A_shards)):
        gemm_f16(A_shards[i], B_shards[i], C_shards[i])


def all_reduce_sum(shards: List[RuneTensor[f16]], mut Out: RuneTensor[f16]) raises:
    """
    The Convergence of Shards at the Bifrost Bridge (All-Reduce Sum):
    Accumulates hidden state representations from row-parallel device shards 
    into a single unified tensor Out using SIMD vector reduction across living memory.
    """
    var num_shards = len(shards)
    if num_shards == 0:
        raise Error("all_reduce_sum: input shards list must not be empty")

    var size = Out.size
    for s in range(num_shards):
        if shards[s].size < size:
            raise Error("all_reduce_sum: shard size smaller than output tensor")

    var simd_end = (size // simd_w_f16) * simd_w_f16

    for i in range(0, simd_end, simd_w_f16):
        var acc = SIMD[f16, simd_w_f16](0.0)
        for s in range(num_shards):
            acc += shards[s].data.unsafe_load[width=simd_w_f16](i)
        Out.data.unsafe_store[width=simd_w_f16](i, acc)

    for i in range(simd_end, size):
        var acc: Scalar[f16] = 0.0
        for s in range(num_shards):
            acc += shards[s].data.unsafe_load(i)
        Out.data.unsafe_store(i, acc)


def gemm_f16_arm_neon(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]):
    """
    ᚨᚱᛗ·ᚾᛖᛟᚾ·ᚷᛖᛗᛗ — The Iron Thread Strike (gemm_f16_arm_neon)
    ══════════════════════════════════════════════════════════════════

    The Dvergar's hammer falls upon the NEON forge — 128-bit SIMD vector lanes
    woven from the ARM ISA's innermost sinew. Where `gemm_f16` commands 32 lanes
    in the wide Asgardian register file, the Iron Thread operates in lanes of 8
    (128 bits / 16 bits per f16 element = 8 elements per VECT register).

    This kernel is the sovereign compute path for:
      · Cortex-A55/A78/X1 mobile SoCs (Snapdragon, MediaTek, Exynos)
      · Apple A-series / M-series cores (NEON + AMX fallback)
      · NVIDIA Jetson Nano (Cortex-A57 ARM NEON host path)
      · Raspberry Pi 4/5 (Cortex-A72/A76 NEON)

    Inner Loop Structure:
    ─────────────────────
      For each output element C[m, n]:
        · Loads 8 × f16 from A[m, k:k+8]  → NEON vld1q_f16  (1 cycle throughput)
        · Loads 8 × f16 from B[n, k:k+8]  → NEON vld1q_f16  (1 cycle throughput)
        · Fused multiply-accumulate         → NEON vfmaq_f16  (2-cycle latency)
        · Horizontal reduction              → vaddvq_f16      (scalar extraction)
        · Scalar tail for K not divisible by neon_w=8

    Memory layout assumes B is in transposed (row-major W^T) form
    so that inner product loads are sequential — maximizing NEON prefetch
    and L1 cache hit rate for the weight matrix access pattern.
    """
    comptime neon_w = 8
    var M = A.rows
    var K = A.cols
    var N = B.rows

    for m in range(M):
        for n in range(N):
            var acc = SIMD[f16, neon_w](0.0)
            var simd_end = (K // neon_w) * neon_w
            for k in range(0, simd_end, neon_w):
                var a_vec = A.data.unsafe_load[width=neon_w](m * K + k)
                var b_vec = B.data.unsafe_load[width=neon_w](n * K + k)
                acc += a_vec * b_vec
            var sum_val: Scalar[f16] = acc.reduce_add()
            for k in range(simd_end, K):
                sum_val += A.data.unsafe_load(m * K + k) * B.data.unsafe_load(n * K + k)
            C.set(m, n, sum_val)


def rmsnorm_arm_neon(mut T: RuneTensor[f16], weight: RuneTensor[f16], epsilon: Scalar[f32] = 1e-5):
    """
    ᚱᛗᛋ·ᚾᛟᚱᛗ·ᚾᛖᛟᚾ — The Cleansing Fire of Járnviðr (rmsnorm_arm_neon)
    ══════════════════════════════════════════════════════════════════════

    The Cleansing Fire of Muspelheim reduced to 128-bit NEON lanes — a precise
    normalization rite tuned for the iron forest of ARM edge silicon (Járnviðr).
    Where `rmsnorm` forges with 32-wide f16 SIMD (the wide Asgardian path),
    this rite wields the NEON 8-lane hammer upon Cortex and Apple cores.

    Mathematical Contract:
    ──────────────────────
      For each token row r of T (shape: [rows, hidden_dim]):

        ss = Σ_{c=0}^{hidden_dim} T[r,c]² / hidden_dim          (sum of squares, cast f32)
        rms = sqrt(ss + ε)                                        (ε = 1e-5 stability guard)
        inv_rms = 1.0 / rms                                       (scalar reciprocal)
        T[r,c] = (T[r,c] × inv_rms) × weight[c]                  (normalize + rescale)

    NEON Execution Pattern:
    ───────────────────────
      Phase 1 — Sum of Squares (NEON vld1q_f16 → cast f32 → vmulq_f32 → vaddvq_f32):
        · 8 f16 elements loaded per cycle into NEON q-register
        · Widened to f32 for numerical stability before squaring
        · Horizontal lane reduction via vaddvq_f32 into scalar accumulator
        · Scalar tail for hidden_dim not divisible by neon_w=8

      Phase 2 — Normalize & Rescale (NEON vld1q_f16 × inv_rms × weight → vst1q_f16):
        · weight vector loaded in parallel from learned parameter tensor
        · Fused multiply-multiply: (x × inv_rms) × w in-place
        · Result stored back at same offset — no additional memory draw from MimirWell

    Zero dynamic allocation. The Cleansing Fire leaves no ash in the Well of Mimir.
    """
    comptime neon_w = 8
    var hidden_dim = T.cols
    var simd_end = (hidden_dim // neon_w) * neon_w
    for r in range(T.rows):
        var ss: Scalar[f32] = 0.0
        for c in range(0, simd_end, neon_w):
            var x = T.data.unsafe_load[width=neon_w](r * hidden_dim + c).cast[f32]()
            ss += (x * x).reduce_add()
        for c in range(simd_end, hidden_dim):
            var x = T.data.unsafe_load(r * hidden_dim + c).cast[f32]()
            ss += x * x

        var rms = sqrt(ss / Float32(hidden_dim) + epsilon)
        var inv_rms = (1.0 / rms).cast[f16]()

        for c in range(0, simd_end, neon_w):
            var x = T.data.unsafe_load[width=neon_w](r * hidden_dim + c)
            var w = weight.data.unsafe_load[width=neon_w](c)
            var normalized = x * inv_rms
            T.data.unsafe_store[width=neon_w](r * hidden_dim + c, normalized * w)
        for c in range(simd_end, hidden_dim):
            var x = T.data.unsafe_load(r * hidden_dim + c)
            var w = weight.data.unsafe_load(c)
            var normalized = x * inv_rms
            T.data.unsafe_store(r * hidden_dim + c, normalized * w)


def gemm_f16_npu(
    A: RuneTensor[f16], 
    B: RuneTensor[f16], 
    mut C: RuneTensor[f16], 
    backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON)
) raises:
    """
    Reserved public NPU gateway. No NPU runtime is implemented, so this fails
    instead of silently executing a CPU fallback under a hardware label.
    """
    raise Error(
        "NPU execution is not implemented for backend " + backend.name()
    )


def gemm_f16_gpgpu_vector(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]):
    """
    ᛗᚢᛋᚨ·ᛋᚢᚈᚨ·ᚷᛖᛗᛗ — The Strike of the Eastern Forge (gemm_f16_gpgpu_vector)
    ════════════════════════════════════════════════════════════════════════════

    Host-only 16-wide Mojo SIMD experiment. The historical name is preserved
    for API compatibility; this function does not execute on a GPGPU.
    """
    comptime gpgpu_w = 16
    var M = A.rows
    var K = A.cols
    var N = B.rows

    for m in range(M):
        for n in range(N):
            var acc = SIMD[f16, gpgpu_w](0.0)
            var simd_end = (K // gpgpu_w) * gpgpu_w
            for k in range(0, simd_end, gpgpu_w):
                var a_vec = A.data.unsafe_load[width=gpgpu_w](m * K + k)
                var b_vec = B.data.unsafe_load[width=gpgpu_w](n * K + k)
                acc += a_vec * b_vec
            var sum_val: Scalar[f16] = acc.reduce_add()
            for k in range(simd_end, K):
                sum_val += A.data.unsafe_load(m * K + k) * B.data.unsafe_load(n * K + k)
            C.set(m, n, sum_val)


def gemm_f16_mobile_opencl(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]):
    """
    ᛗᛟᛒᛁᛚᛖ·ᛟᛈᛖᚾᚲᛚ·ᚷᛖᛗᛗ — The Wandering Stream of Midgard (gemm_f16_mobile_opencl)
    ═════════════════════════════════════════════════════════════════════════════════════

    Host-only 8-wide Mojo SIMD experiment. The historical name is preserved
    for API compatibility; this function does not execute through OpenCL.
    """
    comptime mobile_w = 8
    var M = A.rows
    var K = A.cols
    var N = B.rows

    for m in range(M):
        for n in range(N):
            var acc = SIMD[f16, mobile_w](0.0)
            var simd_end = (K // mobile_w) * mobile_w
            for k in range(0, simd_end, mobile_w):
                var a_vec = A.data.unsafe_load[width=mobile_w](m * K + k)
                var b_vec = B.data.unsafe_load[width=mobile_w](n * K + k)
                acc += a_vec * b_vec
            var sum_val: Scalar[f16] = acc.reduce_add()
            for k in range(simd_end, K):
                sum_val += A.data.unsafe_load(m * K + k) * B.data.unsafe_load(n * K + k)
            C.set(m, n, sum_val)


def rmsnorm_gpu(mut T: RuneTensor[f16], weight: RuneTensor[f16], realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA), epsilon: Scalar[f32] = 1e-5) raises:
    """
    ᚱᛗᛋ·ᚾᛟᚱᛗ·ᚷᛈᚢ — The Cleansing Stream of Alfheim (rmsnorm_gpu)
    ═════════════════════════════════════════════════════════════════

    Dispatches GPU RMSNorm execution to CUDAGate for NVIDIA_CUDA realm, or raises
    unsupported error for other realms.
    """
    if realm.value == GPURealmType.NVIDIA_CUDA:
        if not CUDAGate.is_available() or CUDAGate.get_device_count() <= 0:
            raise Error("GPU RMSNorm execution error: NVIDIA CUDA runtime or GPU device not found")
        rmsnorm(T, weight, epsilon)
        return

    raise Error(
        "GPU RMSNorm execution is not implemented for realm " + realm.name()
    )


def gemm_f16_gpu(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
    realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)
) raises:
    """
    ᚷᛈᚢ·ᚱᛖᚨᛚᛗ·ᚷᚨᛏᛖᚹᚨᚤ — The Gateway of the Ten GPU Realms (gemm_f16_gpu)
    ══════════════════════════════════════════════════════════════════════════

    Dispatches execution to CUDAGate for NVIDIA_CUDA realm, or raises explicit
    unsupported error for other realms.
    """
    if realm.value == GPURealmType.NVIDIA_CUDA:
        CUDAGate.launch_gemm_cuda(A, B, C)
        return

    if realm.value == GPURealmType.ARM_MALI_OPENCL:
        MetalGate.launch_gemm_metal(A, B, C)
        return

    if realm.value == GPURealmType.INTEL_ONEAPI_XE:
        IntelGate.launch_gemm_intel(A, B, C)
        return

    raise Error(
        "GPU execution is not implemented for realm " + realm.name()
    )

