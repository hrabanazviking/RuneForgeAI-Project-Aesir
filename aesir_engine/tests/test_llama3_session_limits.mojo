"""Opt-in real-model CUDA state tests; forced tokens test bounds, not fluency."""
from std.sys import argv
from core.llama3_cuda import Llama3CUDASession

def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_llama3_session_limits <model.gguf>")
    var session = Llama3CUDASession(args[1], 64)
    var x = session.tokenizer.encode("x")[0]
    session.begin_turn("Hello.", "", 1)
    session.pending_token = x
    _ = session.next_chunk()
    if session.generating or session.finish_reason != "length" or session.generated_tokens != 1 or session.position != session.prompt_tokens + 2:
        raise Error("One-token completion/closing state failed")
    session.begin_turn("Continue.", "", 8192)
    while session.generating:
        session.pending_token = x
        _ = session.next_chunk()
    if session.position != 64 or session.finish_reason != "context_exhausted":
        raise Error("8K reply ceiling over a shorter remaining context failed")
    var rejected = False
    try:
        session.begin_turn("Again.", "", 1)
    except:
        rejected = True
    if not rejected or session.position != 64 or not session.healthy:
        raise Error("Rejected prompt changed retained state")
    session.healthy = False
    rejected = False
    try:
        _ = session.forward(x)
    except:
        rejected = True
    if not rejected:
        raise Error("Poisoned session was reused")
    print("PASS: length closure, context exhaustion, atomic prompt rejection and poisoned-session rejection")
