# Original bounded source-byte streaming wrapper. Compression stays in fw.mojo.
# An observed byte stream is not an immutable snapshot or artifact binding.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.fw import _sha256_block
from hailbru.syscall import os_fd_regular_size, os_pread_metadata, errno_now


struct SourceSha256State(Movable):
    var chain: List[UInt32]
    var pending: List[UInt8]
    var byte_count: UInt64
    var sealed: Bool

    def __init__(out self):
        self.chain = [0x6A09E667, 0xBB67AE85, 0x3C6EF372,
            0xA54FF53A, 0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19]
        self.pending = List[UInt8]()
        self.byte_count = 0
        self.sealed = False


def _validate_source_sha256(state: SourceSha256State) raises:
    if state.sealed:
        raise Error("SourceDigest: SHA256 state is sealed")
    if len(state.chain) != 8 or len(state.pending) > 63:
        raise Error("SourceDigest: invalid SHA256 state shape")
    if state.byte_count > UInt64(2305843009213693951) or state.byte_count % 64 != UInt64(len(state.pending)):
        raise Error("SourceDigest: invalid SHA256 count/pending agreement")


def _absorb_source_byte(mut state: SourceSha256State, byte: UInt8):
    state.pending.append(byte)
    if len(state.pending) == 64:
        _sha256_block(state.chain, state.pending)
        state.pending.clear()


def source_sha256_update(mut state: SourceSha256State, data: List[UInt8]) raises:
    _validate_source_sha256(state)
    if UInt64(len(data)) > UInt64(2305843009213693951) - state.byte_count:
        raise Error("SourceDigest: SHA256 byte count overflow")
    for i in range(len(data)):
        _absorb_source_byte(state, data[i])
    state.byte_count += UInt64(len(data))


def source_sha256_finish(mut state: SourceSha256State) raises -> String:
    _validate_source_sha256(state)
    var bit_count = state.byte_count * UInt64(8)
    _absorb_source_byte(state, 0x80)
    while len(state.pending) != 56:
        _absorb_source_byte(state, 0)
    for i in range(8):
        _absorb_source_byte(state, UInt8((bit_count >> UInt64(8 * (7 - i))) & 255))
    var digits = "0123456789abcdef"
    var result = String("")
    for i in range(8):
        for j in range(8):
            var nibble = Int((state.chain[i] >> UInt32(4 * (7 - j))) & 15)
            result += String(chr(Int(digits.as_bytes()[nibble])))
    state.sealed = True
    return result


def sha256_source_bytes(data: List[UInt8]) raises -> String:
    var state = SourceSha256State()
    source_sha256_update(state, data)
    return source_sha256_finish(state)


@fieldwise_init
struct BorrowedSourceDigest(Movable):
    var source_bytes: Int64
    var first: Int
    var count: Int
    var read_calls: Int
    var digest_hex: String


def digest_borrowed_regular_window(arch: String, fd: Int64, expected_size: Int64,
        first: Int, count: Int, read_byte_bound: Int,
        read_call_bound: Int) raises -> BorrowedSourceDigest:
    if arch != "aarch64" or fd < 0 or fd > 2147483647:
        raise Error("SourceDigest: ARM64 Linux and exact regular descriptor required")
    if expected_size < 0 or first < 0 or count < 0 or Int64(first) > expected_size:
        raise Error("SourceDigest: invalid source byte range")
    if Int64(count) > expected_size - Int64(first):
        raise Error("SourceDigest: source byte range exceeds extent")
    if read_byte_bound <= 0 or read_call_bound <= 0 or count > read_byte_bound:
        raise Error("SourceDigest: explicit positive byte/read bounds required")
    if UInt64(count) > UInt64(2305843009213693951):
        raise Error("SourceDigest: SHA256 source byte count overflow")
    if os_fd_regular_size(arch, fd) != expected_size:
        raise Error("SourceDigest: source extent differs before read")
    var state = SourceSha256State()
    # List owns the sole I/O buffer, including exception cleanup. No mmap read.
    var scratch = List[UInt8](length=min(4096, count), fill=0)
    var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(scratch.unsafe_ptr()))
    var done = 0
    var calls = 0
    while done < count:
        if calls >= read_call_bound:
            raise Error("SourceDigest: positional read-call bound exhausted")
        var want = min(4096, count - done)
        calls += 1
        var n = os_pread_metadata(arch, fd, pointer, Int64(want), Int64(first + done))
        if n < 0:
            if errno_now() == 4:
                continue
            raise Error("SourceDigest: positional read failed")
        if n == 0 or n > Int64(want):
            raise Error("SourceDigest: positional read did not make valid progress")
        for i in range(Int(n)):
            _absorb_source_byte(state, scratch[i])
        state.byte_count += UInt64(n)
        done += Int(n)
    if os_fd_regular_size(arch, fd) != expected_size:
        raise Error("SourceDigest: source extent differs after read")
    var digest = source_sha256_finish(state)
    return BorrowedSourceDigest(expected_size, first, count, calls, digest^)
