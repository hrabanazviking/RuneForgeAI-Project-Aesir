# loader/corpus_ingestion.mojo
# The Mímisbrunnr Ingestion Conduit: Deterministic Text Chunking & Corpus Metadata
#
# Breaks raw text documents into fixed-width overlapping chunks and accepts
# caller-computed embeddings for vector storage. This module never invents
# embeddings from document text.

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


def _is_utf8_continuation(b: Byte) -> Bool:
    """True for UTF-8 continuation bytes 0x80..0xBF."""
    return b >= 0x80 and b <= 0xBF


def _utf8_lead_length(lead: Byte) -> Int:
    """Total byte length of the code point opened by lead byte `lead` (>= 0xC0)."""
    if lead < 0xE0:
        return 2
    if lead < 0xF0:
        return 3
    return 4


def _snap_chunk_end(t_bytes: Span[Byte, ...], offset: Int, raw_end: Int) -> Int:
    """Largest code-point boundary `e` with `offset < e <= raw_end`.

    Walks back over at most 3 continuation bytes, then resolves a trailing
    lead byte: a split code point is excluded (the walk alone would leave its
    orphan lead byte inside the chunk), while a code point that ends exactly
    at `raw_end` keeps `raw_end`. `offset` itself is always a boundary, so the
    walk never passes it.
    """
    var end_offset = raw_end
    var steps = 0
    while end_offset > offset and steps < 3 and _is_utf8_continuation(t_bytes[end_offset - 1]):
        end_offset -= 1
        steps += 1
    if end_offset > offset and t_bytes[end_offset - 1] >= 0xC0:
        if end_offset - 1 + _utf8_lead_length(t_bytes[end_offset - 1]) > raw_end:
            end_offset -= 1
        else:
            end_offset = raw_end
    return end_offset


def _snap_chunk_start(t_bytes: Span[Byte, ...], raw_start: Int, text_len: Int) -> Int:
    """Smallest code-point boundary `s >= raw_start` (walks forward over continuations)."""
    var start = raw_start
    while start < text_len and _is_utf8_continuation(t_bytes[start]):
        start += 1
    return start


def chunk_text(text: String, chunk_size: Int = 256, chunk_overlap: Int = 32) -> List[DocumentChunk]:
    """
    Deterministic Text Chunking Kernel.
    Splits text into fixed byte windows with overlap, preserving byte offset metadata.

    R017: windows are snapped to UTF-8 code-point boundaries, so no chunk ever
    starts or ends mid-character. For pure ASCII input the snapping is a no-op,
    so window offsets/ids/counts match the pre-fix layout; chunk text is now
    properly UTF-8-decoded (pre-fix String(slice_bytes) yielded the byte
    list's repr instead of the decoded text).
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
        var raw_end = min(offset + chunk_size, text_len)
        # The tail of the text always ends on a boundary; only interior cuts snap.
        var end_offset = raw_end
        if raw_end < text_len:
            end_offset = _snap_chunk_end(t_bytes, offset, raw_end)
            if end_offset <= offset:
                # A single code point wider than chunk_size: emit that one
                # whole code point instead of an empty or partial chunk.
                var fwd = offset + 1
                while fwd < text_len and _is_utf8_continuation(t_bytes[fwd]):
                    fwd += 1
                end_offset = fwd
        var slice_bytes = List[Byte]()
        for i in range(offset, end_offset):
            slice_bytes.append(t_bytes[i])
        # Decode the snapped bytes as UTF-8. NOTE: the pre-fix code used
        # String(slice_bytes), which stringifies the List (yielding the byte
        # list's repr like "[97, 98, ...]") instead of decoding the bytes.
        # The repo's established bytes->String pattern (as in
        # loader/tokenizer.mojo) is a NUL-terminated unsafe_from_utf8_ptr,
        # which is sound here because snapping guarantees valid UTF-8.
        slice_bytes.append(0)
        var chunk_str = String(unsafe_from_utf8_ptr=slice_bytes.unsafe_ptr())
        var chunk_id = String("chunk_") + String(idx)
        chunks.append(DocumentChunk(chunk_id, chunk_str, String("inline"), idx, offset))
        idx += 1
        if end_offset >= text_len:
            break
        # The next chunk must also start on a boundary. If snapping pinched
        # the overlap shut, tile gaplessly instead of skipping bytes.
        var next_offset = _snap_chunk_start(t_bytes, offset + step, text_len)
        if next_offset > end_offset:
            next_offset = end_offset
        offset = next_offset

    return chunks^


def ingest_corpus_batch(
    mut store: MimirStore,
    chunks: List[DocumentChunk],
    embeddings: RuneTensor[f16],
) raises -> Int:
    """
    Atomically validates and copies caller-computed document embeddings.

    Each matrix row corresponds to the chunk at the same list index. The
    caller owns embedding generation; accepting the matrix here prevents a
    hash or constant from being mislabeled as a semantic embedding.
    """
    var count = len(chunks)
    if embeddings.rows != count or embeddings.cols != store.dim:
        raise Error("ingest_corpus_batch: embedding matrix shape mismatch")
    if store.count + count > store.max_docs:
        raise Error("ingest_corpus_batch: store capacity exceeded")

    for i in range(len(chunks)):
        if chunks[i].text.byte_length() == 0:
            raise Error("ingest_corpus_batch: chunk text must not be empty")

    for i in range(count):
        var row = RuneTensor[f16](
            1,
            store.dim,
            embeddings.data.unsafe_offset(i * store.dim),
            False,
        )
        store.add_document(chunks[i].text, row)
    return count


def mean_pool_token_embeddings(
    token_ids: List[Int],
    token_embeddings: RuneTensor[f16],
    mut well: MimirWell,
) raises -> RuneTensor[f16]:
    """Mean-pools validated rows from a real caller-supplied token table."""
    if len(token_ids) == 0:
        raise Error("mean_pool_token_embeddings: token sequence must not be empty")
    if token_embeddings.rows <= 0 or token_embeddings.cols <= 0:
        raise Error("mean_pool_token_embeddings: token embedding table is empty")
    for i in range(len(token_ids)):
        if token_ids[i] < 0 or token_ids[i] >= token_embeddings.rows:
            raise Error("mean_pool_token_embeddings: token id is out of range")

    var result_ptr = well.allocate(token_embeddings.cols)
    var result = RuneTensor[f16](1, token_embeddings.cols, result_ptr, False)
    for col in range(token_embeddings.cols):
        var total = Scalar[f32](0.0)
        for token_index in range(len(token_ids)):
            total += token_embeddings.get(token_ids[token_index], col).cast[f32]()
        result.set(
            0,
            col,
            Scalar[f16](total / Scalar[f32](len(token_ids))),
        )
    return result^
