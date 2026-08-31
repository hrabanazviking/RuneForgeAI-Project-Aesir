"""Bounded pinned staging for already validated model bytes.

The caller owns the source mapping until this synchronous operation returns
and supplies a destination allocated on the given context's ordered stream.
No host pointer is retained. Each transfer completes before staging is reused.
"""
from max.gpu.host import DeviceContext, DeviceBuffer
from std.memory import Pointer, unsafe_memcpy

comptime MAX_UPLOAD_STAGING_BYTES = 67108864


def upload_staging_bytes(size: Int, chunk_bytes: Int = MAX_UPLOAD_STAGING_BYTES) raises -> Int:
    if size <= 0 or chunk_bytes <= 0 or chunk_bytes > MAX_UPLOAD_STAGING_BYTES:
        raise Error("CUDA upload requires positive size and a staging chunk within 1..64 MiB")
    return min(size, chunk_bytes)


def upload_cuda_bytes(context: DeviceContext, destination: DeviceBuffer[DType.uint8],
                      source: Pointer[UInt8, MutUntrackedOrigin], source_bytes: Int,
                      chunk_bytes: Int = MAX_UPLOAD_STAGING_BYTES) raises -> Int:
    var capacity = upload_staging_bytes(source_bytes, chunk_bytes)
    if len(destination) != source_bytes:
        raise Error("CUDA upload source/destination extent mismatch")
    if context.api() != "cuda" or not context.is_compatible():
        raise Error("Native upload requires a compatible CUDA context")
    var staging = context.enqueue_create_host_buffer[DType.uint8](capacity)
    var offset = 0
    while offset < source_bytes:
        var count = min(capacity, source_bytes - offset)
        unsafe_memcpy(dest=staging.unsafe_ptr(), src=source.unsafe_offset(offset), count=count)
        var view = destination.create_sub_buffer[DType.uint8](offset, count)
        view.enqueue_copy_from(staging.unsafe_ptr())
        context.synchronize()
        offset += count
    # Keep the pinned owner alive across every asynchronous copy/synchronization.
    _ = staging
    return capacity
