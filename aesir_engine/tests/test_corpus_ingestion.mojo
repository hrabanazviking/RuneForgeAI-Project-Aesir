"""UTF-8 boundary-safe chunking: no chunk may start or end mid-code-point."""
from loader.corpus_ingestion import chunk_text


def _is_continuation(b: Byte) -> Bool:
    return b >= 0x80 and b <= 0xBF


def test_chunk_text_ascii_unchanged() raises:
    # Pure ASCII: snapping is a no-op, chunking must equal the pre-fix layout.
    var empty_chunks = chunk_text(String(""), 7, 2)
    if len(empty_chunks) != 0:
        raise Error("empty text must yield no chunks")
    var chunks = chunk_text(String("abcdefghijklmnopqrstuvwxyz"), 7, 2)
    if len(chunks) != 5:
        raise Error("ASCII chunk count changed")
    var want_texts = List[String]()
    want_texts.append("abcdefg")
    want_texts.append("fghijkl")
    want_texts.append("klmnopq")
    want_texts.append("pqrstuv")
    want_texts.append("uvwxyz")
    var want_offsets = List[Int]()
    want_offsets.append(0)
    want_offsets.append(5)
    want_offsets.append(10)
    want_offsets.append(15)
    want_offsets.append(20)
    for i in range(5):
        if chunks[i].text != want_texts[i] or chunks[i].byte_offset != want_offsets[i]:
            raise Error("ASCII chunk text/offset changed at index " + String(i))
        if chunks[i].id != String("chunk_") + String(i) or chunks[i].chunk_index != i:
            raise Error("ASCII chunk id/index changed at index " + String(i))


def test_chunk_text_multibyte_boundaries() raises:
    # CJK (3-byte) + emoji (4-byte) with a small window: every chunk must be
    # valid UTF-8 and cover exactly its source byte slice.
    var text = String("日本語テスト😀🎉中文")
    var t_bytes = text.as_bytes()
    var text_len = len(t_bytes)
    var chunks = chunk_text(text, 7, 2)
    if len(chunks) == 0:
        raise Error("multibyte text yielded no chunks")
    for i in range(len(chunks)):
        var start = chunks[i].byte_offset
        var cb = chunks[i].text.as_bytes()
        var end = start + len(cb)
        if len(cb) == 0:
            raise Error("chunk text must not be empty")
        for j in range(len(cb)):
            if cb[j] != t_bytes[start + j]:
                raise Error("chunk bytes diverge from source at chunk " + String(i))
        if _is_continuation(t_bytes[start]):
            raise Error("chunk starts mid-code-point at byte " + String(start))
        if end < text_len and _is_continuation(t_bytes[end]):
            raise Error("chunk ends mid-code-point at byte " + String(end))


def test_chunk_text_reconstruction() raises:
    # Concatenated chunk bytes with overlap removed must rebuild the source exactly.
    var text = String("日本語テスト😀🎉中文")
    var t_bytes = text.as_bytes()
    var chunks = chunk_text(text, 7, 2)
    var rebuilt = List[Byte]()
    var prev_end = 0
    for i in range(len(chunks)):
        var start = chunks[i].byte_offset
        var cb = chunks[i].text.as_bytes()
        var skip = 0
        if i > 0 and start < prev_end:
            skip = prev_end - start
        for j in range(skip, len(cb)):
            rebuilt.append(cb[j])
        prev_end = start + len(cb)
    if len(rebuilt) != len(t_bytes):
        raise Error("rebuilt byte length mismatch")
    for k in range(len(t_bytes)):
        if rebuilt[k] != t_bytes[k]:
            raise Error("rebuilt bytes mismatch at byte " + String(k))


def test_chunk_text_wide_code_point() raises:
    # A single code point wider than chunk_size is emitted whole, never split.
    var chunks = chunk_text(String("😀ab"), 2, 1)
    if len(chunks) != 2:
        raise Error("wide code point chunk count wrong")
    if chunks[0].text != "😀" or chunks[0].byte_offset != 0:
        raise Error("wide code point was not emitted whole")
    if chunks[1].text != "ab" or chunks[1].byte_offset != 4:
        raise Error("tail after wide code point wrong")


def main() raises:
    test_chunk_text_ascii_unchanged()
    test_chunk_text_multibyte_boundaries()
    test_chunk_text_reconstruction()
    test_chunk_text_wide_code_point()
    print("PASS corpus ingestion UTF-8 chunking")
