"""HIP Gemma 4 prefix-cache proof (HS-4): the Gemma session keeps the
Llama 3 session's exact-prefix discipline on the HIP device layer (gfx1151).

One session executes cache-disabled and cache-enabled sequences. Disabled
execution recomputes every prompt token and overwrites all accessed KV
slots. This proves exact reuse on the supplied real model, not arbitrary
model/logit equivalence.
"""
from std.sys import argv
from core.gemma4_cuda import Gemma4CUDASession
from core.sampling_config import NativeSamplingConfig


def sequence(mut session: Gemma4CUDASession, enabled: Bool) raises -> List[String]:
    session.prefix_cache = enabled
    session.cached_tokens.clear()
    var replies = List[String]()
    var prompts: List[String] = [
        "What is two plus two? Answer with one word.",
        "What is two plus two? Answer with one word.",
        "What is two plus three? Answer with one word.",
        "Write one short sentence about a silver ship.",
        "Write one short sentence about a silver ship.",
    ]
    for i in range(len(prompts)):
        print("gemma prefix case", i, "enabled", enabled)
        session.reset()
        session.configure_sampling(NativeSamplingConfig())
        session.configure_control(30000)
        session.begin_turn(prompts[i], "You are concise.", 16)
        if enabled and i == 1 and session.reused_prompt_tokens != session.prompt_tokens - 1:
            raise Error("Repeated Gemma prompt did not reuse all validated prefix slots")
        if enabled and i == 2 and (session.reused_prompt_tokens <= 1
                or session.reused_prompt_tokens >= session.prompt_tokens - 1):
            raise Error("Diverging Gemma prompt reused a mismatched position")
        if enabled and i == 4 and session.reused_prompt_tokens != session.prompt_tokens - 1:
            raise Error("Repeated Gemma sentence prompt did not reuse all validated prefix slots")
        if not enabled and session.reused_prompt_tokens != 0:
            raise Error("Disabled Gemma prefix cache reused KV")
        var text = String("")
        while session.generating:
            text += session.next_chunk()
        replies.append(text + "|" + session.finish_reason + "|" + String(session.generated_tokens))
    return replies^


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_hip_gemma4_prompt_prefix <real-model.gguf>")
    var session = Gemma4CUDASession(args[1], 512, prefix_cache=False, api="hip")
    var fresh = sequence(session, False)
    var cached = sequence(session, True)
    if len(fresh) != len(cached):
        raise Error("Cached/fresh case counts differ")
    for i in range(len(fresh)):
        if fresh[i] != cached[i]:
            raise Error("Cached and fresh Gemma HIP replies differ at case " + String(i))
    for i in range(len(cached)):
        print("gemma hip reply", i, "::", cached[i])
    print("PASS: five cached/fresh Gemma 4 HIP replies, repeat/divergence isolation, disabled-cache zero reuse")
