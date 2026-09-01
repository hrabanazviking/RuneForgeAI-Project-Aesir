# tests/test_kv_cache.mojo
# Test suite for fixed-capacity KV Cache and multi-step state accumulation

from core.mimir_well import MimirWell, RuneTensor, KVCache, PagedKVCache, f16
from core.inference import forward_pass
from loader.gguf import GGUFSeer
from tests.test_mimir_well import test_kv_cache_ring_buffer
from std.memory import Pointer

def test_kv_cache() raises:
    print("--- Testing KVCache (The Waters of Mímisbrunnr) ---")
    test_kv_cache_ring_buffer()

    var paged_well = MimirWell(1024 * 1024)
    # Two logical sequences share three physical 2-token pages. Sequence 0
    # temporarily owns two pages and sequence 1 owns one, proving exhaustion;
    # releasing sequence 0 then lets sequence 1 reuse a physical page.
    var paged_cache = PagedKVCache(8, 4, paged_well, 2, 2, 2, 3)
    var paged_k = RuneTensor[f16](1, 4, paged_well.allocate(4), False)
    var paged_v = RuneTensor[f16](1, 4, paged_well.allocate(4), False)
    for pos in range(3):
        for column in range(4):
            paged_k.data.unsafe_store(
                column, Float16(10 * pos + column + 1)
            )
            paged_v.data.unsafe_store(
                column, Float16(100 + 10 * pos + column + 1)
            )
        paged_cache.append(0, 0, pos, paged_k, paged_v)
        # Every layer maps the same logical token through the same page table.
        paged_cache.append(0, 1, pos, paged_k, paged_v)
    if paged_cache.sequence_length(0) != 3 or paged_cache.free_blocks != 1:
        raise Error("PagedKVCache sequence-0 page growth mismatch")
    if (
        paged_cache.get_k(0, 0, 2, 3) != Float16(24.0)
        or paged_cache.get_v(0, 1, 2, 3) != Float16(124.0)
    ):
        raise Error("PagedKVCache cross-page or layer mapping corrupted values")

    for pos in range(2):
        for column in range(4):
            paged_k.data.unsafe_store(
                column, Float16(200 + 10 * pos + column)
            )
            paged_v.data.unsafe_store(
                column, Float16(300 + 10 * pos + column)
            )
        paged_cache.append(1, 0, pos, paged_k, paged_v)
    if paged_cache.free_blocks != 0:
        raise Error("PagedKVCache physical-page accounting mismatch")
    var exhausted_pages = False
    try:
        paged_cache.append(1, 0, 2, paged_k, paged_v)
    except error:
        exhausted_pages = "out of physical blocks" in String(error)
    if not exhausted_pages or paged_cache.sequence_length(1) != 2:
        raise Error("PagedKVCache exhaustion was not mutation-free")

    var released_physical = paged_cache.mapped_block(0, 1)
    paged_cache.release_sequence(0)
    if paged_cache.sequence_length(0) != 0 or paged_cache.free_blocks != 2:
        raise Error("PagedKVCache sequence release did not return its pages")
    paged_cache.append(1, 0, 2, paged_k, paged_v)
    if paged_cache.free_blocks != 1:
        raise Error("PagedKVCache did not reuse a released physical page")
    if paged_cache.get_k(1, 0, 0, 0) != Float16(200.0):
        raise Error("PagedKVCache page reuse corrupted another logical page")
    var stale_layer_rejected = False
    try:
        _ = paged_cache.get_k(1, 1, 2, 0)
    except error:
        stale_layer_rejected = "pos out of bounds" in String(error)
    if not stale_layer_rejected:
        raise Error("PagedKVCache exposed an unwritten recycled layer value")
    var paged_snapshot = paged_cache.copy()
    for column in range(4):
        paged_k.data.unsafe_store(column, Float16(900 + column))
        paged_v.data.unsafe_store(column, Float16(950 + column))
    paged_cache.append(1, 0, 0, paged_k, paged_v)
    if (
        paged_cache.get_k(1, 0, 0, 0) != Float16(900.0)
        or paged_snapshot.get_k(1, 0, 0, 0) != Float16(200.0)
    ):
        raise Error("PagedKVCache copy did not own an independent snapshot")
    var double_free_rejected = False
    try:
        paged_cache.free_block(released_physical)
    except error:
        double_free_rejected = "already free" in String(error)
    if not double_free_rejected:
        raise Error("PagedKVCache accepted a double free")
    var gap_rejected = False
    try:
        paged_cache.append(0, 0, 2, paged_k, paged_v)
    except error:
        gap_rejected = "contiguous" in String(error)
    if not gap_rejected or paged_cache.sequence_length(0) != 0:
        raise Error("PagedKVCache accepted a logical-position gap")
    print("PagedKVCache multi-sequence allocation, exhaustion, and reuse: PASS")

    # 1. Instantiation test
    var well = MimirWell(1024 * 1024 * 2) # 2 MB well
    var initial_offset = well.offset
    var alloc_ptr = well.allocate(512)
    var alloc_offset = well.offset
    if alloc_offset <= initial_offset:
        raise Error("MimirWell failed to advance offset")
    well.reset_kv_cache(initial_offset)
    if well.offset != initial_offset:
        raise Error("MimirWell failed to restore runtime_offset")

    var max_seq_len = 64
    var hidden_dim = 16
    var num_layers = 2

    var kv_cache = KVCache(max_seq_len, hidden_dim, well, num_layers)
    if kv_cache.max_seq_len != 64 or kv_cache.hidden_dim != 16 or kv_cache.num_layers != 2:
        print("FAIL: KVCache initialization metadata mismatch")
        raise Error("KVCache initialization metadata mismatch")
    print("KVCache instantiation: PASS")

    # 2. Token append test
    var k_ptr = well.allocate(hidden_dim)
    var v_ptr = well.allocate(hidden_dim)
    var single_k = RuneTensor[f16](1, hidden_dim, k_ptr, False)
    var single_v = RuneTensor[f16](1, hidden_dim, v_ptr, False)

    for i in range(hidden_dim):
        single_k.set(0, i, Scalar[f16](Float32(i + 1)))
        single_v.set(0, i, Scalar[f16](Float32((i + 1) * 2)))

    kv_cache.append(0, 0, single_k, single_v)
    
    # Check value at layer 0, pos 0
    var k0 = kv_cache.get_k_slice(0, 1)
    var v0 = kv_cache.get_v_slice(0, 1)
    if k0.get(0, 0) != 1.0 or v0.get(0, 0) != 2.0:
        print("FAIL: KVCache token append data corruption")
        raise Error("KVCache token append data corruption")
    print("KVCache token append: PASS")

    # 3. Multi-step single-token forward pass state accumulation
    var seer = GGUFSeer("dummy.gguf")
    var vocab = 10
    var dim = 16
    var heads = 4
    var head_dim = 4
    var ffn_hidden = 32

    seer.tensors["token_embd.weight"] = RuneTensor[f16](vocab, dim, well.allocate(vocab * dim), False)
    seer.tensors["blk.0.attn_norm.weight"] = RuneTensor[f16](1, dim, well.allocate(dim), False)
    seer.tensors["blk.0.attn_q.weight"] = RuneTensor[f16](dim, dim, well.allocate(dim * dim), False)
    seer.tensors["blk.0.attn_k.weight"] = RuneTensor[f16](dim, dim, well.allocate(dim * dim), False)
    seer.tensors["blk.0.attn_v.weight"] = RuneTensor[f16](dim, dim, well.allocate(dim * dim), False)
    seer.tensors["blk.0.attn_output.weight"] = RuneTensor[f16](dim, dim, well.allocate(dim * dim), False)
    seer.tensors["blk.0.ffn_norm.weight"] = RuneTensor[f16](1, dim, well.allocate(dim), False)
    seer.tensors["blk.0.ffn_gate.weight"] = RuneTensor[f16](ffn_hidden, dim, well.allocate(ffn_hidden * dim), False)
    seer.tensors["blk.0.ffn_up.weight"] = RuneTensor[f16](ffn_hidden, dim, well.allocate(ffn_hidden * dim), False)
    seer.tensors["blk.0.ffn_down.weight"] = RuneTensor[f16](dim, ffn_hidden, well.allocate(ffn_hidden * dim), False)
    seer.tensors["output_norm.weight"] = RuneTensor[f16](1, dim, well.allocate(dim), False)
    seer.tensors["output.weight"] = RuneTensor[f16](vocab, dim, well.allocate(vocab * dim), False)

    var test_cache = KVCache(16, dim, well, 1)
    var tokens = List[Int]()
    tokens.append(1)

    # Step 0
    var t0 = forward_pass(tokens, seer, well, test_cache, 0, 1, head_dim, heads)
    if t0 != 0:
        raise Error("zero-initialized KV step 0 must select token 0")
    
    # Step 1
    tokens.append(2)
    var t1 = forward_pass(tokens, seer, well, test_cache, 1, 1, head_dim, heads)
    if t1 != 0:
        raise Error("zero-initialized KV step 1 must select token 0")

    # 4. Memory Pool Exhaustion & Bounds Tests (Stage 1 Hardening)
    var tiny_well = MimirWell(1024) # 1 KB well (512 f16 elements)
    var exhausted = False
    try:
        _ = tiny_well.allocate(1000) # Request 1000 elements from 512 capacity
    except e:
        exhausted = True
    if not exhausted:
        print("FAIL: MimirWell did not raise on memory pool exhaustion")
        raise Error("MimirWell did not raise on memory pool exhaustion")
    print("MimirWell memory exhaustion error: PASS")

    # Checked indexing test
    var test_tensor = RuneTensor[f16](2, 2, well.allocate(4), False)
    test_tensor.set(0, 0, Scalar[f16](42.0))
    var val_checked = test_tensor.get_checked(0, 0)
    if val_checked != 42.0:
        raise Error("RuneTensor get_checked mismatch")

    var oob = False
    try:
        _ = test_tensor.get_checked(5, 5)
    except:
        oob = True
    if not oob:
        raise Error("RuneTensor get_checked failed to detect OOB")

    var checked_tensor = RuneTensor[f16].checked(2, 2, well.allocate(4), False)
    if checked_tensor.rows != 2 or checked_tensor.size != 4:
        raise Error("RuneTensor.checked rejected or corrupted a valid view")

    var shape_rejected = False
    try:
        _ = RuneTensor[f16].checked(0, 2, well.allocate(1), False)
    except error:
        shape_rejected = True
        if "dimensions must be positive" not in String(error):
            raise Error("RuneTensor.checked shape rejection was not precise")
    if not shape_rejected:
        raise Error("RuneTensor.checked accepted a zero dimension")

    var overflow_rejected = False
    try:
        _ = RuneTensor[f16].checked(Int(1) << 62, 4, well.allocate(1), False)
    except error:
        overflow_rejected = True
        if "shape product overflow" not in String(error):
            raise Error("RuneTensor.checked overflow rejection was not precise")
    if not overflow_rejected:
        raise Error("RuneTensor.checked accepted an overflowed shape")

    var sentinel_ptr = Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1)
    var pointer_rejected = False
    try:
        _ = RuneTensor[f16].checked(1, 1, sentinel_ptr, False)
    except error:
        pointer_rejected = True
        if "pointer is null or sentinel" not in String(error):
            raise Error("RuneTensor.checked pointer rejection was not precise")
    if not pointer_rejected:
        raise Error("RuneTensor.checked accepted address 1")
    # KVCache slice bounds checks
    var slice_oob = False
    try:
        _ = kv_cache.get_k_slice(10, 1) # layer_idx 10 >= num_layers 2
    except:
        slice_oob = True
    if not slice_oob:
        raise Error("KVCache get_k_slice failed to detect layer OOB")

    var seq_oob = False
    try:
        _ = kv_cache.get_v_slice(0, 500) # seq_len 500 > max_seq_len 64
    except:
        seq_oob = True
    if not seq_oob:
        raise Error("KVCache get_v_slice failed to detect sequence OOB")
    print("KVCache slice bounds: PASS")

    print("KVCache state accumulation: PASS")
    print("test_kv_cache: PASS")

def main() raises:
    test_kv_cache()
