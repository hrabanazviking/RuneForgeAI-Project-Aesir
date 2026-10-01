"""Real-model full-logit, seeded completion and restore tile equivalence.

Same owning CUDA context; sequential native execution is a regression reference,
not an independent external full-model oracle. Pure span tests are separate.
"""
from std.sys import argv
from std.math import isfinite
from core.llama3_cuda import Llama3CUDASession
from core.sampling_config import NativeSamplingConfig


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_cuda_prefill MODEL.gguf")
    var session = Llama3CUDASession(args[1], 512, prefix_cache=False, prefill_batch=4)
    var staging = session.context.enqueue_create_host_buffer[DType.float32](session.buffers.elements)
    var reference = List[Float32]()
    var replies = List[String]()
    var saved = List[Int]()
    var prompts: List[String] = [
        "What is two plus two? Answer with one word.",
        "Write one sentence about a silver ship beneath Bifröst.",
        "Memory must preserve source evidence. " * 16 + "Explain the principle briefly.",
    ]
    for batch in [1, 4]:
        session.prefill_batch = batch
        for index in range(5):
            session.reset()
            var config = NativeSamplingConfig()
            if index >= 3:
                config.temperature = 0.8
                config.top_k = 20
                config.repetition_penalty = 1.2
                config.seed = 123
            session.configure_sampling(config)
            session.configure_control(120000)
            session.begin_turn(prompts[index % 3], "You are concise.", 12)
            session.context.enqueue_copy(staging, session.activations)
            session.context.synchronize()
            for token in range(session.profile.vocabulary_size):
                var value = staging[session.logits_offset + token]
                if not isfinite(value):
                    raise Error("Prefill logits are non-finite")
                if batch == 1:
                    reference.append(value)
                elif value != reference[index * session.profile.vocabulary_size + token]:
                    raise Error("Batched prefill changed a full-model logit")
            var text = String("")
            while session.generating:
                text += session.next_chunk()
            var result = text + "|" + session.finish_reason + "|" + String(session.generated_tokens) + "|" + String(session.position)
            if batch == 1:
                replies.append(result)
                if index == 0:
                    saved = session.conversation_tokens()
            elif result != replies[index]:
                raise Error("Batched prefill changed seeded or greedy completion")
    var restored_reply = String("")
    for batch in [1, 4]:
        session.reset()
        session.prefill_batch = batch
        session.configure_sampling(NativeSamplingConfig())
        session.restore_conversation(saved, 0)
        session.configure_control(120000)
        session.begin_turn("Repeat your previous answer in one word.", "", 8)
        var text = String("")
        while session.generating:
            text += session.next_chunk()
        if batch == 1:
            restored_reply = text
        elif text != restored_reply:
            raise Error("Batched exact-token restore changed continuation")
    session.reset()
    session.prefill_batch = 4
    var invalid = List[Int]()
    for token in [1, 2, 3, -1]:
        invalid.append(token)
    var rejected = False
    try:
        session.prefill_four(invalid, 0)
    except:
        rejected = True
    if not rejected or not session.healthy or session.position != 0 or session.sampler.position != 0:
        raise Error("Invalid prefill mutated healthy session state")
    print("PASS: 641280 exact sequential/batched logits, five greedy/seeded completions, exact-token restore continuation and mutation-free invalid prefill")
