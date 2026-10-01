"""Physical fixed-width/scalar RMS parity, in-place writes and span guards.

CSV values are independently checked by scripts/check_dense_normalization.py.
Finite synthetic inputs prove normalization equations, not full-model logits.
"""
from max.gpu.host import DeviceContext
from core.gemma4_kernels import norm_kernel
from core.dense_normalization import dense_norm_kernel
from core.packed_quantization import Bytes
from core.packed_projection import ProjectionFloats


def check[width: Int](ctx: DeviceContext, groups: Int, inplace: Bool, case_index: Int) raises:
    var src = 17
    var dst = src if inplace else src + width * groups + 13
    var size = src + width * groups * 2 + 32
    var weight = 16
    var w = ctx.enqueue_create_buffer[DType.float32](width + 8)
    var wh = ctx.enqueue_create_host_buffer[DType.float32](width + 8)
    for i in range(width + 8):
        wh[i] = Float32((i * 5) % 17 - 8) / 8
    var a = ctx.enqueue_create_buffer[DType.float32](size)
    var h = ctx.enqueue_create_host_buffer[DType.float32](size)
    var expected = List[Float32]()
    var wp = Bytes(unsafe_from_address=Int(w.unsafe_ptr()))
    var ap = ProjectionFloats(unsafe_from_address=Int(a.unsafe_ptr()))
    ctx.enqueue_copy(w, wh)
    for pass_index in range(2):
        for i in range(size):
            h[i] = -9876
        for i in range(width * groups):
            var value = Float32((i * 7) % 29 - 14) / 16
            if case_index == 1:
                value = 0
            elif case_index == 2:
                value *= 1.0e-12
            elif case_index == 3:
                value *= 1.0e12
            h[src + i] = value
        ctx.enqueue_copy(a, h)
        if pass_index == 0:
            ctx.enqueue_function[norm_kernel](wp, ap, Int64(weight), Int64(src),
                Int64(dst), Int64(width), Int64(groups), Float32(0.00001), Float32(1),
                grid_dim=(groups + 3) // 4, block_dim=128)
        else:
            ctx.enqueue_function[dense_norm_kernel[width]](wp, ap, Int64(weight),
                Int64(src), Int64(dst), Int64(groups), Float32(0.00001),
                grid_dim=(groups + 3) // 4, block_dim=128)
        ctx.enqueue_copy(h, a)
        ctx.synchronize()
        for i in range(size):
            if pass_index == 0:
                expected.append(h[i])
            elif h[i] != expected[i]:
                raise Error("Fixed RMS changed scalar output or an unowned span")
    for i in range(width * groups):
        print(String(width) + "," + String(groups) + "," + String(Int(inplace)) + "," +
            String(case_index) + "," + String(i) + "," + String(h[dst + i]))


def main() raises:
    var ctx = DeviceContext(0, api="cuda")
    for groups in [1, 3]:
        for inplace in [False, True]:
            for case_index in range(4):
                check[128](ctx, groups, inplace, case_index)
                check[3072](ctx, groups, inplace, case_index)
                check[4096](ctx, groups, inplace, case_index)
    print("PASS: 48 CUDA RMS reference/guard cases; 233472 independent values emitted")
