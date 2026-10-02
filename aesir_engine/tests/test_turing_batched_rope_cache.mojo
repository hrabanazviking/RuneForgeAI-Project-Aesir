"""Complete optional grid-y prefill evidence, actual host calls and cache identity."""
from std.sys import argv
from tests.turing_prefill_fixture import TuringPrefillFixture
from tests.test_turing_model_prefill import invalid_tiles, measure
from tests.guarded_cache_digest import guarded_cache_digest


def main() raises:
    var args = argv()
    if len(args) != 3: raise Error("usage: test_turing_batched_rope_cache MODEL.gguf BATCHED")
    var flag = Int(args[2])
    if flag < 0 or flag > 2: raise Error("Batched rotary/cache flag must be0/1/2")
    var f = TuringPrefillFixture(args[1],0,Bool(flag>0),Bool(flag==2))
    invalid_tiles(f)
    if flag == 2: print("ATTENTION,rope_cache_elementwise_grid,1,32")
    else: print("ATTENTION,rope_cache_grid,"+String(flag)+",32")
    print("META,1,128256,1536,32,f16,8")
    var long_prompt = ("A knowledge graph links documents, entities and the passages that support each connection. Sources remain available for citation. New material is appended through a queue, checked for duplicate content, and embedded in the same vector space. Failed imports can be inspected and retried safely. "*20)+"Summarize the reliability principles in a detailed paragraph."
    var prompts: List[String] = ["What is two plus two? Answer with one word.","Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.","Write one sentence about a silver ship beneath Bifröst.",long_prompt]
    for index in range(4):
        measure(f,index,prompts[index])
        print("ENQUEUE,"+String(index)+","+String(f.rope_cache_calls))
        if flag == 2: print("ELEMENTWISE,"+String(index)+","+String(f.elementwise_calls))
        print("CACHE,"+String(index)+","+String(len(f.cache)*2)+","+guarded_cache_digest(f))
    print("COMPLETE,matrix_model,4,513024,32,8")
