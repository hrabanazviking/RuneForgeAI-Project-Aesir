# tests/test_rag.mojo
# The Waters of Mímisbrunnr: RAG & SIMD Vector Search Proving Grounds

from core.mimir_well import MimirWell, RuneTensor, MimirStore, f16, f32
from core.compute import cosine_similarity

def test_cosine_similarity() raises:
    print("--- Testing SIMD Cosine Similarity (The Alignment of Mímisbrunnr) ---")
    var well = MimirWell(1024 * 64)
    
    var dim = 35 # Unaligned length to test SIMD tail loop
    
    var a_ptr = well.allocate(dim)
    var A = RuneTensor[f16](1, dim, a_ptr)
    
    var b_ptr = well.allocate(dim)
    var B = RuneTensor[f16](1, dim, b_ptr)
    
    var c_ptr = well.allocate(dim)
    var C = RuneTensor[f16](1, dim, c_ptr)
    
    # 1. Identical vectors -> Cosine similarity should be 1.0
    for i in range(dim):
        A.data.unsafe_store(i, 1.0)
        B.data.unsafe_store(i, 1.0)
        
    var sim_identical = cosine_similarity(A, B)
    var diff1 = sim_identical - 1.0
    if diff1 < 0:
        diff1 = -diff1

    # 2. Orthogonal vectors -> Cosine similarity should be 0.0
    for i in range(dim):
        B.data.unsafe_store(i, 0.0)
        C.data.unsafe_store(i, 0.0)
    A.data.unsafe_store(0, 1.0)
    for i in range(1, dim):
        A.data.unsafe_store(i, 0.0)
    C.data.unsafe_store(1, 1.0)
    
    var sim_orthogonal = cosine_similarity(A, C)
    var diff2 = sim_orthogonal - 0.0
    if diff2 < 0:
        diff2 = -diff2

    if diff1 < 0.01 and diff2 < 0.01:
        print("cosine_similarity: PASS")
    else:
        print("cosine_similarity: FAIL (identical =", sim_identical, ", orthogonal =", sim_orthogonal, ")")
        raise Error("cosine_similarity invariant mismatch")

def test_mimir_store() raises:
    print("--- Testing MimirStore (Insertion & k-NN Vector Search) ---")
    var well = MimirWell(1024 * 512)
    var dim = 16
    var store = MimirStore(10, dim, well)
    
    # Doc 0: aligned with dim 0
    var e0_ptr = well.allocate(dim)
    var e0 = RuneTensor[f16](1, dim, e0_ptr)
    for i in range(dim):
        e0.set(0, i, Scalar[f16](0.0))
    e0.set(0, 0, Scalar[f16](1.0))
    _ = e0.get(0, 0)
    store.add_document(String("Odin the Allfather"), e0)
    _ = e0
    
    # Doc 1: aligned with dim 1
    var e1_ptr = well.allocate(dim)
    var e1 = RuneTensor[f16](1, dim, e1_ptr)
    for i in range(dim):
        e1.set(0, i, Scalar[f16](0.0))
    e1.set(0, 1, Scalar[f16](1.0))
    _ = e1.get(0, 1)
    store.add_document(String("Thor God of Thunder"), e1)
    _ = e1
    
    # Doc 2: aligned with dim 0
    var e2_ptr = well.allocate(dim)
    var e2 = RuneTensor[f16](1, dim, e2_ptr)
    for i in range(dim):
        e2.set(0, i, Scalar[f16](0.0))
    e2.set(0, 0, Scalar[f16](1.0))
    _ = e2.get(0, 0)
    store.add_document(String("Odin of Valhalla"), e2)
    _ = e2

    var emb_val_ok = store.embeddings.get(2, 0) == Scalar[f16](1.0)
    var count_ok = store.count == 3
    
    # Query vector close to Doc 0 (dim 0)
    var q_ptr = well.allocate(dim)
    var query = RuneTensor[f16](1, dim, q_ptr)
    for i in range(dim):
        query.data.unsafe_store(i, Scalar[f16](0.0))
    query.data.unsafe_store(0, Scalar[f16](1.0))

    var nearest = store.search_knn(query, 2)
    
    var knn_ok = len(nearest) == 2 and nearest[0] == String("Odin the Allfather") and nearest[1] == String("Odin of Valhalla")

    # Dimension mismatch test
    var bad_emb = RuneTensor[f16](1, dim + 5, well.allocate(dim + 5))
    var dim_mismatch = False
    try:
        store.add_document(String("Loki Trickster"), bad_emb)
    except:
        dim_mismatch = True
    if not dim_mismatch:
        raise Error("MimirStore add_document failed to detect dimension mismatch")

    if count_ok and knn_ok and emb_val_ok:
        print("MimirStore (insertion & k-NN): PASS")
    else:
        print("MimirStore: FAIL (count_ok =", count_ok, ", knn_ok =", knn_ok, ", emb_val_ok =", emb_val_ok, ")")
        raise Error("MimirStore invariant mismatch")
    _ = store

def report_engine_integration_boundary():
    # The repository deliberately does not commit model weights. Real engine
    # integration is covered by the opt-in test_real_gguf.mojo fixture.
    print("RAG Engine Integration: SKIP (requires a validated real GGUF fixture)")

def test_rag() raises:
    test_cosine_similarity()
    test_mimir_store()
    report_engine_integration_boundary()

def main() raises:
    test_rag()
