"""Opt-in physical CUDA block-reader/reference parity and row/tail guards.

Synthetic K blocks exercise every lane/group, signed scales, six row widths
and three formats. This is algorithm regression evidence, not model admission.
Independent real GGUF rows remain a separate required acceptance gate.
"""
from max.gpu.host import DeviceContext
from core.gemma4_kernels import matvec_kernel
from core.packed_projection import block_matvec_kernel, ProjectionFloats
from core.packed_quantization import Bytes


def check[kind: Int](ctx: DeviceContext, columns: Int, rows: Int) raises:
    comptime block_bytes = 144 if kind == 12 else (176 if kind == 13 else 210)
    var span = ((rows + 15) // 16) * 16
    var prefix = 32
    var size = prefix + rows * columns // 256 * block_bytes + 32
    var weights = ctx.enqueue_create_buffer[DType.uint8](size)
    var bytes = ctx.enqueue_create_host_buffer[DType.uint8](size)
    for i in range(size):
        bytes[i] = UInt8((i * 37 + i // 7) % 256)
    for block in range(rows * columns // 256):
        var p = prefix + block * block_bytes
        # Exact finite half encodings: d=1/16, dmin=1/32, alternating d sign.
        var scale_offset = p + (208 if kind == 14 else 0)
        bytes[scale_offset] = 0
        bytes[scale_offset + 1] = UInt8(44 if block % 2 == 0 else 172)
        comptime if kind != 14:
            bytes[p + 2] = 0
            bytes[p + 3] = 40
    var activation = ctx.enqueue_create_buffer[DType.float32](columns + 2 * span + 16)
    var host = ctx.enqueue_create_host_buffer[DType.float32](columns + 2 * span + 16)
    for i in range(columns + 2 * span + 16):
        host[i] = Float32((i * 7) % 29 - 14) / 16.0
    for i in range(2 * span):
        host[columns + i] = -9876
    ctx.enqueue_copy(weights, bytes)
    ctx.enqueue_copy(activation, host)
    var wp = Bytes(unsafe_from_address=Int(weights.unsafe_ptr()))
    var ap = ProjectionFloats(unsafe_from_address=Int(activation.unsafe_ptr()))
    ctx.enqueue_function[matvec_kernel](wp, ap, Int64(prefix), Int64(kind),
        Int64(columns), Int64(rows), Int64(0), Int64(columns), grid_dim=(rows + 3) // 4, block_dim=128)
    ctx.enqueue_function[block_matvec_kernel[kind]](wp, ap, Int64(prefix),
        Int64(columns), Int64(rows), Int64(0), Int64(columns + span), grid_dim=(rows + 3) // 4, block_dim=128)
    ctx.enqueue_copy(host, activation)
    ctx.synchronize()
    for row in range(rows):
        if host[columns + row] != host[columns + span + row]:
            raise Error("Block projection changed reference accumulation")
    for row in range(rows, span):
        if host[columns + row] != -9876 or host[columns + span + row] != -9876:
            raise Error("Projection wrote outside admitted row count")


def main() raises:
    var ctx = DeviceContext(0, api="cuda")
    for columns in [256, 512, 1024, 3072, 8192, 14336]:
        for rows in [1, 7, 33]:
            check[12](ctx, columns, rows)
            check[13](ctx, columns, rows)
            check[14](ctx, columns, rows)
    print("PASS: CUDA Q4_K/Q5_K/Q6_K block/reference exact parity; 738 rows, 1404 tail guards")
