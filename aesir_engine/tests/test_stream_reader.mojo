from std.ffi import external_call

from core.stream_reader import (
    FADV_DONTNEED,
    FADV_WILLNEED,
    StreamReader,
)


def _cstring(value: String) -> List[Int8]:
    var result = List[Int8]()
    var source = value.as_bytes()
    for index in range(len(source)):
        result.append(Int8(source[index]))
    result.append(0)
    return result^


def _pattern(index: Int) -> UInt8:
    return UInt8((index * 7 + 3) % 256)


def _write_fixture(path: String, size: Int) raises:
    # O_WRONLY | O_CREAT | O_TRUNC = 1 | 64 | 512 on Linux; mode 0o644.
    var encoded = _cstring(path)
    var fd = external_call["open64", Int32](
        encoded.unsafe_ptr(), Int32(1 | 64 | 512), Int32(0o644)
    )
    if fd < 0:
        raise Error("StreamReader test: cannot create fixture")
    var data = List[UInt8]()
    data.resize(size, 0)
    for index in range(size):
        data[index] = _pattern(index)
    var written = 0
    while written < size:
        var got = external_call["write", Int](
            Int(fd), data.unsafe_ptr().unsafe_offset(written), size - written
        )
        if got <= 0:
            raise Error("StreamReader test: fixture write failed")
        written += got
    _ = external_call["close", Int32](fd)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "StreamReader "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def test_stream_reader() raises:
    var path = String("/tmp/aesir_stream_reader_test.bin")
    var size = 16384
    _write_fixture(path, size)

    var reader = StreamReader(path)

    # A GGUF-shaped slab: unaligned offset (32-byte alignment only in
    # real files), quant-block-sized payload.
    var offset = 480
    var slab_size = 1179
    var buffer = List[UInt8]()
    buffer.resize(slab_size, 0)
    reader.read_slab(offset, slab_size, buffer)
    for index in range(slab_size):
        if buffer[index] != _pattern(offset + index):
            raise Error("StreamReader slab bytes differ from the fixture")
    expect_eq(reader.reads, 1, "read count after one slab")
    expect_eq(reader.bytes_read, slab_size, "bytes after one slab")

    # Readahead advice is accepted for a future slab and counted
    # separately from payload reads.
    reader.advise_willneed(4096, 2048)
    reader.advise_sequential()
    expect_eq(reader.advice_calls, 2, "advice call count")
    expect_eq(reader.advised_bytes, 2048, "advised byte count")

    # A second slab at a different offset reads its own bytes.
    var second = List[UInt8]()
    second.resize(512, 0)
    reader.read_slab(8192, 512, second)
    for index in range(512):
        if second[index] != _pattern(8192 + index):
            raise Error("StreamReader second slab bytes differ")
    expect_eq(reader.reads, 2, "read count after two slabs")

    # A read that runs past end of file is an error, never partial.
    var tail = List[UInt8]()
    tail.resize(256, 0)
    var rejected = False
    try:
        reader.read_slab(size - 128, 256, tail)
    except:
        rejected = True
    if not rejected:
        raise Error("StreamReader admitted a read past end of file")
    expect_eq(reader.reads, 2, "failed read must not be counted")

    # A mismatched buffer is refused before any syscall.
    var wrong = List[UInt8]()
    wrong.resize(10, 0)
    rejected = False
    try:
        reader.read_slab(0, 256, wrong)
    except:
        rejected = True
    if not rejected:
        raise Error("StreamReader admitted a mismatched buffer")

    reader.close()
    var encoded = _cstring(path)
    _ = external_call["unlink", Int32](encoded.unsafe_ptr())
    print("PASS: stream reader slab reads, advice, accounting, EOF refusal")
    print("PASS: " + reader.describe())


def main() raises:
    test_stream_reader()
