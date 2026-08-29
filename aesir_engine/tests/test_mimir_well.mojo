# tests/test_mimir_well.mojo
# Verification of MimirWell allocation and the fixed-capacity KVCache contract

from core.mimir_well import MimirWell, RuneTensor, KVCache, f16


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


def test_kv_cache_fixed_capacity() raises:
    """
    Verifies that KVCache preserves chronological prefix positions, rejects the
    first out-of-capacity write, and leaves existing cells unchanged.
    """
    print("--- Testing KVCache Fixed-Capacity Bounds ---")

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

    # Verify first token K values survived the full-capacity fill.
    var k0_val = k_slice.get_checked(0, 0)
    if Float32(k0_val) != 0.0:
        raise Error("KVCache K[0,0] value mismatch after capacity fill")

    var overflow_k = RuneTensor[f16](1, hidden_dim, well.allocate(hidden_dim), False)
    var overflow_v = RuneTensor[f16](1, hidden_dim, well.allocate(hidden_dim), False)
    overflow_k.set(0, 0, Scalar[f16](999.0))
    overflow_v.set(0, 0, Scalar[f16](999.0))
    var overflow_rejected = False
    try:
        kv.append(0, max_seq_len, overflow_k, overflow_v)
    except error:
        overflow_rejected = True
        if "pos exceeds fixed cache capacity" not in String(error):
            raise Error("KVCache capacity rejection was not precise")
    if not overflow_rejected:
        raise Error("KVCache silently wrapped an out-of-capacity position")
    if Float32(kv.get_k_slice(0, max_seq_len).get_checked(0, 0)) != 0.0:
        raise Error("KVCache overflow rejection mutated the first token")

    print("KVCache fixed-capacity bounds: PASS")


def test_kv_cache_ring_buffer() raises:
    """Compatibility wrapper for the former misleading test name."""
    test_kv_cache_fixed_capacity()
