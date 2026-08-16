# tests/test_sharding.mojo
# Verification of logical host tensor partitioning helpers

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from std.math import abs

from core.mimir_well import RuneTensor, MimirWell, DeviceTopology, ShardTensor, shard_split_cols, shard_split_rows, f16, f32
from core.compute import gemm_f16, gemm_f16_sharded, all_reduce_sum


def test_device_topology() raises:
    print("--- Testing configured logical host topology ---")
    var topo = DeviceTopology(2)
    if topo.num_devices != 2:
        raise Error("DeviceTopology num_devices mismatch")
    if len(topo.device_names) != 2:
        raise Error("DeviceTopology device_names length mismatch")
    if topo.device_names[0] != "host:0" or topo.device_names[1] != "host:1":
        raise Error("DeviceTopology device name mismatch")
    print("logical host topology: PASS")


def test_shard_tensor() raises:
    print("--- Testing ShardTensor (The Thread Slice) ---")
    var alloc_ptr = alloc(Layout[Scalar[f16]](count=4)).unsafe_leak()
    var tensor = RuneTensor[f16](2, 2, alloc_ptr, False)
    var shard = ShardTensor(1, tensor)
    if shard.device_id != 1:
        raise Error("ShardTensor device_id mismatch")
    if shard.tensor.rows != 2 or shard.tensor.cols != 2:
        raise Error("ShardTensor inner tensor shape mismatch")
    alloc_ptr.unsafe_free()
    print("ShardTensor: PASS")


def test_tensor_partitioning() raises:
    print("--- Testing Tensor Partitioning (Rows & Cols) ---")
    var M = 4
    var N = 8
    var alloc_ptr = alloc(Layout[Scalar[f16]](count=M * N)).unsafe_leak()
    var T = RuneTensor[f16](M, N, alloc_ptr, False)

    for r in range(M):
        for c in range(N):
            T.set(r, c, Scalar[f16](Float32(r * N + c)))

    # Test Row Split (4x8 matrix split across 2 shards -> two 2x8 shards)
    var row_shards = shard_split_rows(T, 2)
    if len(row_shards) != 2:
        raise Error("shard_split_rows returned wrong shard count")
    if row_shards[0].rows != 2 or row_shards[0].cols != 8:
        raise Error("shard_split_rows shard 0 shape mismatch")
    if row_shards[1].rows != 2 or row_shards[1].cols != 8:
        raise Error("shard_split_rows shard 1 shape mismatch")
    if row_shards[0].get(0, 0) != Scalar[f16](0.0) or row_shards[1].get(0, 0) != Scalar[f16](16.0):
        raise Error("shard_split_rows data verification failed")

    # Test Col Split (4x8 matrix split across 2 shards -> two 4x4 shards)
    var col_shards = shard_split_cols(T, 2)
    if len(col_shards) != 2:
        raise Error("shard_split_cols returned wrong shard count")
    if col_shards[0].rows != 4 or col_shards[0].cols != 4:
        raise Error("shard_split_cols shard 0 shape mismatch")
    if col_shards[1].rows != 4 or col_shards[1].cols != 4:
        raise Error("shard_split_cols shard 1 shape mismatch")
    if col_shards[0].get(0, 0) != Scalar[f16](0.0) or col_shards[1].get(0, 0) != Scalar[f16](4.0):
        raise Error("shard_split_cols data verification failed")

    alloc_ptr.unsafe_free()
    print("Tensor Partitioning (Rows/Cols): PASS")


def test_all_reduce_sum() raises:
    print("--- Testing all_reduce_sum (The Convergence of Shards) ---")
    var dim = 8
    var ptr1 = alloc(Layout[Scalar[f16]](count=dim)).unsafe_leak()
    var ptr2 = alloc(Layout[Scalar[f16]](count=dim)).unsafe_leak()
    var out_ptr = alloc(Layout[Scalar[f16]](count=dim)).unsafe_leak()

    var s1 = RuneTensor[f16](1, dim, ptr1, False)
    var s2 = RuneTensor[f16](1, dim, ptr2, False)
    var out_t = RuneTensor[f16](1, dim, out_ptr, False)

    for i in range(dim):
        s1.set(0, i, Scalar[f16](Float32(i + 1)))
        s2.set(0, i, Scalar[f16](Float32((i + 1) * 10)))

    var shards = List[RuneTensor[f16]]()
    shards.append(s1.copy())
    shards.append(s2.copy())

    all_reduce_sum(shards, out_t)

    for i in range(dim):
        var expected = Float32((i + 1) * 11)
        var actual = Float32(out_t.get(0, i))
        if abs(actual - expected) > 1e-3:
            raise Error("all_reduce_sum value mismatch at index " + String(i))

    # Shard size mismatch rejection check
    var bad_ptr = alloc(Layout[Scalar[f16]](count=dim - 2)).unsafe_leak()
    var bad_shard = RuneTensor[f16](1, dim - 2, bad_ptr, False)
    var bad_shards = List[RuneTensor[f16]]()
    bad_shards.append(bad_shard.copy())
    var size_mismatch = False
    try:
        all_reduce_sum(bad_shards, out_t)
    except:
        size_mismatch = True
    bad_ptr.unsafe_free()
    if not size_mismatch:
        raise Error("all_reduce_sum failed to detect shard size mismatch")

    # Empty shards list rejection check
    var empty_shards = List[RuneTensor[f16]]()
    var empty_rejected = False
    try:
        all_reduce_sum(empty_shards, out_t)
    except error:
        empty_rejected = True
        if "input shards list must not be empty" not in String(error):
            raise Error("all_reduce_sum empty shards rejection omitted expected error text")
    if not empty_rejected:
        raise Error("all_reduce_sum failed to reject empty input shards list")

    ptr1.unsafe_free()
    ptr2.unsafe_free()
    out_ptr.unsafe_free()
    print("all_reduce_sum: PASS")


def test_sharded_gemm_parity() raises:
    print("--- Testing sequential host-shard GEMM parity ---")
    # Single-device reference: A (1x32), B (32x32), C_ref (1x32)
    var M = 1
    var K = 32
    var N = 32
    var P = 2 # 2 shards

    var a_ptr = alloc(Layout[Scalar[f16]](count=M * K)).unsafe_leak()
    var b_ptr = alloc(Layout[Scalar[f16]](count=N * K)).unsafe_leak()
    var c_ref_ptr = alloc(Layout[Scalar[f16]](count=M * N)).unsafe_leak()

    var A = RuneTensor[f16](M, K, a_ptr, False)
    var B = RuneTensor[f16](N, K, b_ptr, False)
    var C_ref = RuneTensor[f16](M, N, c_ref_ptr, False)

    for k in range(K):
        A.set(0, k, Scalar[f16](Float32(k + 1) * 0.1))
    for n in range(N):
        for k in range(K):
            B.set(n, k, Scalar[f16](Float32((n + 1) * K + k) * 0.05))

    gemm_f16(A, B, C_ref)

    # Sharded GEMM: Split B along N (rows) into 2 shards of (16x32)
    var b_shards = shard_split_rows(B, P)

    var a_shards = List[RuneTensor[f16]]()
    var c_shards = List[RuneTensor[f16]]()

    var c_sh0_ptr = alloc(Layout[Scalar[f16]](count=M * (N // P))).unsafe_leak()
    var c_sh1_ptr = alloc(Layout[Scalar[f16]](count=M * (N // P))).unsafe_leak()

    var a_sh0_ptr = alloc(Layout[Scalar[f16]](count=M * K)).unsafe_leak()
    var a_sh1_ptr = alloc(Layout[Scalar[f16]](count=M * K)).unsafe_leak()
    for k in range(K):
        a_sh0_ptr.unsafe_store(k, A.get(0, k))
        a_sh1_ptr.unsafe_store(k, A.get(0, k))

    a_shards.append(RuneTensor[f16](M, K, a_sh0_ptr, False))
    a_shards.append(RuneTensor[f16](M, K, a_sh1_ptr, False))

    c_shards.append(RuneTensor[f16](M, N // P, c_sh0_ptr, False))
    c_shards.append(RuneTensor[f16](M, N // P, c_sh1_ptr, False))

    gemm_f16_sharded(a_shards, b_shards, c_shards)

    # Verify parity: C_shards[0] matches C_ref[0..16], C_shards[1] matches C_ref[16..32]
    for i in range(N // P):
        var val_ref0 = Float32(C_ref.get(0, i))
        var val_sh0 = Float32(c_shards[0].get(0, i))
        if abs(val_sh0 - val_ref0) > 1e-3:
            raise Error("GEMM parity mismatch in shard 0 at index " + String(i))

        var val_ref1 = Float32(C_ref.get(0, N // P + i))
        var val_sh1 = Float32(c_shards[1].get(0, i))
        if abs(val_sh1 - val_ref1) > 1e-3:
            raise Error("GEMM parity mismatch in shard 1 at index " + String(i))

    a_ptr.unsafe_free()
    b_ptr.unsafe_free()
    c_ref_ptr.unsafe_free()
    c_sh0_ptr.unsafe_free()
    c_sh1_ptr.unsafe_free()
    a_sh0_ptr.unsafe_free()
    a_sh1_ptr.unsafe_free()

    print("sequential host-shard GEMM parity: PASS")


def test_sharding() raises:
    test_device_topology()
    test_shard_tensor()
    test_tensor_partitioning()
    test_all_reduce_sum()
    test_sharded_gemm_parity()
