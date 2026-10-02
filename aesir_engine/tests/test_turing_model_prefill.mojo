"""Isolated complete-model prefill collection; quality is independently gated."""
from std.sys import argv
from std.math import isfinite
from tests.turing_prefill_fixture import TuringPrefillFixture
from tests.test_packed_matrix import seconds


def invalid_tiles(mut f: TuringPrefillFixture) raises:
    var tokens = List[Int]()
    for _ in range(32): tokens.append(1)
    for invalid in range(8):
        var count = 32
        var start = 0
        var logits = False
        if invalid == 0: count = 0
        elif invalid == 1: count = 33
        elif invalid == 2: start = -1
        elif invalid == 3: tokens[31] = -1
        elif invalid == 4:
            count = 4
            logits = True
        elif invalid == 5: f.position = 1505
        elif invalid == 6: f.healthy = False
        else: f.layout.elements += 1
        var before = f.position
        var healthy = f.healthy
        var rejected = False
        try: f.step(tokens,start,count,logits)
        except: rejected = True
        if not rejected or f.position != before or f.healthy != healthy or f.sampler.position != 0 or len(f.committed) != 0:
            raise Error("Invalid model tile mutated its owning fixture")
        tokens[31] = 1
        f.position = 0
        f.healthy = True
        if invalid == 7: f.layout.elements -= 1
    f.guards()


def inputs(f: TuringPrefillFixture,prompt: String) raises -> List[Int]:
    var tokens = List[Int]()
    if f.native.profile.add_bos: tokens.append(f.native.tokenizer.vocabulary.bos_token_id)
    f.native.tokenizer.append_message(tokens,"system","You are concise.")
    f.native.tokenizer.append_message(tokens,"user",prompt)
    f.native.tokenizer.append_header(tokens,"assistant")
    if len(tokens) < 2 or len(tokens) > 1536:
        raise Error("Model fixture prompt does not fit admitted context")
    return tokens^


def run(mut f: TuringPrefillFixture,tokens: List[Int],mode: Int) raises -> Float64:
    if mode == 0: f.native.reset()
    else: f.reset()
    var start = seconds()
    var i = 0
    while i < len(tokens)-1:
        var remaining = len(tokens)-1-i
        if mode == 0:
            if remaining >= 4:
                f.native.prefill_four(tokens,i)
                i += 4
            else:
                _ = f.native.forward(tokens[i],False)
                i += 1
        else:
            var count = 32 if remaining >= 32 else (4 if remaining >= 4 else 1)
            f.step(tokens,i,count)
            i += count
    if mode == 0: _ = f.native.forward(tokens[i],True)
    else: f.step(tokens,i,1,True)
    var elapsed = seconds()-start
    if elapsed <= 0 or not isfinite(elapsed): raise Error("Invalid actual prefill timing")
    var position = f.native.position if mode == 0 else f.position
    var sampler_position = f.native.sampler.position if mode == 0 else f.sampler.position
    var committed = f.native.conversation_tokens() if mode == 0 else f.committed.copy()
    if position != len(tokens) or sampler_position != len(tokens) or len(committed) != len(tokens):
        raise Error("Matrix/reference prefill did not commit exact positions")
    for j in range(len(tokens)):
        if committed[j] != tokens[j]: raise Error("Model prefill changed committed token identity")
    return elapsed


def logits(f: TuringPrefillFixture,mode: Int) raises -> List[Float32]:
    var count = len(f.native.activations) if mode == 0 else len(f.activations)
    var h = f.native.context.enqueue_create_host_buffer[DType.float32](count)
    if mode == 0: f.native.context.enqueue_copy(h,f.native.activations)
    else: f.native.context.enqueue_copy(h,f.activations)
    f.native.context.synchronize()
    var offset = f.native.logits_offset if mode == 0 else f.layout.logits+16
    var result = List[Float32]()
    for i in range(128256):
        if not isfinite(h[offset+i]): raise Error("Nonfinite complete model logit")
        result.append(h[offset+i])
    return result^


def measure(mut f: TuringPrefillFixture,index: Int,prompt: String) raises:
    var tokens = inputs(f,prompt)
    var baseline = List[Float32]()
    var matrix = List[Float32]()
    var timings = List[Float64]()
    for sample in range(4):
        for step in range(2):
            var mode = (sample+step)%2
            timings.append(run(f,tokens,mode))
            var values = logits(f,mode)
            if sample == 0:
                if mode == 0: baseline = values^
                else: matrix = values^
            else:
                for i in range(128256):
                    var expected = baseline[i] if mode == 0 else matrix[i]
                    if values[i] != expected: raise Error("Fresh prefill repeat changed a complete logit")
    f.guards()
    print("CASE,"+String(index)+","+String(len(tokens)))
    for i in range(len(tokens)): print("INPUT,"+String(index)+","+String(i)+","+String(tokens[i]))
    for i in range(128256):
        print("LOGIT,"+String(index)+","+String(i)+","+String(Float64(baseline[i]))+","+String(Float64(matrix[i])))
    for sample in range(4):
        for step in range(2):
            var mode = (sample+step)%2
            print("TIME,"+String(index)+","+String(mode)+","+String(sample)+","+String(timings[sample*2+step])+","+String(len(tokens))+",0")
    print("GUARD,"+String(index)+",1088,0")


def main() raises:
    var args = argv()
    if len(args) != 2 and len(args) != 3: raise Error("usage: test_turing_model_prefill MODEL.gguf [ACTIVATION_PRECISION]")
    var precision = Int(args[2]) if len(args) == 3 else 0
    var fixture = TuringPrefillFixture(args[1],precision)
    invalid_tiles(fixture)
    if precision == 0: print("META,1,128256,1536,32,f16,8")
    else: print("META,1,128256,1536,32,f16,"+String(precision)+",8")
    var long_prompt = ("A knowledge graph links documents, entities and the passages that support each connection. Sources remain available for citation. New material is appended through a queue, checked for duplicate content, and embedded in the same vector space. Failed imports can be inspected and retried safely. "*20)+"Summarize the reliability principles in a detailed paragraph."
    var prompts: List[String] = ["What is two plus two? Answer with one word.",
        "Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.",
        "Write one sentence about a silver ship beneath Bifröst.",long_prompt]
    for index in range(4): measure(fixture,index,prompts[index])
    print("COMPLETE,matrix_model,4,513024,32,8")
