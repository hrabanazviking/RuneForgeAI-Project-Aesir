"""Optional packed-weight public Turing MMA; no production dispatch.

Each warp computes16 weight rows by8 token columns. Original format equations
own decoding; weights use F16 high plus F16 residual, inputs convert once to
F16, and two MMA operations accumulate in F32. The fixed
primitive budgets, not exact scalar parity, own acceptance. No device workspace.
"""
from std.gpu import global_idx, block_idx, thread_idx
from std.memory import stack_allocation, AddressSpace
from std.collections import InlineArray
from max.gpu import barrier
from max.gpu.compute.mma import mma
from max.gpu.host import DeviceContext, DeviceBuffer
from max.gpu.host.device_context import DeviceFunction
from core.packed_quantization import Bytes, packed_value, packed_block_group
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


def accumulate_staged[precision: Int](top: SIMD[DType.float16,4],low: SIMD[DType.float16,4],
    high_input: SIMD[DType.float16,2],low_input: SIMD[DType.float16,2],
    total: SIMD[DType.float32,4]) -> SIMD[DType.float32,4]:
    """Scaled corrections start at zero; legacy accumulation order is unchanged."""
    var intermediate = SIMD[DType.float32,4](0)
    var result = SIMD[DType.float32,4](0)
    comptime if precision <= 2:
        mma(intermediate,top,high_input,total)
        mma(result,low,high_input,intermediate)
        comptime if precision != 0:
            mma(intermediate,top,low_input,result)
            comptime if precision == 2:
                mma(result,low,low_input,intermediate)
            else: result = intermediate
    else:
        var zero = SIMD[DType.float32,4](0)
        comptime if precision == 3:
            mma(result,top,high_input,total)
        else:
            mma(result,top,high_input,zero)
            result += total
        mma(intermediate,low,high_input,zero)
        result += intermediate*Float32(1.0/4096.0)
        mma(intermediate,top,low_input,zero)
        result += intermediate*Float32(1.0/4096.0)
        mma(intermediate,low,low_input,zero)
        result += intermediate*Float32(1.0/16777216.0)
    return result


def staged_turing_kernel[kind: Int,batch: Int,tile_rows: Int,tile_columns: Int = 32,activation_precision: Int = 0](w: Bytes,
    a: ProjectionFloats,base_arg: Int64,columns_arg: Int64,rows_arg: Int64,
    src_arg: Int64,dst_arg: Int64,stride_arg: Int64,tokens_arg: Int64):
    comptime assert kind == 12 or kind == 13 or kind == 14
    comptime assert batch == 4 or batch == 8 or batch == 16 or batch == 32
    comptime assert tile_rows == 16 or tile_rows == 32 or tile_rows == 64
    comptime assert tile_columns == 32 or tile_columns == 64 or tile_columns == 128
    comptime assert tile_rows != 16 or tile_columns == 32
    comptime assert activation_precision >= 0 and activation_precision <= 4
    comptime assert activation_precision == 0 or (tile_rows == 64 and tile_columns == 32)
    comptime input_rows = batch*(1+Int(activation_precision != 0))
    comptime residual_scale = Float32(4096 if activation_precision >= 3 else 1)
    comptime assert (2*tile_rows+input_rows)*(tile_columns+1)*2 <= 49152
    comptime pitch = tile_columns+1
    comptime warps = tile_rows//16
    comptime token_tiles = (batch+7)//8
    comptime block_bytes = 144 if kind == 12 else (176 if kind == 13 else 210)
    var high = stack_allocation[tile_rows*pitch,Float16,address_space=AddressSpace.SHARED]()
    var low = stack_allocation[tile_rows*pitch,Float16,address_space=AddressSpace.SHARED]()
    var inputs = stack_allocation[input_rows*pitch,Float16,address_space=AddressSpace.SHARED]()
    var tid = Int(thread_idx.x)
    var lane = tid%32
    var own_warp = tid//32
    var group = lane//4
    var member = lane%4
    var first_row = Int(block_idx.x)*tile_rows
    var rows = Int(rows_arg)
    var columns = Int(columns_arg)
    var totals = InlineArray[SIMD[DType.float32,4],token_tiles](fill=SIMD[DType.float32,4](0))
    for block in range(columns//256):
        comptime for section in range(256//tile_columns):
            # Coalesced original 32-column format decoding; every shared cell
            # consumed below is initialized, including inactive rows/tokens.
            comptime for subgroup in range(tile_columns//32):
                comptime source_group = section*(tile_columns//32)+subgroup
                comptime for part in range(16):
                    var local_row = own_warp+part*warps
                    var row = first_row+local_row
                    var value: Float32 = 0
                    if row < rows:
                        var p = Int(base_arg)+(row*(columns//256)+block)*block_bytes
                        var d = w.unsafe_offset(p+(208 if kind==14 else 0)).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
                        var dmin: Float32 = 0
                        comptime if kind != 14:
                            dmin = w.unsafe_offset(p+2).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
                        value = packed_block_group[kind,source_group](w,p,lane,d,dmin)
                    var top = value.cast[DType.float16]()
                    high.unsafe_store(local_row*pitch+subgroup*32+lane,top)
                    low.unsafe_store(local_row*pitch+subgroup*32+lane,((value-top.cast[DType.float32]())*residual_scale).cast[DType.float16]())
                comptime for part in range(batch//warps):
                    var token = own_warp+part*warps
                    var value: Float32 = 0
                    if token < Int(tokens_arg):
                        value = a.unsafe_load(Int(src_arg)+token*Int(stride_arg)+block*256+source_group*32+lane)
                    var top_input = value.cast[DType.float16]()
                    inputs.unsafe_store(token*pitch+subgroup*32+lane,top_input)
                    comptime if activation_precision != 0:
                        inputs.unsafe_store((batch+token)*pitch+subgroup*32+lane,((value-top_input.cast[DType.float32]())*residual_scale).cast[DType.float16]())
            barrier()
            comptime for token_tile in range(token_tiles):
                comptime for step in range(tile_columns//8):
                    var top = SIMD[DType.float16,4](0)
                    var residual = SIMD[DType.float16,4](0)
                    var activation = SIMD[DType.float16,2](0)
                    var activation_low = SIMD[DType.float16,2](0)
                    comptime for element in range(4):
                        var local_row = own_warp*16+group+element//2*8
                        var position = local_row*pitch+step*8+member*2+element%2
                        top[element] = high.unsafe_load(position)
                        residual[element] = low.unsafe_load(position)
                    var token = token_tile*8+group
                    # Padding the four-token shape to eight remains warp safe.
                    if token < batch:
                        comptime for element in range(2):
                            activation[element] = inputs.unsafe_load(token*pitch+step*8+member*2+element)
                            comptime if activation_precision != 0:
                                activation_low[element] = inputs.unsafe_load((batch+token)*pitch+step*8+member*2+element)
                    totals[token_tile] = accumulate_staged[activation_precision](top,residual,activation,activation_low,totals[token_tile])
            # No lane may overwrite staging before every warp consumes it.
            barrier()
    comptime for token_tile in range(token_tiles):
        comptime for element in range(4):
            var row = first_row+own_warp*16+group+element//2*8
            var token = token_tile*8+member*2+element%2
            if row < rows and token < Int(tokens_arg):
                a.unsafe_store(Int(dst_arg)+token*Int(stride_arg)+row,totals[token_tile][element])



def cached_header_turing_kernel[kind: Int,batch: Int,tile_rows: Int,tile_columns: Int = 32,activation_precision: Int = 0](w: Bytes,
    a: ProjectionFloats,base_arg: Int64,columns_arg: Int64,rows_arg: Int64,
    src_arg: Int64,dst_arg: Int64,stride_arg: Int64,tokens_arg: Int64):
    comptime cache_headers = True
    comptime assert kind == 12 or kind == 13 or kind == 14
    comptime assert batch == 4 or batch == 8 or batch == 16 or batch == 32
    comptime assert tile_rows == 16 or tile_rows == 32 or tile_rows == 64
    comptime assert tile_columns == 32 or tile_columns == 64 or tile_columns == 128
    comptime assert tile_rows != 16 or tile_columns == 32
    comptime assert activation_precision >= 0 and activation_precision <= 4
    comptime assert activation_precision == 0 or (tile_rows == 64 and tile_columns == 32)
    comptime assert not cache_headers or (activation_precision == 0 and tile_rows == 64 and tile_columns == 32)
    comptime input_rows = batch*(1+Int(activation_precision != 0))
    comptime residual_scale = Float32(4096 if activation_precision >= 3 else 1)
    comptime assert (2*tile_rows+input_rows)*(tile_columns+1)*2 <= 49152
    comptime pitch = tile_columns+1
    comptime warps = tile_rows//16
    comptime token_tiles = (batch+7)//8
    comptime block_bytes = 144 if kind == 12 else (176 if kind == 13 else 210)
    var high = stack_allocation[tile_rows*pitch,Float16,address_space=AddressSpace.SHARED]()
    var low = stack_allocation[tile_rows*pitch,Float16,address_space=AddressSpace.SHARED]()
    var inputs = stack_allocation[input_rows*pitch,Float16,address_space=AddressSpace.SHARED]()
    var tid = Int(thread_idx.x)
    var lane = tid%32
    var own_warp = tid//32
    var group = lane//4
    var member = lane%4
    var first_row = Int(block_idx.x)*tile_rows
    var rows = Int(rows_arg)
    var columns = Int(columns_arg)
    var totals = InlineArray[SIMD[DType.float32,4],token_tiles](fill=SIMD[DType.float32,4](0))
    var header_d = InlineArray[Float32,16](fill=0)
    var header_min = InlineArray[Float32,16](fill=0)
    for block in range(columns//256):
        comptime if cache_headers:
            # Header identity is constant across this block's eight sections.
            # Bounded per-thread storage trades register pressure for reused loads.
            comptime for part in range(16):
                var row = first_row+own_warp+part*warps
                header_d[part] = 0
                header_min[part] = 0
                if row < rows:
                    var p = Int(base_arg)+(row*(columns//256)+block)*block_bytes
                    header_d[part] = w.unsafe_offset(p+(208 if kind==14 else 0)).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
                    comptime if kind != 14:
                        header_min[part] = w.unsafe_offset(p+2).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
        comptime for section in range(256//tile_columns):
            # Coalesced original 32-column format decoding; every shared cell
            # consumed below is initialized, including inactive rows/tokens.
            comptime for subgroup in range(tile_columns//32):
                comptime source_group = section*(tile_columns//32)+subgroup
                comptime for part in range(16):
                    var local_row = own_warp+part*warps
                    var row = first_row+local_row
                    var value: Float32 = 0
                    if row < rows:
                        var p = Int(base_arg)+(row*(columns//256)+block)*block_bytes
                        var d: Float32
                        var dmin: Float32 = 0
                        comptime if cache_headers:
                            d = header_d[part]
                            dmin = header_min[part]
                        else:
                            d = w.unsafe_offset(p+(208 if kind==14 else 0)).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
                            comptime if kind != 14:
                                dmin = w.unsafe_offset(p+2).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
                        value = packed_block_group[kind,source_group](w,p,lane,d,dmin)
                    var top = value.cast[DType.float16]()
                    high.unsafe_store(local_row*pitch+subgroup*32+lane,top)
                    low.unsafe_store(local_row*pitch+subgroup*32+lane,((value-top.cast[DType.float32]())*residual_scale).cast[DType.float16]())
                comptime for part in range(batch//warps):
                    var token = own_warp+part*warps
                    var value: Float32 = 0
                    if token < Int(tokens_arg):
                        value = a.unsafe_load(Int(src_arg)+token*Int(stride_arg)+block*256+source_group*32+lane)
                    var top_input = value.cast[DType.float16]()
                    inputs.unsafe_store(token*pitch+subgroup*32+lane,top_input)
                    comptime if activation_precision != 0:
                        inputs.unsafe_store((batch+token)*pitch+subgroup*32+lane,((value-top_input.cast[DType.float32]())*residual_scale).cast[DType.float16]())
            barrier()
            comptime for token_tile in range(token_tiles):
                comptime for step in range(tile_columns//8):
                    var top = SIMD[DType.float16,4](0)
                    var residual = SIMD[DType.float16,4](0)
                    var activation = SIMD[DType.float16,2](0)
                    var activation_low = SIMD[DType.float16,2](0)
                    comptime for element in range(4):
                        var local_row = own_warp*16+group+element//2*8
                        var position = local_row*pitch+step*8+member*2+element%2
                        top[element] = high.unsafe_load(position)
                        residual[element] = low.unsafe_load(position)
                    var token = token_tile*8+group
                    # Padding the four-token shape to eight remains warp safe.
                    if token < batch:
                        comptime for element in range(2):
                            activation[element] = inputs.unsafe_load(token*pitch+step*8+member*2+element)
                            comptime if activation_precision != 0:
                                activation_low[element] = inputs.unsafe_load((batch+token)*pitch+step*8+member*2+element)
                    totals[token_tile] = accumulate_staged[activation_precision](top,residual,activation,activation_low,totals[token_tile])
            # No lane may overwrite staging before every warp consumes it.
            barrier()
    comptime for token_tile in range(token_tiles):
        comptime for element in range(4):
            var row = first_row+own_warp*16+group+element//2*8
            var token = token_tile*8+member*2+element%2
            if row < rows and token < Int(tokens_arg):
                a.unsafe_store(Int(dst_arg)+token*Int(stride_arg)+row,totals[token_tile][element])


def project_turing_staged[kind: Int,batch: Int,tile_rows: Int,tile_columns: Int = 32,activation_precision: Int = 0,cache_headers: Bool = False](ctx: DeviceContext,
    weights: DeviceBuffer[DType.uint8],activation: DeviceBuffer[DType.float32],
    base: Int,columns: Int,rows: Int,src: Int,dst: Int,stride: Int,tokens: Int) raises:
    """All-span admission before optional shared-stage launch; no global workspace."""
    comptime assert tile_rows == 16 or tile_rows == 32 or tile_rows == 64
    admit_matrix[kind,batch](len(weights),len(activation),base,columns,rows,src,dst,stride,tokens)
    var wp = Bytes(unsafe_from_address=Int(weights.unsafe_ptr()))
    var ap = ProjectionFloats(unsafe_from_address=Int(activation.unsafe_ptr()))
    comptime if cache_headers:
        var function = DeviceFunction[cached_header_turing_kernel[kind,batch,tile_rows,tile_columns,activation_precision],
            TypeList.of[Bytes,ProjectionFloats,Int64,Int64,Int64,Int64,Int64,Int64,Int64](),
            target=turing_ptx65_target()](ctx)
        ctx.enqueue_function(function,wp,ap,Int64(base),Int64(columns),Int64(rows),
            Int64(src),Int64(dst),Int64(stride),Int64(tokens),
            grid_dim=(rows+tile_rows-1)//tile_rows,block_dim=tile_rows//16*32)
    else:
        var function = DeviceFunction[staged_turing_kernel[kind,batch,tile_rows,tile_columns,activation_precision],
            TypeList.of[Bytes,ProjectionFloats,Int64,Int64,Int64,Int64,Int64,Int64,Int64](),
            target=turing_ptx65_target()](ctx)
        ctx.enqueue_function(function,wp,ap,Int64(base),Int64(columns),Int64(rows),
            Int64(src),Int64(dst),Int64(stride),Int64(tokens),
            grid_dim=(rows+tile_rows-1)//tile_rows,block_dim=tile_rows//16*32)
