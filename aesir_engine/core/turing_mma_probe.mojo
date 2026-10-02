"""Optional physical m16n8k8 feasibility; never production inference dispatch.

FP16 A4/B2 and F32 C4 registers follow NVIDIA's documented warp fragments.
Public locked MAX mma owns lowering. Its default sm_75 target uses PTX6.3,
which cannot select m16n8k8. Only this probe uses the matching target with PTX6.5;
no emitted-PTX patch, inline assembly, driver ABI or software fallback.
The generated exact binary matrices exercise dynamic operands, not constants.
"""
from std.gpu import global_idx
from max.gpu.compute.mma import mma
from max.gpu.host import DeviceContext, DeviceBuffer
from max.gpu.host.device_context import DeviceFunction
from std.sys.info import _TargetType
from core.packed_projection import ProjectionFloats


def turing_ptx65_target() -> _TargetType:
    """Matching MAX26.5 RTX2060 layout, with only PTX feature raised63 to65.

    The documented target-definition and DeviceFunction target interfaces own
    this isolated compatibility correction. sm_75 remains the actual hardware.
    """
    return __mlir_attr[
        `#kgen.target<triple = "nvptx64-nvidia-cuda", `,
        `stdlib_plugin = "cuda", `,
        `arch = "sm_75", `,
        `features = "+ptx65,+sm_75", `,
        `tune_cpu = "sm_75", `,
        `data_layout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64",`,
        `index_bit_width = 64,`,
        `simd_bit_width = 128`,
        `> : !kgen.target`,
    ]


@always_inline
def matrix_a(row: Int, column: Int, seed: Int, identity: Bool) -> Float32:
    if identity:
        return 1.0 if row % 8 == column else 0.0
    return Float32((row * 7 + column * 3 + seed * 5) % 17 - 8) / 16.0


@always_inline
def matrix_b(row: Int, column: Int, seed: Int, identity: Bool) -> Float32:
    if identity:
        return 1.0 if row == column else 0.0
    return Float32((row * 5 + column * 11 + seed * 3) % 19 - 9) / 16.0


@always_inline
def matrix_c(row: Int, column: Int, seed: Int, identity: Bool) -> Float32:
    if identity:
        return 0.0
    return Float32((row * 3 + column * 2 + seed) % 13 - 6) / 8.0


def turing_mma_kernel(output: ProjectionFloats, offset_arg: Int64, tiles_arg: Int64,
                      steps_arg: Int64, case_arg: Int64):
    var tile = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    # This branch is uniform within each warp, including the final block tail.
    if tile < Int(tiles_arg):
        var group = lane // 4
        var member = lane % 4
        var identity = Int(case_arg) == 0
        var seed = Int(case_arg) + tile * 7
        var accumulator = SIMD[DType.float32, 4](0)
        comptime for element in range(4):
            var row = group + element // 2 * 8
            var column = member * 2 + element % 2
            accumulator[element] = matrix_c(row,column,seed,identity)
        for step in range(Int(steps_arg)):
            var a = SIMD[DType.float16, 4](0)
            var b = SIMD[DType.float16, 2](0)
            comptime for element in range(4):
                var row = group + element // 2 * 8
                var column = member * 2 + element % 2
                a[element] = matrix_a(row,column,seed+step*11,identity).cast[DType.float16]()
            comptime for element in range(2):
                var row = member * 2 + element
                b[element] = matrix_b(row,group,seed+step*11,identity).cast[DType.float16]()
            var result = SIMD[DType.float32, 4](0)
            mma(result,a,b,accumulator)
            accumulator = result
        comptime for element in range(4):
            var row = group + element // 2 * 8
            var column = member * 2 + element % 2
            output.unsafe_store(Int(offset_arg)+tile*128+row*8+column,accumulator[element])


def admit_mma(elements: Int, offset: Int, tiles: Int, steps: Int, case_index: Int,
              block_size: Int) raises:
    if tiles < 1 or tiles > 64 or steps < 1 or steps > 16 or case_index < 0 or case_index > 5:
        raise Error("MMA probe metadata is outside declared bounds")
    if block_size != 32 and block_size != 128:
        raise Error("MMA probe requires declared warp-compatible block shape")
    if offset < 0 or offset > elements or tiles * 128 > elements - offset:
        raise Error("MMA probe output exceeds borrowed span")


def launch_mma(ctx: DeviceContext, output: DeviceBuffer[DType.float32], offset: Int,
               tiles: Int, steps: Int, case_index: Int, block_size: Int) raises:
    admit_mma(len(output),offset,tiles,steps,case_index,block_size)
    var pointer = ProjectionFloats(unsafe_from_address=Int(output.unsafe_ptr()))
    var function = DeviceFunction[turing_mma_kernel,
        TypeList.of[ProjectionFloats,Int64,Int64,Int64,Int64](),target=turing_ptx65_target()](ctx)
    ctx.enqueue_function(function,pointer,Int64(offset),Int64(tiles),Int64(steps),
        Int64(case_index),grid_dim=(tiles*32+block_size-1)//block_size,block_dim=block_size)
