"""Optional disjoint token-partition Turing MMA; no production dispatch."""
from std.gpu import block_idx, thread_idx
from std.memory import stack_allocation, AddressSpace
from std.collections import InlineArray
from max.gpu import barrier
from max.gpu.host import DeviceContext, DeviceBuffer
from max.gpu.host.device_context import DeviceFunction
from core.packed_quantization import Bytes, packed_block_group
from core.packed_projection import ProjectionFloats
from core.packed_matrix import admit_matrix
from core.turing_mma_probe import turing_ptx65_target
from core.packed_turing_matrix import accumulate_staged


def partition_turing_kernel[kind: Int,logical_batch: Int,tile_rows: Int,token_tile: Int](w: Bytes,
    a: ProjectionFloats,base_arg: Int64,columns_arg: Int64,rows_arg: Int64,
    src_arg: Int64,dst_arg: Int64,stride_arg: Int64,tokens_arg: Int64):
    comptime batch = token_tile
    comptime tile_columns = 32
    comptime activation_precision = 0
    comptime assert logical_batch == 4 or logical_batch == 8 or logical_batch == 16 or logical_batch == 32
    comptime assert token_tile == 8 or token_tile == 16
    comptime assert kind == 12 or kind == 13 or kind == 14
    comptime assert batch == 4 or batch == 8 or batch == 16 or batch == 32
    comptime assert tile_rows == 64 or tile_rows == 128
    comptime assert tile_columns == 32
    comptime assert tile_rows//16*32 <= 256
    comptime assert activation_precision == 0
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
    var first_token = Int(block_idx.y)*token_tile
    var active_tokens = Int(tokens_arg)-first_token
    var partition = a.unsafe_offset(first_token*Int(stride_arg))
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
                # Every row warp initializes its owned partition input cells.
                # Extra row warps never store beyond the batch-sized shared array.
                comptime for part in range((batch+warps-1)//warps):
                    var token = own_warp+part*warps
                    if token < batch:
                        var value: Float32 = 0
                        if token < active_tokens:
                            value = partition.unsafe_load(Int(src_arg)+token*Int(stride_arg)+block*256+source_group*32+lane)
                        inputs.unsafe_store(token*pitch+subgroup*32+lane,value.cast[DType.float16]())
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
            if row < rows and token < active_tokens:
                partition.unsafe_store(Int(dst_arg)+token*Int(stride_arg)+row,totals[token_tile][element])

def project_turing_partition[kind: Int,batch: Int,tile_rows: Int,token_tile: Int](ctx: DeviceContext,
    weights: DeviceBuffer[DType.uint8],activation: DeviceBuffer[DType.float32],
    base: Int,columns: Int,rows: Int,src: Int,dst: Int,stride: Int,tokens: Int) raises:
    """One owned two-dimensional launch after complete original span admission."""
    comptime assert tile_rows == 64 or tile_rows == 128
    comptime assert token_tile == 8 or token_tile == 16
    admit_matrix[kind,batch](len(weights),len(activation),base,columns,rows,src,dst,stride,tokens)
    var wp = Bytes(unsafe_from_address=Int(weights.unsafe_ptr()))
    var ap = ProjectionFloats(unsafe_from_address=Int(activation.unsafe_ptr()))
    var function = DeviceFunction[partition_turing_kernel[kind,batch,tile_rows,token_tile],
        TypeList.of[Bytes,ProjectionFloats,Int64,Int64,Int64,Int64,Int64,Int64,Int64](),
        target=turing_ptx65_target()](ctx)
    ctx.enqueue_function(function,wp,ap,Int64(base),Int64(columns),Int64(rows),
        Int64(src),Int64(dst),Int64(stride),Int64(tokens),
        grid_dim=((rows+tile_rows-1)//tile_rows,(tokens+token_tile-1)//token_tile),
        block_dim=tile_rows//16*32)
