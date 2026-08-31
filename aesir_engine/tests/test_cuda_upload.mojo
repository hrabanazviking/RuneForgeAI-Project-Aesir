"""Opt-in physical CUDA round trips for bounded model upload staging."""
from max.gpu.host import DeviceContext
from core.cuda_upload import upload_cuda_bytes, MAX_UPLOAD_STAGING_BYTES


def main() raises:
    var context = DeviceContext(0, api="cuda")
    var sizes: List[Int] = [1, 7, 31, 32, 65, 65536, 65539, 67108865, 134217729]
    var chunks: List[Int] = [1, 31, 31, 31, 31, 65536, 65536, 67108864, 67108864]
    var checked = 0
    for scenario in range(len(sizes)):
        var size = sizes[scenario]
        var source = List[UInt8](capacity=size)
        for i in range(size):
            source.append(UInt8((i * 131 + i // 251 + 17) % 256))
        var device = context.enqueue_create_buffer[DType.uint8](size)
        device.enqueue_fill(99)
        var staging = upload_cuda_bytes(context, device,
            source.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), size, chunks[scenario])
        if staging != min(size, chunks[scenario]) or staging > MAX_UPLOAD_STAGING_BYTES:
            raise Error("Upload staging exceeded its advertised bound")
        var output = context.enqueue_create_host_buffer[DType.uint8](size)
        context.enqueue_copy(output, device)
        context.synchronize()
        for i in range(size):
            if output[i] != UInt8((i * 131 + i // 251 + 17) % 256):
                raise Error("CUDA upload byte mismatch at " + String(i))
        checked += size
        _ = source
        _ = device
        print("PASS upload bytes=", size, "staging_bytes=", staging)
    var device = context.enqueue_create_buffer[DType.uint8](3)
    var source: List[UInt8] = [1, 2, 3, 4]
    for choice in range(3):
        var rejected = False
        try:
            if choice == 0:
                _ = upload_cuda_bytes(context, device, source.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), 4)
            elif choice == 1:
                _ = upload_cuda_bytes(context, device, source.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), 3, 67108865)
            else:
                _ = upload_cuda_bytes(context, device, source.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), 3, 0)
        except:
            rejected = True
        if not rejected:
            raise Error("Unsafe CUDA upload accepted")
    _ = source
    print("PASS native CUDA upload: round_trips=9 bytes=", checked, "negative_cases=3")
