# loader/corpus_ingestion.mojo
# The Mímisbrunnr Ingestion Conduit: Deterministic Text Chunking & Corpus Metadata
#
# Breaks raw text documents into fixed-width overlapping chunks for vector embedding storage.

from core.mimir_well import MimirWell, MimirStore, RuneTensor, f16, f32

struct DocumentChunk(Copyable, ImplicitlyCopyable):
    var id: String
    var text: String
    var source_file: String
    var chunk_index: Int
    var byte_offset: Int

    def __init__(
        out self,
        id: String,
        text: String,
        source_file: String = String("inline"),
        chunk_index: Int = 0,
        byte_offset: Int = 0,
    ):
        self.id = id
        self.text = text
        self.source_file = source_file
        self.chunk_index = chunk_index
        self.byte_offset = byte_offset

    def __copyinit__(out self, existing: Self):
        self.id = existing.id
        self.text = existing.text
        self.source_file = existing.source_file
        self.chunk_index = existing.chunk_index
        self.byte_offset = existing.byte_offset


def chunk_text(text: String, chunk_size: Int = 256, chunk_overlap: Int = 32) -> List[DocumentChunk]:
    """
    Deterministic Text Chunking Kernel.
    Splits text into fixed character windows with overlap, preserving byte offset metadata.
    """
    var chunks = List[DocumentChunk]()
    var t_bytes = text.as_bytes()
    var text_len = len(t_bytes)
    if text_len == 0 or chunk_size <= 0:
        return chunks^

    var effective_overlap = chunk_overlap
    if effective_overlap >= chunk_size:
        effective_overlap = chunk_size // 2

    var step = chunk_size - effective_overlap
    if step <= 0:
        step = 1

    var offset = 0
    var idx = 0

    while offset < text_len:
        var end_offset = min(offset + chunk_size, text_len)
        var slice_bytes = List[Byte]()
        for i in range(offset, end_offset):
            slice_bytes.append(t_bytes[i])
        var chunk_str = String(slice_bytes)
        var chunk_id = String("chunk_") + String(idx)
        chunks.append(DocumentChunk(chunk_id, chunk_str, String("inline"), idx, offset))
        idx += 1
        if end_offset >= text_len:
            break
        offset += step

    return chunks^


def ingest_corpus_batch(
    mut store: MimirStore,
    chunks: List[DocumentChunk],
    mut well: MimirWell,
    dim: Int,
) raises -> Int:
    """
    Batch Corpus Ingestion Kernel.
    Ingests text chunks into MimirStore with synthetic deterministic projections.
    Returns the count of successfully ingested document chunks.
    """
    var count = 0
    for i in range(len(chunks)):
        var chunk = chunks[i]
        var vec_ptr = well.allocate(dim)
        var vec = RuneTensor[f16](1, dim, vec_ptr, False)
        
        # Deterministic projection from chunk text bytes
        var seed_hash: Int = 5381
        var c_bytes = chunk.text.as_bytes()
        for b_idx in range(len(c_bytes)):
            seed_hash = ((seed_hash << 5) + seed_hash) + Int(c_bytes[b_idx])
        for k in range(dim):
            var proj_val = Scalar[f32](((seed_hash + k * 31) % 1000) - 500) / 1000.0
            vec.data.unsafe_store(k, Scalar[f16](proj_val))

        store.add_document(chunk.text, vec)
        count += 1
    return count
