"""Explicit fused four/32 attention full model, original single-token path."""
from std.sys import argv
from tests.turing_prefill_fixture import TuringPrefillFixture
from tests.test_turing_model_prefill import invalid_tiles,measure
from tests.guarded_cache_digest import guarded_cache_digest


def closed_features(mut f: TuringPrefillFixture) raises:
    var tokens = List[Int]()
    for _ in range(32):tokens.append(1)
    var activation = Int(f.activations.unsafe_ptr())
    var cache = Int(f.cache.unsafe_ptr())
    var weights = Int(f.native.weights.unsafe_ptr())
    for feature in range(3):
        var refused = False
        if feature == 2:f.trace_projections = True
        try:
            if feature == 0:f.configure_control(1)
            elif feature == 1:f.start_control()
            else:f.step(tokens,0,32)
        except:refused = True
        f.trace_projections = False
        if not refused or not f.healthy or not f.native.healthy or f.position != 0 or f.sampler.position != 0 or len(f.committed) != 0 or f.control.enabled() or f.down128_calls != 0 or f.rope_cache_calls != 0 or f.elementwise_calls != 0 or f.fused_attention_calls != 0 or f.original_attention_queries != 0:
            raise Error("Ungated fused feature changed owner state/counters")
        if Int(f.activations.unsafe_ptr()) != activation or Int(f.cache.unsafe_ptr()) != cache or Int(f.native.weights.unsafe_ptr()) != weights:
            raise Error("Ungated fused feature changed allocations")
    f.guards()


def main() raises:
    var args = argv()
    if len(args) == 3 and args[2] == "reject-flags":
        var invalid = TuringPrefillFixture(args[1],0,True,True,False,False,False,True)
        raise Error("Invalid fused flags were admitted")
    if len(args) == 3 and args[2] == "reject-controls":
        var invalid = TuringPrefillFixture(args[1],0,True,True,True,True,False,True)
        raise Error("Invalid fused control capability was admitted")
    if len(args) == 3 and args[2] == "reject-tracing":
        var invalid = TuringPrefillFixture(args[1],0,True,True,True,False,True,True)
        raise Error("Invalid fused tracing capability was admitted")
    if len(args) != 2:raise Error("usage: test_fused_attention_model MODEL.gguf")
    var f = TuringPrefillFixture(args[1],0,True,True,True,False,False,True)
    invalid_tiles(f)
    closed_features(f)
    print("ATTENTION,rope_cache_elementwise_down128_fused,1,32")
    print("META,1,128256,1536,32,f16,8")
    print("ADMISSION,4,3,0")
    var long_prompt = ("A knowledge graph links documents, entities and the passages that support each connection. Sources remain available for citation. New material is appended through a queue, checked for duplicate content, and embedded in the same vector space. Failed imports can be inspected and retried safely. "*20)+"Summarize the reliability principles in a detailed paragraph."
    var prompts: List[String] = ["What is two plus two? Answer with one word.","Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.","Write one sentence about a silver ship beneath Bifröst.",long_prompt]
    for index in range(4):
        measure(f,index,prompts[index])
        print("ENQUEUE,"+String(index)+","+String(f.rope_cache_calls))
        print("ELEMENTWISE,"+String(index)+","+String(f.elementwise_calls))
        print("DOWN_ROWS128,"+String(index)+","+String(f.down128_calls))
        print("FUSED_ATTENTION,"+String(index)+","+String(f.fused_attention_calls)+","+String(f.original_attention_queries))
        print("CACHE,"+String(index)+","+String(len(f.cache)*2)+","+guarded_cache_digest(f))
    print("COMPLETE,matrix_model,4,513024,32,8")
