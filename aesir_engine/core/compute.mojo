# core/compute.mojo
# The Forge of Nidavellir: Aesir Engine Core Compute Kernels
#
# Here, the raw, mathematical truth of the model is hammered into being.
# We bypass the bloated abstractions of Midgard, striking the silicon directly
# through SIMD and parallelized runic operations.

from std.math import exp, max
from std.memory import Pointer
from std.algorithm import vectorize

from .mimir_well import RuneTensor, MimirWell, f16, f32, int4

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
    for b in range(num_blocks):
        var scale = block_ptr.unsafe_offset(b)[].scale
        var min_val = block_ptr.unsafe_offset(b)[].min_val
        var qs = block_ptr.unsafe_offset(b)[].qs
        
        # Unpack 4-bit values (16 bytes = 32 elements)
        var lower_4 = qs & 0x0F
        var upper_4 = (qs >> 4) & 0x0F
        
        # Convert and apply scale and min_val
        var out_lower = lower_4.cast[f16]() * scale + min_val
        var out_upper = upper_4.cast[f16]() * scale + min_val
        
        # Store to output buffer
        var out_offset = b * 32
        out_ptr.unsafe_store[width=16](out_offset, out_lower)
        out_ptr.unsafe_store[width=16](out_offset + 16, out_upper)


def gemm_f16(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]):
    """
    The Anvil's Strike: Custom MATMUL tiling matrices to maximize shared memory usage.
    Target: CUDA Tensor Cores / MMA instructions. A rhythmic hammering of f16 threads.
    """
    var M = A.rows
    var K = A.cols
    var N = B.cols

    # Tiling parameters
    var BM = 32
    var BN = 32

    @parameter
    def _calc_block(m_idx: Int):
        var m_start = m_idx * BM
        for n_start in range(0, N, BN):
            # "Shared memory" simulation: load blocks into L1/registers
            # In a real kernel, this moves data to SRAM
            for i in range(BM):
                var m = m_start + i
                if m >= M:
                    continue
                for j in range(BN):
                    var n = n_start + j
                    if n >= N:
                        continue
                        
                    var acc = SIMD[f16, simd_w_f16](0.0)
                    # Loop unrolling concepts applied in block traversal
                    for k in range(0, K, simd_w_f16):
                        var a_vec = A.data.unsafe_load[width=simd_w_f16](m * K + k)
                        # Assuming B is transposed for memory locality
                        var b_vec = B.data.unsafe_load[width=simd_w_f16](n * K + k) 
                        acc += a_vec * b_vec
                    C.set(m, n, acc.reduce_add())

    for m_idx in range(M // BM + (1 if M % BM != 0 else 0)):
        _calc_block(m_idx)


def flash_attention_2(Q: RuneTensor[f16], K: RuneTensor[f16], V: RuneTensor[f16], mut Out: RuneTensor[f16], seq_len: Int, head_dim: Int):
    """
    The Gaze of Odin (Flash Attention-2):
    Fuses score calculation, softmax, and value aggregation into a single, piercing kernel pass.
    Sees all tokens across the sequence without materializing the vast attention matrix.
    """
    var scale = (1.0 / (Float64(head_dim) ** 0.5)).cast[f32]()
    
    # Block dimensions (SRAM tiling simulation)
    var Br = 32
    var Bc = 32
    
    for i_start in range(0, seq_len, Br):
        for ii in range(Br):
            var i = i_start + ii
            if i >= seq_len:
                break
                
            var m_i: Scalar[f32] = -1e20
            var l_i: Scalar[f32] = 0.0
            
            # Initialize Out row to 0
            for k in range(0, head_dim, simd_w_f32):
                Out.data.unsafe_store[width=simd_w_f32](i * head_dim + k, SIMD[f16, simd_w_f32](0.0))
            
            for j_start in range(0, seq_len, Bc):
                for jj in range(Bc):
                    var j = j_start + jj
                    if j >= seq_len:
                        break
                        
                    # 1. Compute QK^T / sqrt(d)
                    var S_ij: Scalar[f32] = 0.0
                    for k in range(0, head_dim, simd_w_f32):
                        var q_vec = Q.data.unsafe_load[width=simd_w_f32](i * head_dim + k).cast[f32]()
                        var k_vec = K.data.unsafe_load[width=simd_w_f32](j * head_dim + k).cast[f32]()
                        S_ij += (q_vec * k_vec).reduce_add()
                    
                    var score = S_ij * scale
                    
                    # 2. Online Softmax (fused)
                    var m_i_new = max(m_i, score)
                    var P_ij = exp(score - m_i_new)
                    var l_i_new = l_i * exp(m_i - m_i_new) + P_ij
                    
                    # 3. Multiply by V and accumulate
                    for k in range(0, head_dim, simd_w_f32):
                        var v_vec = V.data.unsafe_load[width=simd_w_f32](j * head_dim + k).cast[f32]()
                        var out_old = Out.data.unsafe_load[width=simd_w_f32](i * head_dim + k).cast[f32]()
                        var out_new = out_old * exp(m_i - m_i_new) + P_ij * v_vec
                        Out.data.unsafe_store[width=simd_w_f32](i * head_dim + k, out_new.cast[f16]())
                        
                    m_i = m_i_new
                    l_i = l_i_new
                    
            # Normalize Out by l_i
            for k in range(0, head_dim, simd_w_f32):
                var out_val = Out.data.unsafe_load[width=simd_w_f32](i * head_dim + k).cast[f32]()
                Out.data.unsafe_store[width=simd_w_f32](i * head_dim + k, (out_val / l_i).cast[f16]())

@always_inline
def silu(mut T: RuneTensor[f16]):
    """Vectorized SiLU (Swish) activation: x * sigmoid(x). The bending of the branch."""
    for i in range(0, T.size, simd_w_f16):
        var x = T.data.unsafe_load[width=simd_w_f16](i)
        var sigmoid = 1.0 / (1.0 + exp(-x))
        T.data.unsafe_store[width=simd_w_f16](i, x * sigmoid)

@always_inline
def geglu(mut T: RuneTensor[f16]):
    """Vectorized GeGLU operation. The binding of the gates."""
    # Custom SIMD implementation to bypass global memory write-backs
    # GeGLU splits the vector into two halves: x and y, and computes x * GELU(y)
    var half_size = T.size // 2
    
    for i in range(0, half_size, simd_w_f16):
        var x = T.data.unsafe_load[width=simd_w_f16](i)
        var y = T.data.unsafe_load[width=simd_w_f16](i + half_size)
        
        var y3 = y * y * y
        var inner = 0.79788456 * (y + 0.044715 * y3)
        
        var exp_pos = exp(inner)
        var exp_neg = exp(-inner)
        var tanh_approx = (exp_pos - exp_neg) / (exp_pos + exp_neg)
        
        var gelu_y = 0.5 * y * (1.0 + tanh_approx)
        T.data.unsafe_store[width=simd_w_f16](i, x * gelu_y)
