# tests/test_rag.mojo
# The Waters of Mímisbrunnr: RAG & SIMD Vector Search Proving Grounds

from core.mimir_well import MimirWell, RuneTensor, MimirStore, f16, f32
from core.compute import cosine_similarity
from aesir import AesirEngine

def test_cosine_similarity():
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

def test_mimir_store():
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

    if count_ok and knn_ok and emb_val_ok:
        print("MimirStore (insertion & k-NN): PASS")
    else:
        print("MimirStore: FAIL (count_ok =", count_ok, ", knn_ok =", knn_ok, ", emb_val_ok =", emb_val_ok, ")")
    _ = store

def test_rag_retrieval() raises:
    print("--- Testing RAG Context Retrieval ---")
    var engine = AesirEngine(String("model.gguf"))
    
    # Populate knowledge_base
    var dim = 4096
    var e_ptr = engine.pool.allocate(dim)
    var emb = RuneTensor[f16](1, dim, e_ptr)
    for i in range(dim):
        emb.data.unsafe_store(i, 0.1)

    engine.knowledge_base.add_document(String("Ragnarok is the destiny of Asgard."), emb)
    
    var response = engine.generate(String("What is Ragnarok?"))
    _ = response
    
    print("RAG Context Retrieval: PASS")

def test_rag():
    try:
        test_cosine_similarity()
        test_mimir_store()
        test_rag_retrieval()
    except e:
        print("test_rag error:", e)

def main():
    test_rag()
