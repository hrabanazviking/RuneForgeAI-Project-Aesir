"""Physical CUDA outputs for independent NumPy RoPE/SiLU/F16-GQA checks."""
from max.gpu.host import DeviceContext
from core.gemma4_kernels import Floats
from core.llama3_kernels import Halves, llama_rope, llama_silu, llama_cache, llama_scores, llama_softmax, llama_attention

def main() raises:
    var ctx = DeviceContext(0, api="cuda")
    var a = ctx.enqueue_create_buffer[DType.float32](40000)
    var host = ctx.enqueue_create_host_buffer[DType.float32](40000)
    var kv = ctx.enqueue_create_buffer[DType.float16](137 + 7 * 2 * 1024)
    var ap = Floats(unsafe_from_address=Int(a.unsafe_ptr()))
    var kp = Halves(unsafe_from_address=Int(kv.unsafe_ptr()))
    var positions: List[Int] = [0, 1, 127, 8191]
    for position in positions:
        for i in range(40000):
            host[i] = Float32(i % 97 - 48) / 16
        ctx.enqueue_copy(a, host)
        ctx.enqueue_function[llama_rope](ap, Int64(0), Int64(32), Int64(position), grid_dim=16, block_dim=128)
        ctx.enqueue_copy(host, a)
        ctx.synchronize()
        for i in range(4096):
            print("rope," + String(position) + "," + String(i) + "," + String(host[i]))
    for i in range(40000):
        host[i] = Float32(i % 97 - 48) / 16
    ctx.enqueue_copy(a, host)
    ctx.enqueue_function[llama_silu](ap, Int64(0), Int64(16000), Int64(14336), grid_dim=112, block_dim=128)
    ctx.enqueue_copy(host, a)
    ctx.synchronize()
    for i in range(14336):
        print("silu,0," + String(i) + "," + String(host[16000 + i]))
    # Distinct keys/values at every position expose cache strides and GQA mapping.
    for t in range(7):
        for i in range(40000):
            host[i] = Float32((i + t * 13) % 97 - 48) / 17
        ctx.enqueue_copy(a, host)
        ctx.enqueue_function[llama_cache](ap, kp, Int64(4096), Int64(5120), Int64(137), Int64(7), Int64(t), grid_dim=8, block_dim=128)
        ctx.synchronize()
    for i in range(40000):
        host[i] = Float32(i % 97 - 48) / 16
    ctx.enqueue_copy(a, host)
    ctx.enqueue_function[llama_scores](ap, kp, Int64(0), Int64(7168), Int64(137), Int64(7), grid_dim=56, block_dim=128)
    ctx.enqueue_function[llama_softmax](ap, Int64(7168), Int64(7), grid_dim=8, block_dim=128)
    ctx.enqueue_function[llama_attention](ap, kp, Int64(7168), Int64(8192), Int64(137), Int64(7), Int64(7), grid_dim=32, block_dim=128)
    ctx.enqueue_copy(host, a)
    ctx.synchronize()
    for i in range(4096):
        print("attention,0," + String(i) + "," + String(host[8192 + i]))
