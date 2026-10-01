"""Opt-in actual-call timing, logical traffic, bandwidth and full-logit export.

One owning CUDA context. No production instrumentation or settings changes.
CSV rows are independently consumed by scripts/check_llama3_logits.py.
"""
from std.sys import argv
from std.ffi import external_call
from tests.measurement_kernels import copy_words
from std.math import isfinite
from core.llama3_cuda import Llama3CUDASession
from core.sampling_config import NativeSamplingConfig
from loader.packed_gguf import PackedTensor, packed_row_bytes

def seconds() raises -> Float64:
    var stamp = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), stamp.unsafe_ptr()) != 0:
        raise Error("Cannot measure monotonic clock")
    if stamp[0] < 0 or stamp[1] < 0 or stamp[1] >= 1000000000:
        raise Error("Invalid monotonic timestamp")
    return Float64(stamp[0]) + Float64(stamp[1]) / 1000000000.0


def checked_span(t: PackedTensor, file_size: Int) raises -> Int:
    if t.offset < 0 or t.byte_count <= 0 or t.offset > file_size or t.byte_count > file_size - t.offset:
        raise Error("Unvalidated packed tensor traffic span")
    return t.byte_count


def traffic(session: Llama3CUDASession) raises:
    var projections = 0
    var norms = checked_span(session.model.tensors["output_norm.weight"], Int(session.model.source.file_size))
    for layer in range(session.profile.layer_count):
        var prefix = "blk." + String(layer) + "."
        for name in ["attn_q.weight", "attn_k.weight", "attn_v.weight", "attn_output.weight", "ffn_gate.weight", "ffn_up.weight", "ffn_down.weight"]:
            var size = checked_span(session.model.tensors[prefix + name], Int(session.model.source.file_size))
            if projections > 9223372036854775807 - size:
                raise Error("Projection traffic overflow")
            projections += size
        norms += checked_span(session.model.tensors[prefix + "attn_norm.weight"], Int(session.model.source.file_size))
        norms += checked_span(session.model.tensors[prefix + "ffn_norm.weight"], Int(session.model.source.file_size))
    projections += checked_span(session.output_tensor, Int(session.model.source.file_size))
    var embedding = packed_row_bytes(session.embedding_tensor.kind, session.profile.hidden_size)
    var rope = checked_span(session.model.tensors["rope_freqs.weight"], Int(session.model.source.file_size)) * session.profile.layer_count
    var kv_per_position = session.profile.layer_count * session.profile.kv_width() * 4
    print("TRAFFIC," + String(session.model.source.file_size) + "," + String(projections) + "," + String(norms) + "," + String(embedding) + "," + String(rope) + "," + String(kv_per_position))


def bandwidth(mut session: Llama3CUDASession) raises:
    for count in [8388611, 33554437]:
        var total_bytes = count * 8
        if count < 1 or count > 33554440 or total_bytes + 268435456 > Int(session.context.get_memory_info()[0]):
            raise Error("Bandwidth probe exceeds declared headroom")
        var source = session.context.enqueue_create_buffer[DType.uint32](count)
        var target = session.context.enqueue_create_buffer[DType.uint32](count)
        var host = session.context.enqueue_create_host_buffer[DType.uint32](count)
        for i in range(count):
            host[i] = UInt32((i * 131 + i // 251 + 17) % 4294967296)
        session.context.enqueue_copy(source, host)
        target.enqueue_fill(9999)
        for _ in range(3):
            copy_words(session.context, source, target)
        session.context.synchronize()
        for sample in range(10):
            var started = seconds()
            for _ in range(10):
                copy_words(session.context, source, target)
            session.context.synchronize()
            var elapsed = seconds() - started
            if elapsed <= 0 or not isfinite(elapsed):
                raise Error("Invalid bandwidth elapsed time")
            print("BANDWIDTH," + String(count * 4) + "," + String(sample) + ",10," + String(elapsed) + "," + String(Float64(count * 4 * 20) / elapsed / 1000000000.0))
        session.context.enqueue_copy(host, target)
        session.context.synchronize()
        for i in range(count):
            if host[i] != UInt32((i * 131 + i // 251 + 17) % 4294967296):
                raise Error("Bandwidth copy did not execute all elements")
        print("BANDWIDTH_CHECK," + String(count) + ",0")


def measure_case(mut session: Llama3CUDASession, case_index: Int, prompt: String, emit_logits: Bool) raises:
    session.reset()
    session.configure_control(120000)
    var started = seconds()
    session.begin_turn(prompt, "You are concise.", 128)
    var prefill = seconds() - started
    var input = session.conversation_tokens()
    if emit_logits:
        for token in input:
            print("INPUT," + String(case_index) + "," + String(token))
        var staging = session.context.enqueue_create_host_buffer[DType.float32](session.buffers.elements)
        session.context.enqueue_copy(staging, session.activations)
        session.context.synchronize()
        for i in range(session.profile.vocabulary_size):
            var value = staging[session.logits_offset + i]
            if not isfinite(value):
                raise Error("Exported model logit is nonfinite")
            print("LOGIT," + String(case_index) + "," + String(i) + "," + String(value))
    var decode_start = seconds()
    var first_visible: Float64 = -1
    var body = String("")
    var steps = 0
    while session.generating:
        var piece = session.next_chunk()
        if first_visible < 0 and piece.byte_length() > 0:
            first_visible = seconds() - decode_start
        body += piece
        steps += 1
    var decode = seconds() - decode_start
    if body.byte_length() == 0 or session.finish_reason != "length" and session.finish_reason != "eos":
        raise Error("Measured generation did not complete")
    # Export and print overhead is outside the two timed actual-call intervals.
    print("CASE," + String(case_index) + "," + String(Int(emit_logits)) + "," + String(session.prompt_tokens) + "," + String(session.generated_tokens) + "," + String(prefill) + "," + String(decode) + "," + String(first_visible) + "," + String(steps) + "," + session.finish_reason)


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_cuda_measurement MODEL.gguf")
    var session = Llama3CUDASession(args[1], 4096, prefix_cache=False, prefill_batch=4)
    if session.profile.name != "3B" or session.profile.hidden_size != 3072 or session.profile.vocabulary_size != 128256:
        raise Error("This measurement fixture requires strict Llama 3.2 3B")
    print("META,1," + String(session.profile.vocabulary_size) + ",4096,4,f16")
    traffic(session)
    bandwidth(session)
    var long_prompt = ("A knowledge graph links documents, entities and the passages that support each connection. Sources remain available for citation. New material is appended through a queue, checked for duplicate content, and embedded in the same vector space. Failed imports can be inspected and retried safely. " * 20) + "Summarize the reliability principles in a detailed paragraph."
    var prompts: List[String] = [
        "What is two plus two? Answer with one word.",
        "Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.",
        "Write one sentence about a silver ship beneath Bifröst.",
        long_prompt,
    ]
    for case_index in range(len(prompts)):
        # The first actual generation warms compiled shapes; preserve its logits.
        measure_case(session, case_index, prompts[case_index], True)
        for _ in range(3):
            measure_case(session, case_index, prompts[case_index], False)
    print("PASS,measurement,4,16,513024")
