# Q35-6b T2 long-T1 test: HIP session, bench prompts, T1 with
# max_tokens=32 (the Q35-4b CPU bench's exact shape), then
# resident T2 with max_tokens=12. If T1 == CPU R1 (32 tokens)
# and T2 starts the CPU R2 continuation, the earlier derailment
# was a truncated-T1 stream artifact, not a device defect.

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


def main() raises:
    var path = String("/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf")
    var sys = String("You are a helpful assistant.")
    var u1 = String("What is the capital of France? Name one famous museum there.")
    var u2 = String("What language do most people speak in that city?")
    var a = Qwen35HipSession(path, 4096)
    var r1 = run_turn(a, String("User: ") + u1 + String("\n"), sys, 32)
    print("T1(32) reply=" + esc(r1))
    print("T1 pos=" + String(a.status().position))
    var r2 = run_turn(a, u2, String(""), 12)
    print("T2(12) RESIDENT reply=" + esc(r2))
    print("T2 LONG DONE")
