"""Unscored actual guarded F16 cache identity via an owned anonymous Linux inode."""
from std.ffi import external_call
from tests.turing_prefill_fixture import TuringPrefillFixture
from cli.storage import digest_open_fd


def guarded_cache_digest(f: TuringPrefillFixture) raises -> String:
    var copy = f.native.context.enqueue_create_host_buffer[DType.float16](len(f.cache))
    f.native.context.enqueue_copy(copy,f.cache)
    f.native.context.synchronize()
    var name: List[Int8] = [97,101,115,105,114,45,99,97,99,104,101,0]
    var fd = external_call["memfd_create",Int32](name.unsafe_ptr(),UInt32(1))
    if fd < 0: raise Error("Cannot reserve anonymous guarded-cache inode")
    var result: String
    try:
        var pointer = copy.unsafe_ptr().unsafe_bitcast[Int8]()
        var bytes = len(copy)*2
        var written = 0
        while written < bytes:
            var chunk = min(bytes-written,1048576)
            var count = external_call["write",Int](Int(fd),pointer.unsafe_offset(written),chunk)
            if count <= 0 or count > chunk: raise Error("Anonymous cache copy write failed")
            written += Int(count)
        var digest = digest_open_fd(fd)
        result = String(digest[byte=7:])
    except:
        _ = external_call["close",Int32](fd)
        raise
    if external_call["close",Int32](fd) != 0: raise Error("Anonymous guarded-cache inode close failed")
    return result
