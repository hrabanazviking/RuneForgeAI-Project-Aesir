"""Opt-in strict3B shared-score GQA; original arithmetic, no global scratch."""
from std.gpu import block_idx, thread_idx
from std.gpu.primitives import warp
from std.memory import stack_allocation, AddressSpace
from std.math import exp, max, sqrt
from max.gpu import barrier
from max.gpu.host import DeviceContext, DeviceBuffer
from core.gemma4_kernels import Floats
from core.llama3_kernels import Halves


def admit_attention[batch: Int](elements: Int,kv_elements: Int,src: Int,dst: Int,
    stride: Int,offset: Int,capacity: Int,prefix: Int,tokens: Int,
    query_heads: Int = 24,kv_heads: Int = 8,head_dim: Int = 128) raises:
    comptime assert batch == 1 or batch == 4 or batch == 32
    if query_heads != 24 or kv_heads != 8 or head_dim != 128:
        raise Error("Fused attention requires strict3B GQA24/8/128")
    if capacity < 1 or capacity > 4096 or prefix < 0 or prefix >= capacity:
        raise Error("Fused attention history outside bounded capacity")
    if tokens < 1 or tokens > batch or tokens > capacity-prefix:
        raise Error("Fused attention causal token span exceeds capacity")
    if stride < 1 or src < 0 or dst < 0 or src > stride or dst > stride:
        raise Error("Fused attention has invalid activation metadata")
    if 3072 > stride-src or 3072 > stride-dst or stride > elements//tokens:
        raise Error("Fused attention activation span exceeds borrowed buffer")
    # Subtracted spans and stride <= elements//tokens bound every offset/product
    # by the actual allocation, including the accepted fixture's 33824 stride.
    if src < dst+3072 and dst < src+3072:
        raise Error("Fused attention query/output spans overlap")
    if offset < 0 or offset > kv_elements or 2*capacity*1024 > kv_elements-offset:
        raise Error("Fused attention full F16 K/V span exceeds borrowed buffer")


def fused_attention_kernel(a: Floats,kv: Halves,src_arg: Int64,dst_arg: Int64,
    stride_arg: Int64,offset_arg: Int64,capacity_arg: Int64,prefix_arg: Int64):
    var scores = stack_allocation[4096,Float32,address_space=AddressSpace.SHARED]()
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


def attend_fused[batch: Int](ctx: DeviceContext,a: DeviceBuffer[DType.float32],
    kv: DeviceBuffer[DType.float16],src: Int,dst: Int,stride: Int,offset: Int,
    capacity: Int,prefix: Int,tokens: Int) raises:
    admit_attention[batch](len(a),len(kv),src,dst,stride,offset,capacity,prefix,tokens)
    if ctx.api() != "cuda" or not ctx.is_compatible():
        raise Error("Fused attention requires a compatible CUDA context")
    ctx.enqueue_function[fused_attention_kernel](Floats(unsafe_from_address=Int(a.unsafe_ptr())),
        Halves(unsafe_from_address=Int(kv.unsafe_ptr())),Int64(src),Int64(dst),Int64(stride),
        Int64(offset),Int64(capacity),Int64(prefix),grid_dim=(24,tokens),block_dim=128)
