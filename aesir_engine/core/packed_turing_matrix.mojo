"""Optional packed-weight public Turing MMA; no production dispatch.

Each warp computes16 weight rows by8 token columns. Original format equations
own decoding; weights use F16 high plus F16 residual, inputs convert once to
F16, and two MMA operations accumulate in F32. The fixed
primitive budgets, not exact scalar parity, own acceptance. No device workspace.
"""
from std.gpu import global_idx
from max.gpu.compute.mma import mma
from max.gpu.host import DeviceContext, DeviceBuffer
from max.gpu.host.device_context import DeviceFunction
from core.packed_quantization import Bytes, packed_value
from core.packed_projection import ProjectionFloats
from core.packed_matrix import admit_matrix
from core.turing_mma_probe import turing_ptx65_target


def packed_turing_kernel[kind: Int](w: Bytes, a: ProjectionFloats, base_arg: Int64,
    columns_arg: Int64, rows_arg: Int64, src_arg: Int64, dst_arg: Int64,
    stride_arg: Int64, tokens_arg: Int64):
    comptime assert kind == 12 or kind == 13 or kind == 14
    var tile = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    var rows = Int(rows_arg)
    var columns = Int(columns_arg)
    var tokens = Int(tokens_arg)
    var row_tiles = (rows + 15) // 16
    var token_tiles = (tokens + 7) // 8
    # All active lanes reach public MMA; inactive final warps branch uniformly.
    if tile < row_tiles * token_tiles:
        var row_base = tile % row_tiles * 16
        var token_base = tile // row_tiles * 8
        var group = lane // 4
        var member = lane % 4
        var total = SIMD[DType.float32, 4](0)
        for column in range(0, columns, 8):
            var weights = SIMD[DType.float16, 4](0)
            var residuals = SIMD[DType.float16, 4](0)
            var inputs = SIMD[DType.float16, 2](0)
            comptime for element in range(4):
                var row = row_base + group + element // 2 * 8
                var k = column + member * 2 + element % 2
                if row < rows:
                    var value = packed_value(w,Int(base_arg),kind,row*columns+k)
                    weights[element] = value.cast[DType.float16]()
                    residuals[element] = (value-weights[element].cast[DType.float32]()).cast[DType.float16]()
            var token = token_base + group
            if token < tokens:
                comptime for element in range(2):
                    inputs[element] = a.unsafe_load(Int(src_arg)+token*Int(stride_arg)+column+member*2+element).cast[DType.float16]()
            var next_total = SIMD[DType.float32, 4](0)
            mma(next_total,weights,inputs,total)
            mma(total,residuals,inputs,next_total)
        comptime for element in range(4):
            var row = row_base + group + element // 2 * 8
            var token = token_base + member * 2 + element % 2
            if row < rows and token < tokens:
                a.unsafe_store(Int(dst_arg)+token*Int(stride_arg)+row,total[element])


def project_turing[kind: Int,batch: Int](ctx: DeviceContext,
    weights: DeviceBuffer[DType.uint8], activation: DeviceBuffer[DType.float32],
    base: Int, columns: Int, rows: Int, src: Int, dst: Int, stride: Int, tokens: Int) raises:
    """Checked borrowed spans, version-locked target, zero extra device allocation."""
    admit_matrix[kind,batch](len(weights),len(activation),base,columns,rows,src,dst,stride,tokens)
    var wp = Bytes(unsafe_from_address=Int(weights.unsafe_ptr()))
    var ap = ProjectionFloats(unsafe_from_address=Int(activation.unsafe_ptr()))
    var function = DeviceFunction[packed_turing_kernel[kind],
        TypeList.of[Bytes,ProjectionFloats,Int64,Int64,Int64,Int64,Int64,Int64,Int64](),
        target=turing_ptx65_target()](ctx)
    var tiles = ((rows+15)//16)*((tokens+7)//8)
    ctx.enqueue_function(function,wp,ap,Int64(base),Int64(columns),Int64(rows),
        Int64(src),Int64(dst),Int64(stride),Int64(tokens),grid_dim=(tiles+3)//4,block_dim=128)
