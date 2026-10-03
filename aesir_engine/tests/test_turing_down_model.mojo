"""Down-only128 complete model, actual selected calls and original cache identity."""
from std.sys import argv
from tests.turing_prefill_fixture import TuringPrefillFixture
from tests.test_turing_model_prefill import invalid_tiles, measure
from tests.guarded_cache_digest import guarded_cache_digest


def closed_features(mut f: TuringPrefillFixture) raises:
    var tokens = List[Int]()
    for _ in range(32): tokens.append(1)
    for feature in range(2):
        var refused = False
        if feature == 1: f.trace_projections = True
        try:
            if feature == 0: f.configure_control(-1 if f.down128_controls else 1)
            else: f.step(tokens,0,32)
        except: refused = True
        f.trace_projections = False
        if not refused or not f.healthy or f.position != 0 or f.sampler.position != 0 or len(f.committed) != 0 or f.control.enabled() or f.down128_calls != 0 or f.rope_cache_calls != 0 or f.elementwise_calls != 0:
            raise Error("Ungated down128 feature changed pre-step owner state")
    f.guards()


def main() raises:
    var args = argv()
    if len(args) == 3 and args[2] == "reject-flags":
        var invalid = TuringPrefillFixture(args[1],0,False,False,True)
        raise Error("Invalid down flags were admitted")
    if len(args) == 3 and args[2] == "reject-controls":
        var invalid = TuringPrefillFixture(args[1],0,False,False,False,True)
        raise Error("Invalid control capability was admitted")
    if len(args) != 2 and (len(args) != 3 or args[2] != "control-capable"):
        raise Error("usage: test_turing_down_model MODEL.gguf [control-capable]")
    var f = TuringPrefillFixture(args[1],0,True,True,True,len(args)==3)
    invalid_tiles(f)
    closed_features(f)
    print("ATTENTION,rope_cache_elementwise_down128,1,32")
    print("META,1,128256,1536,32,f16,8")
    print("ADMISSION,3,2,0")
    if f.down128_controls: print("CONTROL_CAPABLE,3,1")
    var long_prompt = ("A knowledge graph links documents, entities and the passages that support each connection. Sources remain available for citation. New material is appended through a queue, checked for duplicate content, and embedded in the same vector space. Failed imports can be inspected and retried safely. "*20)+"Summarize the reliability principles in a detailed paragraph."
    var prompts: List[String] = ["What is two plus two? Answer with one word.","Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.","Write one sentence about a silver ship beneath Bifröst.",long_prompt]
    for index in range(4):
        measure(f,index,prompts[index])
        print("ENQUEUE,"+String(index)+","+String(f.rope_cache_calls))
        print("ELEMENTWISE,"+String(index)+","+String(f.elementwise_calls))
        print("DOWN_ROWS128,"+String(index)+","+String(f.down128_calls))
        print("CACHE,"+String(index)+","+String(len(f.cache)*2)+","+guarded_cache_digest(f))
    print("COMPLETE,matrix_model,4,513024,32,8")
