"""Complete teacher-forced decode and own seeded replay; no speed score."""
from std.sys import argv
from max.gpu.host import HostBuffer
from core.sampling_config import NativeSamplingConfig
from tests.turing_prefill_fixture import TuringPrefillFixture
from tests.test_turing_model_prefill import inputs, run, logits


def policy(index: Int) raises -> NativeSamplingConfig:
    if index == 0: return NativeSamplingConfig()
    if index != 1: raise Error("Unknown decode quality policy")
    return NativeSamplingConfig(temperature=Float32(.7),top_k=40,top_p=Float32(.9),
        min_p=Float32(.05),repetition_penalty=Float32(1.1),repeat_last_n=64,seed=UInt64(1234))


def prepare(mut f: TuringPrefillFixture,tokens: List[Int],configuration: NativeSamplingConfig) raises:
    f.native.reset()
    f.reset()
    f.native.configure_sampling(configuration)
    f.sampler.configure(configuration)
    _ = run(f,tokens,0)
    _ = run(f,tokens,1)


def advance(mut f: TuringPrefillFixture,token: Int) raises:
    _ = f.native.forward(token,True)
    var one: List[Int] = [token]
    f.step(one,0,1,True)


def state(f: TuringPrefillFixture,index: Int,step: Int,label: String,native_diff: Int = 0,matrix_diff: Int = 0):
    print(label+","+String(index)+","+String(step)+","+String(f.native.host_output[0])+","+String(f.host_output[0])+","+
        String(f.native.position)+","+String(f.position)+","+String(f.native.sampler.position)+","+String(f.sampler.position)+","+
        String(f.native.sampler.draws)+","+String(f.sampler.draws)+","+String(native_diff)+","+String(matrix_diff))


def save(mut snapshot: HostBuffer[DType.float32],values: List[Float32],step: Int):
    for i in range(128256): snapshot[step*128256+i] = values[i]


def mismatch(snapshot: HostBuffer[DType.float32],values: List[Float32],step: Int) -> Int:
    var before = snapshot.unsafe_ptr().unsafe_bitcast[UInt32]()
    var after = values.unsafe_ptr().unsafe_bitcast[UInt32]()
    var differences = 0
    for i in range(128256):
        if before.unsafe_load(step*128256+i) != after.unsafe_load(i): differences += 1
    return differences


def causal(mut f: TuringPrefillFixture,expected: List[Int],index: Int,step: Int) raises:
    var actual = f.native.conversation_tokens()
    if len(actual) != len(expected) or len(f.committed) != len(expected):
        raise Error("Decode committed causal history length changed")
    for i in range(len(expected)):
        if actual[i] != expected[i] or f.committed[i] != expected[i]:
            raise Error("Decode committed causal token identity changed")
    print("CAUSAL,"+String(index)+","+String(step)+","+String(len(expected))+",0")


def collect(mut f: TuringPrefillFixture,index: Int,tokens: List[Int],choice: Int) raises -> Int:
    var configuration = policy(choice)
    var cap = 32 if choice == 0 else 16
    # Exactly two cap-sized pinned host snapshots, at most31.313MiB. No device workspace.
    var baseline = f.native.context.enqueue_create_host_buffer[DType.float32](cap*128256)
    var matrix = f.native.context.enqueue_create_host_buffer[DType.float32](cap*128256)
    print("CASE,"+String(index)+","+String(len(tokens))+","+String(choice)+","+String(cap))
    for i in range(len(tokens)): print("INPUT,"+String(index)+","+String(i)+","+String(tokens[i]))
    prepare(f,tokens,configuration)
    if f.down128: print("DOWN_ROWS128,"+String(index)+","+String(f.down128_calls))
    var targets = List[Int]()
    var expected = tokens.copy()
    var finish = String("length")
    for step in range(cap):
        var native = logits(f,0)
        var candidate = logits(f,1)
        save(baseline,native,step)
        save(matrix,candidate,step)
        state(f,index,step,"STEP")
        causal(f,expected,index,step)
        for i in range(128256):
            print("LOGIT,"+String(index)+","+String(step)+","+String(i)+","+String(Float64(native[i]))+","+String(Float64(candidate[i])))
        var target = Int(f.native.host_output[0])
        targets.append(target)
        if target == f.native.profile.eos_token_id or target == f.native.profile.end_of_turn_token_id:
            finish = "eos"
            break
        if step+1 < cap:
            advance(f,target)
            expected.append(target)
    print("END,"+String(index)+","+String(len(targets))+","+finish)
    prepare(f,tokens,configuration)
    expected = tokens.copy()
    for step in range(len(targets)):
        var native = logits(f,0)
        var candidate = logits(f,1)
        var native_diff = mismatch(baseline,native,step)
        var matrix_diff = mismatch(matrix,candidate,step)
        state(f,index,step,"REPLAY",native_diff,matrix_diff)
        causal(f,expected,index,step)
        # Replay the recorded first-round causal stream even on a mismatch.
        if step+1 < len(targets):
            advance(f,targets[step])
            expected.append(targets[step])
    if f.down128: print("REPLAY_DOWN_ROWS128,"+String(index)+","+String(f.down128_calls))
    print("REPLAY_END,"+String(index)+","+String(len(targets))+","+finish)
    f.guards()
    print("GUARD,"+String(index)+",1088,0")
    return len(targets)


def main() raises:
    var args = argv()
    if len(args) != 2 and len(args) != 3: raise Error("usage: test_turing_decode_quality MODEL.gguf [STRATEGY0/1/2/3]")
    var flag = Int(args[2]) if len(args) == 3 else 0
    if flag < 0 or flag > 3: raise Error("Decode execution strategy must be0/1/2/3")
    var f = TuringPrefillFixture(args[1],0,Bool(flag>0),Bool(flag>=2),Bool(flag==3))
    if len(args) == 3:
        if flag == 3: print("ATTENTION,rope_cache_elementwise_down128,1,32")
        elif flag == 2: print("ATTENTION,rope_cache_elementwise_grid,1,32")
        else: print("ATTENTION,rope_cache_grid,"+String(flag)+",32")
    print("META,1,turing_decode,1536,128256,4,2")
    for choice in range(2):
        var p = policy(choice)
        print("POLICY,"+String(choice)+","+String(Float64(p.temperature))+","+String(p.top_k)+","+
            String(Float64(p.top_p))+","+String(Float64(p.min_p))+","+String(Float64(p.repetition_penalty))+","+
            String(p.repeat_last_n)+","+String(p.seed))
    var long_prompt = ("A knowledge graph links documents, entities and the passages that support each connection. Sources remain available for citation. New material is appended through a queue, checked for duplicate content, and embedded in the same vector space. Failed imports can be inspected and retried safely. "*20)+"Summarize the reliability principles in a detailed paragraph."
    var prompts: List[String] = ["Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.",long_prompt]
    var total = 0
    for source in range(2):
        var tokens = inputs(f,prompts[source])
        if len(tokens) != (37 if source == 0 else 1070): raise Error("Public decode prompt identity changed")
        for choice in range(2): total += collect(f,source*2+choice,tokens,choice)
    print("COMPLETE,turing_decode,4,"+String(total)+","+String(total*128256)+",4352,2")
