"""Complete opt-in causal attention values, input ownership and rotated timings."""
from std.sys import argv
from std.memory import Pointer
from std.math import isfinite
from max.gpu.host import DeviceContext,DeviceBuffer
from core.gemma4_kernels import Floats
from core.llama3_kernels import Halves,llama_scores,llama_softmax,llama_attention_tiled
from core.fused_causal_attention import admit_attention,attend_fused
from tests.test_packed_matrix import seconds


def query_value(token: Int,head: Int,col: Int,mode: Int) -> Float32:
    if mode == 1:return 0
    return Float32((col*7+token*13+head*3)%29-14)/16.0*Float32(16 if mode == 2 else 1)


def kv_value(t: Int,head: Int,col: Int,mode: Int,value: Bool) -> Float16:
    if mode == 1:return Float16(0)
    if value:return (Float32((t*7+head*13+col*5)%37-18)/8.0).cast[DType.float16]()
    return (Float32((t*5+head*11+col*3)%31-15)/32.0*Float32(8 if mode == 2 else 1)).cast[DType.float16]()


def spans() raises -> Int:
    admit_attention[4](4*9276,11+2*37*1024,17,3102,9276,11,37,33,4)
    admit_attention[4](4*33824,11+2*37*1024,17,3102,33824,11,37,33,4)
    var rejected = 0
    for defect in range(16):
        var elements = 4*9276
        var kv_elements = 11+2*37*1024
        var src = 17
        var dst = 3102
        var stride = 9276
        var offset = 11
        var capacity = 37
        var prefix = 33
        var tokens = 4
        var heads = 24
        var kv_heads = 8
        var dim = 128
        if defect == 0:elements -= 1
        elif defect == 1:kv_elements -= 1
        elif defect == 2:src = -1
        elif defect == 3:dst = -1
        elif defect == 4:dst = src
        elif defect == 5:stride = 0
        elif defect == 6:offset = -1
        elif defect == 7:capacity = 0
        elif defect == 8:capacity = 4097
        elif defect == 9:prefix = -1
        elif defect == 10:prefix = 34
        elif defect == 11:tokens = 0
        elif defect == 12:tokens = 5
        elif defect == 13:heads = 23
        elif defect == 14:kv_heads = 7
        else:dim = 127
        var refused = False
        try:admit_attention[4](elements,kv_elements,src,dst,stride,offset,capacity,prefix,tokens,heads,kv_heads,dim)
        except:refused = True
        if not refused:raise Error("Fused attention admitted hostile metadata")
        rejected += 1
    return rejected


def original(ctx: DeviceContext,a: DeviceBuffer[DType.float32],kv: DeviceBuffer[DType.float16],
    src: Int,dst: Int,stride: Int,score: Int,offset: Int,capacity: Int,prefix: Int,tokens: Int) raises:
    var ap = Floats(unsafe_from_address=Int(a.unsafe_ptr()))
    var kp = Halves(unsafe_from_address=Int(kv.unsafe_ptr()))
    for token in range(tokens):
        var count = prefix+token+1
        ctx.enqueue_function[llama_scores](ap,kp,Int64(src+token*stride),Int64(score),Int64(offset),Int64(count),Int64(128),Int64(24),Int64(8),grid_dim=(24*count+3)//4,block_dim=128)
        ctx.enqueue_function[llama_softmax](ap,Int64(score),Int64(count),Int64(24),grid_dim=6,block_dim=128)
        ctx.enqueue_function[llama_attention_tiled](ap,kp,Int64(score),Int64(dst+token*stride),Int64(offset),Int64(capacity),Int64(count),Int64(128),Int64(24),Int64(8),grid_dim=24,block_dim=128)


def exercise[batch: Int](ctx: DeviceContext,end: Int,index: Int) raises -> Int:
    var tokens = min(batch,end)
    var prefix = end-tokens
    var capacity = min(4096,end+13)
    var mode = index%3
    var src = 17
    var dst = 3102
    var native_dst = 6187
    var stride = 9276
    var score = batch*stride+17
    var elements = score+24*capacity+19
    var offset = 11
    var kv_elements = offset+2*capacity*1024+23
    var a = ctx.enqueue_create_buffer[DType.float32](elements)
    var h = ctx.enqueue_create_host_buffer[DType.float32](elements)
    var kv = ctx.enqueue_create_buffer[DType.float16](kv_elements)
    var hk = ctx.enqueue_create_host_buffer[DType.float16](kv_elements)
    for i in range(elements):h[i] = -9876
    for token in range(tokens):
        for head in range(24):
            for col in range(128):h[token*stride+src+head*128+col] = query_value(token,head,col,mode)
    for i in range(kv_elements):hk[i] = -999
    for value in range(2):
        for t in range(capacity):
            for head in range(8):
                for col in range(128):hk[offset+value*capacity*1024+t*1024+head*128+col] = kv_value(t,head,col,mode,value==1)
    ctx.enqueue_copy(a,h)
    ctx.enqueue_copy(kv,hk)
    original(ctx,a,kv,src,native_dst,stride,score,offset,capacity,prefix,tokens)
    attend_fused[batch](ctx,a,kv,src,dst,stride,offset,capacity,prefix,tokens)
    ctx.enqueue_copy(h,a)
    ctx.enqueue_copy(hk,kv)
    ctx.synchronize()
    var guards = 0
    for i in range(elements):
        var token = i//stride
        var col = i%stride
        var query = token < tokens and col >= src and col < src+3072
        var output = token < tokens and ((col >= dst and col < dst+3072) or (col >= native_dst and col < native_dst+3072))
        var workspace = i >= score and i < score+24*end
        if query:
            if h[i] != query_value(token,(col-src)//128,(col-src)%128,mode):raise Error("Attention changed query input")
        elif not output and not workspace:
            if h[i] != -9876:raise Error("Attention changed unowned activation")
            guards += 1
    for i in range(kv_elements):
        if i < offset or i >= offset+2*capacity*1024:
            if hk[i] != -999:raise Error("Attention changed K/V guard")
            guards += 1
        else:
            var p = i-offset
            var value = p//(capacity*1024)
            var within = p%(capacity*1024)
            if hk[i] != kv_value(within//1024,(within%1024)//128,within%128,mode,value==1):raise Error("Attention changed K/V input")
    print("CASE,"+String(index)+","+String(batch)+","+String(tokens)+","+String(capacity)+","+String(prefix)+","+String(mode))
    for token in range(tokens):
        for head in range(24):
            for col in range(128):
                var candidate = h[token*stride+dst+head*128+col]
                var native = h[token*stride+native_dst+head*128+col]
                if not isfinite(candidate) or not isfinite(native):raise Error("Nonfinite attention output")
                if Pointer(to=candidate).unsafe_bitcast[UInt32]()[] != Pointer(to=native).unsafe_bitcast[UInt32]()[]:raise Error("Fused attention changed original F32 bits")
                print("VALUE,"+String(index)+","+String(token)+","+String(head)+","+String(col)+","+String(Float64(native))+","+String(Float64(candidate)))
    print("INPUT,"+String(index)+","+String(tokens*3072)+","+String(2*capacity*1024)+",0")
    print("GUARD,"+String(index)+","+String(guards)+",0")
    for _ in range(2):
        original(ctx,a,kv,src,native_dst,stride,score,offset,capacity,prefix,tokens)
        attend_fused[batch](ctx,a,kv,src,dst,stride,offset,capacity,prefix,tokens)
    ctx.synchronize()
    for sample in range(10):
        for step in range(2):
            var owner = (sample+step)%2
            var start = seconds()
            for _ in range(3):
                if owner == 0:original(ctx,a,kv,src,native_dst,stride,score,offset,capacity,prefix,tokens)
                else:attend_fused[batch](ctx,a,kv,src,dst,stride,offset,capacity,prefix,tokens)
            ctx.synchronize()
            var elapsed = seconds()-start
            if not isfinite(elapsed) or elapsed <= 0:raise Error("Invalid attention timing")
            print("TIME,"+String(index)+","+String(owner)+","+String(sample)+",3,"+String(elapsed))
    return tokens*3072


def main() raises:
    if len(argv()) != 1:raise Error("usage: test_fused_causal_attention")
    print("MODE,fused_shared_attention,24,8,128,4096,1")
    print("SPANS,"+String(spans())+",0")
    var ctx = DeviceContext(0,api="cuda")
    if ctx.api() != "cuda" or not ctx.is_compatible():raise Error("Compatible CUDA required; no CPU fallback")
    print("CUDA,0,"+ctx.api()+",1,0")
    var index = 0
    var values = 0
    comptime for batch in [1,4,32]:
        for end in [1,31,32,33,37,255,256,257,1070,1535,1536,4095,4096]:
            values += exercise[batch](ctx,end,index)
            index += 1
    print("COMPLETE,attention,"+String(index)+","+String(values)+",780")
