"""Narrow down-only128 actual-F32 source and exact original staging collection."""
from std.sys import argv
from std.math import abs, sqrt, isfinite
from core.llama3_cuda import Llama3CUDASession
from core.packed_turing_matrix import project_turing_staged, project_turing_large_rows
from tests.test_turing_activations import capture
from tests.test_packed_matrix import reference, span_guards


def project_case[kind: Int,batch: Int,large_down: Bool = False](mut s: Llama3CUDASession, sources: List[Float32],
    state: Int,index: Int,name: String,source: Int) raises -> Int:
    var t = s.model.tensors[name]
    var width = s.profile.hidden_size
    var source_base = 0 if source == 0 else (4*width if source == 1 else 8*width)
    var columns = s.profile.feed_forward_size if source == 2 else width
    if t.kind != kind or t.columns != columns or len(sources) != 4*(2*width+s.profile.feed_forward_size):
        raise Error("Activation tensor/source identity mismatch")
    var dst = columns+13
    var span = (t.rows+31)//32*32
    var reference_offset = dst+span+13
    var stride = reference_offset+span+17
    var a = s.context.enqueue_create_buffer[DType.float32](batch*stride)
    var h = s.context.enqueue_create_host_buffer[DType.float32](batch*stride)
    for i in range(batch*stride): h[i] = -9876
    for token in range(batch):
        for col in range(columns):
            h[token*stride+col] = sources[source_base+(token%4)*columns+col]
    s.context.enqueue_copy(a,h)
    reference[kind,batch](s.context,s.weights,a,t.offset,columns,t.rows,reference_offset,stride,batch)
    var native_snapshot = List[Float32]()
    s.context.enqueue_copy(h,a)
    s.context.synchronize()
    for token in range(batch):
        for row in range(t.rows): native_snapshot.append(h[token*stride+reference_offset+row])
    project_turing_staged[kind,batch,64,32](s.context,s.weights,a,t.offset,columns,t.rows,0,reference_offset,stride,batch)
    comptime if large_down:
        comptime assert batch == 32
        if name != "blk.27.ffn_down.weight": raise Error("Larger rows are down-only")
        project_turing_large_rows[kind,batch,128](s.context,s.weights,a,t.offset,columns,t.rows,0,dst,stride,batch)
    else:
        project_turing_staged[kind,batch,64,32](s.context,s.weights,a,t.offset,columns,t.rows,0,dst,stride,batch)
    s.context.enqueue_copy(h,a)
    s.context.synchronize()
    print("CASE,"+String(index)+","+String(state)+","+name+","+String(kind)+","+String(columns)+","+String(t.rows)+","+String(batch)+","+String(t.offset)+","+String(source))
    var total: Float64 = 0
    var maximum: Float64 = 0
    var guards = 0
    for token in range(batch):
        for i in range(stride):
            if not (dst <= i < dst+t.rows) and not (reference_offset <= i < reference_offset+t.rows):
                var expected: Float32 = -9876
                if i < columns:
                    expected = sources[source_base+(token%4)*columns+i]
                if h[token*stride+i] != expected:
                    raise Error("Activation candidate mutated input/guard span")
                guards += 1
        for row in range(t.rows):
            var actual = Float64(h[token*stride+dst+row])
            var expected = Float64(native_snapshot[token*t.rows+row])
            var original = Float64(h[token*stride+reference_offset+row])
            if not isfinite(actual) or not isfinite(expected) or not isfinite(original):
                raise Error("Nonfinite activation projection output")
            var error = abs(actual-expected)/(1.0+abs(expected))
            if error > maximum: maximum = error
            total += error*error
            print("VALUE,"+String(index)+","+String(token)+","+String(row)+","+String(expected)+","+String(actual)+","+String(original))
    print("GUARD,"+String(index)+","+String(guards)+",0")
    print("METRIC,"+String(index)+","+String(maximum)+","+String(sqrt(total/Float64(batch*t.rows))))
    return batch*t.rows


def cases[batch: Int](mut s: Llama3CUDASession,sources: List[Float32],state: Int,
    mut index: Int,mut values: Int) raises:
    var names: List[String] = ["blk.27.attn_q.weight","blk.27.attn_k.weight","blk.27.attn_v.weight",
        "blk.27.attn_output.weight","blk.27.ffn_gate.weight","blk.27.ffn_up.weight","blk.27.ffn_down.weight"]
    for i in range(7):
        var t = s.model.tensors[names[i]]
        var source = 1 if i == 3 else (2 if i == 6 else 0)
        if t.kind == 12:
            comptime if batch == 32:
                if i == 6: values += project_case[12,batch,True](s,sources,state,index,names[i],source)
                else: values += project_case[12,batch](s,sources,state,index,names[i],source)
            else: values += project_case[12,batch](s,sources,state,index,names[i],source)
        elif t.kind == 14:
            comptime if batch == 32:
                if i == 6: values += project_case[14,batch,True](s,sources,state,index,names[i],source)
                else: values += project_case[14,batch](s,sources,state,index,names[i],source)
            else: values += project_case[14,batch](s,sources,state,index,names[i],source)
        else:
            raise Error("Unexpected activation fixture quantization")
        index += 1


def main() raises:
    var args = argv()
    if len(args) != 2: raise Error("usage: test_turing_down_activations MODEL.gguf")
    var s = Llama3CUDASession(args[1],512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.feed_forward_size != 8192 or s.profile.layer_count != 28:
        raise Error("Down activation gate requires strict3B")
    span_guards()
    print("META,1,turing_native_f32_down_rows,128,32,12")
    var index = 0
    var values = 0
    for state in range(2):
        var sources = capture(s,state)
        cases[4](s,sources,state,index,values)
        cases[32](s,sources,state,index,values)
    print("COMPLETE,activation,"+String(index)+","+String(values)+",114688,12")
