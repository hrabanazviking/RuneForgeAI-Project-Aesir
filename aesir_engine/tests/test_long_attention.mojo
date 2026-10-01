"""Physical original-order long-attention parity and independent CSV output."""
from max.gpu.host import DeviceContext
from core.llama3_kernels import Halves, llama_attention, llama_attention_tiled
from core.gemma4_kernels import Floats


def check(ctx: DeviceContext, count: Int, heads: Int) raises:
    var dim = 128
    var kv_heads = 8
    var width = kv_heads * dim
    var capacity = count + 3
    var offset = 17
    var scores = 19
    var first = scores + heads * count + 11
    var second = first + heads * dim + 13
    var size = second + heads * dim + 17
    var a = ctx.enqueue_create_buffer[DType.float32](size)
    var h = ctx.enqueue_create_host_buffer[DType.float32](size)
    var kv = ctx.enqueue_create_buffer[DType.float16](offset + 2 * capacity * width + 13)
    var kh = ctx.enqueue_create_host_buffer[DType.float16](offset + 2 * capacity * width + 13)
    for i in range(size):
        h[i] = -9876
    for head in range(heads):
        for t in range(count):
            h[scores + head * count + t] = Float32((t + head * 7) % 17 + 1) / Float32(count * 9)
    for i in range(offset + 2 * capacity * width + 13):
        kh[i] = Float16(-9876)
    for t in range(count):
        for i in range(width):
            kh[offset + capacity * width + t * width + i] = (Float32((t * 13 + i * 7) % 97 - 48) / 17).cast[DType.float16]()
    ctx.enqueue_copy(a, h)
    ctx.enqueue_copy(kv, kh)
    var ap = Floats(unsafe_from_address=Int(a.unsafe_ptr()))
    var kp = Halves(unsafe_from_address=Int(kv.unsafe_ptr()))
    ctx.enqueue_function[llama_attention](ap, kp, Int64(scores), Int64(first), Int64(offset), Int64(capacity), Int64(count), Int64(dim), Int64(heads), Int64(kv_heads), grid_dim=(heads * dim + 127) // 128, block_dim=128)
    ctx.enqueue_function[llama_attention_tiled](ap, kp, Int64(scores), Int64(second), Int64(offset), Int64(capacity), Int64(count), Int64(dim), Int64(heads), Int64(kv_heads), grid_dim=(heads * dim + 127) // 128, block_dim=128)
    ctx.enqueue_copy(h, a)
    ctx.synchronize()
    for i in range(heads * dim):
        if h[first + i] != h[second + i]:
            raise Error("Tiled attention changed chronological accumulation")
        print(String(count) + "," + String(heads) + "," + String(i) + "," + String(h[second + i]))
    for i in range(13):
        if h[first + heads * dim + i] != -9876 or h[second + heads * dim + i] != -9876:
            raise Error("Attention wrote outside its output span")


def main() raises:
    var ctx = DeviceContext(0, api="cuda")
    for count in [1, 7, 31, 32, 33, 1024, 4096, 8192]:
        for heads in [8, 24, 32]:
            check(ctx, count, heads)
    print("PASS: 24 exact long-attention cases and guarded outputs")
