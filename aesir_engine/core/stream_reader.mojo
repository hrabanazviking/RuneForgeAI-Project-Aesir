"""Explicit streaming slab reader for streamed experts (Janas road J-019).

Implements the disk-reading discipline J-019 measured (see
docs/janas/J019_DISK_READING.md for the benchmark and the verdict):

- A cache miss reads exactly the missed expert's slabs -- no more, no
  less. Reads are explicit pread calls at directory-true offsets (the
  J-017 section 3.3 contract: offsets and sizes come from the opened
  file's tensor directory, never from a family layout assumption), so
  the bytes that move are the bytes the router asked for, and the read
  pattern does not depend on the OS page-fault path's readahead window
  the way the mmap-backed loader's does.
- Readahead is requested, not hoped for: advise_willneed issues
  posix_fadvise(POSIX_FADV_WILLNEED) for a future slab while the current
  slab is being consumed, which is the mechanism the J-019 pipeline leg
  measured. Advice ranges need no alignment (the kernel rounds), unlike
  madvise on the mmap path, which requires page-aligned ranges over
  32-byte-aligned GGUF slabs.
- The reader never fights the OS: it is a plain blocking reader on one
  descriptor, it issues no writes, and its statistics (reads, bytes,
  advice calls) are reported in the J-016/J-018 vocabulary so a live
  streaming run can be compared against the J-019 benchmark legs.

What Mojo honestly allows today, stated plainly: pread and
posix_fadvise are plain libc calls and are expressed here with the same
external_call surface the tree already uses (loader/huggingface.mojo's
pread, cli storage's close/unlink). True async submission (io_uring,
POSIX AIO) has no binding in this tree and no stdlib surface in Mojo
1.0; J-019 therefore records async I/O as NOT PROVEN, and this module
deliberately does not fake an async interface. Direct I/O (O_DIRECT)
is likewise not offered here: GGUF slab offsets are only 32-byte
aligned, so direct reads need aligned-cover over-read (measured by
J-019 at ~4 KiB per slab) for no measured gain on the target device.

There is still no MoE forward path in the engine (J-012..J-018), so --
like the expert cache -- this module is standalone and tested, ready
for the Part II integration slices to call on a cache miss.
"""

from std.ffi import external_call


# Linux posix_fadvise advice values (fcntl.h).
comptime FADV_NORMAL = 0
comptime FADV_RANDOM = 1
comptime FADV_SEQUENTIAL = 2
comptime FADV_WILLNEED = 3
comptime FADV_DONTNEED = 4
comptime FADV_NOREUSE = 5

comptime _O_RDONLY = 0


def _cstring(value: String) -> List[Int8]:
    var result = List[Int8]()
    var source = value.as_bytes()
    for index in range(len(source)):
        result.append(Int8(source[index]))
    result.append(0)
    return result^


struct StreamReader(Movable):
    """One open model file, read slab-by-slab at explicit offsets.

    Counters are part of the contract: reads / bytes_read count only
    slab payload reads issued through read_slab; advice calls and the
    bytes they covered are counted separately, so streamed-byte totals
    stay comparable with the expert cache's bytes_streamed statistic.
    """

    var fd: Int32
    var path: String
    var reads: Int
    var bytes_read: Int
    var advice_calls: Int
    var advised_bytes: Int

    def __init__(out self, path: String) raises:
        var encoded = _cstring(path)
        # open64 with an explicit mode argument is the form the tree's
        # loader already uses (loader/huggingface.mojo).
        var fd = external_call["open64", Int32](
            encoded.unsafe_ptr(), Int32(_O_RDONLY), Int32(0)
        )
        if fd < 0:
            raise Error("StreamReader: cannot open " + path)
        self.fd = fd
        self.path = path
        self.reads = 0
        self.bytes_read = 0
        self.advice_calls = 0
        self.advised_bytes = 0

    def read_slab(
        mut self, offset: Int, size: Int, mut buffer: List[UInt8]
    ) raises:
        """Read exactly [offset, offset+size) into buffer (len == size).

        Loops over partial preads; raises on error or on a short file
        (EOF before size bytes) -- a slab is either fully read or the
        read has failed, never silently partial.
        """
        if offset < 0:
            raise Error("StreamReader: negative slab offset")
        if size < 0 or len(buffer) != size:
            raise Error("StreamReader: buffer length must equal slab size")
        var filled = 0
        while filled < size:
            var got = external_call["pread", Int](
                self.fd,
                buffer.unsafe_ptr().unsafe_offset(filled),
                size - filled,
                Int64(offset + filled),
            )
            if got < 0:
                raise Error("StreamReader: pread failed")
            if got == 0:
                raise Error("StreamReader: short read at end of file")
            filled += got
        self.reads += 1
        self.bytes_read += size

    def advise(mut self, advice: Int, offset: Int, size: Int) raises:
        """posix_fadvise on [offset, offset+size); size 0 means to EOF."""
        if offset < 0 or size < 0:
            raise Error("StreamReader: negative advice range")
        var rc = external_call["posix_fadvise", Int32](
            self.fd, Int64(offset), Int64(size), Int32(advice)
        )
        if rc != 0:
            raise Error("StreamReader: posix_fadvise failed")
        self.advice_calls += 1
        self.advised_bytes += size

    def advise_willneed(mut self, offset: Int, size: Int) raises:
        """Ask the kernel to prefetch a future slab (J-019 pipeline)."""
        self.advise(FADV_WILLNEED, offset, size)

    def advise_sequential(mut self) raises:
        """Declare the descriptor's access pattern sequential."""
        self.advise(FADV_SEQUENTIAL, 0, 0)

    def close(mut self):
        if self.fd >= 0:
            _ = external_call["close", Int32](self.fd)
            self.fd = Int32(-1)

    def describe(self) -> String:
        return (
            "StreamReader(path="
            + self.path
            + ", reads="
            + String(self.reads)
            + ", bytes_read="
            + String(self.bytes_read)
            + ", advice_calls="
            + String(self.advice_calls)
            + ", advised_bytes="
            + String(self.advised_bytes)
            + ")"
        )
