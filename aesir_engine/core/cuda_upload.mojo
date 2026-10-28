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
    if len(destination) != source_bytes:
        raise Error("CUDA upload source/destination extent mismatch")
    return upload_cuda_bytes_at(context, destination, 0, source, source_bytes,
                                chunk_bytes)


def upload_cuda_bytes_at(context: DeviceContext, destination: DeviceBuffer[DType.uint8],
                         destination_offset: Int,
                         source: Pointer[UInt8, MutUntrackedOrigin], source_bytes: Int,
                         chunk_bytes: Int = MAX_UPLOAD_STAGING_BYTES) raises -> Int:
    """Copy source_bytes from a host pointer into the destination buffer at
    destination_offset, through the same bounded pinned staging as
    upload_cuda_bytes. The destination may be larger than the copied range
    (compacted multi-tensor uploads); the range must fit inside it."""
    var capacity = upload_staging_bytes(source_bytes, chunk_bytes)
    if destination_offset < 0 or destination_offset + source_bytes > len(destination):
        raise Error("CUDA upload range exceeds destination extent")
    if context.api() != "cuda" or not context.is_compatible():
        raise Error("Native upload requires a compatible CUDA context")
    var staging = context.enqueue_create_host_buffer[DType.uint8](capacity)
    var offset = 0
    while offset < source_bytes:
        var count = min(capacity, source_bytes - offset)
        unsafe_memcpy(dest=staging.unsafe_ptr(), src=source.unsafe_offset(offset), count=count)
        var view = destination.create_sub_buffer[DType.uint8](destination_offset + offset, count)
        view.enqueue_copy_from(staging.unsafe_ptr())
        context.synchronize()
        offset += count
    # Keep the pinned owner alive across every asynchronous copy/synchronization.
    _ = staging
    return capacity
