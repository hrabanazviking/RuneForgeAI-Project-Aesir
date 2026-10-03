"""Owned inference-only NVTX capture; all vectors and cache exported unscored."""
from std.sys import argv
from std.ffi import OwnedDLHandle, external_call
from tests.turing_prefill_fixture import TuringPrefillFixture
from tests.test_turing_model_prefill import inputs, logits
from tests.guarded_cache_digest import guarded_cache_digest


def main() raises:
    var args = argv()
    if len(args) != 4 and len(args) != 5:
        raise Error("usage: test_turing_prefill_trace MODEL.gguf CASE[1|3] NEW.csv [STAGES:0|1]")
    var stages = Int(args[4]) if len(args) == 5 else 0
    if stages != 0 and stages != 1: raise Error("Projection trace flag must be0/1")
    var index = Int(args[2])
    if index != 1 and index != 3: raise Error("Trace supports accepted public case1/3 only")
    var lib = OwnedDLHandle("libnvToolsExt.so.1")
    var push = lib.get_function[Int32]("nvtxRangePushA")
    var pop = lib.get_function[Int32]("nvtxRangePop")
    # Own one new regular artifact; direct execution retains native process identity.
    var output = args[3].as_c_string_slice()
    var fd = external_call["open64",Int32](output.unsafe_ptr(),Int32(657601),Int32(384))
    if fd < 0: raise Error("Cannot reserve new trace CSV")
    if external_call["dup2",Int32](fd,Int32(1)) < 0:
        _ = external_call["close",Int32](fd)
        raise Error("Cannot direct owned trace output")
    if external_call["close",Int32](fd) != 0: raise Error("Cannot close owned trace descriptor")
    var f = TuringPrefillFixture(args[1],0,True,True)
    f.trace_projections = Bool(stages)
    var prompt = "Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences."
    if index == 3:
        prompt = ("A knowledge graph links documents, entities and the passages that support each connection. Sources remain available for citation. New material is appended through a queue, checked for duplicate content, and embedded in the same vector space. Failed imports can be inspected and retried safely. "*20)+"Summarize the reliability principles in a detailed paragraph."
    var tokens = inputs(f,prompt)
    f.reset()
    f.native.context.synchronize()
    var range_name = String("aesir.fixture.prefill")
    var label = range_name.as_c_string_slice()
    _ = push(label.unsafe_ptr())
    try:
        var offset = 0
        while offset < len(tokens)-1:
            var remaining = len(tokens)-1-offset
            var count = 32 if remaining >= 32 else (4 if remaining >= 4 else 1)
            f.step(tokens,offset,count)
            offset += count
        f.step(tokens,offset,1,True)
        f.native.context.synchronize()
    except:
        _ = pop()
        raise
    _ = pop()
    if f.position != len(tokens) or f.sampler.position != len(tokens) or len(f.committed) != len(tokens):
        raise Error("Trace prefill did not commit exact positions")
    for i in range(len(tokens)):
        if f.committed[i] != tokens[i]: raise Error("Trace prefill changed committed token identity")
    var values = logits(f,1)
    f.guards()
    var cache = guarded_cache_digest(f)
    print("TRACE,1,2,"+String(index)+","+String(external_call["getpid",Int32]())+",aesir.fixture.prefill")
    if stages: print("STAGES,1")
    print("STATE,"+String(len(tokens))+","+String(f.position)+","+String(f.sampler.position)+","+String(len(f.committed)))
    for i in range(len(f.committed)): print("INPUT,"+String(i)+","+String(f.committed[i]))
    for i in range(128256): print("LOGIT,"+String(i)+","+String(Float64(values[i])))
    print("ENQUEUE,"+String(f.rope_cache_calls)+","+String(f.elementwise_calls))
    print("CACHE,"+String(len(f.cache)*2)+","+cache)
    print("GUARD,1088,0")
    print("COMPLETE,prefill_trace,128256")
