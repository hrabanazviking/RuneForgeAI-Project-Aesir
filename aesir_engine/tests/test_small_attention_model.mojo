"""Explicit bounded small-score model prefill; controls/trace/replay remain closed."""
from std.sys import argv
from tests.turing_prefill_fixture import TuringPrefillFixture
from tests.test_turing_model_prefill import invalid_tiles,measure
from tests.guarded_cache_digest import guarded_cache_digest
from tests.turing_replay_plan import FixtureReplayPlan
from tests.turing_checkpoint_replay import restore


def closed_features(mut f: TuringPrefillFixture) raises:
    var tokens = List[Int]()
    for _ in range(32): tokens.append(1)
    var activation = Int(f.activations.unsafe_ptr())
    var cache = Int(f.cache.unsafe_ptr())
    var weights = Int(f.native.weights.unsafe_ptr())
    var replay_tokens = List[Int]()
    replay_tokens.append(1)
    var replay_tiles = List[Int]()
    replay_tiles.append(1)
    var replay = FixtureReplayPlan(0,weights,Int(f.native.activations.unsafe_ptr()),
        Int(f.native.cache.unsafe_ptr()),replay_tokens,replay_tiles,1,f.native.sampler.config,UInt64(0))
    for feature in range(12):
        if feature == 2:f.trace_projections = True
        elif feature == 3:f.fused_controls = True
        elif feature == 4:f.fused_tracing = True
        elif feature == 5:f.down128_controls = True
        elif feature == 6:f.down128_tracing = True
        elif feature == 7:f.fused_attention = False
        elif feature == 8:f.down128 = False
        elif feature == 9:f.batched_elementwise = False
        elif feature == 10:f.batched_rope_cache = False
        var refused = False
        try:
            if feature == 0:f.configure_control(1)
            elif feature == 1:f.start_control()
            elif feature == 11:restore(f,replay)
            else:f.step(tokens,0,32)
        except:refused = True
        f.trace_projections = False
        f.fused_controls = False
        f.fused_tracing = False
        f.down128_controls = False
        f.down128_tracing = False
        f.fused_attention = True
        f.down128 = True
        f.batched_elementwise = True
        f.batched_rope_cache = True
        if not refused or not f.small_attention or f.execution_strategy() != 5 or not f.healthy or not f.native.healthy or f.position != 0 or f.native.position != 0 or f.sampler.position != 0 or f.native.sampler.position != 0 or len(f.committed) != 0 or len(f.native.conversation_tokens()) != 0 or f.control.enabled() or f.control.reset_required or f.down128_calls != 0 or f.rope_cache_calls != 0 or f.elementwise_calls != 0 or f.fused_attention_calls != 0 or f.small_attention_calls != 0 or f.original_attention_queries != 0:
            raise Error("Ungated small feature changed owner state/counters")
        if Int(f.activations.unsafe_ptr()) != activation or Int(f.cache.unsafe_ptr()) != cache or Int(f.native.weights.unsafe_ptr()) != weights:
            raise Error("Ungated small feature changed allocations")
    f.guards()


def main() raises:
    var args = argv()
    if len(args) == 3:
        if args[2] == "reject-fused":
            var invalid = TuringPrefillFixture(args[1],0,True,True,True,False,False,False,False,False,True)
            raise Error("Small attention without fused capability admitted")
        if args[2] == "reject-controls":
            var invalid = TuringPrefillFixture(args[1],0,True,True,True,False,False,True,True,False,True)
            raise Error("Small attention controls admitted")
        if args[2] == "reject-tracing":
            var invalid = TuringPrefillFixture(args[1],0,True,True,True,False,False,True,False,True,True)
            raise Error("Small attention tracing admitted")
        if args[2] == "reject-down":
            var invalid = TuringPrefillFixture(args[1],0,True,True,False,False,False,True,False,False,True)
            raise Error("Small attention without down capability admitted")
        if args[2] == "reject-precision":
            var invalid = TuringPrefillFixture(args[1],1,True,True,True,False,False,True,False,False,True)
            raise Error("Small attention precision admitted")
        if args[2] == "reject-batched":
            var invalid = TuringPrefillFixture(args[1],0,False,True,True,False,False,True,False,False,True)
            raise Error("Small attention without rotary capability admitted")
    if len(args) != 2:raise Error("usage: test_small_attention_model MODEL.gguf")
    var f = TuringPrefillFixture(args[1],0,True,True,True,False,False,True,False,False,True)
    invalid_tiles(f)
    closed_features(f)
    print("ATTENTION,rope_cache_elementwise_down128_small,1,32")
    print("META,1,128256,1536,32,f16,8")
    print("ADMISSION,5,12,0")
    var long_prompt = ("A knowledge graph links documents, entities and the passages that support each connection. Sources remain available for citation. New material is appended through a queue, checked for duplicate content, and embedded in the same vector space. Failed imports can be inspected and retried safely. "*20)+"Summarize the reliability principles in a detailed paragraph."
    var prompts: List[String] = ["What is two plus two? Answer with one word.","Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.","Write one sentence about a silver ship beneath Bifröst.",long_prompt]
    for index in range(4):
        measure(f,index,prompts[index])
        print("ENQUEUE,"+String(index)+","+String(f.rope_cache_calls))
        print("ELEMENTWISE,"+String(index)+","+String(f.elementwise_calls))
        print("DOWN_ROWS128,"+String(index)+","+String(f.down128_calls))
        print("SMALL_ATTENTION,"+String(index)+","+String(f.small_attention_calls)+","+String(f.original_attention_queries))
        print("FUSED_ATTENTION,"+String(index)+","+String(f.fused_attention_calls)+","+String(f.original_attention_queries))
        print("CACHE,"+String(index)+","+String(len(f.cache)*2)+","+guarded_cache_digest(f))
    print("COMPLETE,matrix_model,4,513024,32,8")
