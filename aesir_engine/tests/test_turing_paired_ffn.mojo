"""Owned paired gate/up primitive values, guards and rotated actual timings."""
from std.sys import argv
from std.memory import Pointer
from std.math import abs, sqrt, isfinite
from max.gpu.host import DeviceContext, DeviceBuffer
from core.llama3_cuda import Llama3CUDASession
from core.packed_turing_pair import admit_pair, project_turing_pair
from core.packed_turing_matrix import project_turing_staged
from core.packed_projection import block_matvec_kernel, ProjectionFloats
from core.packed_quantization import Bytes
from tests.test_packed_matrix import seconds, reference


def spans() raises -> Int:
    admit_pair[12,4](1024,4096,32,512,256,3,17,300,400,1024,4)
    var rejected = 0
    for defect in range(12):
        var weights = 1024
        var elements = 4096
        var left = 32
        var right = 512
        var columns = 256
        var rows = 3
        var src = 17
        var dst_left = 300
        var dst_right = 400
        var stride = 1024
        var tokens = 4
        if defect == 0: weights = 943
        elif defect == 1: elements = 4095
        elif defect == 2: left = -1
        elif defect == 3: right = 100
        elif defect == 4: columns = 255
        elif defect == 5: rows = 0
        elif defect == 6: src = -1
        elif defect == 7: dst_left = 17
        elif defect == 8: dst_right = dst_left
        elif defect == 9: stride = 256
        elif defect == 10: tokens = 0
        else: tokens = 5
        var refused = False
        try: admit_pair[12,4](weights,elements,left,right,columns,rows,src,dst_left,dst_right,stride,tokens)
        except: refused = True
        if not refused: raise Error("Paired projection accepted a hostile span")
        rejected += 1
    return rejected


def exercise[kind: Int,batch: Int](ctx: DeviceContext,w: DeviceBuffer[DType.uint8],
    left: Int,right: Int,columns: Int,rows: Int,tokens: Int,index: Int,real: Bool) raises -> Int:
    var span = ((rows+31)//32)*32
    var src = 17
    var offsets = InlineArray[Int,6](fill=0)
    offsets[0] = src+columns+13
    for i in range(1,6): offsets[i] = offsets[i-1]+span+13
    var stride = offsets[5]+span+17
    var a = ctx.enqueue_create_buffer[DType.float32](batch*stride)
    var h = ctx.enqueue_create_host_buffer[DType.float32](batch*stride)
    for i in range(batch*stride): h[i] = -9876
    for token in range(tokens):
        for col in range(columns): h[token*stride+src+col] = Float32((col*7+token*13)%29-14)/16.0
    ctx.enqueue_copy(a,h)
    var wp = Bytes(unsafe_from_address=Int(w.unsafe_ptr()))
    var ap = ProjectionFloats(unsafe_from_address=Int(a.unsafe_ptr())).unsafe_offset(src)
    for token in range(tokens):
        ctx.enqueue_function[block_matvec_kernel[kind]](wp,ap,Int64(left),Int64(columns),Int64(rows),Int64(token*stride),Int64(token*stride+offsets[4]-src),grid_dim=(rows+3)//4,block_dim=128)
        ctx.enqueue_function[block_matvec_kernel[kind]](wp,ap,Int64(right),Int64(columns),Int64(rows),Int64(token*stride),Int64(token*stride+offsets[5]-src),grid_dim=(rows+3)//4,block_dim=128)
    project_turing_staged[kind,batch,64](ctx,w,a,left,columns,rows,src,offsets[2],stride,tokens)
    project_turing_staged[kind,batch,64](ctx,w,a,right,columns,rows,src,offsets[3],stride,tokens)
    project_turing_pair[kind,batch](ctx,w,a,left,right,columns,rows,src,offsets[0],offsets[1],stride,tokens)
    ctx.enqueue_copy(h,a)
    ctx.synchronize()
    var guards = 0
    for token in range(batch):
        for col in range(stride):
            var owned = token < tokens and col >= src and col < src+columns
            for offset in offsets: owned = owned or (token < tokens and col >= offset and col < offset+rows)
            if not owned:
                if h[token*stride+col] != -9876: raise Error("Paired projection wrote an unowned cell")
                guards += 1
            elif col >= src and col < src+columns:
                if h[token*stride+col] != Float32(((col-src)*7+token*13)%29-14)/16.0: raise Error("Paired projection changed input")
    if real: print("CASE,"+String(index)+","+String(batch)+","+String(rows)+","+String(columns)+","+String(kind)+","+String(left)+","+String(right))
    var total: Float64 = 0
    for side in range(2):
        for token in range(tokens):
            for row in range(rows):
                var actual = h[token*stride+offsets[side]+row]
                var original = h[token*stride+offsets[side+2]+row]
                var native = h[token*stride+offsets[side+4]+row]
                if not isfinite(actual) or not isfinite(original) or not isfinite(native): raise Error("Nonfinite paired result")
                if Pointer(to=actual).unsafe_bitcast[UInt32]()[] != Pointer(to=original).unsafe_bitcast[UInt32]()[]: raise Error("Paired projection changed original F32 bits")
                var error = Float64(abs(actual-native))/(1+Float64(abs(native)))
                if error > .002: raise Error("Paired projection exceeds fixed scaled error")
                total += error*error
                if real: print("VALUE,"+String(index)+","+String(side)+","+String(token)+","+String(row)+","+String(Float64(native))+","+String(Float64(actual))+","+String(Float64(original)))
    if sqrt(total/Float64(2*rows*tokens)) > .0002: raise Error("Paired projection exceeds fixed normalized RMS")
    if real:
        print("GUARD,"+String(index)+","+String(guards)+",0")
        for token in range(batch):
            for col in range(columns): h[token*stride+col] = Float32((col*7+token*13)%29-14)/16.0
        ctx.enqueue_copy(a,h)
        for _ in range(2):
            reference[kind,batch](ctx,w,a,left,columns,rows,offsets[4],stride,batch)
            reference[kind,batch](ctx,w,a,right,columns,rows,offsets[5],stride,batch)
            project_turing_staged[kind,batch,64](ctx,w,a,left,columns,rows,0,offsets[2],stride,batch)
            project_turing_staged[kind,batch,64](ctx,w,a,right,columns,rows,0,offsets[3],stride,batch)
            project_turing_pair[kind,batch](ctx,w,a,left,right,columns,rows,0,offsets[0],offsets[1],stride,batch)
        ctx.synchronize()
        for sample in range(10):
            for step in range(3):
                var mode = (sample+step)%3
                var start = seconds()
                for _ in range(3):
                    if mode == 0:
                        reference[kind,batch](ctx,w,a,left,columns,rows,offsets[4],stride,batch)
                        reference[kind,batch](ctx,w,a,right,columns,rows,offsets[5],stride,batch)
                    elif mode == 1:
                        project_turing_pair[kind,batch](ctx,w,a,left,right,columns,rows,0,offsets[0],offsets[1],stride,batch)
                    else:
                        project_turing_staged[kind,batch,64](ctx,w,a,left,columns,rows,0,offsets[2],stride,batch)
                        project_turing_staged[kind,batch,64](ctx,w,a,right,columns,rows,0,offsets[3],stride,batch)
                ctx.synchronize()
                var elapsed = seconds()-start
                if not isfinite(elapsed) or elapsed <= 0: raise Error("Invalid paired elapsed")
                print("TIME,"+String(index)+","+String(mode)+","+String(sample)+",3,"+String(elapsed))
    return 2*rows*tokens


def synthetic[kind: Int,batch: Int](ctx: DeviceContext) raises -> Int:
    comptime bytes = 144 if kind == 12 else (176 if kind == 13 else 210)
    var cases = 0
    for columns in [256,512,3072,8192]:
        for rows in [1,7,33]:
            var packed = rows*(columns//256)*bytes
            var left = 32
            var right = left+packed+32
            var size = right+packed+32
            var w = ctx.enqueue_create_buffer[DType.uint8](size)
            var h = ctx.enqueue_create_host_buffer[DType.uint8](size)
            for i in range(size): h[i] = UInt8((i*37+i//7)%256)
            for base in [left,right]:
                for block in range(rows*(columns//256)):
                    var p = base+block*bytes
                    var d = p+(208 if kind == 14 else 0)
                    h[d] = 0
                    h[d+1] = UInt8(44 if (block+Int(base==right))%2 == 0 else 172)
                    comptime if kind != 14:
                        h[p+2] = 0
                        h[p+3] = 40
            ctx.enqueue_copy(w,h)
            _ = exercise[kind,batch](ctx,w,left,right,columns,rows,batch-1,0,False)
            cases += 1
    return cases


def main() raises:
    var args = argv()
    if len(args) != 2: raise Error("usage: test_turing_paired_ffn MODEL.gguf")
    print("MODE,turing_pair_gate_up,64,32")
    print("SPANS,"+String(spans())+",0")
    var s = Llama3CUDASession(args[1],512,prefix_cache=False,prefill_batch=4)
    var left = s.model.tensors["blk.0.ffn_gate.weight"]
    var right = s.model.tensors["blk.0.ffn_up.weight"]
    if s.profile.hidden_size != 3072 or s.profile.layer_count != 28 or left.kind != 12 or right.kind != 12 or left.columns != 3072 or right.columns != 3072 or left.rows != 8192 or right.rows != 8192: raise Error("Paired FFN probe requires actual strict3B gate/up12 geometry")
    var count = 0
    comptime for batch in [4,8,16,32]:
        count += synthetic[12,batch](s.context)
        count += synthetic[13,batch](s.context)
        count += synthetic[14,batch](s.context)
    print("SYNTHETIC,"+String(count)+",0")
    var values = 0
    var index = 0
    comptime for batch in [4,8,16,32]:
        values += exercise[12,batch](s.context,s.weights,left.offset,right.offset,3072,8192,batch,index,True)
        index += 1
    print("COMPLETE,pair,"+String(index)+","+String(values)+",120")
