# Q35-6b T2 debug: real-file HIP session continuation routes.
# Session A: turn 1, then RESIDENT begin_turn(delta) (no reset).
# Session B: turn 1, reset(), then full-history begin_turn
# (snapshot restore path). Bench prompts; max_tokens=6.

from loader.packed_gguf import PackedGGUF  # anchor (Q35-1 lesson)
from qwen35_hip_session import Qwen35HipSession
from core.sampling_config import NativeSamplingConfig


def esc(text: String) -> String:
    return text.replace("\n", "<NL>")


def run_turn(mut session: Qwen35HipSession, prompt: String, system: String, max_tokens: Int) raises -> String:
    session.configure_sampling(NativeSamplingConfig())
    session.configure_output("")
    session.configure_tool("", "")
    session.configure_control(1800000, -1)
    session.begin_turn(prompt, system, max_tokens)
    var answer = String("")
    while session.status().generating:
        answer += session.next_chunk()
    return answer


def stream_text(session: Qwen35HipSession) -> String:
    var out = String("")
    for token in session.stream:
        out += String(token) + " "
    return out


def main() raises:
    var path = String("/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf")
    var sys = String("You are a helpful assistant.")
    var u1 = String("What is the capital of France? Name one famous museum there.")
    var u2 = String("What language do most people speak in that city?")
    var t1 = String("User: ") + u1 + String("\n")
    var a = Qwen35HipSession(path, 4096)
    var r1a = run_turn(a, t1, sys, 6)
    print("A T1 reply=" + esc(r1a) + " pos=" + String(a.status().position))
    print("A STREAM1=" + stream_text(a))
    var r2a = run_turn(a, u2, String(""), 6)
    print("A T2 RESIDENT reply=" + esc(r2a) + " reused=" + String(a.status().reused_prompt_tokens))
    print("A STREAM2=" + stream_text(a))
    var b = Qwen35HipSession(path, 4096)
    var r1b = run_turn(b, t1, sys, 6)
    print("B T1 reply=" + esc(r1b) + " pos=" + String(b.status().position))
    b.reset()
    var full = t1 + String("Assistant: ") + r1b + String("\nUser: ") + u2 + String("\n")
    var r2b = run_turn(b, full, sys, 6)
    print("B T2 SNAPSHOT reply=" + esc(r2b) + " reused=" + String(b.status().reused_prompt_tokens))
    print("B STREAM2=" + stream_text(b))
    print("T2 DEBUG DONE")
