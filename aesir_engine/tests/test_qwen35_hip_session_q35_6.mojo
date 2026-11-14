# tests/test_qwen35_hip_session_q35_6.mojo
# Q35-6: in-process reference for the Qwen35 HIP serve session.
#
# Drives Qwen35HipSession with EXACTLY the call sequence
# serve_loaded's OpenAI route uses (the Q35-4a pattern), with
# greedy sampling (NativeSamplingConfig defaults: temperature 0,
# the serve's own defaults per Q35-4b). Proves on the fixture:
#  (a) two resident turns on ONE device-resident state (R1, R2);
#  (b) after reset(), turn 1 reproduces exactly (the executor's
#      position-0 state wipe);
#  (c) a fresh session reproduces R1 + resident R2 exactly;
#  (d) STATELESS SNAPSHOT REUSE: after reset(), a begin_turn
#      with the full resent history restores the turn-1 snapshot
#      (status().reused_prompt_tokens == turn-1 boundary) and
#      its reply equals resident R2 exactly -- snapshots compose
#      with the HIP session (executor seam proven bit-exact in
#      the Q35-6 executor test (f)).
#
# Usage: test_qwen35_hip_session_q35_6 <qwen35_forward.gguf>

from std.sys import argv

from loader.packed_gguf import PackedGGUF  # direct loader import anchors the package root (Q35-1 lesson)
from qwen35_hip_session import Qwen35HipSession
from core.sampling_config import NativeSamplingConfig


def esc(text: String) -> String:
    return text.replace("\n", "<NL>")


def run_turn(mut session: Qwen35HipSession, prompt: String, system: String, max_tokens: Int) raises -> String:
    session.configure_sampling(NativeSamplingConfig())
    session.configure_output("")
    session.configure_tool("", "")
    session.configure_control(30000, -1)
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
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_qwen35_hip_session_q35_6 <qwen35_forward.gguf>")
    var system = String("You are a toy test assistant.")
    var u1 = String("alpha bravo charlie")
    var u2 = String("delta echo foxtrot")
    var max_tokens = 16

    var session = Qwen35HipSession(args[1], 512)
    session.reset()
    var r1 = run_turn(session, "User: " + u1 + "\n", system, max_tokens)
    print("R1=" + esc(r1))
    print("STREAM1=" + stream_text(session))
    var pos1 = session.status().position
    print("POS1=" + String(pos1))
    var r2 = run_turn(session, u2, "", max_tokens)
    print("R2=" + esc(r2))
    print("STREAM2=" + stream_text(session))
    print("POS2=" + String(session.status().position))
    if r1 == "" or r2 == "":
        raise Error("empty reply from the qwen35 HIP session")
    print("PASS (a): two resident turns on one device-resident state")
    session.reset()
    var r1b = run_turn(session, "User: " + u1 + "\n", system, max_tokens)
    print("R1_RESET=" + esc(r1b))
    if r1b != r1:
        raise Error("turn 1 after reset diverged from the first run")
    print("PASS (b): turn 1 after reset reproduces exactly")
    var fresh = Qwen35HipSession(args[1], 512)
    fresh.reset()
    var fr1 = run_turn(fresh, "User: " + u1 + "\n", system, max_tokens)
    var fr2 = run_turn(fresh, u2, "", max_tokens)
    if fr1 != r1 or fr2 != r2:
        raise Error("fresh HIP session diverged from the resident reference")
    print("PASS (c): fresh session reproduces R1 and resident R2 exactly")
    # (d) stateless snapshot reuse: reset, then resent full history.
    session.reset()
    var resent = "User: " + u1 + "\n" + "Assistant: " + r1 + "\n" + "User: " + u2 + "\n"
    var sr2 = run_turn(session, resent, system, max_tokens)
    var reused = session.status().reused_prompt_tokens
    print("R2_STATELESS=" + esc(sr2))
    print("STATELESS_REUSED=" + String(reused) + " POS1=" + String(pos1))
    if sr2 != r2:
        raise Error("stateless snapshot-reuse reply diverged from resident R2")
    if reused != pos1:
        raise Error("stateless reuse did not restore the turn-1 snapshot boundary")
    print("PASS (d): stateless text-extension restored the turn-1 snapshot; reply == resident R2")
    print("Q35-6 qwen35 HIP session reference: ALL PASS")
