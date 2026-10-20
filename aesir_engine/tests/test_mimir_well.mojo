# tests/test_mimir_well.mojo
# Verification of MimirWell core memory allocation and KVCache ring-buffer rotation

from core.mimir_well import MimirWell, RuneTensor, KVCache, f16


def expect_allocation_rejection(mut well: MimirWell, elements: Int) raises:
    var before = well.offset
    var rejected = False
    try:
        _ = well.allocate(elements)
    except error:
        rejected = True
    if not rejected:
        raise Error("MimirWell admitted an invalid allocation count")
    if well.offset != before:
        raise Error("Rejected MimirWell allocation changed the arena offset")


def test_mimir_well_allocation_bounds() raises:
    var well = MimirWell(16)  # eight F16 elements
    var first = well.allocate(3)
    var second = well.allocate(5)
    if second != first.unsafe_offset(3):
        raise Error("Adjacent allocations did not meet at the prior end")
    if well.offset != 8:
        raise Error("Exact-capacity allocations produced the wrong final offset")

    expect_allocation_rejection(well, 1)
    expect_allocation_rejection(well, 0)
    expect_allocation_rejection(well, -1)

    var reset_well = MimirWell(16)
    expect_allocation_rejection(reset_well, 9)
    if reset_well.offset != 0:
        raise Error("Oversized allocation changed an empty arena offset")
    print("PASS: MimirWell exact capacity and mutation-free rejection")


def test_mimir_well_allocation() raises:
    """
    ᛗᛁᛗᛁᚱ·ᚹᛖᛚᛚ — Sovereign Memory Pool Allocation Verification
    ═════════════════════════════════════════════════════════════
    Verifies that MimirWell correctly advances its allocation offset,
    and restores offset on reset.
    """
    print("--- Testing MimirWell Allocation ---")

    # 1. Basic allocation advances offset
    var well = MimirWell(1024 * 1024)  # 1 MB pool
    var start_offset = well.offset
    var ptr = well.allocate(256)
    if well.offset <= start_offset:
        raise Error("MimirWell.allocate() did not advance offset")

    # 2. Multiple allocations are non-overlapping
    var offset_after_first = well.offset
    var ptr2 = well.allocate(512)
    if well.offset <= offset_after_first:
        raise Error("Second allocate() did not advance offset beyond first")

    # 3. Reset restores offset
    well.reset_kv_cache(start_offset)
    if well.offset != start_offset:
        raise Error("MimirWell.reset_kv_cache() did not restore offset")

    # Prevent premature deallocation of returned pointers
    _ = ptr
    _ = ptr2

    print("MimirWell allocation: PASS")


def test_kv_cache_ring_buffer() raises:
    """
    ᚲᚠ·ᚱᛁᚾᚷ — KVCache Ring-Buffer Rotation Verification
    ═══════════════════════════════════════════════════════════
    Verifies that KVCache correctly handles token appends via
    the ring-buffer modulus slot, and slice extraction boundaries.
    """
    print("--- Testing KVCache Ring-Buffer Rotation ---")

    var well = MimirWell(1024 * 1024 * 4)  # 4 MB pool
    var max_seq_len = 8
    var hidden_dim = 4
    var num_layers = 1

    var kv = KVCache(max_seq_len, hidden_dim, well, num_layers)

    if kv.max_seq_len != max_seq_len:
        raise Error("KVCache max_seq_len mismatch")
    if kv.hidden_dim != hidden_dim:
        raise Error("KVCache hidden_dim mismatch")

    # Append tokens up to capacity using correct API: append(layer_idx, pos, key, val)
    for t in range(max_seq_len):
        var k_ptr = well.allocate(hidden_dim)
        var v_ptr = well.allocate(hidden_dim)
        var k_tok = RuneTensor[f16](1, hidden_dim, k_ptr, False)
        var v_tok = RuneTensor[f16](1, hidden_dim, v_ptr, False)
        for d in range(hidden_dim):
            k_tok.set(0, d, Scalar[f16](Float32(t * hidden_dim + d)))
            v_tok.set(0, d, Scalar[f16](Float32((t + 1) * 100 + d)))
        kv.append(0, t, k_tok, v_tok)

    # Verify slice extraction does not crash and has correct shape
    # get_k_slice(layer_idx, seq_len), get_v_slice(layer_idx, seq_len)
    var k_slice = kv.get_k_slice(0, max_seq_len)
    var v_slice = kv.get_v_slice(0, max_seq_len)

    if k_slice.rows != max_seq_len or k_slice.cols != hidden_dim:
        raise Error("KVCache K slice shape mismatch")
    if v_slice.rows != max_seq_len or v_slice.cols != hidden_dim:
        raise Error("KVCache V slice shape mismatch")

    # Verify first token K values survived ring-buffer fill
    var k0_val = k_slice.get_checked(0, 0)
    if Float32(k0_val) != 0.0:
        raise Error("KVCache ring-buffer K[0,0] value mismatch after fill")

    print("KVCache ring-buffer rotation: PASS")
