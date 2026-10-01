"""Physical same-model cached/fresh equivalence, sampling and timeout recovery.

One session executes cache-disabled and cache-enabled sequences. Disabled
execution recomputes every prompt token and overwrites all accessed KV slots. This proves
exact reuse on the supplied real model, not arbitrary model/logit equivalence.
"""
from std.sys import argv
from core.llama3_cuda import Llama3CUDASession
from core.sampling_config import NativeSamplingConfig


def sequence(mut session: Llama3CUDASession, enabled: Bool) raises -> List[String]:
    session.prefix_cache = enabled
    session.cached_tokens.clear()
    var replies = List[String]()
    var prompts: List[String] = [
        "What is two plus two? Answer with one word.",
        "What is two plus two? Answer with one word.",
        "What is two plus three? Answer with one word.",
        "Write one short sentence about a silver ship.",
        "Write one short sentence about a silver ship.",
        "What is two plus two? Answer with one word.",
    ]
    for i in range(len(prompts)):
        print("prefix case", i, "enabled", enabled)
        session.reset()
        var sampling = NativeSamplingConfig()
        if i == 3 or i == 4:
            sampling.temperature = 0.8
            sampling.top_k = 20
            sampling.repetition_penalty = 1.2
            sampling.seed = 123
        session.configure_sampling(sampling)
        session.configure_control(30000)
        var system = "You are concise." if i < 5 else "Answer accurately."
        session.begin_turn(prompts[i], system, 16)
        if enabled and i == 1 and session.reused_prompt_tokens != session.prompt_tokens - 1:
            raise Error("Repeated prompt did not reuse all validated prefix slots")
        if enabled and i == 2 and (session.reused_prompt_tokens <= 1
                or session.reused_prompt_tokens >= session.prompt_tokens - 1):
            raise Error("Diverging prompt reused a mismatched position")
        if enabled and i == 5:
            var header = List[Int]()
            if session.profile.add_bos:
                header.append(session.tokenizer.vocabulary.bos_token_id)
            session.tokenizer.append_header(header, "system")
            if session.reused_prompt_tokens != len(header):
                raise Error("Changed system reused content beyond its common header")
        if not enabled and session.reused_prompt_tokens != 0:
            raise Error("Disabled prefix cache reused KV")
        var text = String("")
        while session.generating:
            text += session.next_chunk()
        replies.append(text + "|" + session.finish_reason + "|" + String(session.generated_tokens))
    session.reset()
    session.configure_control(1)
    var timed_out: Bool
    try:
        session.begin_turn("Write a long detailed sea adventure.", "Answer accurately.", 16)
        while session.generating:
            _ = session.next_chunk()
        timed_out = session.finish_reason == "timeout"
    except:
        timed_out = session.finish_reason == "timeout" and session.reset_required
    if not timed_out or not session.healthy:
        raise Error("Prefix prefill did not preserve timeout/reset recovery")
    session.reset()
    session.configure_control(30000)
    session.begin_turn(prompts[5], "Answer accurately.", 16)
    var text = String("")
    while session.generating:
        text += session.next_chunk()
    replies.append(text + "|" + session.finish_reason + "|" + String(session.generated_tokens))
    return replies^


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_cuda_prompt_prefix <real-model.gguf>")
    var session = Llama3CUDASession(args[1], 512, prefix_cache=False)
    var fresh = sequence(session, False)
    var cached = sequence(session, True)
    if len(fresh) != len(cached):
        raise Error("Cached/fresh case counts differ")
    for i in range(len(fresh)):
        if fresh[i] != cached[i]:
            raise Error("Cached and fresh CUDA replies differ at case " + String(i))
    print("PASS: seven cached/fresh CUDA replies, divergence/system isolation, sampled replay and timeout/reset recovery")
