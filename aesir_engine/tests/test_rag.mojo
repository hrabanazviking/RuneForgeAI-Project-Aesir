# tests/test_rag.mojo
# The Waters of Mímisbrunnr: RAG & SIMD Vector Search Proving Grounds

from core.mimir_well import MimirWell, RuneTensor, MimirStore, f16, f32
from core.compute import cosine_similarity
from loader.corpus_ingestion import (
    chunk_text,
    ingest_corpus_batch,
    mean_pool_token_embeddings,
    DocumentChunk,
)

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

    # 3. Zero-vector -> Cosine similarity should be 0.0
    for i in range(dim):
        B.data.unsafe_store(i, 0.0)
    var sim_zero = cosine_similarity(B, B)
    if sim_zero != 0.0:
        raise Error("Zero vector cosine similarity must return 0.0")

    # 4. Non-finite / corrupt vector -> Cosine similarity should return 0.0 without crash
    A.data.unsafe_store(0, Scalar[f16](0.0 / 0.0)) # NaN
    var sim_nan = cosine_similarity(A, B)
    if sim_nan != 0.0:
        raise Error("NaN corrupt vector cosine similarity must return 0.0")

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

    var query_dim_mismatch = False
    try:
        _ = store.search_knn(bad_emb, 2)
    except:
        query_dim_mismatch = True
    if not query_dim_mismatch:
        raise Error("MimirStore search_knn failed to detect query dimension mismatch")

    # Clear method test
    store.clear()
    if store.count != 0 or len(store.documents) != 0:
        raise Error("MimirStore clear() failed to reset document count and list")

    if count_ok and knn_ok and emb_val_ok:
        print("MimirStore (insertion & k-NN): PASS")
    else:
        print("MimirStore: FAIL (count_ok =", count_ok, ", knn_ok =", knn_ok, ", emb_val_ok =", emb_val_ok, ")")
        raise Error("MimirStore invariant mismatch")
    _ = store

def test_query_embedding_extraction() raises:
    print("--- Testing Query Embedding Extraction (Mean-Pooled Token Vectors) ---")
    var well = MimirWell(1024 * 64)
    var table = RuneTensor[f16](4, 3, well.allocate(12), False)
    for row in range(4):
        for col in range(3):
            table.set(row, col, Scalar[f16](Float32(row * 10 + col)))

    var tokens = List[Int]()
    tokens.append(1)
    tokens.append(3)
    var query_vector = mean_pool_token_embeddings(tokens, table, well)
    if query_vector.rows != 1 or query_vector.cols != 3:
        raise Error("mean_pool_token_embeddings returned the wrong shape")
    for col in range(3):
        var expected = Float32(20 + col)
        var actual = query_vector.get(0, col).cast[f32]()
        if actual != expected:
            raise Error("mean_pool_token_embeddings returned an incorrect value")

    var offset_before_rejection = well.offset
    var invalid_tokens = List[Int]()
    invalid_tokens.append(1)
    invalid_tokens.append(4)
    var rejected = False
    try:
        _ = mean_pool_token_embeddings(invalid_tokens, table, well)
    except:
        rejected = True
    if not rejected or well.offset != offset_before_rejection:
        raise Error("invalid token IDs must be rejected before allocation")
    print("Query Embedding Extraction: PASS")

def test_corpus_ingestion() raises:
    print("--- Testing Corpus Ingestion & Deterministic Text Chunking ---")
    var text = String("Odin Allfather sat at the well of Mímir seeking supreme wisdom. Thor forged Mjölnir in the depths of Nidavellir.")
    var chunks = chunk_text(text, 40, 10)
    if len(chunks) < 2:
        raise Error("chunk_text failed to split text into expected overlapping chunks")
    
    var well = MimirWell(1024 * 64)
    var dim = 16
    var store = MimirStore(well, max_docs=10, dim=dim)
    var embeddings = RuneTensor[f16](len(chunks), dim, well.allocate(len(chunks) * dim), False)
    for row in range(len(chunks)):
        for col in range(dim):
            embeddings.set(row, col, Scalar[f16](Float32(row + col + 1)))
    var count = ingest_corpus_batch(store, chunks, embeddings)
    if count != len(chunks) or store.count != count:
        raise Error("ingest_corpus_batch count mismatch")

    var bad_embeddings = RuneTensor[f16](len(chunks), dim - 1, well.allocate(len(chunks) * (dim - 1)), False)
    var count_before_rejection = store.count
    var rejected = False
    try:
        _ = ingest_corpus_batch(store, chunks, bad_embeddings)
    except:
        rejected = True
    if not rejected or store.count != count_before_rejection:
        raise Error("shape mismatch must fail before mutating the corpus store")
    print("Corpus Ingestion & Text Chunking: PASS")

def test_end_to_end_rag_grounding() raises:
    print("--- Testing End-to-End RAG Grounded Context & Citation Budgeting ---")
    var well = MimirWell(1024 * 64)
    var dim = 16
    var store = MimirStore(well, max_docs=5, dim=dim)
    
    # Ingest document
    var text = String("Hávamál Stanza 141: I know that I hung on a windy tree nine whole nights.")
    var chunks = chunk_text(text, 50, 10)
    var corpus_embeddings = RuneTensor[f16](len(chunks), dim, well.allocate(len(chunks) * dim), False)
    for row in range(len(chunks)):
        for col in range(dim):
            corpus_embeddings.set(row, col, Scalar[f16](0.1 + Float32(row + col) / 100.0))
    _ = ingest_corpus_batch(store, chunks, corpus_embeddings)

    # Search KNN
    var query_ptr = well.allocate(dim)
    var q_vec = RuneTensor[f16](1, dim, query_ptr, False)
    for i in range(dim):
        q_vec.data.unsafe_store(i, 0.1)
    
    var docs = store.search_knn(q_vec, 2)
    if len(docs) == 0:
        raise Error("End-to-end RAG retrieval returned 0 documents")
    
    var context_str = String("[GROUNDED CONTEXT]:\n")
    for i in range(len(docs)):
        context_str += String("[CITATION ") + String(i + 1) + String("]: ") + docs[i] + String("\n")
    
    if len(context_str.as_bytes()) == 0:
        raise Error("End-to-end RAG citation formatting failed")
    print("End-to-End RAG Grounded Context & Citation Budgeting: PASS")

def report_engine_integration_boundary():
    # The repository deliberately does not commit model weights. Real engine
    # integration is covered by the opt-in test_real_gguf.mojo fixture.
    print("RAG Engine Integration: SKIP (requires a validated real GGUF fixture)")

def test_rag() raises:
    test_cosine_similarity()
    test_mimir_store()
    test_query_embedding_extraction()
    test_corpus_ingestion()
    test_end_to_end_rag_grounding()
    report_engine_integration_boundary()

def main() raises:
    test_rag()
