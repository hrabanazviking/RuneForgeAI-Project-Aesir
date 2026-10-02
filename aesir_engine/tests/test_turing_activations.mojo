"""Complete ordinary native F32 operand precision collection; not a pass marker."""
from std.sys import argv
from std.math import abs, sqrt, isfinite
from core.llama3_cuda import Llama3CUDASession
from core.packed_turing_matrix import project_turing_staged
from tests.test_packed_matrix import reference, span_guards


def capture(mut s: Llama3CUDASession, state: Int) raises -> List[Float32]:
    s.reset()
    var prompt = String("Explain how a river changes the landscape over time. Include erosion, transport, deposition and one simple example.")
    if state == 1:
        prompt = "Describe how to organize a small open-source software project. Include clear interfaces, bounded resources, validation, recovery and documentation."
    var tokens = List[Int]()
    if s.profile.add_bos:
        tokens.append(s.tokenizer.vocabulary.bos_token_id)
    s.tokenizer.append_message(tokens,"user",prompt)
    s.tokenizer.append_header(tokens,"assistant")
    var count = len(tokens)//4*4
    if count < 4 or count > 512:
        raise Error("Activation fixture token count exceeds admitted bounds")
    for start in range(0,count,4):
        s.prefill_four(tokens,start)
    if not s.healthy or s.position != count or s.sampler.position != count:
        raise Error("Activation source replay did not commit exact positions")
    var ids = String("STATE,"+String(state)+","+String(count))
    for i in range(count):
        ids += ","+String(tokens[i])
    print(ids)
    var host = s.context.enqueue_create_host_buffer[DType.float32](len(s.activations))
    s.context.enqueue_copy(host,s.activations)
    s.context.synchronize()
    var sources = List[Float32]()
    for source in range(3):
        var width = s.profile.feed_forward_size if source == 2 else s.profile.hidden_size
        var offset = s.norm_offset if source == 0 else (s.attention_offset if source == 1 else s.up_offset)
        print("SOURCE,"+String(state)+","+String(source)+","+String(width)+",4")
        for token in range(4):
            for col in range(width):
                var value = host[s.buffers.token_base(token)+offset+col]
                if not isfinite(value):
                    raise Error("Nonfinite native activation source")
                sources.append(value)
                print("ACT,"+String(state)+","+String(source)+","+String(token)+","+String(col)+","+String(Float64(value)))
    return sources^


def project_case[kind: Int,batch: Int,precision: Int = 0](mut s: Llama3CUDASession, sources: List[Float32],
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
    project_turing_staged[kind,batch,64,32,precision](s.context,s.weights,a,t.offset,columns,t.rows,0,dst,stride,batch)
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
            var expected = Float64(h[token*stride+reference_offset+row])
            if not isfinite(actual) or not isfinite(expected):
                raise Error("Nonfinite activation projection output")
            var error = abs(actual-expected)/(1.0+abs(expected))
            if error > maximum: maximum = error
            total += error*error
            print("VALUE,"+String(index)+","+String(token)+","+String(row)+","+String(expected)+","+String(actual))
    print("GUARD,"+String(index)+","+String(guards)+",0")
    print("METRIC,"+String(index)+","+String(maximum)+","+String(sqrt(total/Float64(batch*t.rows))))
    return batch*t.rows


def cases[batch: Int,precision: Int = 0](mut s: Llama3CUDASession,sources: List[Float32],state: Int,
    mut index: Int,mut values: Int) raises:
    var names: List[String] = ["blk.27.attn_q.weight","blk.27.attn_k.weight","blk.27.attn_v.weight",
        "blk.27.attn_output.weight","blk.27.ffn_gate.weight","blk.27.ffn_up.weight","blk.27.ffn_down.weight"]
    for i in range(7):
        var t = s.model.tensors[names[i]]
        var source = 1 if i == 3 else (2 if i == 6 else 0)
        if t.kind == 12:
            values += project_case[12,batch,precision](s,sources,state,index,names[i],source)
        elif t.kind == 14:
            values += project_case[14,batch,precision](s,sources,state,index,names[i],source)
        else:
            raise Error("Unexpected activation fixture quantization")
        index += 1


def run[precision: Int](path: String) raises:
    var s = Llama3CUDASession(path,512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.feed_forward_size != 8192 or s.profile.layer_count != 28:
        raise Error("Activation gate requires strict3B fixture")
    span_guards()
    comptime if precision == 0: print("META,1,turing_native_f32,64,32,12")
    else: print("META,1,turing_native_f32_split,64,32,"+String(precision)+",12")
    var index = 0
    var values = 0
    for state in range(2):
        var sources = capture(s,state)
        cases[4,precision](s,sources,state,index,values)
        cases[32,precision](s,sources,state,index,values)
    print("COMPLETE,activation,"+String(index)+","+String(values)+",114688,12")


def main() raises:
    var args = argv()
    if len(args) != 2 and len(args) != 3:
        raise Error("usage: test_turing_activations MODEL.gguf [ACTIVATION_PRECISION]")
    var precision = Int(args[2]) if len(args) == 3 else 0
    if precision == 0: run[0](args[1])
    elif precision == 1: run[1](args[1])
    elif precision == 2: run[2](args[1])
    else: raise Error("Activation precision must be0/1/2")
