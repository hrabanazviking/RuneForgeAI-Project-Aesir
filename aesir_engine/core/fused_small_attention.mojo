"""Opt-in strict3B bounded1536 shared-score GQA; original arithmetic, no global scratch."""
from std.gpu import block_idx, thread_idx
from std.gpu.primitives import warp
from std.memory import stack_allocation, AddressSpace
from std.math import exp, max, sqrt
from max.gpu import barrier
from max.gpu.host import DeviceContext, DeviceBuffer
from core.gemma4_kernels import Floats
from core.llama3_kernels import Halves


from core.fused_causal_attention import admit_attention


def admit_small_attention[batch: Int](elements: Int,kv_elements: Int,src: Int,dst: Int,
    stride: Int,offset: Int,capacity: Int,prefix: Int,tokens: Int,
    query_heads: Int = 24,kv_heads: Int = 8,head_dim: Int = 128) raises:
    """Original complete allocation admission, then bounded visible-score span."""
    admit_attention[batch](elements,kv_elements,src,dst,stride,offset,capacity,prefix,tokens,query_heads,kv_heads,head_dim)
    if tokens > 1536-prefix:
        raise Error("Small attention visible causal span exceeds1536 scores")


def small_attention_kernel(a: Floats,kv: Halves,src_arg: Int64,dst_arg: Int64,
    stride_arg: Int64,offset_arg: Int64,capacity_arg: Int64,prefix_arg: Int64):
    var scores = stack_allocation[1536,Float32,address_space=AddressSpace.SHARED]()
    var tid = Int(thread_idx.x)
    var lane = tid%32
    var own_warp = tid//32
    var head = Int(block_idx.x)
    var token = Int(block_idx.y)
    var count = Int(prefix_arg)+token+1
    var kv_head = head*8//24
    var query = Int(src_arg)+token*Int(stride_arg)+head*128
    var key = Int(offset_arg)+kv_head*128
    for t in range(own_warp,count,4):
        var total: Float32 = 0
        for j in range(lane,128,32):
            total += a.unsafe_load(query+j)*kv.unsafe_load(key+t*1024+j).cast[DType.float32]()
        total = warp.sum(total)
        if lane == 0: scores.unsafe_store(t,total/sqrt(Float32(128)))
    barrier()
    if own_warp == 0:
        var maximum: Float32 = -3.4028235e38
        for t in range(lane,count,32):maximum = max(maximum,scores.unsafe_load(t))
        maximum = warp.max(maximum)
        var total: Float32 = 0
        for t in range(lane,count,32):total += exp(scores.unsafe_load(t)-maximum)
        total = warp.sum(total)
        for t in range(lane,count,32):scores.unsafe_store(t,exp(scores.unsafe_load(t)-maximum)/total)
    barrier()
    var value = Int(offset_arg)+Int(capacity_arg)*1024+kv_head*128+tid
    var total: Float32 = 0
    for t in range(0,count//4*4,4):
        var v0 = scores.unsafe_load(t)*kv.unsafe_load(value+t*1024).cast[DType.float32]()
        var v1 = scores.unsafe_load(t+1)*kv.unsafe_load(value+(t+1)*1024).cast[DType.float32]()
        var v2 = scores.unsafe_load(t+2)*kv.unsafe_load(value+(t+2)*1024).cast[DType.float32]()
        var v3 = scores.unsafe_load(t+3)*kv.unsafe_load(value+(t+3)*1024).cast[DType.float32]()
        total += v0
        total += v1
        total += v2
        total += v3
    for t in range(count//4*4,count):total += scores.unsafe_load(t)*kv.unsafe_load(value+t*1024).cast[DType.float32]()
    a.unsafe_store(Int(dst_arg)+token*Int(stride_arg)+head*128+tid,total)

def attend_small[batch: Int](ctx: DeviceContext,a: DeviceBuffer[DType.float32],
    kv: DeviceBuffer[DType.float16],src: Int,dst: Int,stride: Int,offset: Int,
    capacity: Int,prefix: Int,tokens: Int) raises:
    admit_small_attention[batch](len(a),len(kv),src,dst,stride,offset,capacity,prefix,tokens)
    if ctx.api() != "cuda" or not ctx.is_compatible():
        raise Error("Fused attention requires a compatible CUDA context")
    ctx.enqueue_function[small_attention_kernel](Floats(unsafe_from_address=Int(a.unsafe_ptr())),
        Halves(unsafe_from_address=Int(kv.unsafe_ptr())),Int64(src),Int64(dst),Int64(stride),
        Int64(offset),Int64(capacity),Int64(prefix),grid_dim=(24,tokens),block_dim=128)
