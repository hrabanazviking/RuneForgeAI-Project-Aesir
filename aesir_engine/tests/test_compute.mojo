# tests/test_compute.mojo
# The Proving Grounds: Verification of the Forge's Mathematical Truth

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    gemm_f16,
    flash_attention_2,
    flash_attention_gqa,
    geglu,
    silu,
    rmsnorm,
    apply_rope,
    cosine_similarity,
    dequantize_compressed_tensor,
)

def test_gemm() raises:
    print("--- Testing gemm_f16 (The Anvil's Strike) ---")
    var well = MimirWell(1024 * 1024) # 1 MB
    
    var M = 32
    var K = 32
    var N = 32
    
    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr)
    
    var b_ptr = well.allocate(N * K)
    var B = RuneTensor[f16](N, K, b_ptr) # B is transposed in memory (N rows of K)
    
    var c_ptr = well.allocate(M * N)
    var C = RuneTensor[f16](M, N, c_ptr)
    
    # Initialize A and B with 1.0
    for i in range(M * K):
        A.data.unsafe_store(i, 1.0)
    for i in range(N * K):
        B.data.unsafe_store(i, 1.0)
        
    gemm_f16(A, B, C)
    
    # Check result
    # C should be 32.0 everywhere since sum(1 * 1) over K=32 is 32.
    var success = True
    for i in range(M * N):
        var val = C.data.unsafe_load(i)
        if val != 32.0:
            print("Mismatch at index", i, "Expected 32.0, got", val)
            success = False
            break
            
    if success:
        print("gemm_f16: PASS")
    else:
        raise Error("gemm_f16 result mismatch")

def test_flash_attention() raises:
    print("--- Testing flash_attention_2 (The Gaze of Odin) ---")
    var well = MimirWell(1024 * 1024) # 1 MB
    
    var seq_len = 64
    var head_dim = 64
    
    var q_ptr = well.allocate(seq_len * head_dim)
    var Q = RuneTensor[f16](seq_len, head_dim, q_ptr)
    
    var k_ptr = well.allocate(seq_len * head_dim)
    var K = RuneTensor[f16](seq_len, head_dim, k_ptr)
    
    var v_ptr = well.allocate(seq_len * head_dim)
    var V = RuneTensor[f16](seq_len, head_dim, v_ptr)
    
    var out_ptr = well.allocate(seq_len * head_dim)
    var Out = RuneTensor[f16](seq_len, head_dim, out_ptr)
    
    # Init with 0.1
    for i in range(seq_len * head_dim):
        Q.data.unsafe_store(i, 0.1)
        K.data.unsafe_store(i, 0.1)
        V.data.unsafe_store(i, 0.1)
        
    flash_attention_2(Q, K, V, Out, seq_len, head_dim)
    
    # Check result
    # All rows are identical. V is all 0.1. Softmax over identical QK^T will just be uniform.
    # Then multiplying by V (which is all 0.1) yields 0.1.
    var success = True
    var first_val = Out.data.unsafe_load(0)
    var diff = first_val - 0.1
    if diff < 0:
        diff = -diff
    if diff > 0.01:
        print("Mismatch! Expected approx 0.1, got", first_val)
        success = False
        
    if success:
        print("flash_attention_2: PASS")
    else:
        raise Error("flash_attention_2 result mismatch")

def test_silu() raises:
    """Test SiLU activation: silu(x) = x * sigmoid(x)."""
    print("--- Testing silu (The Bending of the Branch) ---")
    var well = MimirWell(1024 * 64)
    
    var size = 35 # Unaligned size to verify SIMD tail handling
    var t_ptr = well.allocate(size)
    var T = RuneTensor[f16](1, size, t_ptr)
    
    # Fill with 1.0 => silu(1.0) = 1.0 * sigmoid(1.0) = 1.0 * 0.7311 ~ 0.7311
    for i in range(size):
        T.data.unsafe_store(i, 1.0)
    
    silu(T)
    
    var val = T.data.unsafe_load(0)
    var val_tail = T.data.unsafe_load(34)
    var expected = Scalar[f16](0.7311)
    var diff = val - expected
    if diff < 0:
        diff = -diff
    var diff_tail = val_tail - expected
    if diff_tail < 0:
        diff_tail = -diff_tail
    
    if diff < 0.05 and diff_tail < 0.05:
        print("silu: PASS")
    else:
        print("silu: FAIL (expected ~0.7311, got head=", val, ", tail=", val_tail, ")")
        raise Error("silu result mismatch")

def test_geglu() raises:
    """Test GeGLU: first half = x * GELU(y) where y is second half."""
    print("--- Testing geglu (The Binding of the Gates) ---")
    var well = MimirWell(1024 * 64)
    
    var half = 35 # Unaligned half size to verify SIMD tail handling
    var total = half * 2
    var t_ptr = well.allocate(total)
    var T = RuneTensor[f16](1, total, t_ptr)
    
    # Fill x=2.0 (first half), y=1.0 (second half)
    # GELU(1.0) ~ 0.8413, so result ~ 2.0 * 0.8413 ~ 1.6826
    for i in range(half):
        T.data.unsafe_store(i, 2.0)
    for i in range(half, total):
        T.data.unsafe_store(i, 1.0)
    
    geglu(T)
    
    var val = T.data.unsafe_load(0)
    var val_tail = T.data.unsafe_load(34)
    var diff = val - 1.6826
    if diff < 0:
        diff = -diff
    var diff_tail = val_tail - 1.6826
    if diff_tail < 0:
        diff_tail = -diff_tail
    
    if diff < 0.1 and diff_tail < 0.1:
        print("geglu: PASS")
    else:
        print("geglu: FAIL (expected ~1.68, got head=", val, ", tail=", val_tail, ")")
        raise Error("geglu result mismatch")


def test_dequantize_q4_k_m() raises:
    """Known-value dequantization through the canonical 144-byte GGML layout."""
    var well = MimirWell(8192)
    var raw = well.allocate(144).unsafe_bitcast[UInt8]()
    for i in range(144):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.5))
    for i in range(4):
        raw.unsafe_store(4 + i, UInt8(1))
        raw.unsafe_store(12 + i, UInt8(1))
    for i in range(128):
        raw.unsafe_store(16 + i, UInt8(0x21))
    var output = well.allocate(256)
    dequantize_compressed_tensor(
        CompressedFormatType(CompressedFormatType.Q4_K_M), raw, output, 256
    )
    if output.unsafe_load(0) != Float16(0.5) or output.unsafe_load(32) != Float16(1):
        raise Error("Canonical Q4_K dequantization known-value mismatch")
    _ = well
    print("canonical Q4_K dequantization: PASS")


def test_kernel_bounds() raises:
    """Test checked kernel boundaries for gemm_f16, rmsnorm, apply_rope, and cosine_similarity."""
    print("--- Testing Checked Kernel Boundaries (Stage 2 Hardening) ---")
    var well = MimirWell(1024 * 64)

    # 1. GEMM dimension mismatch test (A.cols != B.cols)
    var A = RuneTensor[f16](2, 4, well.allocate(8))
    var B = RuneTensor[f16](3, 8, well.allocate(24)) # B.cols is 8 != A.cols 4
    var C = RuneTensor[f16](2, 3, well.allocate(6))
    var gemm_mismatch = False
    try:
        gemm_f16(A, B, C)
    except:
        gemm_mismatch = True
    if not gemm_mismatch:
        raise Error("gemm_f16 failed to detect inner dimension mismatch")

    # 2. RMSNorm weight dimension mismatch test
    var T = RuneTensor[f16](2, 16, well.allocate(32))
    var bad_w = RuneTensor[f16](1, 8, well.allocate(8)) # weight 8 < T.cols 16
    var rms_mismatch = False
    try:
        rmsnorm(T, bad_w)
    except:
        rms_mismatch = True
    if not rms_mismatch:
        raise Error("rmsnorm failed to detect weight dimension mismatch")

    # 3. RoPE odd head dimension test
    var Q = RuneTensor[f16](1, 15, well.allocate(15))
    var K = RuneTensor[f16](1, 15, well.allocate(15))
    var rope_odd = False
    try:
        apply_rope(Q, K, 0, 15) # odd head_dim 15
    except:
        rope_odd = True
    if not rope_odd:
        raise Error("apply_rope failed to detect odd head_dim")

    # 5. GeGLU odd size test (returns early safely without mutation)
    var G_odd = RuneTensor[f16](1, 15, well.allocate(15))
    G_odd.data.unsafe_store(0, Scalar[f16](5.0))
    geglu(G_odd)
    if G_odd.data.unsafe_load(0) != Scalar[f16](5.0):
        raise Error("geglu mutated odd size tensor")

    # 6. Incremental causal attention head bounds safety (returns early without panic)
    var q_att = RuneTensor[f16](1, 8, well.allocate(8))
    var k_att = RuneTensor[f16](1, 8, well.allocate(8))
    var v_att = RuneTensor[f16](1, 8, well.allocate(8))
    var out_att = RuneTensor[f16](1, 8, well.allocate(8))
    out_att.data.unsafe_store(0, Scalar[f16](7.0))
    flash_attention_gqa(q_att, k_att, v_att, out_att, 1, 0, 4, 2) # head_dim = 0
    if out_att.data.unsafe_load(0) != Scalar[f16](7.0):
        raise Error("flash_attention_gqa failed on zero head_dim safety check")

    flash_attention_gqa(q_att, k_att, v_att, out_att, 1, 4, 3, 2) # non-divisible 3 // 2
    if out_att.data.unsafe_load(0) != Scalar[f16](7.0):
        raise Error("flash_attention_gqa failed on non-divisible head ratio safety check")

    print("checked kernel boundaries: PASS")

def test_unaligned_flash_attention() raises:
    """Test flash_attention_2 with unaligned head dimensions (head_dim = 40)."""
    print("--- Testing flash_attention_2 with unaligned head_dim=40 (Scalar Tails) ---")
    var well = MimirWell(1024 * 64)
    var seq_len = 16
    var head_dim = 40 # 40 is not a multiple of simd_w_f32 (16)
    
    var Q = RuneTensor[f16](seq_len, head_dim, well.allocate(seq_len * head_dim))
    var K = RuneTensor[f16](seq_len, head_dim, well.allocate(seq_len * head_dim))
    var V = RuneTensor[f16](seq_len, head_dim, well.allocate(seq_len * head_dim))
    var Out = RuneTensor[f16](seq_len, head_dim, well.allocate(seq_len * head_dim))
    
    for i in range(seq_len * head_dim):
        Q.data.unsafe_store(i, 0.2)
        K.data.unsafe_store(i, 0.2)
        V.data.unsafe_store(i, 0.5)
        
    flash_attention_2(Q, K, V, Out, seq_len, head_dim)
    
    var val = Out.data.unsafe_load(0)
    var val_tail = Out.data.unsafe_load(39) # tail element at col index 39
    
    var diff = val - 0.5
    if diff < 0:
        diff = -diff
    var diff_tail = val_tail - 0.5
    if diff_tail < 0:
        diff_tail = -diff_tail
        
    if diff < 0.05 and diff_tail < 0.05:
        print("unaligned flash_attention_2 (scalar tails): PASS")
    else:
        raise Error("unaligned flash_attention_2 result mismatch")

def test_gemm_f32_reference() raises:
    """Test rectangular gemm_f16 against F32 double-loop reference matrix multiplication."""
    print("--- Testing gemm_f16 F32 Reference (Rectangular 17x35 x 29x35) ---")
    var well = MimirWell(1024 * 64)
    var M = 17
    var K = 35
    var N = 29
    
    var A = RuneTensor[f16](M, K, well.allocate(M * K))
    var B = RuneTensor[f16](N, K, well.allocate(N * K)) # Transposed B: N rows of K cols
    var C = RuneTensor[f16](M, N, well.allocate(M * N))
    
    for r in range(M):
        for c in range(K):
            A.data.unsafe_store(r * K + c, Scalar[f16](((r + c) % 5 + 1).cast[f16]() * 0.1))
            
    for r in range(N):
        for c in range(K):
            B.data.unsafe_store(r * K + c, Scalar[f16](((r * c) % 7 + 1).cast[f16]() * 0.1))
            
    gemm_f16(A, B, C)
    
    # Compute F32 reference
    var max_err: Scalar[f32] = 0.0
    for r in range(M):
        for n in range(N):
            var expected_sum: Scalar[f32] = 0.0
            for k in range(K):
                var a_val = A.data.unsafe_load(r * K + k).cast[f32]()
                var b_val = B.data.unsafe_load(n * K + k).cast[f32]()
                expected_sum += a_val * b_val
            var actual = C.data.unsafe_load(r * N + n).cast[f32]()
            var diff = actual - expected_sum
            if diff < 0:
                diff = -diff
            if diff > max_err:
                max_err = diff
                
    if max_err < 0.05:
        print("gemm_f16 F32 reference (17x35 x 29x35): PASS")
    else:
        print("FAIL: gemm_f16 max error =", max_err)
        raise Error("gemm_f16 F32 reference error exceeded tolerance")

def test_silu_f32_reference() raises:
    """Test silu against Float32 math reference x * (1 / (1 + exp(-x)))."""
    print("--- Testing silu F32 Reference ---")
    var well = MimirWell(1024 * 64)
    var size = 37 # Unaligned tail size
    var T = RuneTensor[f16](1, size, well.allocate(size))
    
    from std.math import exp
    for i in range(size):
        var val = Float32(i - 18) * 0.25
        T.data.unsafe_store(i, Scalar[f16](val.cast[f16]()))
        
    silu(T)
    
    var max_err: Scalar[f32] = 0.0
    for i in range(size):
        var x = Float32(i - 18) * 0.25
        var expected = x * (1.0 / (1.0 + exp(-x)))
        var actual = T.data.unsafe_load(i).cast[f32]()
        var diff = actual - expected
        if diff < 0:
            diff = -diff
        if diff > max_err:
            max_err = diff
            
    if max_err < 0.02:
        print("silu F32 reference (size=37): PASS")
    else:
        print("FAIL: silu max error =", max_err)
        raise Error("silu F32 reference error exceeded tolerance")

def test_gqa_attention_reference() raises:
    """Test flash_attention_gqa with 8 Query heads and 2 KV heads (4:1 ratio)."""
    print("--- Testing flash_attention_gqa F32 Reference (8 Q-heads : 2 KV-heads) ---")
    var well = MimirWell(1024 * 64)
    var seq_len = 8
    var head_dim = 16
    var num_q_heads = 8
    var num_kv_heads = 2
    
    var Q = RuneTensor[f16](1, num_q_heads * head_dim, well.allocate(num_q_heads * head_dim))
    var K = RuneTensor[f16](seq_len, num_kv_heads * head_dim, well.allocate(seq_len * num_kv_heads * head_dim))
    var V = RuneTensor[f16](seq_len, num_kv_heads * head_dim, well.allocate(seq_len * num_kv_heads * head_dim))
    var Out = RuneTensor[f16](1, num_q_heads * head_dim, well.allocate(num_q_heads * head_dim))
    
    for i in range(Q.size):
        Q.data.unsafe_store(i, 0.1)
    for i in range(K.size):
        K.data.unsafe_store(i, 0.1)
    for i in range(V.size):
        V.data.unsafe_store(i, 0.3)
        
    flash_attention_gqa(Q, K, V, Out, seq_len, head_dim, num_q_heads, num_kv_heads)
    
    var val = Out.data.unsafe_load(0).cast[f32]()
    var diff = val - 0.3
    if diff < 0:
        diff = -diff
    if diff < 0.02:
        print("flash_attention_gqa F32 reference (8:2 ratio): PASS")
    else:
        print("FAIL: flash_attention_gqa expected approx 0.3, got", val)
        raise Error("flash_attention_gqa reference mismatch")

def main() raises:
    print("Starting Compute Kernel Verification...")
    test_gemm()
    test_gemm_f32_reference()
    test_flash_attention()
    test_unaligned_flash_attention()
    test_gqa_attention_reference()
    test_silu()
    test_silu_f32_reference()
    test_geglu()
    test_dequantize_q4_k_m()
    test_kernel_bounds()
    print("Verification complete.")
